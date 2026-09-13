import 'dart:math';

import '../../data/local/preferences_service.dart';

/// The situational facts a 本気モード (Serious Mode) message template can
/// weave in — everything here is already known locally, no AI/API involved.
class SeriousModeTemplateContext {
  const SeriousModeTemplateContext({
    required this.reason,
    required this.goal,
    required this.todayCount,
    required this.waitSeconds,
  });

  /// What the user typed for "何のために開く？". Templates that reference it
  /// are only offered when this is non-empty (see [SeriousModeCopy.pickNoSting]).
  final String reason;

  /// The user's registered goal, or `null` if they haven't set one.
  final String? goal;

  /// How many times today the serious-mode flow has been triggered.
  final int todayCount;

  /// What "それでも開く" would cost right now (the escalated wait, seconds).
  final int waitSeconds;
}

typedef _Build = String Function(SeriousModeTemplateContext ctx);

class _Template {
  const _Template(this.id, this.build);
  final String id;
  final _Build build;
}

/// Picks 本気モード copy from ~100 hand-written, categorized templates
/// instead of one flat random pool, so the line shown actually reflects
/// what's happening (the user's own typed reason, their goal, how many
/// times today, how much is at stake) rather than feeling generic.
///
/// No AI, no network calls — this is a local, synchronous-feeling table
/// lookup (the only `await`s are reading/writing the ~20-entry recent-usage
/// history in [PreferencesService], so the same line isn't repeated too
/// soon).
///
/// Tone constraint (Phase 6.6): a little provocative/stinging/wryly funny is
/// fine; never a personal attack, discrimination, or excessive insult. Every
/// line targets *the choice/contradiction/susceptibility to temptation*, not
/// the person themselves.
class SeriousModeCopy {
  SeriousModeCopy._();

  static final _random = Random();

  /// A line to show after the user answers "今必要ではない" (NO) — meant to
  /// use their own admission against the urge, per the Phase 6.6 spec.
  static Future<String> pickNoSting(PreferencesService prefs, SeriousModeTemplateContext ctx) {
    final pool = <_Template>[..._genericSting, ..._countBased, ..._waitBased];
    if (ctx.reason.trim().isNotEmpty) pool.addAll(_reasonBased);
    if (ctx.goal != null && ctx.goal!.trim().isNotEmpty) {
      pool.addAll(_goalBased);
    } else {
      pool.addAll(_noGoalGeneric);
    }
    return _pickAndRecord(prefs, pool, ctx);
  }

  /// A short, light acknowledgement for the "今必要" (YES) branch — genuine
  /// needs shouldn't be over-obstructed, so this never stings.
  static Future<String> pickYesAck(PreferencesService prefs, SeriousModeTemplateContext ctx) {
    return _pickAndRecord(prefs, List<_Template>.of(_yesAck), ctx);
  }

  static Future<String> _pickAndRecord(
    PreferencesService prefs,
    List<_Template> pool,
    SeriousModeTemplateContext ctx,
  ) async {
    final recent = await prefs.loadSeriousModeMessageHistory();
    var candidates = pool.where((t) => !recent.contains(t.id)).toList();
    // If recent history happens to cover the whole applicable pool (a small
    // context, e.g. no goal + no reason), fall back to the full pool rather
    // than get stuck — still picked at random, so it won't be the exact same
    // line as immediately before unless the pool has only one entry.
    if (candidates.isEmpty) candidates = pool;
    final chosen = candidates[_random.nextInt(candidates.length)];
    final safeCtx = ctx.reason.trim().isEmpty
        ? SeriousModeTemplateContext(reason: 'それ', goal: ctx.goal, todayCount: ctx.todayCount, waitSeconds: ctx.waitSeconds)
        : ctx;
    await prefs.pushSeriousModeMessageId(chosen.id);
    return chosen.build(safeCtx);
  }

