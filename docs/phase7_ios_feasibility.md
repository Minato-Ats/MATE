# Phase 7A: iOS Architecture / Feasibility 調査・設計レポート

作成日: 2026-09-15
ブランチ: `phase7-ios`（`main` = `b662434` から分岐、Android v1 Release Candidate機能凍結済み）
開発環境: Windows（macOS/Xcode実機検証は未実施。本レポートはApple公式ドキュメント調査 + 既存Dartコード調査に基づく設計であり、Xcodeでのビルド確認は行っていない）

このドキュメントの結論を先に一つだけ挙げるなら：**iOS版MATEは実現可能。ただしユーザーが提示した「理想フロー」のうち Shield→MATE本体 の遷移は、Appleの現行公式APIでは直接には実現できない**（詳細はセクション3）。回避策はあるが、Android版と完全に同一のシームレスさにはならない。これは実装の巧拙の問題ではなく、Appleが意図的に用意していない機能。

---

## 1. Apple公式APIを前提にした設計

MATEがiOSで使うべきフレームワークと、それぞれの役割：

| フレームワーク | 役割 |
|---|---|
| `FamilyControls` | `AuthorizationCenter`（Screen Time権限の許可取得）、`FamilyActivityPicker`（対象アプリ選択UI）、`FamilyActivitySelection`（選択結果）、`ApplicationToken`/`ActivityCategoryToken`/`WebDomainToken`（不透明な識別子） |
| `ManagedSettings` | `ManagedSettingsStore` — 実際に「このアプリを開けなくする」を適用するAPI（`store.shield.applications = tokens`） |
| `ManagedSettingsUI` | `ShieldConfiguration`/`ShieldConfigurationDataSource` — Shield画面（Android版InterventionScreenに相当する最初の壁）の見た目をカスタムする。**別Extension target** |
| `DeviceActivity` | `DeviceActivityCenter`/`DeviceActivitySchedule`/`DeviceActivityEvent` — 監視スケジュールとしきい値イベントを登録するAPI |
| `DeviceActivityMonitorExtension` | スケジュール/しきい値イベントに応じて呼ばれるコールバック（`intervalDidStart`/`intervalDidEnd`/`eventDidReachThreshold`）を実装する**別Extension target**。一時解除後の再shieldはここで行う |
| `ShieldActionExtension` (`ShieldActionDelegate`) | Shield画面のボタンタップを処理する**別Extension target**。返せるのは `.close` / `.defer` / `.none` の3つのみ |

Android版のUsageStatsManager方式（能動ポーリングで検知→後追いで割り込み画面を被せる）とは根本的に発想が逆で、iOSは**OS自体がアプリ起動をブロックする**（Shieldが先に立ちはだかる、後追いではない）。これは弱点ではなくむしろ検知漏れ・競合状態（Android版で実際に踏んだGmail初回起動競合バグのような）が構造的に起こり得ないという利点でもある。

---

## 2. Android機能との対応表

