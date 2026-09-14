# Phase 7A: iOS Architecture / Feasibility 調査・設計レポート

作成日: 2026-09-15（初版）／2026-09-15 追記更新（`ShieldActionResponse.openParentalControlsApp`の確認を反映）
ブランチ: `phase7-ios`（`main` = `b662434` から分岐、Android v1 Release Candidate機能凍結済み）
開発環境: Windows（macOS/Xcode実機検証は未実施。本レポートはApple公式ドキュメント調査 + 既存Dartコード調査に基づく設計であり、Xcodeでのビルド確認は行っていない）

## 更新履歴

**【追記】初版では「ShieldActionResponseは`.close`/`.defer`/`.none`の3つのみで、ShieldからMATE本体を直接開く公式APIは存在しない」と結論していたが、これは誤り（正確には「当時参照した情報が古かった」）。Apple公式ドキュメントを再確認した結果、`ShieldActionResponse.openParentalControlsApp`というcaseが実在し、iOS/iPadOS/Mac Catalyst **26.5+**で正式に利用可能であることを確認した。詳細はセクション3を全面更新。旧調査結果は打ち消し線ではなく「旧」として残し、何が変わったかを明示する。**

このドキュメントの結論を先に挙げるなら：**iOS版MATEは実現可能。Shield→MATE本体の遷移は、iOS 26.5以降であれば`ShieldActionResponse.openParentalControlsApp`という公式APIで直接実現できる（要Phase 7B実機検証）。iOS 26.5未満では引き続き通知中継のフォールバックが必要**（詳細はセクション3）。一方、MATE本体→対象アプリへの自動復帰は今回のAPI確認では解決しておらず、別問題として依然未解決（セクション3参照）。

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
| `ShieldActionExtension` (`ShieldActionDelegate`) | Shield画面のボタンタップを処理する**別Extension target**。返せるのは `.close` / `.defer` / `.none` に加え、iOS 26.5+では `.openParentalControlsApp`（MATE本体を直接開かせる指示）も利用可能【追記で更新、セクション3参照】 |

Android版のUsageStatsManager方式（能動ポーリングで検知→後追いで割り込み画面を被せる）とは根本的に発想が逆で、iOSは**OS自体がアプリ起動をブロックする**（Shieldが先に立ちはだかる、後追いではない）。これは弱点ではなくむしろ検知漏れ・競合状態（Android版で実際に踏んだGmail初回起動競合バグのような）が構造的に起こり得ないという利点でもある。

---

## 2. Android機能との対応表

| MATE機能 | Android実装 | iOS実現方法 | 分類 |
|---|---|---|---|
| 対象アプリ選択 | 自前Flutter UI（PackageManagerでアプリ一覧取得、アイコン/名前を自由表示） | `FamilyActivityPicker`（システム提供UI）。返るのは不透明`ApplicationToken` | **UXを変更すれば可能**（自前の一覧UIは組めない。トークンは不透明でアイコン/パッケージ名を自力取得できない） |
| アプリ起動時の介入 | `ForegroundWatcherService`が0.5秒ポーリングで検知→`InterventionActivity`を被せる | `ManagedSettingsStore.shield.applications`でOSレベルに事前ブロック（Shield画面をOSが表示） | **同等に再現可能**（方式は逆だが体験としては同等以上。ポーリング遅延・競合状態がそもそも存在しない） |
| 「何のために開く？」自由記述 | InterventionActivity内のFlutter TextField | Shield自体には入力欄を置けない。MATE本体アプリ内でのみ可能 | **iOS 26.5+／`.individual`対応確認後は同等に再現可能、それ未満は UXを変更すれば可能**（セクション3参照。`openParentalControlsApp`によりShield→本体の遷移がほぼ直結になる見込み。未確認環境では引き続き通知中継が必要） |
| 「それ、今必要？」YES/NO | InterventionScreen/SeriousModeFlow | MATE本体アプリ内で完全再現可能（既存Dart UIロジックがそのまま動く） | **同等に再現可能**（本体アプリ到達後は） |
| 煽り文（本気モードcopy） | `serious_mode_templates.dart` | 同上、MATE本体アプリ内 | **同等に再現可能** |
| 通常待機 | カウントダウンUI＋タイマー | 同上、MATE本体アプリ内 | **同等に再現可能**（「待った後に対象アプリを開く」の復帰導線は`openParentalControlsApp`とは無関係の別問題としてセクション3-6の制約が残る） |
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

## 3. Shield → MATE本体への遷移（最重要調査事項）【2026-09-15 追記で全面更新】

### 3-0. 旧調査結果（初版時点、誤り含む・記録として残す）

初版では以下のように結論していた：

