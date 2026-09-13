import 'package:flutter/material.dart';

import '../../../core/copy/mate_copy.dart';
import '../../../core/theme/app_colors.dart';

/// Small streak badge shown on Home. Streaks add a light game feel without
/// pressuring the user (no penalty language if a streak breaks).
class StreakCard extends StatelessWidget {
  const StreakCard({super.key, required this.streakDays});

  final int streakDays;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          children: [
            const Icon(Icons.local_fire_department_rounded, color: AppColors.streak, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$streakDays${MateCopy.homeStreakSuffix}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    MateCopy.homeStreakSubtitle,
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