| MATE機能 | Android実装 | iOS実現方法 | 分類 |
|---|---|---|---|
| 対象アプリ選択 | 自前Flutter UI（PackageManagerでアプリ一覧取得、アイコン/名前を自由表示） | `FamilyActivityPicker`（システム提供UI）。返るのは不透明`ApplicationToken` | **UXを変更すれば可能**（自前の一覧UIは組めない。トークンは不透明でアイコン/パッケージ名を自力取得できない） |
| アプリ起動時の介入 | `ForegroundWatcherService`が0.5秒ポーリングで検知→`InterventionActivity`を被せる | `ManagedSettingsStore.shield.applications`でOSレベルに事前ブロック（Shield画面をOSが表示） | **同等に再現可能**（方式は逆だが体験としては同等以上。ポーリング遅延・競合状態がそもそも存在しない） |
| 「何のために開く？」自由記述 | InterventionActivity内のFlutter TextField | Shield自体には入力欄を置けない。MATE本体アプリ内でのみ可能 | **UXを変更すれば可能**（セクション3参照。Shield→本体への遷移に一手間かかる） |
| 「それ、今必要？」YES/NO | InterventionScreen/SeriousModeFlow | MATE本体アプリ内で完全再現可能（既存Dart UIロジックがそのまま動く） | **同等に再現可能**（本体アプリ到達後は） |
| 煽り文（本気モードcopy） | `serious_mode_templates.dart` | 同上、MATE本体アプリ内 | **同等に再現可能** |
| 通常待機 | カウントダウンUI＋タイマー | 同上、MATE本体アプリ内 | **同等に再現可能**（ただし「待った後に対象アプリを開く」の遷移はセクション3の制約を受ける） |
| 本気モード | `SeriousModeFlow` | 同上、MATE本体アプリ内 | **同等に再現可能** |
| 全誘惑アプリ共通15秒累積 | `SeriousModeEscalation`（純粋Dart、`PreferencesService`に永続化） | ロジックはプラットフォーム非依存。App Group経由で共有ストレージにすれば同一に動く | **同等に再現可能** |
| 1時間で累積リセット | 同上、`DateTime`ベースの純粋ロジック | 同上 | **同等に再現可能** |
| 一時休止 | `pausedUntil`、ネイティブwatcherが判定 | 一時休止中は`shield.applications = nil`にし、休止終了は`DeviceActivityMonitorExtension`のスケジュールイベントで再shield | **UXを変更すれば可能**（再shieldの信頼性に既知の課題あり。セクション3・9参照） |
| 見守る時間／曜日 | `ScheduleRule`をネイティブが都度判定 | `DeviceActivitySchedule`で表現。曜日別の扱いはPhase 7Bでの詳細検証が必要（要調査事項として残す） | **同等に再現可能**（詳細未検証） |
| ルール固定モード | `StrictModeGuard`（アプリ内Dartロジックのみ） | ロジックはそのまま移植可能。ただし**iOSでは`.individual`認可をユーザーがiOS設定から常に取り消せる**（Family Controlsのプラットフォーム上の設計）ため、MATEのアプリ内制御では防げない迂回経路が原理的に残る | **同等に再現可能（アプリ内ロジックとしては）／根本的な迂回はプラットフォーム制約で防げない** |
| 統計 | `InterventionEvent`ログ→`StatsRepository`で集計 | ロジックは完全共通化可能。イベント発生点だけAndroidの検知タイミングからiOSの各ポイント（Shield表示時=Extension側でApp Group書き込み、本体到達時=通知タップ後）に置き換え | **同等に再現可能** |
| SAVE時間 | `SaveTimeEstimator`（純粋Dart） | 同上 | **同等に再現可能** |
| streak | `StatsRepository._computeStreak`（純粋Dart） | 同上 | **同等に再現可能** |
| アプリ再起動後の状態維持 | `SharedPreferences`（Android両エンジン共有） | App Group共有`UserDefaults(suiteName:)`。Flutter側`shared_preferences`プラグインのsuiteName対応、またはExtension（Swift専用・Flutter engine不可）用に別途シリアライズ形式を合わせる必要あり | **同等に再現可能（要adapter実装）** |

---

## 3. Shield → MATE本体への遷移（最重要調査事項）

### 結論

ユーザーが提示した理想フロー（Shield上の「MATEへ進む」ボタン→直接MATE本体が開く）は**Appleの現行公式APIでは実現不可能**。

Appleのフレームワークエンジニアがdeveloper forumsで明言：

> "There's no supported way for your extension to open your main app with the APIs currently available. If you'd like us to consider adding the necessary functionality, please file an enhancement request using Feedback Assistant."
> （2022年11月、2025年1月に再度同内容で回答。未解決のFeedback Assistant起票: FB17261679, FB22696417 — 2026年5月時点でも未解決）

試して失敗が確認されているもの：`@Environment(\.openURL)`、`NSExtensionContext.open(_:)`（このExtension種別では無音で失敗）、`UIApplication.shared.open()`（Extension内では利用不可）、responder chain経由の裏技（iOS 18+で動作しないことが確認済み）。`LSApplicationWorkspace`等の非公開APIで強引に実現しているアプリはApp Store Guideline 2.5.1違反でリジェクトされている（ユーザー指示通り、非公開APIは使用しない）。

