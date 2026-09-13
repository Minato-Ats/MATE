import 'package:flutter/animation.dart';

/// Shared animation timing so motion added across the app feels like one
/// system instead of each screen inventing its own durations/curves.
class MateMotion {
  MateMotion._();

  /// Small, immediate feedback (e.g. a button's own press state).
  static const quick = Duration(milliseconds: 150);

  /// A value settling into place (e.g. a progress ring, a counted-up
  /// number, a card fading in).
  static const settle = Duration(milliseconds: 300);

  /// A slightly longer, more deliberate beat — reserved for moments meant
  /// to feel like a small release rather than a routine UI update (e.g. the
  /// intervention screen's wait-completed transition).
  static const release = Duration(milliseconds: 450);

  static const curve = Curves.easeOutCubic;
}
