import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/copy/mate_copy.dart';
import '../../core/feedback.dart';
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
            title: const Text(MateCopy.appsUnguardConfirmTitle),
            content: Text(MateCopy.appsUnguardConfirmBody(appName)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(MateCopy.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(MateCopy.appsRemove),
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
    MateFeedback.tap(preferences);

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
      appBar: AppBar(title: const Text(MateCopy.navApps)),
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
                          MateCopy.appsFetchFailedTitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          MateCopy.appsFetchFailedHint,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      children: [
                        Text(
                          MateCopy.appsHint,
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
