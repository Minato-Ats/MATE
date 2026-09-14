// Unit tests for JunkReasonDetector — the local heuristic that rejects
// obvious input-dodging in 本気モード's required "何のために開く？" field
// (keyboard mashing, symbols-only, keyboard-walk strings) without any
// natural-language understanding, AI, or network access.

import 'package:flutter_test/flutter_test.dart';
import 'package:mate/core/junk_reason_detector.dart';

void main() {
  group('JunkReasonDetector.isJunk — reject (obvious input-dodging)', () {
    const rejectCases = <String, String>{
      'ああああ': 'same-character repeat (kana)',
      'aaaaaa': 'same-character repeat (ascii)',
      '111111': 'same-character repeat (digits)',
      '!!!!!!': 'symbols only',
      '？？？？？？': 'full-width symbols only',
      '。。。。。。': 'full-width punctuation only',
      'qwerty': 'keyboard walk',
      'asdfgh': 'keyboard walk',
      'あいあいあいあい': 'short pattern repeated 4x',
      '': 'empty string',
      '   ': 'whitespace only',
      '　　　': 'full-width whitespace only',
      'AAAA': 'same-character repeat, uppercase',
      'asdfasdf': 'keyboard-walk substring repeated',
      'QWERTY': 'keyboard walk, uppercase',
      '  qwerty  ': 'keyboard walk with surrounding whitespace',
      'zxcvbn': 'keyboard walk',
    };

    rejectCases.forEach((input, reason) {
      test('rejects "$input" ($reason)', () {
        expect(JunkReasonDetector.isJunk(input), isTrue, reason: reason);
      });
    });
  });

  group('JunkReasonDetector.isJunk — accept (genuine short reasons)', () {
    const acceptCases = <String, String>{
      '返信': 'required example',
      '仕事': 'required example',
      '検索': 'required example',
      '英語': 'required example',
      '勉強': 'required example',
      '動画を見る': 'required example',
      '友達に返信': 'required example',
      '数学の解説を見る': 'required example',
      '調べ物': 'plausible short reason',
      'はい': 'plausible short reason, 2 distinct kana',
      'a': 'boundary: single character must not be rejected by length alone',
      'ab': 'boundary: 2 distinct characters, short',
      'OK': '2 distinct ascii letters, not a keyboard-walk pattern',
      '暇つぶし': 'reason used elsewhere in the app (Phase 6.6 example)',
      '仕事の確認': 'longer genuine reason, all distinct characters',
      '8時から会議': 'reason containing digits mixed with real words',
    };

    acceptCases.forEach((input, reason) {
      test('accepts "$input" ($reason)', () {
        expect(JunkReasonDetector.isJunk(input), isFalse, reason: reason);
      });
    });
  });

  group('JunkReasonDetector.isJunk — boundary cases', () {
    test('does not reject purely on short length (no minimum-length rule)', () {
      expect(JunkReasonDetector.isJunk('検'), isFalse);
    });

    test('a 3-character phrase with 3 distinct characters is not caught by the low-distinct rule', () {
      expect(JunkReasonDetector.isJunk('調べ物'), isFalse);
    });

    test('a 4-character phrase with 3+ distinct characters is accepted', () {
      expect(JunkReasonDetector.isJunk('映画見る'), isFalse);
    });

    test('two repeats of a short pattern (below the 3x threshold) are not flagged as periodic spam', () {
      // "あいあい" alone (not part of a longer run) should not be treated as
      // spam just because it repeats once — only 3+ repeats do.
      expect(JunkReasonDetector.isJunk('あいあい'), isFalse);
    });

    test('three repeats of a short pattern are flagged as periodic spam', () {
      expect(JunkReasonDetector.isJunk('あいあいあい'), isTrue);
    });

    test('a non-periodic mix of 2 distinct characters is deliberately not rejected '
        '(avoids false-positiving genuine short phrases that happen to reuse a character)', () {
      expect(JunkReasonDetector.isJunk('aaab'), isFalse);
    });

    test('mixed symbol + real word is accepted (not symbols-only)', () {
      expect(JunkReasonDetector.isJunk('！返信'), isFalse);
    });
  });
}
