# まんまる

「やる事リストトラッカー」のキャラ「まんまる」が、iPhoneの画面で動くアプリ。
トラッカーの公開JSON（`widget.json`）から、レベル・EX・タスク・なつき度を読むよ。

- iOS 17以上、SwiftUIだけ。外部ライブラリなし。
- 買い物なし、アカウント作成なし、ログインなし。
- URLはコードに入れない。設定画面で自分で貼るよ。

## Macで開く

```sh
brew install xcodegen
xcodegen
```

できあがった `Manmaru.xcodeproj` を Xcode で開くよ。
`.xcodeproj` は手書きしない。`project.yml` を変えたら、もう一度 `xcodegen` を打つよ。

## iPhoneで動かす

概要だけここに書くよ。詳しくは [INSTALL.md](INSTALL.md) を見てね。

1. Xcode で iPhone を選んで、実行（▶）する。
2. 初めてのときは、iPhone の「設定 → 一般 → VPNとデバイス管理」で開発者を信頼する。
3. アプリを開いて、右上の歯車から `widget.json` のURLを貼る。

## JSONのURLの設定方法

1. アプリ右上の歯車（設定）を開く。
2. 「トラッカーのJSON」に `widget.json` のURLを貼る。
3. 「保存する」を押す。トラッカーのURLはここから自動で作るよ。
4. 「テスト取得」で取れるか確認できるよ。

ウィジェットも同じURLを使うよ。ホーム画面でウィジェットを長押し → 「ウィジェットを編集」からもURLを貼れるよ。

## 注意点

- App Group のIDは両ターゲットで同じにする（`group.manmaru`）。変えるときはアプリとウィジェットの両方を変えるよ。
- 無料のApple IDだと App Groups が使えない場合があり、そのときはウィジェットの設定にURLを直接貼ると動く。
- Live Activityは8時間で終わるよ（iOSの仕様）。終わったら、アプリの「島にキャラを出す」をもう一度押すよ。
- 無料のApple IDだと7日ごとに更新が必要だよ。7日経つとアプリが開けなくなるので、Xcodeからもう一度入れるよ。
- キャラの画像は `Manmaru/Assets.xcassets` の `stage1` / `stage2` / `stage3` に入っているよ。アプリアイコンは `stage1` の画像を使っているよ。

## ファイルの場所

- アプリ：`Manmaru/App/`
- ウィジェット：`ManmaruWidget/`
- 画像：`Manmaru/Assets.xcassets/`
- プロジェクト定義：`project.yml`（XcodeGen）
