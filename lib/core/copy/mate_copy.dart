/// Centralized Japanese copy for MATE.
///
/// One file so tone and wording can be iterated without hunting through
/// widgets (Phase 5's explicit goal: copy is something the product cares a
/// lot about going forward). Only literal, static strings live here —
/// widgets still own their own layout and conditional logic.
///
/// MATE's voice: a companion that helps you pause and remember why you
/// picked up your phone, not a blocker enforcing a rule. See
/// `interventionWaitingSubtitle`/`interventionReadySubtitle` and the
/// onboarding strings below for where that voice matters most.
class MateCopy {
  MateCopy._();

  // Navigation
  static const navHome = 'ホーム';
  static const navApps = '対象アプリ';
  static const navStats = '統計';
  static const navSettings = '設定';

  static const appName = 'MATE';
  static const cancel = 'キャンセル';
  static const save = '保存';

  // Home screen
  static const homeToday = '今日';
  static const homeTemptationsWonSuffix = '回、誘惑に勝った';
  static const homeNoAttemptsYet = '対象アプリを開くとここに記録されます';
  static const homeMinutesSavedSuffix = '分 SAVEしました';
  static const homeStreakSuffix = '日連続で継続中';
  static const homeStreakSubtitle = 'この調子でいきましょう';
  static const homeAttemptsLabel = '起動を試みた回数';
  static const homeWinRateLabel = '今日の勝率';
  static const homeGuardedAppsCountSuffix = '個のアプリを見守り中';
  static const homeNoGuardedApps = 'まだ対象アプリが設定されていません';
  static const homeGuardedAppsHint = '対象アプリはいつでも変更できます';
  static const homeGuardedAppsHintEmpty = '「対象アプリ」からいつでも設定できます';

  // Home status banner (Phase 6.5) — a one-glance answer to "is MATE
  // actually watching right now?", computed from state the app already
  // has (no new native sync).
  static const homeStatusGuarding = '見守り中';
  static const homeStatusPaused = '一時休止中';
  static const homeStatusNoApps = '見守るアプリを選んでください';
  static const homeStatusNeedsSetup = '設定が必要です';

  // Apps screen
  static const appsHint = '見守ってほしいアプリをONにしてください。行をタップすると待機時間や質問文を変更できます';
  static const appsFetchFailedTitle = 'インストール済みのアプリを取得できませんでした';
  static const appsFetchFailedHint = '下に引っ張って更新するか、しばらくしてから再度お試しください';
  static const appsUnguardConfirmTitle = '見守りを外しますか？';
  static String appsUnguardConfirmBody(String appName) => 'ルール固定モードが有効です。$appNameを見守り対象から外します。';
  static const appsRemove = '外す';
  static String appsSwitchSemanticLabel(String appName, bool guarded) =>
      '$appNameを見守る、${guarded ? "オン" : "オフ"}';
  static String appsWaitAndAlwaysGuardSuffix(int waitSeconds) => '$waitSeconds秒待機・常に見守る';
  static String appsWaitSuffix(int waitSeconds) => '$waitSeconds秒待機';

  // Per-app settings sheet
  static String sheetTitle(String appName) => '$appNameの見守り設定';
  static const sheetWaitTimeLabel = '待機時間';
  static const sheetStrictWaitHint = 'ルール固定モード中は、今より短い待機時間には変更できません';
  static const sheetQuestionLabel = 'ひとこと質問';
  static const sheetQuestionHint = '何しに開く？';
  static const sheetQuestionHelper = '空欄ならデフォルトの文言を使います';
  static const sheetAlwaysGuardTitle = '時間帯ルールを無視して常に見守る';
  static const sheetAlwaysGuardSubtitle = 'このアプリだけ24時間見守りたい場合に使います';
  static const sheetAlwaysGuardStrictHint = 'ルール固定モード中は「常に見守る」を解除できません';

  // Intervention screen — the one moment every user hits repeatedly, so this
  // is where the "companion, not blocker" voice matters most.
  static String interventionTitle(String appName) => '$appNameを開く？';
  static const interventionWaitingSubtitle = '一緒に、少しだけ待とう';
  static const interventionReadySubtitle = '決めるのは、あなた次第だよ';
  static String interventionHint(String question) => '$question（任意）';
  static const interventionGiveUp = 'やめとく';
  static const interventionOpen = '開く';
  static const interventionWaitingSemantic = '待機中';
  static const interventionReadySemantic = '開けるようになりました';

  // Settings — reorganized (Phase 6.5) around "usable with almost no
  // settings touched": 基本設定 holds the handful of things a first-time
  // user might plausibly want (pause, schedule, sound, theme); everything
  // else lives collapsed under 詳細設定 so it doesn't compete for attention.
  static const settingsBasicSection = '基本設定';
  static const settingsAdvancedSection = '詳細設定';
  static const settingsOtherSection = 'その他';

  static const settingsScheduleTitle = '見守る時間';
  static const settingsScheduleSubtitleOff = 'OFFなら24時間いつでも見守ります';
  static const settingsScheduleOvernightHint = '終了が開始より早い場合は、日付をまたぐ時間帯として扱います';
  static const settingsPauseTitle = '一時休止';
  static const settingsPauseSubtitle = '15分・30分・1時間・今日いっぱい';
  static const settingsPauseAutoResume = '時間になると自動で見守りを再開します';
  static const settingsResumeNow = '今すぐ再開';