> Shield上のボタン→直接MATE本体が開くルートは**Appleの現行公式APIでは実現不可能**。`ShieldActionResponse`が持つケースは`.close`/`.defer`/`.none`の3つのみ。Appleのフレームワークエンジニアがdeveloper forumsで「サポートされた方法はない」と明言（2022年11月・2025年1月）。唯一の回避策はローカル通知経由の中継のみ。

これは**当時参照した一次情報（2022年11月・2025年1月のApple公式フォーラム回答、および2026年3月時点のdeveloper forumsでの`openParentApp`機能要望スレッド）が、後述の新APIが追加される前の状態を反映したものだった**ために生じた結論であり、現在は古い。以下3-1以降が最新の確認結果。

### 3-1. 最新公式APIによる更新：`ShieldActionResponse.openParentalControlsApp`

Apple公式ドキュメント（developer.apple.com、生JSON APIを直接取得し内容を検証済み — モデルの要約ではなく生データで"openParentalControlsApp"の文字列出現と`platforms`メタデータを確認）で、`ShieldActionResponse`enumに4番目のcaseとして以下が存在することを確認した。

- **Case名**: `openParentalControlsApp`
- **公式説明文（逐語）**: "An instruction for the system to open your parental controls app that is responsible for shielding the application or web browser"
- **Availability（個別シンボルページで確認）**: iOS **26.5+**、iPadOS **26.5+**、Mac Catalyst **26.5+**（`beta: false`, `deprecated: false`, `unavailable: false` — 正式リリース済み扱い）

注記：`ShieldActionResponse`enum全体の一覧ページでは、全4ケースがまとめて「iOS 15.0+」という表示になっており紛らわしいが、これは他の3ケース（`.close`/`.defer`/`.none`）がenum自体の導入時点（iOS 15）から存在することに引きずられた一覧表示で、**`openParentalControlsApp`個別のシンボルページでは明確にiOS 26.5+**と表示される。個別ページの情報の方が正確と判断した。

**利用方法**：`ShieldActionDelegate.handle(action: ShieldAction, for: ApplicationToken, completionHandler: (ShieldActionResponse) -> Void)`のcompletionHandlerに`.openParentalControlsApp`を渡せばよい。`for:`引数として、その瞬間shieldされている`ApplicationToken`をExtensionは既に受け取っている。

**タイムライン的な整合性**：2026年6月のWWDC 2026では「trust and safety」を軸にした保護者向け機能の大規模刷新（Child Account刷新、Screen Time再設計、開発者向けSafety API群）が発表されており、`openParentalControlsApp`はこの流れの中でiOS 26.5（2026年内リリース）に合わせて追加されたAPIと考えるのが時系列的に整合する。2026年3月時点のdeveloper forumsでの機能要望スレッド（`openParentApp`という名前で要望されていたもの）と、Apple公式が実際に出荷した`openParentalControlsApp`は文言こそ違うが同種の要望に応える形で追加されたものと考えられる。

### 3-2. 最新OSでの推奨UX（iOS 26.5+、確認済み事項に基づく）

```
対象アプリを開く
↓
iOS Shield表示（「MATEで確認」等のボタン）
↓
ShieldActionExtension.handle(action:for:completionHandler:) が呼ばれる
  → （保険として）App Group共有ストレージに対象ApplicationTokenを書き込む
  → completionHandler(.openParentalControlsApp)
↓
システムがMATE本体を直接起動（通知タップ不要、公式API経由）
↓
MATE本体：どの対象アプリがトリガーだったかを判定
  （システムが起動コンテキストで自動的に渡すのか、Extension側で保存したApp Group共有ストレージを読むのかは未確認 — 3-4参照）
↓
「何のために開く？」→ JunkReasonDetector検証 → YES/NO → （必要なら）本気モード累積待機
↓
条件を満たした場合のみ shield.applications から対象アプリのトークンを除外（unshield）
↓
対象アプリへの復帰 ← ★これは`openParentalControlsApp`とは別問題、3-6参照
↓
DeviceActivityMonitorExtensionでN分後に自動re-shield（★信頼性に既知課題、3-7参照）
```

初版で標準UXとしていた「Shieldボタン→ローカル通知→通知タップ→MATE本体」という中継フローは、**iOS 26.5以降では不要になる見込み**。ご指示の通り、古い仕様（通知中継）を最新iOSまで標準UXとして扱うのは避け、`openParentalControlsApp`が使える環境では直接遷移を第一候補とする。

### 3-3. 旧OSフォールバック（iOS 26.5未満）

`openParentalControlsApp`はiOS 26.5未満の端末では利用できないため、それ未満のOSバージョンでは初版で調査した以下のフローを維持する：

1. Shieldのボタンタップ → `ShieldActionDelegate.handle(action:)`が呼ばれる
2. ローカル通知（deep link付き）を発火し、`.close`を返す
3. ユーザーが通知をタップ → MATE本体アプリが開く
4. MATE本体のFlutter UIが動く