`ShieldActionResponse`が持つケースは3つのみ：
- `.close` — Shieldを閉じてホーム画面に戻る
- `.defer` — `ShieldConfigurationDataSource`を再評価してShield UIを再描画（親承認待ちのような用途）
- `.none` — 何もしない

### 実現可能な唯一の経路：ローカル通知による中継

コミュニティで収斂している（Appleが公式に推奨したわけではない）唯一の動作パターン：

1. Shieldのボタンタップ → `ShieldActionDelegate.handle(action:)`が呼ばれる
2. その中でローカル通知（deep link付き）を発火し、`.close`を返す（Shieldは維持したまま閉じるだけ。対象アプリはまだshield中）
3. ユーザーが通知をタップ → MATE本体アプリが開く（通知のペイロードでどのアプリがトリガーだったか判別）
4. ここでようやくMATE本体のFlutter UI（「何のために開く？」→YES/NO→本気モード）が動く

これにより理想フローは実質的にこう変わる：

```
対象アプリを開く
↓
iOS Shield表示（「MATEへ進む」ボタン）
↓
ボタンタップ → Shieldは閉じるが対象アプリはまだブロック中
↓
通知が届く → ユーザーが通知をタップ（追加の1タップ、通知許可が前提）
↓
MATE本体が開く
↓
「何のために開く？」→ JunkReasonDetector検証 → YES/NO → （必要なら）本気モード累積待機
↓
条件を満たした場合のみ shield.applications から対象アプリのトークンを除外（unshield）
↓
対象アプリへの復帰 ← ★もう一つの制約、下記参照
↓
DeviceActivityMonitorExtensionでN分後に自動re-shield（★信頼性に既知課題、下記参照）
```

### 復帰時のもう一つの制約：対象アプリを自動で開く公式手段がない

MATE本体から「対象アプリを直接起動する」公式APIも存在しない。ベストエフォートとして、対象アプリがURL Scheme/Universal Linkに対応していれば（Instagram: `instagram://`、YouTube: `youtube://`、X: `twitter://`等、主要SNSアプリは大抵対応）それを試みることはできるが、汎用的な保証はない。フォールバックとして「ホーム画面から◯◯を開いてください」という案内が必要になる。

### 再shieldの信頼性リスク

`DeviceActivityMonitorExtension`の`eventDidReachThreshold`/`intervalDidEnd`について、developer forumsで現在進行形の不具合報告あり（iOS 26.2時点で`eventDidReachThreshold`が実利用0分でも発火する、非リピートスケジュールで`intervalDidEnd`が発火しないケースが報告されている）。「一時解除→N分後に自動re-shield」という設計はこの上に成り立つため、**発火漏れ時のセーフティネット**（例: MATE本体起動のたびにshield状態を再検証する／unshield時に本体側でも別途タイマーを持ち次回起動時に強制re-shieldする）をPhase 7Bの実装で必ず設計する必要がある。

---

## 4. Family Controls entitlement設計

### 対象（すべて個別申請が必要）

| Target | 用途 |
|---|---|
| メインMATEアプリ | `com.minatoapps.mate` |
| Shield Configuration Extension | `com.minatoapps.mate.ShieldConfiguration` |
| Shield Action Extension | `com.minatoapps.mate.ShieldAction` |
| Device Activity Monitor Extension | `com.minatoapps.mate.DeviceActivityMonitor` |

調査で判明した重要な落とし穴：**Distribution向けFamily Controls entitlementは、メインアプリで承認されても各Extensionには自動で波及しない。Extensionそれぞれについて個別にApple側へ申請が必要**。これを見落として「メインアプリだけ申請して審査直前に気づく」という報告がdeveloper forumsに複数あった。

### ユーザー側でApple Developer Portalにて行う必要がある手続き（まだ何も実行していません）

1. Apple Developer Program登録（個人 or 組織、年額$99）— 未加入の場合はこれが前提
2. 各Bundle ID（メイン＋Extension 3つ）をIdentifiersに登録
3. 各Bundle IDに「App Groups」capabilityを有効化し、共通のApp Group ID（例: `group.com.minatoapps.mate`）を割り当て
4. 各Bundle IDに「Family Controls」capability（Development版）を有効化 — これは即時利用可能（Apple承認不要）で、Xcodeから自分の実機での開発・検証に使える
5. **Family Controls (Distribution) entitlement申請フォーム**（https://developer.apple.com/contact/request/family-controls-distribution）を、メインアプリ・各Extensionそれぞれについて個別に提出
6. 承認を待つ（一般的な報告では営業日4日程度〜数週間。Extension側の承認だけ数週間止まっている報告も複数あり、配布スケジュールに余裕を持たせる必要がある）
7. 承認後、Distribution向けProvisioning Profile作成時にこのentitlementが選択可能になる

