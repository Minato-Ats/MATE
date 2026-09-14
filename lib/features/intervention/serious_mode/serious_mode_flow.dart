import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/copy/mate_copy.dart';
import '../../../core/copy/serious_mode_templates.dart';
import '../../../core/feedback.dart';
import '../../../core/time/clock.dart';
import '../../../core/widgets/centered_scroll_area.dart';
import '../../../data/local/preferences_service.dart';
import '../../../data/models/intervention_event.dart';
import '../../../platform/intervention_bridge.dart';
import '../widgets/wait_countdown_ring.dart';

enum _Step { reason, need, waitingLight, sting, waitingEscalated }

/// The 本気モード (Serious Mode, Phase 6.6) intervention flow — a distinct,
/// much stricter path than [InterventionScreen]'s normal countdown, shown
/// instead of it (never alongside) when [PreferencesService.seriousModeEnabled]
/// is on.
///
/// One question per screen throughout (requirement: the user should always
/// know what to do next at a glance):
/// 何のために開く？ → それ、今必要？ → (YES: light wait) / (NO: sting → やめとく
/// or それでも開く, which escalates the shared cumulative wait) → 待機.
///
/// [onGiveUp]/[onOpen] are the same callbacks the normal flow uses (they
/// already log the generic `gaveUp`/`opened` events and resolve the native
/// bridge), so existing stats (win rate, streak, save time) stay correct
/// regardless of which flow produced the outcome. This widget additionally
/// logs the more granular `serious_mode_*` event types for future detailed
/// stats, per Phase 6.6 requirement 11.
class SeriousModeFlow extends StatefulWidget {
  const SeriousModeFlow({
    super.key,
    required this.args,
    required this.preferences,
    required this.normalWaitSeconds,
    required this.onGiveUp,
    required this.onOpen,
    this.clock = Clock.system,
  });

  final InterventionArgs args;
  final PreferencesService preferences;

  /// The user's own configured per-app wait — reused as-is for the YES
  /// ("今必要") branch, per requirement 3: genuine needs aren't over-obstructed
  /// and never get a long penalty.
  final int normalWaitSeconds;

  final Future<void> Function() onGiveUp;
  final Future<void> Function() onOpen;

  /// Injectable so escalation timing (in particular whether the 1-hour reset
  /// window has passed) is testable without a real wait.
  final Clock clock;

  @override
  State<SeriousModeFlow> createState() => _SeriousModeFlowState();
}

class _SeriousModeFlowState extends State<SeriousModeFlow> {
  final _reasonController = TextEditingController();
  _Step _step = _Step.reason;
  String _reason = '';
  String? _stingMessage;
  String? _yesAckMessage;
  bool _showReasonRequiredHint = false;

  Timer? _timer;
  int _waitTotal = 0;
  int _waitRemaining = 0;
  bool _waitCompleted = false;

  @override
  void initState() {
    super.initState();
    unawaited(widget.preferences.appendEvent(InterventionEvent(
      type: InterventionEventType.seriousModeStarted,
      packageName: widget.args.packageName,
      timestamp: widget.clock.now(),
    )));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _reasonController.dispose();
    super.dispose();
  }

  Future<int> _todayCount() async {
    final events = await widget.preferences.loadEventLog();
    final now = widget.clock.now();
    return events
        .where((e) =>
            e.type == InterventionEventType.seriousModeStarted &&
            e.timestamp.year == now.year &&
            e.timestamp.month == now.month &&
            e.timestamp.day == now.day)
        .length;
  }

  void _submitReason() {
    final trimmed = _reasonController.text.trim();
    if (trimmed.isEmpty) {
      setState(() => _showReasonRequiredHint = true);
      return;
    }
    MateFeedback.select(widget.preferences);
    setState(() {
      _reason = trimmed;
      _step = _Step.need;
    });
  }

  Future<void> _answerNeed(bool needed) async {
    MateFeedback.select(widget.preferences);
    await widget.preferences.appendEvent(InterventionEvent(
      type: needed ? InterventionEventType.seriousModeYes : InterventionEventType.seriousModeNo,
      packageName: widget.args.packageName,
      timestamp: widget.clock.now(),
    ));

    if (needed) {
      final message = await SeriousModeCopy.pickYesAck(
        widget.preferences,
        SeriousModeTemplateContext(reason: _reason, goal: widget.preferences.goal, todayCount: 0, waitSeconds: 0),
      );
      if (!mounted) return;
      setState(() {
        _yesAckMessage = message;
        _step = _Step.waitingLight;
      });
      _startWait(widget.normalWaitSeconds);
      return;
    }

    final todayCount = await _todayCount();
    final waitSeconds = await widget.preferences.effectiveSeriousModeWaitSeconds(widget.clock.now());
    final message = await SeriousModeCopy.pickNoSting(
      widget.preferences,
      SeriousModeTemplateContext(reason: _reason, goal: widget.preferences.goal, todayCount: todayCount, waitSeconds: waitSeconds),
    );
    if (!mounted) return;
    setState(() {
      _stingMessage = message;
      _step = _Step.sting;
    });
  }

  Future<void> _giveUpAtSting() async {
    MateFeedback.giveUp(widget.preferences);
    await widget.preferences.appendEvent(InterventionEvent(
      type: InterventionEventType.seriousModeGaveUp,
      packageName: widget.args.packageName,
      timestamp: widget.clock.now(),
    ));
    await widget.onGiveUp();
  }

