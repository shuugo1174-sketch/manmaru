# まんまる — Windowsでコードを上げる手順（GitHub Desktop）

シュウゴ用。1つずつやる。分からなくなったらチャッチャに聞く。

## 用意するもの
- Windowsパソコン
- manmaru-app.zip（チャッチャからもらったもの）

## 手順1：GitHub Desktopを入れる
1. https://desktop.github.com を開く。
2. 「Download for Windows」を押して、入れる。
3. 開いたら、GitHubのアカウントでサインインする（shuugo1174-sketch）。

## 手順2：リポジトリをパソコンに落とす
1. GitHub Desktopで「File」→「Clone repository」。
2. shuugo1174-sketch/manmaru を選ぶ。
3. 「Clone」を押す。場所はそのままでいい。

## 手順3：コードを入れる
1. manmaru-app.zip を解凍する。
2. 中身を全部、Cloneした manmaru フォルダに入れる。
3. README.md は上書きしていい（「置き換える」を選ぶ）。
4. .github フォルダも一緒に入れる（見えなければ、隠しファイルを表示する）。

## 手順4：アップロードする
1. GitHub Desktopに戻る。左に変わったファイルが並ぶ。
2. 左下の「Summary」に「Add Manmaru app」と書く。
3. 「Commit to main」を押す。
4. 上の「Push origin」を押す。

## 手順5：ビルドする
1. ブラウザで https://github.com/shuugo1174-sketch/manmaru を開く。
2. 上の「Actions」を押す。
3. 左の「iOS Build」を押す。
4. 「Run workflow」→「Run workflow」を押す。
5. 数分待つ。緑のチェックが出たら成功。
6. 出来上がった「Manmaru-unsigned」を押して、IPAをダウンロードする。

## 手順6：iPhoneに入れる（AltStore）
1. Windowsに AltServer を入れる（https://altstore.io）。
2. iTunesとiCloudはAppleの公式サイトから入れたものを使う（Microsoft Store版ではダメ）。
3. iPhoneをUSBでWindowsにつないで、AltServer → Install AltStore → 自分のiPhoneを選ぶ。Apple IDでサインインする。
4. iPhoneでデベロッパモードをオンにする（設定 → プライバシーとセキュリティ → デベロッパモード）。
5. 設定 → 一般 → VPNとデバイス管理 で自分のApple IDを「信頼」する。
6. IPAファイルをiPhoneの「ファイル」に保存する。
7. AltStoreを開いて「My Apps」→「+」→ IPAファイルを選び、Apple IDでサインインしてインストールする。

## 注意
- 無料のApple IDだと、7日ごとに更新が必要。AltStoreがWi-Fiで自動更新を試みる。
- ビルドが赤くなったら（失敗したら）、チャッチャに教える。エラーの画面のスクショを送る。