申請操作自体は行っていません。実施はユーザーの判断とタイミングでお願いします。

---

## 5. Bundle ID設計

Android（`com.minatoapps.mate`）を基準に：

| Target | Bundle ID |
|---|---|
| iOS メインアプリ | `com.minatoapps.mate` |
| Shield Configuration Extension | `com.minatoapps.mate.ShieldConfiguration` |
| Shield Action Extension | `com.minatoapps.mate.ShieldAction` |
| Device Activity Monitor Extension | `com.minatoapps.mate.DeviceActivityMonitor` |
| App Group ID | `group.com.minatoapps.mate` |

Extension用Bundle IDは親アプリのBundle ID＋`.`＋サフィックスという、Appleが要求するネスト規則に沿っており問題なし。App Group IDは`group.`プレフィックス必須というApple規則に準拠。

---

## 6. Flutter共通ロジックの再利用調査（実コード確認済み）

| 対象 | ファイル | 分類 | 根拠 |
|---|---|---|---|
| `SeriousModeEscalation` | `lib/data/models/serious_mode_escalation.dart` | **共通化可能** | 純粋Dart、`DateTime`を引数で受け取るだけでI/Oなし |
| `JunkReasonDetector` | `lib/core/junk_reason_detector.dart` | **共通化可能** | 純粋ローカル文字列判定、プラットフォーム非依存 |
| serious mode templates | `lib/core/copy/serious_mode_templates.dart` | **共通化可能** | `PreferencesService`にのみ依存、I/Oなし |
| goal | `PreferencesService.goal`/`setGoal` | **共通化可能** | key-value読み書きのみ |
| `MateCopy` | `lib/core/copy/mate_copy.dart` | **共通化可能** | 静的文字列定数のみ |
| Preferences / repository抽象 | `PreferencesService`、`GuardedAppsRepository`、`StatsRepository`（interface） | **共通化可能（interfaceは）／iOS用adapterが必要（実装は）** | `GuardedAppsRepository`は既にinterface化済み。`AndroidGuardedAppsRepository`と並ぶ`IosGuardedAppsRepository`を新設すれば良い設計。ただし対象アプリの識別子がAndroidは`packageName`(String)、iOSは不透明`ApplicationToken`であるため、モデル（`GuardedApp`）の識別子型を抽象化する設計変更が必要になる |
| Interventionイベント | `lib/data/models/intervention_event.dart`、`PreferencesService.appendEvent/loadEventLog` | **共通化可能** | 純粋データモデル＋key-value永続化のみ |
| 統計計算 | `lib/data/repositories/stats_repository.dart` | **共通化可能** | `InterventionEvent`ログのみに依存する純粋計算 |
| UI（`CenteredScrollArea`、各Screen/Flow widget） | `lib/features/intervention/*`, `lib/core/widgets/*` | **共通化可能** | Flutter標準ウィジェットのみで構成、プラットフォームAPI直呼びなし |
| copy | 上記`MateCopy`参照 | **共通化可能** | - |
| haptics / SE | `lib/core/haptics.dart`、`lib/core/feedback.dart`、`lib/core/sound/sound_service.dart` | **共通化可能** | `flutter/services.dart`のHapticFeedback、`audioplayers`はいずれもiOS対応済みパッケージ |
| `InterventionBridge`（`platform/intervention_bridge.dart`） | - | **Android専用** | 「別Flutter engine上のInterventionActivityと通信する」という設計そのものがAndroid固有。iOSのExtensionはSwift専用でFlutter engineを埋め込めないため、この設計は丸ごと成立しない |
| `ForegroundAppWatcher`/`WatcherCoordinator`（`platform/*.dart`） | - | **Android専用** | UsageStatsManagerポーリング・フォアグラウンドサービス管理という概念自体がiOSに存在しない |
| `UsageAccessController`/`OverlayAccessController`（`state/*.dart`） | - | **Android専用** | 「使用状況アクセス」「他アプリの上に表示」というAndroid固有の特殊権限の概念。iOS側は`AuthorizationCenter.requestAuthorization(for: .individual)`という全く別の権限モデルになる |

