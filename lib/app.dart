import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/mate_scroll_behavior.dart';
import 'data/local/preferences_service.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/shell/main_shell.dart';
import 'state/theme_controller.dart';

class MateApp extends StatelessWidget {
  const MateApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeController>().mode;

    return MaterialApp(
      title: 'MATE',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      scrollBehavior: const MateScrollBehavior(),
      home: const _AppRoot(),
    );
  }
}

/// Gates first-run onboarding in front of [MainShell]. Reads
/// [PreferencesService.onboardingCompleted] once at startup — it's already
/// constructed synchronously before `runApp` (see `main.dart`), so no
/// `FutureBuilder` is needed — and flips to [MainShell] locally once
/// onboarding finishes, without needing a rebuild from further up the tree.
class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  late bool _showOnboarding;

  @override
  void initState() {
    super.initState();
    _showOnboarding = !context.read<PreferencesService>().onboardingCompleted;
  }

  @override
  Widget build(BuildContext context) {
    if (_showOnboarding) {
      return OnboardingScreen(onDone: () => setState(() => _showOnboarding = false));
    }
    return const MainShell();
  }
}
