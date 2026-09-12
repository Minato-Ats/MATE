import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/guarded_app.dart';
import '../../state/app_state.dart';
import 'widgets/quick_stats_row.dart';
import 'widgets/streak_card.dart';
import 'widgets/today_summary_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final summary = appState.statsSummary;

    return Scaffold(
      appBar: AppBar(title: const Text('MATE')),
      body: appState.isLoading || summary == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: appState.load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  TodaySummaryCard(today: summary.today),
                  const SizedBox(height: 16),
                  StreakCard(streakDays: summary.currentStreakDays),
                  const SizedBox(height: 16),
                  QuickStatsRow(today: summary.today),
                  const SizedBox(height: 16),
                  _GuardedAppsPreviewCard(
                    apps: appState.guardedApps.where((app) => app.isGuarded).toList(),
                  ),
                ],
              ),
            ),
    );
  }
}

class _GuardedAppsPreviewCard extends StatelessWidget {
  const _GuardedAppsPreviewCard({required this.apps});

  final List<GuardedApp> apps;

  static const _maxIconsShown = 5;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(Icons.shield_rounded, color: colorScheme.primary, size: 26),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    apps.isEmpty ? 'まだ対象アプリが設定されていません' : '${apps.length}個のアプリを見守り中',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    apps.isEmpty ? '「対象アプリ」からいつでも設定できます' : '対象アプリはいつでも変更できます',
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (apps.isNotEmpty) ...[
              const SizedBox(width: 8),
              _AppIconStack(apps: apps.take(_maxIconsShown).toList()),
            ],
          ],
        ),
      ),
    );
  }
}

class _AppIconStack extends StatelessWidget {
  const _AppIconStack({required this.apps});

  final List<GuardedApp> apps;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const size = 32.0;
    const overlap = 10.0;

    return SizedBox(
      width: size + (apps.length - 1) * (size - overlap),
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < apps.length; i++)
            Positioned(
              left: i * (size - overlap),
              child: CircleAvatar(
                radius: size / 2,
                backgroundColor: colorScheme.surfaceContainerHigh,
                child: CircleAvatar(
                  radius: size / 2 - 2,
                  backgroundColor: colorScheme.secondaryContainer,
                  backgroundImage: apps[i].iconBytes != null ? MemoryImage(apps[i].iconBytes!) : null,
                  child: apps[i].iconBytes == null
                      ? Icon(Icons.apps_rounded, size: 14, color: colorScheme.onSecondaryContainer)
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
