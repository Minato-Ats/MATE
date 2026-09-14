import 'package:flutter/material.dart';

/// Centers [child] — as one whole block, not piece by piece — within the
/// available space when it fits; scrolls instead of overflowing when it
/// doesn't (e.g. a long sting message on a small screen, or the keyboard
/// eating vertical space).
///
/// A plain `SingleChildScrollView(child: Center(...))` doesn't actually
/// center anything — `Center` has no effect along a scroll view's main
/// axis, since the scroll view sizes its child to its natural height
/// regardless. This does the usual `ConstrainedBox(minHeight) + Align`
/// trick to get real centering with a scrollable fallback.
///
/// Biased very slightly above dead-center (rather than exactly 50%), which
/// reads as more natural than mathematically perfect centering — every
/// intervention screen (normal mode, serious mode's every step, both the
/// light and escalated waits) uses this same widget so that bias is
/// consistent everywhere rather than a per-screen magic number.
class CenteredScrollArea extends StatelessWidget {
  const CenteredScrollArea({super.key, required this.child});

  final Widget child;

  static const _verticalBias = Alignment(0, -0.06);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Align(alignment: _verticalBias, child: child),
          ),
        );
      },
    );
  }
}