  Future<void> _openAnyway() async {
    final now = widget.clock.now();
    final applied = await widget.preferences.effectiveSeriousModeWaitSeconds(now);
    await widget.preferences.recordSeriousModeOpenAnyway(now);
    await widget.preferences.appendEvent(InterventionEvent(
      type: InterventionEventType.seriousModeOpenAnyway,
      packageName: widget.args.packageName,
      timestamp: now,
    ));
    if (!mounted) return;
    setState(() => _step = _Step.waitingEscalated);
    _startWait(applied);
  }

  void _startWait(int seconds) {
    _timer?.cancel();
    setState(() {
      _waitTotal = seconds;
      _waitRemaining = seconds;
      _waitCompleted = seconds <= 0;
    });
    if (_waitCompleted) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_waitRemaining <= 1) {
        _timer?.cancel();
        setState(() {
          _waitRemaining = 0;
          _waitCompleted = true;
        });
        MateFeedback.waitComplete(widget.preferences);
      } else {
        setState(() => _waitRemaining -= 1);
      }
    });
  }

  Future<void> _giveUpDuringWait() async {
    MateFeedback.giveUp(widget.preferences);
    await widget.onGiveUp();
  }

  Future<void> _openAfterWait() async {
    MateFeedback.tap(widget.preferences);
    await widget.onOpen();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
          // Icon, title, and the current step's content are one visual
          // block, centered together — not icon/title pinned to the top
          // with the step content centered separately below it, which read
          // as two disconnected halves rather than one screen.
          child: CenteredScrollArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: colorScheme.secondaryContainer,
                  backgroundImage: widget.args.iconBytes != null ? MemoryImage(widget.args.iconBytes!) : null,
                  child: widget.args.iconBytes == null
                      ? Icon(Icons.apps_rounded, size: 32, color: colorScheme.onSecondaryContainer)
                      : null,
                ),
                const SizedBox(height: 20),
                Text(
                  MateCopy.seriousModeStepTitle(widget.args.appName),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 24),
                _buildStep(colorScheme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(ColorScheme colorScheme) {
    switch (_step) {
      case _Step.reason:
        return _ReasonStep(
          controller: _reasonController,
          showRequiredHint: _showReasonRequiredHint,
          onSubmit: _submitReason,
        );
      case _Step.need:
        return _NeedStep(reason: _reason, onAnswer: _answerNeed);
      case _Step.waitingLight:
        return _WaitStep(
          subtitle: _yesAckMessage ?? '',
          remainingSeconds: _waitRemaining,
          totalSeconds: _waitTotal,
          waitCompleted: _waitCompleted,
          onGiveUp: _giveUpDuringWait,
          onOpen: _waitCompleted ? _openAfterWait : null,
        );
      case _Step.sting:
        return _StingStep(
          message: _stingMessage ?? '',
          onGiveUp: _giveUpAtSting,
          onOpenAnyway: _openAnyway,
        );
      case _Step.waitingEscalated:
        return _WaitStep(
          subtitle: MateCopy.seriousModeEscalatedWaitingSubtitle,
          remainingSeconds: _waitRemaining,
          totalSeconds: _waitTotal,
          waitCompleted: _waitCompleted,
          onGiveUp: _giveUpDuringWait,
          onOpen: _waitCompleted ? _openAfterWait : null,
        );
    }
  }
}

class _ReasonStep extends StatelessWidget {
  const _ReasonStep({required this.controller, required this.showRequiredHint, required this.onSubmit});

  final TextEditingController controller;
  final bool showRequiredHint;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          MateCopy.seriousModeReasonQuestion,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: controller,
          autofocus: true,
          textAlign: TextAlign.center,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSubmit(),
          decoration: InputDecoration(
            hintText: MateCopy.seriousModeReasonHint,
            border: const OutlineInputBorder(),
            errorText: showRequiredHint ? MateCopy.seriousModeReasonRequiredHint : null,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onSubmit,
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            child: const Text(MateCopy.seriousModeReasonContinue),
          ),
        ),
      ],
    );
  }
}

class _NeedStep extends StatelessWidget {
  const _NeedStep({required this.reason, required this.onAnswer});

  final String reason;
  final void Function(bool needed) onAnswer;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '「$reason」',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        Text(
          MateCopy.seriousModeNeedQuestion,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => onAnswer(false),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text(MateCopy.seriousModeNeedNo),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () => onAnswer(true),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text(MateCopy.seriousModeNeedYes),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StingStep extends StatelessWidget {
  const _StingStep({required this.message, required this.onGiveUp, required this.onOpenAnyway});

  final String message;
  final Future<void> Function() onGiveUp;
  final Future<void> Function() onOpenAnyway;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: onGiveUp,
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text(MateCopy.seriousModeGiveUp),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: onOpenAnyway,
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text(MateCopy.seriousModeOpenAnyway),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _WaitStep extends StatelessWidget {
  const _WaitStep({
    required this.subtitle,
    required this.remainingSeconds,
    required this.totalSeconds,
    required this.waitCompleted,
    required this.onGiveUp,
    required this.onOpen,
  });

  final String subtitle;
  final int remainingSeconds;
  final int totalSeconds;
  final bool waitCompleted;
  final Future<void> Function() onGiveUp;
  final Future<void> Function()? onOpen;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (subtitle.isNotEmpty) ...[
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
        ],
        WaitCountdownRing(remainingSeconds: remainingSeconds, totalSeconds: totalSeconds, waitCompleted: waitCompleted),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onGiveUp,
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text(MateCopy.interventionGiveUp),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: onOpen,
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text(MateCopy.interventionOpen),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
