import 'package:flutter/foundation.dart';

import '../data/models/guarded_app.dart';
import '../data/models/stats_summary.dart';
import '../data/repositories/guarded_apps_repository.dart';
import '../data/repositories/stats_repository.dart';

/// App-wide data state shared via `provider`.
///
/// Screens read from this instead of talking to repositories directly, so
/// the Home/Apps/Stats screens automatically stay in sync when guarded-app
/// toggles change.
class AppState extends ChangeNotifier {
  AppState({
    required GuardedAppsRepository guardedAppsRepository,
    required StatsRepository statsRepository,
  })  : _guardedAppsRepository = guardedAppsRepository, // ignore: prefer_initializing_formals
        _statsRepository = statsRepository; // ignore: prefer_initializing_formals

  final GuardedAppsRepository _guardedAppsRepository;
  final StatsRepository _statsRepository;

  List<GuardedApp> _guardedApps = const [];
  StatsSummary? _statsSummary;
  bool _isLoading = true;

  List<GuardedApp> get guardedApps => _guardedApps;
  StatsSummary? get statsSummary => _statsSummary;
  bool get isLoading => _isLoading;

  int get guardedAppCount => _guardedApps.where((app) => app.isGuarded).length;

  Future<void> load() async {
    final results = await Future.wait([
      _guardedAppsRepository.fetchApps(),
      _statsRepository.fetchSummary(),
    ]);
    _guardedApps = results[0] as List<GuardedApp>;
    _statsSummary = results[1] as StatsSummary;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> setAppGuarded(String packageName, bool isGuarded) async {
    await _guardedAppsRepository.setGuarded(packageName, isGuarded);
    _guardedApps = await _guardedAppsRepository.fetchApps();
    notifyListeners();
  }

  /// Re-reads just the stats summary, without the heavier installed-apps +
  /// icon fetch that [load] does. Intended for "the app resumed, the user
  /// may have just been through an intervention in the separate engine"
  /// (see `MainShell`), since that's a far more frequent trigger than a
  /// guarded-app change.
  Future<void> refreshStats() async {
    _statsSummary = await _statsRepository.fetchSummary();
    notifyListeners();
  }
}
