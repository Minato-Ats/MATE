import 'package:flutter/material.dart';

import '../../../core/copy/mate_copy.dart';
import '../../../data/models/daily_stats.dart';

/// Two compact stat tiles: attempts today and today's win rate.
class QuickStatsRow extends StatelessWidget {
  const QuickStatsRow({super.key, required this.today});

  final DailyStats today;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: MateCopy.homeAttemptsLabel,
            value: '${today.launchAttempts}回',
            icon: Icons.touch_app_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            label: MateCopy.homeWinRateLabel,
            value: '${(today.winRate * 100).round()}%',
            icon: Icons.emoji_events_rounded,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 10),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
