import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final allowedSeconds = StrictModeGuard.selectableWaitSeconds(
      PreferencesService.waitSecondsOptions,
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
                '${widget.appName}の見守り設定',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 20),
              const Text('待機時間', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final seconds in PreferencesService.waitSecondsOptions)
                    ChoiceChip(
                      label: Text('$seconds秒'),
                      selected: seconds == _selectedSeconds,
                      onSelected: allowedSeconds.contains(seconds)
                          ? (_) => setState(() => _selectedSeconds = seconds)
                          : null,
                    ),
                ],
              ),
              if (widget.strictModeEnabled) ...[
                const SizedBox(height: 8),
                Text(
                  'Strict Mode中は現在より短い待機時間には変更できません',
                  style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 22),
              const Text('ひとこと質問', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              TextField(
                controller: _questionController,
                maxLength: 40,
                decoration: const InputDecoration(
                  hintText: '何しに開く？',
                  helperText: '空欄ならデフォルトの文言を使います',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('時間帯ルールを無視して常に見守る'),
                subtitle: const Text('このアプリだけ24時間見守りたい場合に使います'),
                value: _alwaysGuard,
                onChanged: widget.strictModeEnabled && widget.alwaysGuard
                    ? null
                    : (value) => setState(() => _alwaysGuard = value),
              ),
              if (widget.strictModeEnabled && widget.alwaysGuard)
                Text(
                  'Strict Mode中は「常に見守る」を解除できません',
                  style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(
                    AppGuardSettingsResult(
                      waitSeconds: _selectedSeconds,
                      question: _questionController.text.trim(),
                      alwaysGuard: _alwaysGuard,
                    ),
                  ),
                  child: const Text('保存'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