**重要な設計含意**：Android版の「別Flutter engineでInterventionActivityを起動する」というアーキテクチャの中核部分（`InterventionBridge`、`intervention_main.dart`）はiOSには一切移植できない。iOSでは**Shield自体はFlutterで描画できず**（Extensionにはメモリ制約もあり、Flutter engineを積むのは非現実的）、Flutter UIが動くのはユーザーが通知経由でMATE本体アプリに到達した後だけ。つまりiOS版の「介入UI」は事実上すべて**メインアプリのFlutterウィジェットツリーの一部**として作ることになり、Android版のような「独立ウィンドウとして被さる」体験にはならない。

Android側を壊すリファクタは行っていません（このレポートは調査のみで、既存コードへの変更は一切加えていません）。

---

## 7. Windowsで安全に実装できる範囲（今回は未着手・候補のみ）

以下はXcode/macOS不要でWindows上のDart環境だけで安全に実装・テストできる候補です。ただし今回のPhase 7Aでは**調査・設計の完了後に一度停止する**というご指示のため、実装はまだ着手していません。Phase 7Bへ進む前にどこまでこの段階でやるか改めて指示をお願いします。

候補：
- `GuardedApp`の識別子を、現在の生の`packageName: String`から、Android/iOSで共通に使えるopaqueな識別子型（例: `GuardTargetId`という薄いラッパー）に抽象化する設計変更（Androidの挙動は変えず、文字列をラップするだけの後方互換な変更として可能）
- iOS用の`GuardedAppsRepository`実装のインターフェース設計（実装本体はPlatform Channel経由でネイティブ側とやり取りする必要があるため、Channel名・メソッドシグネチャの設計まではWindowsで可能。実際のSwift側実装はXcode必須）
- App Group越しの共有ストレージ用に、`PreferencesService`のキー命名・JSON形式をiOS Extension側Swiftコードでも同じ形式で読み書きできるよう明文化したスキーマドキュメント作成
- iOS向け`InterventionArgs`相当のモデル設計（通知のdeep linkペイロードから復元するモデル）

これらはいずれも**Android側の既存コードには一切触れず**、新規ファイル追加のみで完結できる範囲です。

Xcode/macOSがなければ検証できないため保留するもの（ご指示通り）：Swiftの大量実装、Xcode project構成変更、entitlement plist、Extension target追加、signing設定。

---

## 8. Phase 7Bに必要なmacOS環境（Mac購入を前提としない構成）

| 要素 | 現実的な選択肢 |
|---|---|
| Apple Developer Program | 必須。年額$99。Mac不要でWeb登録可能。**今すぐ着手可能**（entitlement申請の前提でもあり、承認待ち期間があるため早めが望ましい） |
| Family Controls Distribution entitlement申請 | 必須。Mac不要でWeb申請可能。承認に数日〜数週間かかるため、**Phase 7Bの一番最初にやるべき** |
| Xcode project初期構築（Extension target追加、entitlements、Signing & Capabilities） | GUIでの対話的操作が現実的。**一時的なクラウドMacのインタラクティブセッション**（MacinCloud等の時間課金プラン、$1〜2/時間程度）を数時間〜1日分借りるのが最も現実的。`.pbxproj`を手打ちで編集するのは事故率が高く非推奨 |
| 継続的なビルド・署名・TestFlightアップロード | **GitHub Actions のmacOSホストランナー**（`macos-14`/`macos-15`）でCI化すれば、以降はMac無しで`xcodebuild`〜`altool`/`xcrun notarytool`によるTestFlightアップロードまで自動化可能 |
| 実機テスト | Screen Time API（ManagedSettings/Shield）は**iOS Simulatorでは実効的に動作しないとされる**（enforcement layerがSimulatorに存在しない）。**物理iPhoneが最低1台必須**。所有Macは不要だが所有iPhoneは実質必須（お持ちかご確認をお願いします） |
| App Store Connect / TestFlight | Apple Developer Program加入で無料付帯。ビルドが揃った段階で利用 |

