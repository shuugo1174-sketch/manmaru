import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// iPhoneの中のAI（Apple Foundation Models）。iOS 26以上・Apple Intelligenceがオンのときだけ使える。
// 使えないときは nil を返す。呼ぶ側は決まったセリフを使う。外のAIには何も送らない。
enum ManmaruAI {
    // まんまるの話し方のルール（大事）
    static let voice = """
    あなたは「まんまる」という小さな紺色のキャラクター。一人称は「ぼく」。相手はシュウゴ。
    やさしく、短く、かわいく話す。
    セルフ・コンパッション（自分への思いやり）の考え方で話す。責めない。説教しない。押しつけない。
    うまくいかなかった日は、まず「大変だったね」と気持ちに寄りそい、そのあと次にどうするかを一言だけ言う。
    「もっと自分を大切にしなよ」のような、いたわる言葉も言っていい。
    医療や健康について断定しない。絵文字や記号の飾りは使わない。日本語で答える。
    """

    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if case .available = SystemLanguageModel.default.availability { return true }
        }
        #endif
        return false
    }

    /// 設定画面に出す説明
    static var statusText: String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return "このiPhoneでAIが使えるよ（iPhoneの中だけで動く）。"
            case .unavailable(.deviceNotEligible):
                return "このiPhoneはAIに対応していないよ。決まったセリフで話すね。"
            case .unavailable(.appleIntelligenceNotEnabled):
                return "Apple Intelligenceがオフだよ。設定でオンにするとAIで話すよ。"
            case .unavailable(.modelNotReady):
                return "AIの準備中だよ（ダウンロード中かも）。少し待ってね。"
            case .unavailable:
                return "いまはAIが使えないよ。決まったセリフで話すね。"
            }
        }
        #endif
        return "AIはiOS 26からだよ。決まったセリフで話すね。"
    }

    /// AIに文章を作ってもらう。使えない・時間切れ・失敗のときは nil。
    static func generate(task: String, prompt: String, timeout: Double = 10) async -> String? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            guard isAvailable else { return nil }
            return await withTaskGroup(of: String?.self) { group in
                group.addTask {
                    do {
                        let session = LanguageModelSession(instructions: voice + "\n" + task)
                        let response = try await session.respond(to: prompt)
                        return clean(response.content)
                    } catch {
                        return nil
                    }
                }
                group.addTask {
                    try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    return nil
                }
                let first = await group.next() ?? nil
                group.cancelAll()
                return first
            }
        }
        #endif
        return nil
    }

    /// まわりの「」や空白を取る
    static func clean(_ text: String) -> String? {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let quotes: Set<Character> = ["「", "」", "\"", "『", "』"]
        while let first = result.first, quotes.contains(first) { result.removeFirst() }
        while let last = result.last, quotes.contains(last) { result.removeLast() }
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }

    /// 1行に1つずつの答えを、行のリストにする（「1.」「・」「-」などは取る）
    static func lines(_ text: String) -> [String] {
        text.split(whereSeparator: \.isNewline).compactMap { raw in
            var line = raw.trimmingCharacters(in: .whitespaces)
            while let first = line.first, "・-*•0123456789０１２３４５６７８９.)）、. ".contains(first) {
                line.removeFirst()
            }
            line = line.trimmingCharacters(in: .whitespaces)
            return line.isEmpty ? nil : line
        }
    }
}

// まんまるのひとことをAIで作る
enum ManmaruAISpeech {
    static func line(feed: TrackerFeed, mood: ManmaruMood, justLeveledUp: Bool) async -> String? {
        let hour = Calendar.current.component(.hour, from: Date())
        var facts: [String] = []
        facts.append("いまの時間：\(hour)時")
        facts.append("レベル：\(feed.level)、次のレベルまであと\(feed.exRemaining) EX")
        if let y = feed.yesterday {
            facts.append("きのうのタスク：\(y.tasksDone)/\(y.tasksTotal)できた、+\(y.plusEx) EX")
        } else {
            facts.append("きょうのタスク：\(feed.tasksDone)/\(feed.tasksTotal)できた")
        }
        if let steps = StepsRule.todaySteps(feed: feed) { facts.append("きょうの歩数：\(steps)歩") }

        let situation: String
        if justLeveledUp {
            situation = "レベルが上がった。いっしょに喜んでお祝いする。"
        } else {
            switch mood {
            case .sleepySad:
                situation = "ゆうべ夜更かしした。まんまるは眠くてちょっと悲しい。責めずに「もう寝ようよ」とやさしく言う。"
            case .worried:
                situation = "きのうカロリーが多すぎた。まんまるはしょんぼりしている。責めずに「お腹、大丈夫？」と気づかい、次にどうするかを一言。"
            case .happy:
                situation = "きのうのタスクがぜんぶできた。心から褒める。"
            case .normal:
                if hour >= 5 && hour < 11 {
                    situation = "朝のあいさつ。きょうを始める人に、やさしく声をかける。"
                } else if let y = feed.yesterday, y.tasksDone > 0 {
                    situation = "きのうできたことを褒める。"
                } else if let y = feed.yesterday, y.tasksTotal > 0, y.tasksDone == 0 {
                    situation = "きのうは何もできなかった。まず「大変だったね」と寄りそい、きょうはひとつだけでいいと伝える。"
                } else {
                    situation = "ふつうに、やさしく声をかける。"
                }
            }
        }
        let prompt = "状況：\(situation)\nデータ：\n" + facts.joined(separator: "\n") + "\nまんまるのセリフを1つだけ。"
        return await ManmaruAI.generate(task: "セリフは1〜2文、60文字以内。セリフだけを書く。", prompt: prompt, timeout: 8)
    }
}
