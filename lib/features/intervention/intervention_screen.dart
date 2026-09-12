import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/local/preferences_service.dart';
import '../../data/models/intervention_event.dart';
import '../../platform/intervention_bridge.dart';

/// The Phase 2 core experience: shown full-screen, instantly, on top of
/// whatever the user was doing the moment a guarded app is detected.
///
/// Deliberately not styled as a "blocked" screen — no red, no lock icon, no
/// warning language. The idea is one deliberate pause, not a punishment:
/// giving up is always one tap away, and opening just asks for a few
/// seconds of "did I actually mean to do this?" first.
class InterventionScreen extends StatefulWidget {
  const InterventionScreen({super.key});

  @override
  State<InterventionScreen> createState() => _InterventionScreenState();
}

class _InterventionScreenState extends State<InterventionScreen> {
  final _bridge = InterventionBridge();
  PreferencesService? _preferences;

  InterventionArgs? _args;
  bool _loading = true;

  int _totalWaitSeconds = PreferencesService.defaultWaitSeconds;
  int _remainingSeconds = PreferencesService.defaultWaitSeconds;
  String _question = PreferencesService.defaultQuestion;
  Timer? _timer;
  bool _waitCompleted = false;

  final _purposeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _bridge.setOnArgsChanged(_load);
    _load();
    // Tell native as soon as *any* frame of ours has drawn — even the
    // loading spinner — so it can remove the transition cover it showed
    // while launching this Activity. Signalling here (rather than only
    // once real content is loaded) means the user sees a brief spinner in
    // the worst case, never a blank native background with nothing on it.
    WidgetsBinding.instance.addPostFrameCallback((_) => _bridge.notifyReady());
  }

  Future<void> _load() async {
    _timer?.cancel();
    _preferences ??= await PreferencesService.create();
    final args = await _bridge.getArgs();

    if (args == null) {
      // Nothing to show (shouldn't normally happen); bail out quietly.
      await _bridge.resolveGiveUp();
      return;
    }

    final waitSeconds = _preferences!.waitSecondsFor(args.packageName);
    final question = _preferences!.questionFor(args.packageName);
    await _preferences!.appendEvent(InterventionEvent(
      type: InterventionEventType.detected,
      packageName: args.packageName,
      timestamp: DateTime.now(),
    ));

    if (!mounted) return;
    setState(() {
      _args = args;
      _loading = false;
      _totalWaitSeconds = waitSeconds;
      _remainingSeconds = waitSeconds;
      _question = question;
      _waitCompleted = waitSeconds <= 0;
      _purposeController.clear();
    });

    if (!_waitCompleted) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    } else {
      unawaited(_logWaitCompleted());
    }
  }

  void _tick() {
    if (_remainingSeconds <= 1) {
      _timer?.cancel();
      setState(() {
        _remainingSeconds = 0;
        _waitCompleted = true;
      });
      unawaited(_logWaitCompleted());
    } else {
      setState(() => _remainingSeconds -= 1);
    }
  }

  Future<void> _logWaitCompleted() async {
    final args = _args;
    if (args == null || _preferences == null) return;
    await _preferences!.appendEvent(InterventionEvent(
      type: InterventionEventType.waitCompleted,
      packageName: args.packageName,
      timestamp: DateTime.now(),
    ));
  }

  Future<void> _giveUp() async {
    final args = _args;
    if (args != null && _preferences != null) {
      await _preferences!.appendEvent(InterventionEvent(
        type: InterventionEventType.gaveUp,
        packageName: args.packageName,
        timestamp: DateTime.now(),
      ));
    }
    await _bridge.resolveGiveUp();
  }

  Future<void> _open() async {
    final args = _args;
    if (args == null) return;
    if (_preferences != null) {
      await _preferences!.appendEvent(InterventionEvent(
        type: InterventionEventType.opened,
        packageName: args.packageName,
        timestamp: DateTime.now(),
      ));
    }
    await _bridge.resolveOpen(args.packageName);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _purposeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_loading || _args == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final args = _args!;
    final progress = _totalWaitSeconds == 0 ? 1.0 : 1 - (_remainingSeconds / _totalWaitSeconds);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
          child: Column(
            children: [
              const Spacer(),
              CircleAvatar(
                radius: 36,
                backgroundColor: colorScheme.secondaryContainer,
                backgroundImage: args.iconBytes != null ? MemoryImage(args.iconBytes!) : null,
                child: args.iconBytes == null
                    ? Icon(Icons.apps_rounded, size: 32, color: colorScheme.onSecondaryContainer)
                    : null,
              ),
              const SizedBox(height: 20),
              Text(
                '${args.appName}を開く？',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                _waitCompleted ? 'それでも開く？' : 'ちょっとだけ待とう。',
                style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _purposeController,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: '$_question（任意）',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 96,
                height: 96,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 96,
                      height: 96,
                      child: CircularProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        strokeWidth: 6,
                        backgroundColor: colorScheme.surfaceContainerHigh,
                        valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                      ),
                    ),
                    Text(
                      _waitCompleted ? '✓' : '$_remainingSeconds',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _giveUp,
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: const Text('やめとく'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _waitCompleted ? _open : null,
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: const Text('開く'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
