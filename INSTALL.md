# まんまる — iPhoneに入れる方法

このアプリを自分のiPhoneに入れる方法は2つある。どちらもお金はかからない（無料のApple IDで入れる）。長く使うなら年99ドルのApple Developer Programが楽になる。

シュウゴの場合は今はWindowsしかないので、**当面は方法Bが現実的**。2027年2月にMacBook Airを買ったら、方法Aも使えるようになる。

---

## 方法A：Mac + Xcode（無料のApple ID）

### 手順

1. MacにXcodeを入れる（App Storeから無料）。
2. プロジェクトのフォルダで `xcodegen` を実行する（`brew install xcodegen` で入る）。`Manmaru.xcodeproj` ができる。
3. Xcodeで `Manmaru.xcodeproj` を開く。
4. Xcode → Settings → Accounts → 自分のApple IDでサインインする。無料のままでいい（Personal Teamができる）。
5. プロジェクトの各ターゲット（Manmaru、ManmaruWidget）の Signing & Capabilities で、Teamに自分のApple IDを選ぶ。Bundle ID（com.shugo.manmaru）が「使えない」と言われたら、自分のものに変える（例：com.自分の名前.manmaru）。
6. iPhoneをUSBでMacにつないで、Xcodeで実行先に自分のiPhoneを選び、▶を押す（Cmd+R）。
7. 初めてのときはiPhone側で「デベロッパモード」をオンにする必要がある（設定 → プライバシーとセキュリティ → デベロッパモード、iOS 16以降）。その後、設定 → 一般 → VPNとデバイス管理 で自分のApple IDを「信頼」する。

### 無料のApple IDの制限

- **7日ごとに更新が必要**。プロビジョニングプロファイルの有効期限が7日で、切れるとアプリが開かなくなる。MacにつないでXcodeからもう一度実行すれば直る。
- **同時に3つまで**。無料だと1台のiPhoneに3つまでしか入れられない。
- App StoreやTestFlightには出せない。

出典：Appleの開発者向け資料（無料のPersonal Teamは3アプリ・7日）。まとめ記事：https://tms-outsource.com/blog/posts/how-to-sideload-apps-on-iphone/

### 年99ドルのApple Developer Programだと

- 7日の制限がなくなる。App StoreやTestFlightにも出せる。
- 年99ドル（USD）。Appleの公式ページで申し込む。

### App Groupsについての注意（未確認）

このアプリはアプリ本体とウィジェットでデータを共有するために App Groups（group.manmaru）を使っている。無料のApple IDで App Groups が使えるかどうかは、**調べた記事の意見が分かれている**。

- 使えると書いている記事：https://expo.dev/blog/apple-developer-program-explained-free-vs-paid （Appleの機能一覧表によると App Groups は無料でも使える、としている）
- 使えないと書いている記事：https://codemia.io/knowledge-hub/path/test_ios_app_on_device_without_apple_developer_program_or_jailbreak （無料では App Groups は使えない、としている）

そのため、このアプリはフォールバックを入れてある。App Groups が使えなくても、ウィジェットの設定画面にJSONのURLを直接貼れば、ウィジェットは自分でデータを取りに行く。アプリ本体とDynamic Islandは App Groups がなくても動く。

**実際に無料のApple IDでビルドして試したわけではないので、ここは未確認。** もしXcodeが「App Groupsは使えない」と言ったら、年99ドルのプランにするか、ウィジェットのフォールバックを使う。

---

## 方法B：GitHub Actionsでビルド → WindowsのAltStoreで入れる

Macがなくてもできる方法。GitHubのクラウド上のMac（macOSランナー）でビルドして、できたIPAファイルをWindowsのAltStoreでiPhoneに入れる。

### 手順1：GitHubに置く

1. GitHubで新しいリポジトリを作る（無料でいい）。
2. このプロジェクト一式（project.yml、Manmaru/、ManmaruWidget/）を push する。`.xcodeproj` は入れない（ビルド時に作る）。

### 手順2：GitHub Actionsでビルドする

`.github/workflows/ios-build.yml` というファイルを作る。例：

