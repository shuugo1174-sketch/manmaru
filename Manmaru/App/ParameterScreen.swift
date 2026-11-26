import SwiftUI

struct ParameterScreen: View {
    @EnvironmentObject private var store: TrackerStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("育てた力が、技になる")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(ManmaruPalette.caption)
                if let feed = store.feed {
                    ForEach(feed.parameters.indices, id: \.self) { index in
                        ParameterSkillCard(parameter: feed.parameters[index])
                    }
                    if feed.parameters.isEmpty {
                        Text("パラメータはまだないよ。")
                            .frame(maxWidth: .infinity)
                            .manmaruCard()
                    }
                }
            }
            .padding(18)
        }
        .background(ManmaruPalette.background)
        .foregroundStyle(.white)
        .font(.system(size: 16, weight: .semibold, design: .rounded))
        .navigationTitle("パラメータ")
        .toolbarBackground(ManmaruPalette.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

private struct ParameterSkillCard: View {
    let parameter: TrackerParameter

    private var goldUnlocked: Bool { parameter.goldSkill?.unlocked == true }

    private var goldName: String {
        guard goldUnlocked,
              let name = parameter.goldSkill?.name?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else { return "？？？" }
        return name
    }

    private var level10Text: String {
        if parameter.level >= 10 { return "Lv10 達成！" }
        if let remaining = parameter.exToLevel10 { return "Lv10まであと \(max(remaining, 0)) EX" }
        return "Lv10まであと ？？？ EX"
    }

    private var techniques: [TrackerSkill] {
        if let skills = parameter.skills, !skills.isEmpty { return skills }
        return Array(repeating: TrackerSkill(), count: 3)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text(parameter.label.isEmpty ? "パラメータ" : parameter.label)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                Text("Lv.\(parameter.level)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Spacer()
                Text("\(parameter.totalEx) EX")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(ManmaruPalette.caption)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("金スキル")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(ManmaruPalette.caption)
                HStack(spacing: 8) {
                    Image(systemName: goldUnlocked ? "star.fill" : "lock.fill")
                    Text(goldName)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                }
                .foregroundStyle(goldUnlocked ? ManmaruPalette.yellow : ManmaruPalette.caption)
                Text(level10Text)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(parameter.level >= 10 ? ManmaruPalette.yellow : Color.white)
                if !goldUnlocked, let unlockLevel = parameter.goldSkill?.unlockLevel {
                    Text("金スキルはLv\(unlockLevel)で解放")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(ManmaruPalette.caption)
                }
            }
            Text("技")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(ManmaruPalette.caption)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(techniques.indices, id: \.self) { index in
                        techniqueSlot(techniques[index])
                    }
                }
            }
        }
        .manmaruCard()
    }

    private func techniqueSlot(_ skill: TrackerSkill) -> some View {
        VStack(spacing: 6) {
            Image(systemName: skill.unlocked ? "sparkles" : "lock.fill")
                .foregroundStyle(skill.unlocked ? ManmaruPalette.yellow : ManmaruPalette.caption)
            Text(techniqueName(skill))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(skill.unlocked ? Color.white : ManmaruPalette.caption)
                .lineLimit(2)
        }
        .frame(width: 86, height: 60)
        .padding(8)
        .background(ManmaruPalette.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(skill.unlocked ? ManmaruPalette.yellow : ManmaruPalette.border, lineWidth: 1)
        }
    }

    private func techniqueName(_ skill: TrackerSkill) -> String {
        guard skill.unlocked,
              let name = skill.name?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else { return "？？？" }
        return name
    }
}
