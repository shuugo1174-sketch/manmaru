import SwiftUI

// 大きい目標を、きょうやる小さいタスクに分ける。
// 結果はこのiPhoneの中だけに保存する（どこにも送らない）。
struct GoalItem: Codable, Identifiable, Equatable {
    var id = UUID()
    var text: String
    var done = false
}

struct GoalPlan: Codable, Equatable {
    var goal: String = ""
    var date: String = ""
    var items: [GoalItem] = []
}

enum GoalPlanStore {
    private static let key = "goalPlan"

    static var todayString: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    static func load() -> GoalPlan {
        guard let data = UserDefaults.standard.data(forKey: key),
              let plan = try? JSONDecoder().decode(GoalPlan.self, from: data) else { return GoalPlan() }
        return plan
    }

    static func save(_ plan: GoalPlan) {
        if let data = try? JSONEncoder().encode(plan) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

struct GoalSplitterView: View {
    @State private var plan = GoalPlanStore.load()
    @State private var goalText = ""
    @State private var newItem = ""
    @State private var isThinking = false
    @State private var note: String?

    private var isToday: Bool { plan.date == GoalPlanStore.todayString }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("大きい目標")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                    TextField("例：3か月で5kgやせる", text: $goalText, axis: .vertical)
                        .lineLimit(1...4)
                        .padding(12)
                        .background(ManmaruPalette.background)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    Button {
                        Task { await split() }
                    } label: {
                        Label(isThinking ? "まんまるが考え中…" : "今日の分に分ける", systemImage: "wand.and.stars")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isThinking || goalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Text(ManmaruAI.isAvailable ? "iPhoneの中のAIが、きょうやることを3〜5個にするよ。" : "このiPhoneではAIが使えないよ。下に自分で足してね。")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(ManmaruPalette.caption)
                    if let note {
                        Text(note)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(ManmaruPalette.caption)
                    }
                }
                .manmaruCard()

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text(isToday ? "きょうはこれだけ" : "まえに分けたもの")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                        Spacer()
                        Text("\(plan.items.filter { $0.done }.count) / \(plan.items.count)")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(ManmaruPalette.caption)
                    }
                    if !plan.goal.isEmpty {
                        Text("目標：\(plan.goal)")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(ManmaruPalette.caption)
                    }
                    ForEach(plan.items) { item in
                        Button {
                            toggle(item)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 22))
                                    .foregroundStyle(item.done ? ManmaruPalette.green : ManmaruPalette.caption)
                                Text(item.text)
                                    .strikethrough(item.done)
                                    .foregroundStyle(item.done ? ManmaruPalette.caption : Color.white)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                            }
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("消す", role: .destructive) { remove(item) }
                        }
                    }
                    if plan.items.isEmpty {
                        Text("まだないよ。目標を書いて分けてみてね。")
                            .foregroundStyle(ManmaruPalette.caption)
                    }
                    HStack {
                        TextField("自分で足す", text: $newItem)
                            .padding(10)
                            .background(ManmaruPalette.background)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        Button("足す") { add() }
                            .buttonStyle(.bordered)
                            .disabled(newItem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .manmaruCard()
            }
            .padding(18)
        }
        .background(ManmaruPalette.background)
        .foregroundStyle(.white)
        .font(.system(size: 16, weight: .semibold, design: .rounded))
        .navigationTitle("目標を分ける")
        .toolbarBackground(ManmaruPalette.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear { if goalText.isEmpty { goalText = plan.goal } }
    }

    private func split() async {
        let goal = goalText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !goal.isEmpty else { return }
        isThinking = true
        note = nil
        defer { isThinking = false }
        let task = """
        大きい目標を、きょう1日でできる小さいタスクに分ける。3〜5個。
        1つ15〜30分でできる、具体的で小さいことにする。無理をさせない。
        1行に1つずつ、タスクだけを書く。番号や説明はいらない。
        """
        if let answer = await ManmaruAI.generate(task: task, prompt: "目標：\(goal)", timeout: 20) {
            let items = ManmaruAI.lines(answer).prefix(5).map { GoalItem(text: $0) }
            if !items.isEmpty {
                plan = GoalPlan(goal: goal, date: GoalPlanStore.todayString, items: Array(items))
                GoalPlanStore.save(plan)
                return
            }
        }
        note = ManmaruAI.isAvailable ? "うまく分けられなかったよ。もう一度ためすか、自分で足してね。" : "このiPhoneではAIが使えないよ。自分で足してね。"
        if plan.goal != goal {
            plan = GoalPlan(goal: goal, date: GoalPlanStore.todayString, items: [])
            GoalPlanStore.save(plan)
        }
    }

    private func toggle(_ item: GoalItem) {
        guard let index = plan.items.firstIndex(where: { $0.id == item.id }) else { return }
        plan.items[index].done.toggle()
        GoalPlanStore.save(plan)
    }

    private func remove(_ item: GoalItem) {
        plan.items.removeAll { $0.id == item.id }
        GoalPlanStore.save(plan)
    }

    private func add() {
        let text = newItem.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if plan.date.isEmpty { plan.date = GoalPlanStore.todayString }
        plan.items.append(GoalItem(text: text))
        GoalPlanStore.save(plan)
        newItem = ""
    }
}