実装上は `if #available(iOS 26.5, *) { completionHandler(.openParentalControlsApp) } else { /* ローカル通知フォールバック */ completionHandler(.close) }` のような分岐が必要になる。MATEの最低対応iOSバージョンをどこに置くか（26.5をターゲットにするか、それ未満も広くサポートしてフォールバックを常設するか）は、iOS 26.5のリリース時期とユーザー普及率を見てPhase 7Bで判断が必要（本レポート作成時点でリリースからの経過期間が短く、実際の普及率データは持ち合わせていない）。

### 3-4. 未確認事項：対象ApplicationTokenをMATE本体へどう引き継ぐか

**現時点で最も重要な未確認事項。** `openParentalControlsApp`のApple公式シンボルページには、追加のDiscussion/サンプルコードが一切なく、「システムがMATE本体を起動した後、どのアプリがトリガーだったかをアプリ側がどう知るか」を説明する記述が見当たらなかった（WWDC 26セッション動画・リリースノートの精読までは今回実施していない）。

考えられる可能性：
- (a) システムが起動時に何らかの形（launch options、`NSUserActivity`、Scene connection optionsなど）で自動的にtoken情報を渡す
- (b) 渡されない前提で、Extension側が`.openParentalControlsApp`を返す前に自前でApp Group共有ストレージへtokenを書き込んでおき、MATE本体がそれを読む

設計としては(b)を前提に進めるのが安全（Appleの一般的なプライバシー設計パターン、および初版から一貫してApp Group共有ストレージを前提にしている設計と矛盾しない）。ただし(a)の自動連携が実際にあるなら実装がよりシンプルになるため、**Phase 7Bで実機（iOS 26.5+）を使って必ず検証すべき最優先事項**として明記する。

### 3-5. 未確認事項：`.individual`（自己管理）authorizationでも使えるか

**もう一つの重要な未確認事項。** case名が「open your **parental** controls app」であり、WWDC 2026の文脈が主に真の保護者/子供シナリオ（Child Account刷新）にフォーカスしていたことから、このAPIが`.child`権限を前提に設計されている可能性を否定できない。MATEは`.individual`（自己管理、非-保護者用途）で動くアプリであり、この組み合わせで`.openParentalControlsApp`が同様に機能するかはApple公式ドキュメント上どこにも明言されていなかった（肯定も否定もされていない）。

これが確認できない場合、`.individual`認可のMATEでは`openParentalControlsApp`が使えず、iOS 26.5以降でも3-3のフォールバック（通知中継）が事実上の標準UXになる可能性がある。**Phase 7Bの実機検証で最初に確認すべき項目**として扱う。

### 3-6. 「Shield→MATEを開けるか」と「MATE→元の対象アプリへ自動復帰できるか」は別問題

ご指摘の通り、この二つを混同しないよう明確に切り分ける。

- **Shield→MATE本体**：今回の調査で大きく前進。iOS 26.5+かつ`.individual`で機能する前提が確認できれば、公式APIで直接遷移可能（3-2）。
- **MATE→対象アプリへの自動復帰**：`openParentalControlsApp`はShield側からMATEを開く一方向の指示であり、この逆方向（MATE本体から対象アプリを自動的に開き直す）の問題には一切関与しない。この点は初版の調査結果から変化なし：**MATE本体から「対象アプリを直接起動する」公式APIは存在しない**。ベストエフォートとして、対象アプリがURL Scheme/Universal Linkに対応していれば（Instagram: `instagram://`、YouTube: `youtube://`、X: `twitter://`等、主要SNSアプリは大抵対応）それを試みることはできるが、汎用的な保証はない。フォールバックとして「ホーム画面から◯◯を開いてください」という案内が必要になる点は変わらない。

### 3-7. 再shieldの信頼性リスク（変化なし）

`DeviceActivityMonitorExtension`の`eventDidReachThreshold`/`intervalDidEnd`について、developer forumsで現在進行形の不具合報告あり（iOS 26.2時点で`eventDidReachThreshold`が実利用0分でも発火する、非リピートスケジュールで`intervalDidEnd`が発火しないケースが報告されている）。「一時解除→N分後に自動re-shield」という設計はこの上に成り立つため、**発火漏れ時のセーフティネット**（例: MATE本体起動のたびにshield状態を再検証する／unshield時に本体側でも別途タイマーを持ち次回起動時に強制re-shieldする）をPhase 7Bの実装で必ず設計する必要がある。`openParentalControlsApp`の確認とは無関係の別問題であり、今回の追記調査でも状況は変わっていない。

### 3-8. 未確認事項まとめ

