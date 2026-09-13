import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/copy/mate_copy.dart';
import '../../../core/feedback.dart';
import '../../../core/widgets/mate_switch.dart';
import '../../../data/local/preferences_service.dart';
import '../../../data/models/strict_mode_guard.dart';

class AppGuardSettingsResult {
  const AppGuardSettingsResult({
    required this.waitSeconds,
    required this.question,
    required this.alwaysGuard,
  });

  final int waitSeconds;
  final String question;
  final bool alwaysGuard;
}

/// Bottom sheet for one app's Phase 4 settings: wait time, intervention
/// question, and whether this app ignores the global schedule.
class WaitTimeSheet extends StatefulWidget {
  const WaitTimeSheet({
    super.key,
    required this.appName,
    required this.currentSeconds,
    required this.currentQuestion,
    required this.alwaysGuard,
    required this.strictModeEnabled,
  });

  final String appName;
  final int currentSeconds;
  final String currentQuestion;
  final bool alwaysGuard;
  final bool strictModeEnabled;

  static Future<AppGuardSettingsResult?> show(
    BuildContext context, {
    required String appName,
    required int currentSeconds,
    required String currentQuestion,
    required bool alwaysGuard,
    required bool strictModeEnabled,
  }) {
    return showModalBottomSheet<AppGuardSettingsResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => WaitTimeSheet(
        appName: appName,
        currentSeconds: currentSeconds,
        currentQuestion: currentQuestion,
        alwaysGuard: alwaysGuard,
        strictModeEnabled: strictModeEnabled,
      ),
    );
  }

  @override
  State<WaitTimeSheet> createState() => _WaitTimeSheetState();
}

class _WaitTimeSheetState extends State<WaitTimeSheet> {
  late int _selectedSeconds;
  late bool _alwaysGuard;
  late TextEditingController _questionController;

  PreferencesService get _preferences => context.read<PreferencesService>();

  @override
  void initState() {
    super.initState();
    _selectedSeconds = widget.currentSeconds;
    _alwaysGuard = widget.alwaysGuard;
    _questionController = TextEditingController(
      text: widget.currentQuestion == PreferencesService.defaultQuestion
          ? ''
          : widget.currentQuestion,
    );
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  void _selectSeconds(int seconds) {
    MateFeedback.select(_preferences);
    setState(() => _selectedSeconds = seconds);
  }

  void _toggleAlwaysGuard(bool value) {
    MateFeedback.tap(_preferences);
    setState(() => _alwaysGuard = value);
  }

  void _save() {
    MateFeedback.tap(_preferences);
    Navigator.of(context).pop(
      AppGuardSettingsResult(
        waitSeconds: _selectedSeconds,
        question: _questionController.text.trim(),
        alwaysGuard: _alwaysGuard,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Earlier Phase 2 builds offered a few different values (8/15/60).
    // Keep an already-saved legacy value visible instead of silently
    // snapping it to the new, intentionally shorter Phase 4 list.
    final options = {...PreferencesService.waitSecondsOptions, widget.currentSeconds}.toList()..sort();
    final allowedSeconds = StrictModeGuard.selectableWaitSeconds(
      options,
      widget.currentSeconds,
      strictModeEnabled: widget.strictModeEnabled,
    ).toSet();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                MateCopy.sheetTitle(widget.appName),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 20),
              const Text(MateCopy.sheetWaitTimeLabel, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final seconds in options)
                    ChoiceChip(
                      label: Text('$seconds秒'),
                      selected: seconds == _selectedSeconds,
                      onSelected: allowedSeconds.contains(seconds) ? (_) => _selectSeconds(seconds) : null,
                    ),
                ],
              ),
              if (widget.strictModeEnabled) ...[
                const SizedBox(height: 8),
                Text(
                  MateCopy.sheetStrictWaitHint,
                  style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 22),
              const Text(MateCopy.sheetQuestionLabel, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              TextField(
                controller: _questionController,
                maxLength: 40,
                decoration: const InputDecoration(
                  hintText: MateCopy.sheetQuestionHint,
                  helperText: MateCopy.sheetQuestionHelper,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              MateSwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(MateCopy.sheetAlwaysGuardTitle),
                subtitle: const Text(MateCopy.sheetAlwaysGuardSubtitle),
                value: _alwaysGuard,
                onChanged: widget.strictModeEnabled && widget.alwaysGuard ? null : _toggleAlwaysGuard,
              ),
              if (widget.strictModeEnabled && widget.alwaysGuard)
                Text(
                  MateCopy.sheetAlwaysGuardStrictHint,
                  style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  child: const Text(MateCopy.save),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