```yaml
name: iOS Build
on:
  workflow_dispatch:  # 手動で実行する

jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install XcodeGen
        run: brew install xcodegen
      - name: Generate Xcode project
        run: xcodegen generate
      - name: Build unsigned IPA
        run: |
          xcodebuild -project Manmaru.xcodeproj \
            -scheme Manmaru \
            -configuration Release \
            -destination "generic/platform=iOS" \
            CODE_SIGNING_ALLOWED=NO \
            build
          # （IPA化の手順は下の「未確認」を読むこと）
      - name: Upload IPA
        uses: actions/upload-artifact@v4
        with:
          name: Manmaru-unsigned
          path: build/*.ipa
```

- macOSランナーはGitHub Actionsの無料枠でも使えるが、macOSの分はLinuxの約10倍の換算になる（無料枠の分を早く使う）。1回のビルドは数分〜20分くらい。
- 参考：Windowsでコードを書いてGitHub ActionsのmacOSランナーでビルドする例（NomiというアプリのREADME）：https://github.com/adoyyy/nomi/blob/HEAD/README.md
- 参考：MacなしでiOSアプリを出す方法の解説：https://usharik.dev/articles/ios-without-mac/ 、https://dev.to/nesimrazon/shipping-an-iphone-app-without-a-mac-kotlin-multiplatform-a-cloud-mac-and-testflight-2jgc

### 手順3：AltStoreでiPhoneに入れる

1. Windowsに **AltServer** を入れる（https://altstore.io からダウンロード）。iTunesとiCloudはAppleの公式サイトから入れたものが必要（Microsoft Store版ではだめ、とAltStoreのFAQにある）。
2. iPhoneをUSBでWindowsにつないで、AltServer → Install AltStore → 自分のiPhoneを選ぶ。Apple IDでサインインする。
3. iPhoneでデベロッパモードをオンにする（設定 → プライバシーとセキュリティ → デベロッパモード、iOS 16以降）。設定 → 一般 → VPNとデバイス管理 で自分のApple IDを「信頼」する。
4. GitHub Actionsで作ったIPAファイルをiPhoneの「ファイル」に保存する。
5. AltStoreを開いて「My Apps」→「+」→ IPAファイルを選び、Apple IDでサインインしてインストールする。

出典：https://tms-outsource.com/blog/posts/how-to-download-apps-from-files-on-iphone/ 、https://tms-outsource.com/blog/posts/how-to-install-ipa-on-iphone/

### 方法Bの制限

- 無料のApple IDだと、**7日ごとに更新が必要**（方法Aと同じ）。AltStoreはWi-Fi経由で自動更新を試みる。
- 同時に3つまで。
- App Groups の問題は方法Aと同じ（上の「未確認」を読むこと）。

### 方法Bで未確認のこと

このプロジェクトで方法Bを実際に試したわけではない（手元にMacが無いため）。次は未確認：

- **未確認**：unsigned IPA を作る正確なコマンド（`xcodebuild build` だけでは .ipa にならない。`xcodebuild archive` ＋ `xcodebuild -exportArchive`、または Payload フォルダをzipして .ipa にする方法があるが、このプロジェクトでの動作は試していない）。
- **未確認**：AltStoreでこのアプリのIPAが実際に入ること（App Groups とウィジェット拡張があるアプリの署名が、無料のApple IDで通るかどうか）。
- **未確認**：GitHub Actionsの無料枠でこのビルドが何分かかるか。

NomiのREADMEには「unsigned IPA はそのままではiPhoneに入らない。無料のApple IDで署名する手順（例：3uTools）が必要」と書いてある。AltStoreも同じ仕組み（自分のApple IDで署名する）なので、理屈の上では入るはずだが、試していない。

---

## どっちが現実的か

|  | 方法A（Mac + Xcode） | 方法B（GitHub Actions + AltStore） |
|---|---|---|
| いるもの | Mac、iPhone、無料のApple ID | Windows、iPhone、無料のApple ID、GitHubアカウント |
| 手順の多さ | 少ない | 多い（GitHubの設定、AltStoreの設定） |
| 7日の更新 | 要る（Xcodeから再実行） | 要る（AltStoreが自動更新を試みる） |
| 確かさ | 一番確実 | 未確認の部分あり |

- **Macがあるなら方法A**。一番簡単で確実。
- **今のシュウゴ（Windowsだけ）なら方法B**。ただし初めてだとつまずきやすい。まず一度、方法Bで入れてみて動くか確認するのがいい。
- **2027年2月にMacBook Airを買ったら方法Aに切り替える**のが楽。
- 7日ごとの更新が面倒になったら、年99ドルのApple Developer Programを考える。
