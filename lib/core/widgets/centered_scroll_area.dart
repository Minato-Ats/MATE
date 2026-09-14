import 'package:flutter/material.dart';

/// Centers [child] vertically within the available space when it fits;
/// scrolls instead of overflowing when it doesn't (e.g. a long sting message
/// on a small screen, or the keyboard eating vertical space).
///
/// A plain `SingleChildScrollView(child: Center(...))` doesn't actually
/// center anything — `Center` has no effect along a scroll view's main
/// axis, since the scroll view sizes its child to its natural height
/// regardless. This does the usual `ConstrainedBox(minHeight) + Center`
/// trick to get real centering with a scrollable fallback.
class CenteredScrollArea extends StatelessWidget {
  const CenteredScrollArea({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: child),
          ),
        );
      },
    );
  }
}
