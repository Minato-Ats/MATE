import 'package:flutter/material.dart';

/// Removes Material 3's default "stretch" overscroll effect app-wide.
///
/// The stretch indicator visibly deforms whatever's on screen when a
/// scrollable hits its edge (most noticeable with a mouse wheel on desktop
/// or an emulator) — not the calm feel MATE wants. Applied once here via
/// `MaterialApp.scrollBehavior` rather than per-screen, so every current
/// and future scrollable (Home, Stats, Settings, Apps, onboarding, ...)
/// gets the same treatment automatically.
///
/// Scrolling itself, momentum, and each platform's normal scroll physics
/// (from [MaterialScrollBehavior]) are untouched — this only removes the
/// visual overscroll indicator, so content never changes shape at the
/// edges; it doesn't affect scroll position, offsets, or any screen's own
/// state.
class MateScrollBehavior extends MaterialScrollBehavior {
  const MateScrollBehavior();

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}
