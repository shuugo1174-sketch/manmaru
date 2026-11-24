import SwiftUI

// MARK: - キャラ画像（バンドル or フォールバック）
/// JSONの stage で "stage1" / "stage2" / "stage3" を選ぶ。
/// アセットが無ければ SwiftUIで描くシンプルな生き物を出す。
/// 生成画像の背景が白いので、円形にクリップして表示する。
struct CharacterImageView: View {
    var stage: Int
    var size: CGFloat

    var body: some View {
        Group {
            if let uiImage = UIImage(named: "stage\(stage)") {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else if let uiImage = UIImage(named: "stage1") {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                FallbackCreatureView()
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

/// フォールバック：白い丸＋点の目＋笑った口
struct FallbackCreatureView: View {
    var body: some View {
        ZStack {
            Circle().fill(Color.white)
            // ほっぺ
            HStack(spacing: 34) {
                Circle().fill(Color.pink.opacity(0.35)).frame(width: 12, height: 12)
                Circle().fill(Color.pink.opacity(0.35)).frame(width: 12, height: 12)
            }
            .offset(y: 14)
            // 目
            HStack(spacing: 22) {
                Circle().fill(Color.black).frame(width: 8, height: 10)
                Circle().fill(Color.black).frame(width: 8, height: 10)
            }
            .offset(y: -4)
            // 笑った口
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0))
                path.addQuadCurve(to: CGPoint(x: 20, y: 0), control: CGPoint(x: 10, y: 14))
            }
            .stroke(Color.black, lineWidth: 3)
            .frame(width: 20, height: 14)
            .offset(y: 12)
        }
        .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
    }
}

// MARK: - 遊び場（キャラが生きてる感で動く）
/// 状態マシーン＋タイマーで、数秒ごとに状態を変える。
/// 歩く／走る・隠れる・ひょっこり・寝る・呼吸・まばたき・タップで跳ねる。
struct CharacterPlaygroundView: View {
    var stage: Int

    @State private var state: PetState = .idle
    @State private var position: CGPoint = CGPoint(x: 0.5, y: 0.55) // 0.0〜1.0 の割合
    @State private var isBlinking = false
    @State private var isJumping = false
    @State private var speech: String?
    @State private var lastSpeech = ""
    @State private var breathing = false

    private let size: CGFloat = 96

    private let lines = ["今日もやってるね", "その調子", "お、いいね", "待ってるよ", "がんばってるね", "ひょっこり"]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 背景：うすい空
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.blue.opacity(0.08))

                // 隠れ場所の目印（カード風の岩・草）
                HStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.green.opacity(0.25))
                        .frame(width: 70, height: 44)
                        .offset(y: 40)
                }
                .padding(.trailing, 16)

                // 吹き出し
                if let speech {
                    Text(speech)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.white)
                        .clipShape(Capsule())
                        .shadow(radius: 3)
                        .position(
                            x: clamp(position.x * geo.size.width, min: 70, max: geo.size.width - 70),
                            y: max(position.y * geo.size.height - 78, 24)
                        )
                        .zIndex(3)
                }

                // キャラ
                CharacterImageView(stage: stage, size: size)
                    // 呼吸：ふわふわ上下
                    .offset(y: breathing ? -4 : 4)
                    // まばたき：画像を一瞬だけ縦に少しつぶす
                    .scaleEffect(x: 1.0, y: isBlinking ? 0.12 : 1.0)
                    // 寝る：横になる
                    .rotationEffect(.degrees(state == .sleep ? 90 : 0))
                    // ひょっこり：半分だけ出す
                    .offset(y: state == .peek ? size * 0.28 : 0)
                    // タップ：ぴょんと跳ねる
                    .offset(y: isJumping ? -36 : 0)
                    .position(
                        x: clamp(position.x * geo.size.width, min: size / 2 + 4, max: geo.size.width - size / 2 - 4),
                        y: clamp(position.y * geo.size.height, min: size / 2 + 4, max: geo.size.height - size / 2 - 4)
                    )
                    // 隠れている間はカードより後ろにする
                    .zIndex(state == .hide ? 0 : 2)
                    .opacity(state == .hide ? 0.25 : 1.0)
                    .onTapGesture { tap() }
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: position)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isJumping)
                    .animation(.easeInOut(duration: 0.4), value: state)
            }
            .onAppear {
                startBreathing()
                startBlinking()
                startStateTimer(in: geo.size)
            }
        }
        .frame(height: 260)
    }

    // MARK: - 状態マシーン
    private enum PetState: Equatable {
        case idle, walk, run, hide, peek, sleep
    }

    private func startBreathing() {
        breathing = true
        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
            breathing.toggle()
        }
    }

    private func startBlinking() {
        Timer.scheduledTimer(withTimeInterval: 3.2, repeats: true) { _ in
            Task { @MainActor in
                isBlinking = true
                try? await Task.sleep(nanoseconds: 120_000_000)
                isBlinking = false
            }
        }
    }

    private func startStateTimer(in size: CGSize) {
        Timer.scheduledTimer(withTimeInterval: 3.5, repeats: true) { _ in
            Task { @MainActor in
                pickNextState()
            }
        }
    }

    private func pickNextState() {
        // 寝るはたまにだけ。隠れる・ひょっこりも入れる。
        let roll = Int.random(in: 0..<10)
        switch roll {
        case 0:
            state = .sleep
            showSpeech("Zzz")
        case 1:
            state = .hide
            speech = nil
        case 2:
            state = .peek
            showSpeech("！")
            // ひょっこりの後は真ん中に戻る
            position = CGPoint(x: 0.85, y: 0.6)
        case 3:
            state = .run
            moveRandomly(far: true)
            speech = nil
        case 4, 5:
            state = .walk
            moveRandomly(far: false)
            speech = nil
        default:
            state = .idle
            speech = nil
        }
        // 寝た後は数秒で起きる
        if state == .sleep {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if state == .sleep {
                    state = .idle
                    speech = nil
                }
            }
        }
        // 隠れた後は数秒でひょっこり出る
        if state == .hide {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 3_500_000_000)
                if state == .hide {
                    state = .peek
                    showSpeech("！")
                }
            }
        }
    }

    private func moveRandomly(far: Bool) {
        // 画面の外に出ないように 0.12〜0.88 の範囲にする
        let range: ClosedRange<CGFloat> = far ? 0.12...0.88 : 0.2...0.8
        position = CGPoint(
            x: CGFloat.random(in: range),
            y: CGFloat.random(in: 0.3...0.75)
        )
    }

    private func showSpeech(_ text: String) {
        speech = text
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if speech == text { speech = nil }
        }
    }

    private func tap() {
        // ぴょんと跳ねる
        isJumping = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            isJumping = false
        }
        // 連続で同じセリフは出さない
        var next = lines.randomElement() ?? "お、いいね"
        while next == lastSpeech && lines.count > 1 {
            next = lines.randomElement() ?? next
        }
        lastSpeech = next
        state = .idle
        showSpeech(next)
    }

    private func clamp(_ value: CGFloat, min minValue: CGFloat, max maxValue: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, minValue), maxValue)
    }
}
