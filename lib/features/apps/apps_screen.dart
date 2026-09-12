import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/local/preferences_service.dart';
import '../../data/models/strict_mode_guard.dart';
import '../../platform/watcher_coordinator.dart';
import '../../state/app_state.dart';
import 'widgets/guarded_app_tile.dart';
import 'widgets/wait_time_sheet.dart';

class AppsScreen extends StatefulWidget {
  const AppsScreen({super.key});

  @override
  State<AppsScreen> createState() => _AppsScreenState();
}

class _AppsScreenState extends State<AppsScreen> {
  Future<void> _openSettingsSheet(String packageName, String appName) async {
    final preferences = context.read<PreferencesService>();
    final coordinator = context.read<WatcherCoordinator>();
    final current = preferences.waitSecondsFor(packageName);
    final selected = await WaitTimeSheet.show(
      context,
      appName: appName,
      currentSeconds: current,
      currentQuestion: preferences.questionFor(packageName),
      alwaysGuard: preferences.alwaysGuardPackages.contains(packageName),
      strictModeEnabled: preferences.strictModeEnabled,
    );
    if (selected == null) return;

    await preferences.setWaitSecondsFor(packageName, selected.waitSeconds);
    await preferences.setQuestionFor(packageName, selected.question);

    final alwaysGuard = preferences.alwaysGuardPackages;
    if (selected.alwaysGuard) {
      alwaysGuard.add(packageName);
    } else {
      alwaysGuard.remove(packageName);
    }
    await preferences.setAlwaysGuardPackages(alwaysGuard);
    await coordinator.evaluate();

    if (mounted) setState(() {});
  }

  Future<bool> _confirmUnguard(String appName) async {
    final preferences = context.read<PreferencesService>();
    if (!StrictModeGuard.requiresConfirmationToUnguard(
      strictModeEnabled: preferences.strictModeEnabled,
    )) {
      return true;
    }

    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('見守りを外しますか？'),
            content: Text('Strict Modeが有効です。$appNameを見守り対象から外します。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('外す'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _setGuarded(String packageName, String appName, bool value) async {
    final appState = context.read<AppState>();
    final preferences = context.read<PreferencesService>();
    final coordinator = context.read<WatcherCoordinator>();

    if (!value && !await _confirmUnguard(appName)) return;

    await appState.setAppGuarded(packageName, value);

    if (!value) {
      final alwaysGuard = preferences.alwaysGuardPackages..remove(packageName);
      await preferences.setAlwaysGuardPackages(alwaysGuard);
      await coordinator.evaluate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final preferences = context.read<PreferencesService>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('対象アプリ')),
      body: appState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: appState.load,
              child: appState.guardedApps.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      children: [
                        const SizedBox(height: 80),
                        Icon(Icons.apps_outlined, size: 40, color: colorScheme.onSurfaceVariant),
                        const SizedBox(height: 16),
                        Text(
                          'インストール済みのアプリを取得できませんでした',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '下に引っ張って更新するか、しばらくしてから再度お試しください',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      children: [
                        Text(
                          '見守ってほしいアプリをONにしてください。行をタップすると待機時間や質問文を変更できます',
                          style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 12),
                        for (final app in appState.guardedApps) ...[
                          GuardedAppTile(
                            app: app,
                            waitSeconds: preferences.waitSecondsFor(app.packageName),
                            alwaysGuard: preferences.alwaysGuardPackages.contains(app.packageName),
                            onChanged: (value) => _setGuarded(app.packageName, app.appName, value),
                            onTap: () => _openSettingsSheet(app.packageName, app.appName),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
            ),
    );
  }
}
