import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/copy/mate_copy.dart';
import '../../core/feedback.dart';
import '../../data/local/preferences_service.dart';
import '../../state/app_state.dart';
import '../../state/overlay_access_controller.dart';
import '../../state/usage_access_controller.dart';
import '../apps/apps_screen.dart';
import '../home/home_screen.dart';
import '../settings/settings_screen.dart';
import '../stats/stats_screen.dart';

/// Bottom-navigation shell hosting MATE's four top-level screens.
///
/// Uses [IndexedStack] so switching tabs never rebuilds/loses scroll state
/// of the other screens.
class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialIndex = 0});

  /// Which tab to land on. Defaults to Home; `app.dart` passes the 対象アプリ
  /// tab instead right after a user finishes onboarding, since picking an
  /// app to guard is the one thing they actually need to do next.
  final int initialIndex;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  late int _index = widget.initialIndex;

  static const _screens = [
    HomeScreen(),
    AppsScreen(),
    StatsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The user may have just been through an intervention (a separate
    // Flutter engine/Activity) before returning here, so refresh the
    // numbers rather than showing whatever was loaded at cold start.
    if (state == AppLifecycleState.resumed) {
      context.read<AppState>().refreshStats();
      context.read<UsageAccessController>().refresh();
      context.read<OverlayAccessController>().refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _selectTab(int index) {
    if (index == _index) return;
    MateFeedback.select(context.read<PreferencesService>());
    setState(() => _index = index);
    // Home's guard-status banner reads pause/permission state directly
    // (not through a ChangeNotifier of its own), and IndexedStack doesn't
    // rebuild an inactive tab just because it's selected again — so landing
    // back on Home wouldn't otherwise notice a pause toggled from Settings
    // a moment ago. Reusing the same refresh already called on app resume
    // is enough to force that rebuild.
    if (index == 0) context.read<AppState>().refreshStats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _index, children: _screens),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _selectTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: MateCopy.navHome,
          ),
          NavigationDestination(
            icon: Icon(Icons.apps_outlined),
            selectedIcon: Icon(Icons.apps_rounded),
            label: MateCopy.navApps,
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart_rounded),
            label: MateCopy.navStats,
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: MateCopy.navSettings,
          ),
        ],
      ),
    );
  }
}
