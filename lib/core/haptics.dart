import 'package:flutter/services.dart';

/// Thin wrapper around [HapticFeedback], named by role rather than by raw
/// feedback constant. Kept separate from sound (see `MateFeedback` in
/// `feedback.dart`, which combines this with SE) since haptics always fire
/// regardless of the user's sound-effects setting.
///
/// Uses Flutter's built-in haptic feedback constants, which map to the
/// platform's standard haptic APIs and need no extra permission (Android's
/// `VIBRATE` permission is only required for direct `Vibration` API calls,
/// not `View.performHapticFeedback`-backed constants like these).
class Haptics {
  Haptics._();

  /// A tab, chip, or choice was selected — the lightest touch.
  static void select() => HapticFeedback.selectionClick();

  /// A normal toggle or button (switch, checkbox, generic confirm).
  static void tap() => HapticFeedback.lightImpact();

  /// The intervention screen's wait finished — a beat that should stand out
  /// a little more than a routine tap.
  static void waitComplete() => HapticFeedback.mediumImpact();

  /// The user chose "やめとく". Same strength as [tap] for now, kept as its
  /// own named method so it can be tuned independently later without
  /// touching call sites.
  static void giveUp() => HapticFeedback.lightImpact();
}