  static final _genericSting = <_Template>[
    _Template('sting_1', (c) => '必要ないって自分で答えたのに、それでも開く？'),
    _Template('sting_2', (c) => '今じゃなくていいって分かってるんだ。'),
    _Template('sting_3', (c) => '意志弱いね。それでも開く？'),
    _Template('sting_4', (c) => '自分で「いらない」って言ったんだよ、さっき。'),
    _Template('sting_5', (c) => 'その指、もう誘惑に負けかけてるよ。'),
    _Template('sting_6', (c) => '「今じゃない」って、数秒前の自分が言ってた。'),
    _Template('sting_7', (c) => '誘惑には勝てても、指には勝てないタイプ？'),
    _Template('sting_8', (c) => '今の一瞬が、あとで後悔になるやつかも。'),
    _Template('sting_9', (c) => 'その気持ち、10分後には消えてるやつだよ。'),
    _Template('sting_10', (c) => '開く前に、もう一度聞くね。ほんとに今？'),
    _Template('sting_11', (c) => '「いらない」と「開きたい」、どっちが本音？'),
    _Template('sting_12', (c) => '誘惑に負けそうな自分、自覚ある？'),
    _Template('sting_13', (c) => 'スマホは逃げない。でも今日はここまでにしない？'),
    _Template('sting_14', (c) => 'その1タップ、あとの自分が笑ってくれるといいけど。'),
    _Template('sting_15', (c) => '「今必要ない」に自分で丸をつけたのに。'),
    _Template('sting_16', (c) => '強がらなくていいよ。でも開くなら覚悟して。'),
    _Template('sting_17', (c) => 'この流れ、いつものパターンじゃない？'),
    _Template('sting_18', (c) => '誘惑に負ける理由、今考えてみて。'),
    _Template('sting_19', (c) => '本当は分かってるくせに。'),
    _Template('sting_20', (c) => '「ちょっとだけ」が一番危ない。'),
    _Template('sting_21', (c) => '今の自分、目標に近づいてる？それとも逃げてる？'),
    _Template('sting_22', (c) => 'その手、無意識に動いてない？'),
    _Template('sting_23', (c) => '「今必要ない」を選んだのは、誰でもない自分。'),
    _Template('sting_24', (c) => '誘惑に負けるの、今日はここまでにしない？'),
    _Template('sting_25', (c) => 'そのタップ、5秒だけ待ってから決めても遅くないよ。'),
  ];

  static final _countBased = <_Template>[
    _Template('count_1', (c) => '今日これで${c.todayCount}回目。'),
    _Template('count_2', (c) => '今日、もう${c.todayCount}回もここに来てるよ。'),
    _Template('count_3', (c) => '${c.todayCount}回目の「それでも開く」、多くない？'),
    _Template('count_4', (c) => 'この1回だけで全部が決まるわけじゃない。でも、その「1回だけ」今日何回目？'),
    _Template('count_5', (c) => '今日${c.todayCount}回目の誘惑。さすがに気づいてるよね？'),
    _Template('count_6', (c) => '今日はもう${c.todayCount}回、この画面を見てる。'),
    _Template('count_7', (c) => '${c.todayCount}回目だよ、今日。まだ続ける？'),
    _Template('count_8', (c) => '今日${c.todayCount}回目の「今必要ない」を無視するところ。'),
    _Template('count_9', (c) => 'この画面、今日${c.todayCount}回目の登場。'),
    _Template('count_10', (c) => '${c.todayCount}回もここまで来て、まだ開く？'),
    _Template('count_11', (c) => '今日の記録、また${c.todayCount}回目を更新中。'),
    _Template('count_12', (c) => '積み重ねると${c.todayCount}回。ちりも積もれば、だよ。'),
    _Template('count_13', (c) => '${c.todayCount}回目の自分に、1回目の自分は何て言うと思う？'),
    _Template('count_14', (c) => '今日${c.todayCount}回目、正直多い。'),
    _Template('count_15', (c) => '${c.todayCount}回目。そろそろ気づいてもいい頃。'),
  ];

