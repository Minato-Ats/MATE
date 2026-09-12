import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'intervention_screen.dart';

/// Root widget for the separate Flutter engine that powers the Phase 2
/// intervention screen (see `InterventionActivity.kt` and the
/// `interventionMain` entrypoint in `main.dart`).
///
/// Deliberately minimal — no Provider/AppState wiring, since this runs in
/// its own isolate independent of the main MATE UI. It reads the little
/// state it needs (wait-time settings) directly through
/// [PreferencesService], which both engines can safely read because they
/// share the same underlying Android SharedPreferences storage.
class InterventionApp extends StatelessWidget {
  const InterventionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const InterventionScreen(),
    );
  }
}
