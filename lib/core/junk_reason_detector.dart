/// Detects obviously junk/low-effort input in 本気モード's required "何のために
/// 開く？" reason field — keyboard mashing, single-character spam, symbols-only
/// text, and keyboard-walk strings (qwerty, asdf, ...).
///
/// Deliberately NOT natural-language understanding: this can't and isn't
/// meant to judge whether a reason is *true* or *sensible* — only whether it
/// looks like someone typed *something* just to get past the input
/// requirement without writing anything at all. Every check is a cheap,
/// explainable string heuristic (character-distinctness, exact short-pattern
/// repetition, a small curated keyboard-walk list); there is no AI/API call
/// or network access involved, and none of this runs outside 本気モード —
/// the normal-mode purpose field (always optional) never calls this.
class JunkReasonDetector {
  JunkReasonDetector._();

  /// Matches at least one Unicode letter or number. Used to reject
  /// symbols-only input (e.g. "！！！！" or "。。。。") without needing a
  /// per-script allowlist — anything with zero letters/digits in it is
  /// treated as not having said anything.
  static final RegExp _wordCharPattern = RegExp(r'[\p{L}\p{N}]', unicode: true);

  static const _keyboardWalkPatterns = [
    'qwerty',
    'qwertz',
    'azerty',
    'asdf',
    'asdfgh',
    'asdfghjkl',
    'zxcv',
    'zxcvbn',
    'qazwsx',
    'wsxedc',
    'edcrfv',
    '1qaz2wsx',
    'qweasdzxc',
    'poiuyt',
    'lkjhgf',
    'mnbvcx',
  ];

  /// True if [input] looks like an attempt to dodge the reason prompt
  /// rather than an actual (however short) answer.
  static bool isJunk(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return true;
    if (!_wordCharPattern.hasMatch(trimmed)) return true; // symbols only

    final runes = trimmed.runes.toList();
    final distinct = runes.toSet().length;

    // Same character repeated (e.g. "ああああ", "aaaaaa", "111111", "。。。。"),
    // but not a single genuine short word ("a", "ん" alone is fine).
    if (runes.length >= 2 && distinct == 1) return true;

    // A short pattern (of any length, not just one character) repeated 3+
    // times back to back — e.g. "あいあいあいあい" (period 2). Deliberately
    // *not* a broader "few distinct characters over N total characters"
    // rule: that would also catch a genuine 2-character reduplication like
    // "あいあい" (only 2 reps) or a short phrase that happens to reuse a
    // character, which is exactly the over-rejection the detector must
    // avoid — see the module doc.
    if (_isPeriodicSpam(trimmed)) return true;
    if (_isKeyboardWalk(trimmed)) return true;

    return false;
  }

  /// True if the whole string is some short substring repeated exactly 3+
  /// times back to back (e.g. "あいあいあいあい" = "あい" × 4,
  /// "asdfasdfasdf" = "asdf" × 3). Requiring 3+ repeats (rather than 2) keeps
  /// this from flagging ordinary short reduplicated words.
  static bool _isPeriodicSpam(String s) {
    final len = s.length;
    for (var period = 1; period <= len ~/ 3; period++) {
      if (len % period != 0) continue;
      final pattern = s.substring(0, period);
      var matchesThroughout = true;
      for (var i = period; i < len; i += period) {
        if (s.substring(i, i + period) != pattern) {
          matchesThroughout = false;
          break;
        }
      }
      if (matchesThroughout) return true;
    }
    return false;
  }

  static bool _isKeyboardWalk(String s) {
    final normalized = s.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    return _keyboardWalkPatterns.any(normalized.contains);
  }
}
