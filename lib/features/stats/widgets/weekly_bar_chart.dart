import 'package:flutter/material.dart';

import '../../../data/models/daily_stats.dart';

/// A lightweight, dependency-free bar chart for the last 7 days of wins.
///
/// Built with plain widgets rather than a charting package to keep MATE
/// small and fast, in line with the project's "no unnecessary weight"
/// principle.
class WeeklyBarChart extends StatelessWidget {
  const WeeklyBarChart({super.key, required this.days});

  final List<DailyStats> days;

  static const _weekdayLabels = ['月', '火', '水', '木', '金', '土', '日'];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final maxValue = days.map((d) => d.temptationsWon).fold<int>(1, (a, b) => a > b ? a : b);
    final todayIndex = days.length - 1;

    return SizedBox(
      height: 160,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < days.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${days[i].temptationsWon}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: i == todayIndex ? FontWeight.w800 : FontWeight.w700,
                        color: i == todayIndex ? colorScheme.primary : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: (days[i].temptationsWon / maxValue).clamp(0.06, 1.0),
                          widthFactor: 1,
                          child: Container(
                            decoration: BoxDecoration(
                              color: i == todayIndex ? colorScheme.primary : colorScheme.primary.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      i == todayIndex ? '今日' : _weekdayLabels[days[i].date.weekday - 1],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: i == todayIndex ? FontWeight.w700 : FontWeight.normal,
                        color: i == todayIndex ? colorScheme.primary : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