  // "Strict Mode" (Phase 4-5) renamed for clarity (Phase 6.5): the old name
  // didn't say what it does. Wording below must keep matching the actual
  // behavior in StrictModeGuard — wait time can only be raised not lowered,
  // unguarding and "常に見守る" both need confirmation, and turning this
  // itself off has a short delay.
  static const settingsStrictModeTitle = 'ルール固定モード';
  static const settingsStrictModeSubtitle =
      '勉強中や作業中につい設定を甘くしてしまう人向け。ONの間は、待ち時間を短くしたり見守りを外したりを、簡単にはできなくします。';
  static const settingsPauseConfirmTitle = '一時休止しますか？';
  static const settingsPauseConfirmBody = 'ルール固定モードが有効です。一時休止中は対象アプリを開いても介入しません。';
  static const settingsContinue = '続ける';
  static const settingsPauseSheetTitle = 'MATEを一時休止';
  static const settingsPauseSheetSubtitle = '終了すると自動で見守りを再開します';
  static const settingsPause15 = '15分';
  static const settingsPause30 = '30分';
  static const settingsPause60 = '1時間';
  static const settingsPauseToday = '今日いっぱい';
  static const settingsSoundEffectsTitle = '操作音（SE）';
  static const settingsSoundEffectsSubtitle = 'ボタン操作時に短い効果音を鳴らします';
  static const settingsAppearance = '外観';
  static const settingsThemeSystem = '自動';
  static const settingsThemeLight = 'ライト';
  static const settingsThemeDark = 'ダーク';

  static const settingsPermissionsSection = '権限';
  static const settingsUsageAccessTitle = '使用状況へのアクセス';
  static const settingsUsageAccessGranted = '対象アプリの起動を検知できます';
  static const settingsUsageAccessMissing = '見守り対象アプリの起動検知に必要です（未許可）';
  static const settingsOverlayTitle = '他のアプリの上に表示';
  static const settingsOverlayGranted = '一呼吸おく画面をすぐに表示できます';
  static const settingsOverlayMissing = '見守り対象アプリを開いたときの画面表示に必要です（未許可）';
  static const settingsDetectionTestTitle = '検知テスト（開発用）';
  static const settingsDetectionTestSubtitle = '前面アプリの検知が動作しているか確認します';
  static const settingsOpenAction = '開く';
  static const settingsGoToSettingsAction = '設定';

  static const settingsAboutSection = 'このアプリについて';
  static const settingsVersion = 'バージョン';
  // Plain semantic version only — internal phase/milestone tracking has no
  // meaning to an end user and doesn't belong in user-facing UI.
  static const settingsVersionValue = '0.7.0';
  static const settingsPrivacyTitle = 'プライバシー';
  static const settingsPrivacyBody = 'データは端末内にのみ保存され、外部に送信されません';
  static const settingsReplayOnboarding = '使い方をもう一度見る';
  static const settingsReplayOnboardingSubtitle = 'MATEの考え方を、もう一度';
  static const settingsStrictDisableTitle = 'ルール固定モードを解除';
  static String settingsStrictDisableWaiting(int secondsLeft) => '勢いで解除しないため、あと$secondsLeft秒だけ待ってください。';
  static const settingsStrictDisableReady = '解除できます。必要になったらいつでも再びONにできます。';
  static const settingsStrictDisableCancel = 'やめる';
  static const settingsStrictDisableConfirm = '解除する';
  static const settingsPausedUntilToday = '今日いっぱい休止中';
  static String settingsPausedUntilTime(String time) => '$timeまで休止中';

  // Stats
  static const statsNoRecordsYet = 'まだ記録がありません。対象アプリを開くとここに実績が表示されます';
  static const statsLast7Days = '直近7日間';
  static String statsWeeklyWon(int count) => '合計 $count回 誘惑に勝ちました';
  static const statsCurrentStreak = '現在のストリーク';
  static const statsWeeklySave = '今週のSAVE時間';
  static const statsTotalSave = '累計SAVE時間';
  static const statsLast30Days = '直近30日';
  static const statsMonthlyWon = '誘惑に勝った回数';
  static const statsMonthlySave = 'SAVE時間';

  // Onboarding — states MATE's positioning up front, in its own voice.
  static const onboardingWelcomeTitle = 'はじめまして、MATEです';
  static const onboardingWelcomeBody = 'MATEは、アプリをブロックしません。\n開く前に、一呼吸だけ一緒に置く相棒です。';
  static const onboardingHowTitle = '使い方はシンプル';
  static const onboardingHowBody =
      '見守ってほしいアプリを選ぶと、開こうとした瞬間にMATEが一緒に立ち止まります。\n少し待つ間に「本当に今開きたい理由」を思い出せたら、それでOK。';
  static const onboardingPermissionsTitle = '2つだけ、力を貸してください';
  static const onboardingPermissionsBody = 'アプリに気づいて、すぐ声をかけるために必要です。あとからいつでも設定できます。';
  static const onboardingPermissionUsageTitle = '使用状況へのアクセス';
  static const onboardingPermissionUsageBody = 'アプリの起動に気づくために使います';
  static const onboardingPermissionOverlayTitle = '他のアプリの上に表示';
  static const onboardingPermissionOverlayBody = '気づいた瞬間にすぐ声をかけるために使います';
  static const onboardingGrant = '設定を開く';
  static const onboardingSkip = '後で設定する';
  static const onboardingGranted = '許可済み';
  static const onboardingDoneTitle = '準備完了！';
  static const onboardingDoneBody = '対象アプリはあとからいつでも変更できます。\nさっそく、見守ってほしいアプリを選んでみましょう。';
  static const onboardingStart = 'はじめる';
  static const onboardingNext = 'つぎへ';
  static const onboardingBack = 'もどる';
}
