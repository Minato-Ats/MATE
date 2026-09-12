import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/local/preferences_service.dart';
import 'data/repositories/guarded_apps_repository.dart';
import 'data/repositories/stats_repository.dart';
import 'features/intervention/intervention_app.dart';
import 'platform/installed_apps_bridge.dart';
import 'platform/watcher_coordinator.dart';
import 'state/app_state.dart';
import 'state/overlay_access_controller.dart';
import 'state/theme_controller.dart';
import 'state/usage_access_controller.dart';

/// Entrypoint for the separate, pre-declared Flutter engine that powers
/// Phase 2's intervention screen (see `InterventionActivity.kt`, which
/// selects this by name via `getDartEntrypointFunctionName()`). It must
/// live in the same compiled Dart library graph as [main] — defining it
/// here (rather than in some file `main.dart` never imports) is what
/// guarantees the build doesn't tree-shake it away.
@pragma('vm:entry-point')
void interventionMain() {
  runApp(const InterventionApp());
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await PreferencesService.create();
  final installedAppsBridge = InstalledAppsBridge();
  final watcherCoordinator = WatcherCoordinator(
    bridge: installedAppsBridge,
    preferences: preferences,
  );

  runApp(
    MultiProvider(
      providers: [
        Provider<PreferencesService>.value(value: preferences),
        Provider<WatcherCoordinator>.value(value: watcherCoordinator),
        ChangeNotifierProvider(create: (_) => ThemeController(preferences)),
        ChangeNotifierProvider(
          create: (_) => AppState(
            guardedAppsRepository: AndroidGuardedAppsRepository(
              bridge: installedAppsBridge,
              preferences: preferences,
              watcherCoordinator: watcherCoordinator,
            ),
            statsRepository: RealStatsRepository(preferences),
          )..load(),
        ),
        ChangeNotifierProvider(
          create: (_) => UsageAccessController(installedAppsBridge, watcherCoordinator)..refresh(),
        ),
        ChangeNotifierProvider(
          create: (_) => OverlayAccessController(installedAppsBridge, watcherCoordinator)..refresh(),
        ),
      ],
      child: const MateApp(),
    ),
  );
}
