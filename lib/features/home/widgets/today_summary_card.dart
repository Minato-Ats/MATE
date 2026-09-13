import 'package:flutter/material.dart';

import '../../../core/copy/mate_copy.dart';
import '../../../core/motion/mate_motion.dart';
import '../../../data/models/daily_stats.dart';

/// The hero card on Home: today's win count and time saved, framed
/// positively ("今日は8回誘惑に勝った") rather than as a usage warning.
class TodaySummaryCard extends StatelessWidget {
  const TodaySummaryCard({super.key, required this.today});

  final DailyStats today;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              MateCopy.homeToday,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TweenAnimationBuilder<int>(
                  tween: IntTween(begin: 0, end: today.temptationsWon),
                  duration: MateMotion.release,
                  curve: MateMotion.curve,
                  builder: (context, value, _) => Text(
                    '$value',
                    style: TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    MateCopy.homeTemptationsWonSuffix,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.savings_rounded, size: 18, color: colorScheme.secondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    today.launchAttempts == 0
                        ? MateCopy.homeNoAttemptsYet
                        : '${today.minutesSaved}${MateCopy.homeMinutesSavedSuffix}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