**推奨する最小構成の順序**：
1. （Mac不要）Apple Developer Program登録
2. （Mac不要）Family Controls Distribution entitlement申請をメイン＋全Extension分、早めに提出（承認待ちがボトルネックになりやすいため）
3. （一時的クラウドMac、数時間）Xcode projectにExtension target追加、entitlements/App Groups/Signing設定
4. （Mac不要、以降）GitHub Actions macOSランナーでCIビルド・署名・TestFlightアップロードを自動化
5. （実機必須）物理iPhoneでShield/unshield/re-shieldの実地検証
6. （Mac不要）TestFlightで動作確認・フィードバック収集

---

## 9. Phase 7A完了条件（まとめ）

- **iOSで再現可能なMATE機能**：本気モード累積エスカレーション、1時間リセット、統計、SAVE時間、streak、ルール固定モードのアプリ内ロジック、通常待機、本気モードの自由記述・YES/NO・煽り文 — いずれもMATE本体アプリ内でAndroid版とほぼ同一のDartロジック・UIで再現可能
- **完全再現できない機能／制約**：
  - Shield→MATE本体への直接遷移（通知タップ中継が必要、1タップ＋若干の遅延が増える）
  - MATE本体→対象アプリへの自動復帰（公式APIなし、URL Schemeのベストエフォートかユーザーの手動操作）
  - 対象アプリ選択UIの自由なカスタマイズ（`FamilyActivityPicker`という不透明トークンベースのシステムUIに依存）
  - ルール固定モードによる完全な迂回防止（`.individual`認可はユーザーがiOS設定からいつでも取り消せる、プラットフォーム構造上の制約）
- **Android版から変更が必要なUX**：Shield画面（システムテンプレート、自由なデザイン不可）／Shieldから本体への遷移が通知タップ経由になる／対象アプリへの復帰導線の再設計／一時休止・再shieldの自動化に信頼性面のセーフティネットが必要
- **推奨iOSアーキテクチャ**：セクション1・3参照。Shield ConfigurationとShield Actionの2 Extensionは薄く保ち（システムテンプレート表示＋通知発火のみ）、実質的な機能はすべてMATE本体アプリ側のFlutterで実装
- **必要なApp／Extension構成**：メインアプリ＋Shield Configuration Extension＋Shield Action Extension＋Device Activity Monitor Extensionの計4 target
- **Bundle ID一覧**：セクション5参照
- **Entitlement一覧**：Family Controls（Development即時利用可／Distributionは4 target個別申請）＋App Groups（4 target共通）
- **App Group等の共有ストレージ設計**：`group.com.minatoapps.mate`を全targetで共有。`PreferencesService`のkey/value形式をExtension側Swiftコードからも同一スキーマで読み書きする設計が必要（セクション6・7）
- **Windowsで今できる作業**：セクション7の候補（未着手、指示待ち）
- **macOSが必要になる境界**：Extension target追加・entitlements・Signing設定・実機検証（セクション8）
- **Apple側でユーザー本人が行う必要がある手続き**：Apple Developer Program登録、Bundle ID登録、App Groups/Family Controls capability有効化、Family Controls Distribution entitlement申請（メイン＋Extension個別）（セクション4）
- **Phase 7Bの実装手順**：セクション8の推奨順序
- **iOS対応で重大なブロッカーがあるか**：**開発を止めるレベルの致命的ブロッカーはなし**。ただし「Shield→本体」「本体→対象アプリ復帰」の2箇所はAndroid版と同一のシームレスさを諦める必要があり、UX設計の見直しが必須。また`DeviceActivityMonitorExtension`の発火信頼性に現在進行形の既知不具合があり、再shield設計にセーフティネットが要る

---

以上でPhase 7Aの調査・設計を完了します。ここで一度停止します。Phase 7Bのネイティブ実装（Xcode/Swift側の実装、Extension追加、entitlement申請の実行など）は、この設計内容をご確認いただいてから着手します。

Android v1のコードは変更していません。Play Store公開作業も行っていません。
