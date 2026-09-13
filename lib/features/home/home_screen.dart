import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/copy/mate_copy.dart';
import '../../core/motion/mate_motion.dart';
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
      appBar: AppBar(title: const Text(MateCopy.appName)),
      body: appState.isLoading || summary == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: appState.load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  _StaggeredFadeIn(index: 0, child: TodaySummaryCard(today: summary.today)),
                  const SizedBox(height: 16),
                  _StaggeredFadeIn(index: 1, child: StreakCard(streakDays: summary.currentStreakDays)),
                  const SizedBox(height: 16),
                  _StaggeredFadeIn(index: 2, child: QuickStatsRow(today: summary.today)),
                  const SizedBox(height: 16),
                  _StaggeredFadeIn(
                    index: 3,
                    child: _GuardedAppsPreviewCard(
                      apps: appState.guardedApps.where((app) => app.isGuarded).toList(),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Small entrance grace note for Home's cards: each fades and slides up in
/// turn rather than all popping in at once. Purely cosmetic — if the delay
/// never fires because the widget was disposed first, `mounted` guards it,
/// so there's nothing to clean up.
class _StaggeredFadeIn extends StatefulWidget {
  const _StaggeredFadeIn({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_StaggeredFadeIn> createState() => _StaggeredFadeInState();
}

class _StaggeredFadeInState extends State<_StaggeredFadeIn> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 60 * widget.index), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: MateMotion.settle,
      curve: MateMotion.curve,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, 0.04),
        duration: MateMotion.settle,
        curve: MateMotion.curve,
        child: widget.child,
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
                    apps.isEmpty
                        ? MateCopy.homeNoGuardedApps
                        : '${apps.length}${MateCopy.homeGuardedAppsCountSuffix}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    apps.isEmpty ? MateCopy.homeGuardedAppsHintEmpty : MateCopy.homeGuardedAppsHint,
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
