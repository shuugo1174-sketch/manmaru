import SwiftUI

// 週の振り返り。iPhoneの中のAIが「できたこと・うまくいかなかったこと・来週の一言」を書く。
// AIが使えないときは、数字から決まった形で書く。結果は週ごとにこのiPhoneに保存する。
struct WeeklyReview: Codable, Equatable {
    var good: String
    var hard: String
    var advice: String
    var byAI: Bool
}

enum WeeklyReviewMaker {
    static func load(week: TrackerWeek) -> WeeklyReview? {
        guard let data = UserDefaults.standard.data(forKey: week.cacheKey) else { return nil }
        return try? JSONDecoder().decode(WeeklyReview.self, from: data)
    }

    static func save(_ review: WeeklyReview, week: TrackerWeek) {
        if let data = try? JSONEncoder().encode(review) {
            UserDefaults.standard.set(data, forKey: week.cacheKey)
        }
    }

    static func facts(week: TrackerWeek, feed: TrackerFeed) -> String {
        var lines: [String] = []
        if let from = week.from, let to = week.to { lines.append("期間：\(from)〜\(to)") }
        if let done = week.tasksDone, let total = week.tasksTotal { lines.append("タスク：\(done)/\(total)できた") }
        if let ex = week.plusEx { lines.append("もらったEX：+\(ex)") }
        if let list = week.doneOften, !list.isEmpty { lines.append("よくできたタスク：" + list.joined(separator: "、")) }
        if let list = week.missedOften, !list.isEmpty { lines.append("できなかったことが多いタスク：" + list.joined(separator: "、")) }
        if let gains = week.parameterGains, !gains.isEmpty {
            let text = gains.sorted { $0.key < $1.key }
                .map { "\(feed.parameterLabel(for: $0.key))+\($0.value)" }
                .joined(separator: " ")
            lines.append("パラメータの伸び：" + text)
        }
        if let steps = week.stepsAvg { lines.append("1日の歩数の平均：\(steps)歩") }
        if let weight = week.weightChangeKg { lines.append(String(format: "体重の変化：%+.1fkg", weight)) }
        if let days = week.overCalorieDays { lines.append("カロリーが多すぎた日：\(days)日") }
        if let days = week.lateNightDays { lines.append("夜更かしした日：\(days)日") }
        if let notes = week.chatNotes, !notes.isEmpty { lines.append("今週のシュウゴの様子（チャットより）：" + notes) }
        lines.append("いまのレベル：\(feed.level)")
        return lines.joined(separator: "\n")
    }

    static func make(week: TrackerWeek, feed: TrackerFeed) async -> WeeklyReview {
        let data = facts(week: week, feed: feed)
        let task = """
        シュウゴの1週間をふり返る。次の3行だけを、この形のまま書く。
        できたこと：（1〜2文。具体的に褒める）
        うまくいかなかったこと：（1〜2文。まず「大変だったね」と寄りそう。責めない）
        来週の一言：（「〜してみてはどう？」の形の提案を1つだけ。短く。押しつけない。シュウゴの様子に合わせる）
        """
        if let answer = await ManmaruAI.generate(task: task, prompt: data, timeout: 25),
           let review = parse(answer) {
            return review
        }
        return template(week: week)
    }

    static func parse(_ text: String) -> WeeklyReview? {
        var good = "", hard = "", advice = ""
        for raw in text.split(whereSeparator: \.isNewline) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if let found = Self.value(of: line, label: "できたこと") { good = found }
            else if let found = Self.value(of: line, label: "うまくいかなかったこと") { hard = found }
            else if let found = Self.value(of: line, label: "来週の一言") { advice = found }
        }
        guard !good.isEmpty, !advice.isEmpty else { return nil }
        if hard.isEmpty { hard = "大変な日もあったよね。それでも続けてるのがえらいよ。" }
        return WeeklyReview(good: good, hard: hard, advice: advice, byAI: true)
    }

    private static func value(of line: String, label: String) -> String? {
        guard let range = line.range(of: label) else { return nil }
        var rest = String(line[range.upperBound...])
        while let first = rest.first, "：:　 ".contains(first) { rest.removeFirst() }
        return ManmaruAI.clean(rest)
    }

    static func template(week: TrackerWeek) -> WeeklyReview {
        let done = week.tasksDone ?? 0
        let total = week.tasksTotal ?? 0
        var good = "今週は\(done)/\(total)できたよ。"
        if let list = week.doneOften, let first = list.first { good += "とくに「\(first)」がよく続いたね！" }
        var hard = "大変だった日もあったよね。"
        if let list = week.missedOften, let first = list.first { hard += "「\(first)」はむずかしかったね。責めなくていいよ。" }
        let advice: String
        if let days = week.lateNightDays, days >= 3 {
            advice = "来週は、1日だけ早く寝る日を作ってみてはどう？"
        } else if let first = week.missedOften?.first {
            advice = "「\(first)」を、半分の大きさにしてみてはどう？"
        } else {
            advice = "来週も、自分のペースでひとつずつ進めてみてはどう？"
        }
        return WeeklyReview(good: good, hard: hard, advice: advice, byAI: false)
    }
}

struct WeeklyReviewView: View {
    let week: TrackerWeek
    let feed: TrackerFeed
    @State private var review: WeeklyReview?
    @State private var isWriting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    ManmaruCharacterImage(level: feed.level, size: 72)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("今週のふり返り")
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                        if let from = week.from, let to = week.to {
                            Text("\(from)〜\(to)")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(ManmaruPalette.caption)
                        }
                    }
                }
                if isWriting && review == nil {
                    ProgressView("まんまるが書いてるよ…")
                        .frame(maxWidth: .infinity)
                        .manmaruCard()
                }
                if let review {
                    section("できたこと", review.good, icon: "star.fill", color: ManmaruPalette.yellow)
                    section("うまくいかなかったこと", review.hard, icon: "heart.fill", color: ManmaruPalette.pink)
                    section("来週の一言", review.advice, icon: "leaf.fill", color: ManmaruPalette.green)
                    Text(review.byAI ? "iPhoneの中のAIが書いたよ。" : "数字から書いたよ（AIが使えないとき）。")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(ManmaruPalette.caption)
                    Button {
                        Task { await write(force: true) }
                    } label: {
                        Label(isWriting ? "書き直し中…" : "書き直す", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isWriting)
                }
            }
            .padding(18)
        }
        .background(ManmaruPalette.background)
        .foregroundStyle(.white)
        .font(.system(size: 16, weight: .semibold, design: .rounded))
        .navigationTitle("週の振り返り")
        .toolbarBackground(ManmaruPalette.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task { await write(force: false) }
    }

    private func section(_ title: String, _ text: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(text)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .manmaruCard()
    }

    private func write(force: Bool) async {
        if !force, let saved = WeeklyReviewMaker.load(week: week) {
            review = saved
            return
        }
        isWriting = true
        defer { isWriting = false }
        let made = await WeeklyReviewMaker.make(week: week, feed: feed)
        review = made
        WeeklyReviewMaker.save(made, week: week)
    }
}