  static final _waitBased = <_Template>[
    _Template('wait_1', (c) => '${c.waitSeconds}秒待ってまで、それ見たい？'),
    _Template('wait_2', (c) => '${c.waitSeconds}秒も払う価値、本当にある？'),
    _Template('wait_3', (c) => '次はもっと待つことになるよ。今${c.waitSeconds}秒。'),
    _Template('wait_4', (c) => '${c.waitSeconds}秒待つ間に、目標のこと1つ思い出せる？'),
    _Template('wait_5', (c) => '${c.waitSeconds}秒、正直長くなってきてない？'),
    _Template('wait_6', (c) => '待ち時間が${c.waitSeconds}秒まで伸びてる。気づいてた？'),
    _Template('wait_7', (c) => '${c.waitSeconds}秒待ってでも欲しいもの？'),
    _Template('wait_8', (c) => 'この調子だと次は${c.waitSeconds}秒よりさらに長い。'),
    _Template('wait_9', (c) => '${c.waitSeconds}秒のために、今日を使う？'),
    _Template('wait_10', (c) => '${c.waitSeconds}秒、意外と長いよ。試してみる？'),
    _Template('wait_11', (c) => '誘惑の代償、今${c.waitSeconds}秒まで来てる。'),
    _Template('wait_12', (c) => '${c.waitSeconds}秒待った先に、後悔だけだったら？'),
    _Template('wait_13', (c) => '${c.waitSeconds}秒。それでも今開く理由、ある？'),
    _Template('wait_14', (c) => '積み上がって${c.waitSeconds}秒。まだ増やす？'),
    _Template('wait_15', (c) => '${c.waitSeconds}秒待つより先にやることない？'),
  ];

  static final _reasonBased = <_Template>[
    _Template('reason_1', (c) => '「${c.reason}」は今必要ないって答えたよね。'),
    _Template('reason_2', (c) => '「${c.reason}」、さっき自分で「いらない」って言ったのに。'),
    _Template('reason_3', (c) => '「${c.reason}」のために、今日を使っていいの？'),
    _Template('reason_4', (c) => '「${c.reason}」って書いたけど、本音は違うんじゃない？'),
    _Template('reason_5', (c) => '「${c.reason}」、さっきの自分は「今じゃない」って言ってたよ。'),
    _Template('reason_6', (c) => '「${c.reason}」のせいにして、開こうとしてない？'),
    _Template('reason_7', (c) => '「${c.reason}」、それ今じゃなくても困らないやつだよね。'),
    _Template('reason_8', (c) => '「${c.reason}」と答えて、「いらない」とも答えた。矛盾してるよ。'),
    _Template('reason_9', (c) => '「${c.reason}」を理由に、また誘惑に負けるところ。'),
    _Template('reason_10', (c) => '「${c.reason}」、それは開く理由じゃなくて言い訳じゃない？'),
    _Template('reason_11', (c) => '「${c.reason}」って言った手前、今開いたら格好つかないよ。'),
    _Template('reason_12', (c) => 'さっき「${c.reason}」って正直に書いたよね。なら今も正直に。'),
    _Template('reason_13', (c) => '「${c.reason}」、それ本当に今しかできないこと？'),
    _Template('reason_14', (c) => '「${c.reason}」と「今必要ない」、両方あなたの言葉。'),
    _Template('reason_15', (c) => '「${c.reason}」のためだけなら、開かなくても済むんじゃない？'),
  ];

