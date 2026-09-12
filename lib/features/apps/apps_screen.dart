import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/local/preferences_service.dart';
import '../../state/app_state.dart';
import 'widgets/guarded_app_tile.dart';
import 'widgets/wait_time_sheet.dart';

class AppsScreen extends StatefulWidget {
  const AppsScreen({super.key});

  @override
  State<AppsScreen> createState() => _AppsScreenState();
}

class _AppsScreenState extends State<AppsScreen> {
  Future<void> _openWaitTimeSheet(String packageName, String appName) async {
    final preferences = context.read<PreferencesService>();
    final current = preferences.waitSecondsFor(packageName);
    final selected = await WaitTimeSheet.show(context, appName: appName, currentSeconds: current);
    if (selected != null) {
      await preferences.setWaitSecondsFor(packageName, selected);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    // PreferencesService isn't a ChangeNotifier (plain synchronous storage);
    // this screen re-reads it on every rebuild and rebuilds itself manually
    // via setState after a wait-time change.
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
                          '見守ってほしいアプリをONにしてください。行をタップすると待機時間を変更できます',
                          style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 12),
                        for (final app in appState.guardedApps) ...[
                          GuardedAppTile(
                            app: app,
                            waitSeconds: preferences.waitSecondsFor(app.packageName),
                            onChanged: (value) => appState.setAppGuarded(app.packageName, value),
                            onTap: () => _openWaitTimeSheet(app.packageName, app.appName),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
            ),
    );
  }
}
