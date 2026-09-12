import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/foreground_event.dart';
import '../../data/models/guarded_app.dart';
import '../../platform/foreground_app_watcher.dart';
import '../../state/app_state.dart';
import '../../state/usage_access_controller.dart';

/// Phase 1 technical-verification screen: logs, in order, every "app came to
/// the foreground" event the OS reports, and flags the ones that match a
/// guarded app.
///
/// This is intentionally plain (not a polished product screen) — its only
/// purpose is to prove the detection pipeline (Android `UsageStatsManager`
/// → platform channel → Flutter) works end to end before Phase 2 builds the
/// real "wait / open / give up" experience on top of it. A log (rather than
/// a single "current app" readout) is used deliberately: switching back to
/// MATE to check the result is itself a foreground event, so a "current
/// app" readout would just show MATE again by the time you look at it.
class DetectionTestScreen extends StatefulWidget {
  const DetectionTestScreen({super.key});

  @override
  State<DetectionTestScreen> createState() => _DetectionTestScreenState();
}

class _DetectionTestScreenState extends State<DetectionTestScreen> with WidgetsBindingObserver {
  final _watcher = ForegroundAppWatcher();
  StreamSubscription<ForegroundEvent>? _subscription;
  final List<ForegroundEvent> _log = [];

  static const _maxLogEntries = 20;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<UsageAccessController>().refresh();
    _subscription = _watcher.onForegroundAppChanged.listen((event) {
      setState(() {
        _log.insert(0, event);
        if (_log.length > _maxLogEntries) _log.removeLast();
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<UsageAccessController>().refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasAccess = context.watch<UsageAccessController>().hasAccess;
    final guardedApps = context.watch<AppState>().guardedApps;

    return Scaffold(
      appBar: AppBar(title: const Text('検知テスト（Phase 1 検証用）')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        hasAccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                        color: hasAccess ? colorScheme.primary : colorScheme.error,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          hasAccess ? '使用状況へのアクセス: 許可済み' : '使用状況へのアクセス: 未許可',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  if (!hasAccess) ...[
                    const SizedBox(height: 8),
                    Text(
                      'アプリの前面検知には、設定画面での許可が必要です',
                      style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => context.read<UsageAccessController>().openSettings(),
                      child: const Text('設定を開く'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '手順: ホームボタンで他のアプリ（例: ブラウザ）を開き、\n'
            'このアプリに戻ると下にログが記録されます。',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          if (_log.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'まだ検知したイベントはありません',
                  style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                ),
              ),
            )
          else
            for (final event in _log) ...[
              _ForegroundEventTile(
                event: event,
                isGuarded: _isGuardedPackage(guardedApps, event.packageName),
              ),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }

  bool _isGuardedPackage(List<GuardedApp> apps, String packageName) {
    return apps.any((app) => app.packageName == packageName && app.isGuarded);
  }
}

class _ForegroundEventTile extends StatelessWidget {
  const _ForegroundEventTile({required this.event, required this.isGuarded});

  final ForegroundEvent event;
  final bool isGuarded;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final time = event.timestamp;
    final timeLabel =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';

    return Card(
      color: isGuarded ? colorScheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              isGuarded ? Icons.shield_rounded : Icons.circle_outlined,
              size: 18,
              color: isGuarded ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                event.packageName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isGuarded ? FontWeight.w700 : FontWeight.w500,
                  color: isGuarded ? colorScheme.onPrimaryContainer : null,
                ),
              ),
            ),
            Text(
              timeLabel,
              style: TextStyle(
                fontSize: 12,
                color: isGuarded ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