  static final _goalBased = <_Template>[
    _Template('goal_1', (c) => '目標は「${c.goal}」。今やろうとしてることは、そっちに近づいてる？'),
    _Template('goal_2', (c) => '「${c.goal}」を掲げたの、自分だよね。'),
    _Template('goal_3', (c) => '「${c.goal}」に近づく1分？それとも遠ざかる1分？'),
    _Template('goal_4', (c) => '「${c.goal}」、今この選択の先にある？'),
    _Template('goal_5', (c) => '「${c.goal}」を思い出して。今、必要な行動かな。'),
    _Template('goal_6', (c) => '未来の自分は「${c.goal}」を達成してる？今の選択次第。'),
    _Template('goal_7', (c) => '「${c.goal}」のために我慢するって決めたの、いつだっけ。'),
    _Template('goal_8', (c) => '「${c.goal}」と、今開こうとしてるアプリ。どっちが本当に大事？'),
    _Template('goal_9', (c) => '「${c.goal}」に向けて、今日何かやった？'),
    _Template('goal_10', (c) => '「${c.goal}」を叶えた自分が、今の自分を見たら何て言う？'),
    _Template('goal_11', (c) => '「${c.goal}」、まだ本気で目指してる？今の行動を見る限り。'),
    _Template('goal_12', (c) => '「${c.goal}」のための時間、今削ってない？'),
    _Template('goal_13', (c) => '「${c.goal}」を諦めたわけじゃないなら、今は踏みとどまろう。'),
    _Template('goal_14', (c) => '「${c.goal}」に使うはずだった集中力、今どこ行った？'),
    _Template('goal_15', (c) => '「${c.goal}」。忘れてなければ、今開かない方がいいはず。'),
  ];

  static final _noGoalGeneric = <_Template>[
    _Template('nogoal_1', (c) => '目標、まだ登録してないんだね。決めておくと、こういう時に思い出せるよ。'),
    _Template('nogoal_2', (c) => 'やりたいこと、なんだっけ。目標を登録すると次から表示されるよ。'),
    _Template('nogoal_3', (c) => '何のために頑張ってるか、思い出せる？目標を決めておくと楽になるよ。'),
    _Template('nogoal_4', (c) => '今、何を優先したい人だっけ。目標を登録すると分かりやすくなるよ。'),
    _Template('nogoal_5', (c) => '目的を忘れかけてない？設定から目標を登録できるよ。'),
    _Template('nogoal_6', (c) => '何かに向かって頑張ってるはず。目標、登録してみる？'),
    _Template('nogoal_7', (c) => '目標がないと、こういう時に踏みとどまりにくいかも。'),
    _Template('nogoal_8', (c) => '「本当にやりたいこと」、ちゃんと言葉にしてみない？'),
    _Template('nogoal_9', (c) => '目標を決めてる人の方が、この画面で踏みとどまりやすいよ。'),
    _Template('nogoal_10', (c) => '今の自分が何のために頑張ってるか、あとで登録しておこう。'),
  ];

  static final _yesAck = <_Template>[
    _Template('yes_1', (c) => '「${c.reason}」が目的なんだね。目的だけ済ませて戻ろ。'),
    _Template('yes_2', (c) => '「${c.reason}」ね、了解。それだけ済ませたら、また今度。'),
    _Template('yes_3', (c) => '「${c.reason}」のためなら仕方ないね。サクッと済ませよう。'),
    _Template('yes_4', (c) => '「${c.reason}」、分かった。用が済んだら戻ってきてね。'),
    _Template('yes_5', (c) => '「${c.reason}」ね。無理に止めたりしないよ。'),
    _Template('yes_6', (c) => '「${c.reason}」なら必要だもんね。ただ、長居はしないでね。'),
    _Template('yes_7', (c) => '「${c.reason}」了解。目的だけ果たして、あとは自分のために時間使お。'),
    _Template('yes_8', (c) => '「${c.reason}」、ちゃんと理由があるならOK。'),
    _Template('yes_9', (c) => '「${c.reason}」ね。じゃあそれだけ済ませよう。'),
    _Template('yes_10', (c) => '「${c.reason}」、分かった。深追いはしないようにね。'),
  ];
}
