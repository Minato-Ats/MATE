import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import 'widgets/weekly_bar_chart.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final summary = appState.statsSummary;
    final colorScheme = Theme.of(context).colorScheme;

    final hasAnyActivity = summary != null && summary.last7Days.any((day) => day.launchAttempts > 0);

    return Scaffold(
      appBar: AppBar(title: const Text('統計')),
      body: appState.isLoading || summary == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: appState.refreshStats,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  if (!hasAnyActivity) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Icon(Icons.query_stats_rounded, color: colorScheme.onSurfaceVariant),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'まだ記録がありません。対象アプリを開くとここに実績が表示されます',
                                style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '直近7日間',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '合計 ${summary.weeklyTemptationsWon}回 誘惑に勝ちました',
                            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 16),
                          WeeklyBarChart(days: summary.last7Days),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryTile(
                          icon: Icons.local_fire_department_rounded,
                          label: '現在のストリーク',
                          value: '${summary.currentStreakDays}日',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryTile(
                          icon: Icons.timer_rounded,
                          label: '今週のSAVE時間',
                          value: '${summary.weeklyMinutesSaved}分',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SummaryTile(
                    icon: Icons.savings_rounded,
                    label: '累計SAVE時間',
                    value: '${summary.totalMinutesSavedAllTime}分',
                    fullWidth: true,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '直近30日',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryTile(
                          icon: Icons.emoji_events_rounded,
                          label: '誘惑に勝った回数',
                          value: '${summary.monthlyTemptationsWon}回',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryTile(
                          icon: Icons.savings_outlined,
                          label: 'SAVE時間',
                          value: '${summary.monthlyMinutesSaved}分',
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

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
    this.fullWidth = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Icon(icon, color: colorScheme.primary, size: 22),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