- ApplicationTokenの引き継ぎ方法（自動 or App Group経由の自前実装か）— 3-4
- `.individual` authorizationでの動作可否 — 3-5
- Family Controls entitlementとの関係（`openParentalControlsApp`固有の追加entitlementが必要かどうかはドキュメント上見当たらなかったが、既存のFamily Controls entitlement保有Extensionであれば使える、という前提で設計を進める。要Phase 7B確認）
- App Store配布時の利用可否（`unavailable: false`/`beta: false`であることから配布可能なAPIと判断しているが、リリース間もないAPIであり実配布事例のコミュニティ報告はまだ見当たらない）
- iOS 26.5の実機普及率・MATEの最低対応バージョンをどこに置くべきか

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

**重要な設計含意**：Android版の「別Flutter engineでInterventionActivityを起動する」というアーキテクチャの中核部分（`InterventionBridge`、`intervention_main.dart`）はiOSには一切移植できない。iOSでは**Shield自体はFlutterで描画できず**（Extensionにはメモリ制約もあり、Flutter engineを積むのは非現実的）、Flutter UIが動くのはユーザーがMATE本体アプリに到達した後だけ。つまりiOS版の「介入UI」は事実上すべて**メインアプリのFlutterウィジェットツリーの一部**として作ることになり、Android版のような「独立ウィンドウとして被さる」体験にはならない。この結論自体はセクション3の`openParentalControlsApp`確認によっても変わらない——変わるのは本体アプリへの**遷移経路**（直接 or 通知経由）だけで、本体到達後の実装がFlutterウィジェットツリーの一部になるという設計は変化しない。

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
  - MATE本体→対象アプリへの自動復帰（公式APIなし、URL Schemeのベストエフォートかユーザーの手動操作。`openParentalControlsApp`とは無関係の別問題、セクション3-6）
  - 対象アプリ選択UIの自由なカスタマイズ（`FamilyActivityPicker`という不透明トークンベースのシステムUIに依存）
  - ルール固定モードによる完全な迂回防止（`.individual`認可はユーザーがiOS設定からいつでも取り消せる、プラットフォーム構造上の制約）
  - Shield→MATE本体への直接遷移は、iOS 26.5+かつ`.individual`authorizationでの動作が実機で確認できるまでは未確定（セクション3-4・3-5）。確認できなければiOS 26.5未満と同様、通知中継が必要
- **Android版から変更が必要なUX**：Shield画面（システムテンプレート、自由なデザイン不可）／iOS 26.5未満またはtoken引き継ぎ・`.individual`対応が実機で確認できない場合はShieldから本体への遷移が通知タップ経由になる／対象アプリへの復帰導線の再設計／一時休止・再shieldの自動化に信頼性面のセーフティネットが必要
- **推奨iOSアーキテクチャ**：セクション1・3参照。Shield ConfigurationとShield Actionの2 Extensionは薄く保ち（システムテンプレート表示＋通知発火のみ）、実質的な機能はすべてMATE本体アプリ側のFlutterで実装
- **必要なApp／Extension構成**：メインアプリ＋Shield Configuration Extension＋Shield Action Extension＋Device Activity Monitor Extensionの計4 target
- **Bundle ID一覧**：セクション5参照
- **Entitlement一覧**：Family Controls（Development即時利用可／Distributionは4 target個別申請）＋App Groups（4 target共通）
- **App Group等の共有ストレージ設計**：`group.com.minatoapps.mate`を全targetで共有。`PreferencesService`のkey/value形式をExtension側Swiftコードからも同一スキーマで読み書きする設計が必要（セクション6・7）
- **Windowsで今できる作業**：セクション7の候補（未着手、指示待ち）
- **macOSが必要になる境界**：Extension target追加・entitlements・Signing設定・実機検証（セクション8）
- **Apple側でユーザー本人が行う必要がある手続き**：Apple Developer Program登録、Bundle ID登録、App Groups/Family Controls capability有効化、Family Controls Distribution entitlement申請（メイン＋Extension個別）（セクション4）
- **Phase 7Bの実装手順**：セクション8の推奨順序
- **iOS対応で重大なブロッカーがあるか**：**開発を止めるレベルの致命的ブロッカーはなし**。「Shield→本体」は`openParentalControlsApp`（iOS 26.5+）により大きく改善する見込みだが、token引き継ぎ方法と`.individual`対応可否という2つの重要未確認事項が残るため、Phase 7Bの実機検証を最優先で行うべき。「本体→対象アプリ復帰」は今回の追記調査でも未解決のまま、Android版と同一のシームレスさを諦める必要がある。また`DeviceActivityMonitorExtension`の発火信頼性に現在進行形の既知不具合があり、再shield設計にセーフティネットが要る

---

以上でPhase 7Aの調査・設計を完了します。ここで一度停止します。Phase 7Bのネイティブ実装（Xcode/Swift側の実装、Extension追加、entitlement申請の実行など）は、この設計内容をご確認いただいてから着手します。

Android v1のコードは変更していません。Play Store公開作業も行っていません。
