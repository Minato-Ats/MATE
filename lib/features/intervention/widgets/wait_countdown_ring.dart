import 'package:flutter/material.dart';

import '../../../core/copy/mate_copy.dart';
import '../../../core/motion/mate_motion.dart';

/// The countdown ring shown while waiting (normal intervention, and the
/// Phase 6.6 serious-mode "それでも開く" escalated wait) — extracted out of
/// [InterventionScreen] so both flows render the exact same visual language
/// instead of drifting apart (Phase 6.6 requirement: reuse the existing
/// design system rather than inventing new UI for the stricter path).
class WaitCountdownRing extends StatelessWidget {
  const WaitCountdownRing({
    super.key,
    required this.remainingSeconds,
    required this.totalSeconds,
    required this.waitCompleted,
  });

  final int remainingSeconds;
  final int totalSeconds;
  final bool waitCompleted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = totalSeconds == 0 ? 1.0 : 1 - (remainingSeconds / totalSeconds);

    return Semantics(
      label: waitCompleted ? MateCopy.interventionReadySemantic : MateCopy.interventionWaitingSemantic,
      liveRegion: true,
      child: ExcludeSemantics(
        child: SizedBox(
          width: 96,
          height: 96,
          child: Stack(
            alignment: Alignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
                duration: MateMotion.settle,
                curve: MateMotion.curve,
                builder: (context, value, _) => SizedBox(
                  width: 96,
                  height: 96,
                  child: CircularProgressIndicator(
                    value: value,
                    strokeWidth: 6,
                    backgroundColor: colorScheme.surfaceContainerHigh,
                    valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: MateMotion.release,
                switchInCurve: MateMotion.curve,
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation,
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: Text(
                  waitCompleted ? '✓' : '$remainingSeconds',
                  key: ValueKey(waitCompleted),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
