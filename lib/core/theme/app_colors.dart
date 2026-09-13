import 'package:flutter/material.dart';

/// Brand palette for MATE.
///
/// Kept deliberately calm (teal/indigo) rather than an alarming "warning"
/// palette, since MATE frames usage as something to celebrate resisting,
/// not something shameful to be punished for.
class AppColors {
  AppColors._();

  static const Color seed = Color(0xFF2F9E8F);
  static const Color success = Color(0xFF2F9E8F);

  /// Deliberately darker than a typical "amber" — computed against both
  /// themes' `surfaceContainerHigh` (see Phase 5 accessibility pass): the
  /// original lighter amber (0xFFE8A33D) measured only ~1.77:1 in light
  /// mode, well under the 3:1 WCAG AA minimum for a graphical icon. This
  /// value clears 3:1 in both light and dark.
  static const Color streak = Color(0xFFB8720A);
  static const Color danger = Color(0xFFE0654C);
}
