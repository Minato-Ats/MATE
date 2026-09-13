import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/copy/mate_copy.dart';
import '../../core/feedback.dart';
import '../../core/widgets/mate_switch.dart';
import '../../data/local/preferences_service.dart';
import '../../data/models/schedule_rule.dart';
import '../../data/models/strict_mode_guard.dart';
import '../../platform/watcher_coordinator.dart';
import '../../state/overlay_access_controller.dart';
import '../../state/theme_controller.dart';
import '../../state/usage_access_controller.dart';
import '../detection_test/detection_test_screen.dart';
import '../onboarding/onboarding_screen.dart';

// Permission status here is refreshed by MainShell's lifecycle observer
// (this screen stays mounted inside an IndexedStack, so it doesn't need its
// own — that would just double every refresh call on every app resume).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  PreferencesService get _preferences => context.read<PreferencesService>();
  WatcherCoordinator get _coordinator => context.read<WatcherCoordinator>();

  Future<void> _saveSchedule(ScheduleRule rule) async {
    await _preferences.setScheduleRule(rule);
    await _coordinator.evaluate();
    if (mounted) setState(() {});
  }

  Future<void> _toggleSchedule(bool value) async {
    MateFeedback.tap(_preferences);
    await _saveSchedule(_preferences.scheduleRule.copyWith(enabled: value));
  }

  Future<void> _pickTime({required bool start}) async {
    final rule = _preferences.scheduleRule;
    final minutes = start ? rule.startMinutes : rule.endMinutes;
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    if (selected == null) return;
    final value = selected.hour * 60 + selected.minute;
    await _saveSchedule(
      start ? rule.copyWith(startMinutes: value) : rule.copyWith(endMinutes: value),
    );
  }

  Future<void> _toggleWeekday(int weekday, bool selected) async {
    MateFeedback.select(_preferences);
    final rule = _preferences.scheduleRule;
    final days = Set<int>.of(rule.weekdays);
    if (selected) {
      days.add(weekday);
    } else if (days.length > 1) {
      // Keep at least one day selected so enabling a schedule can never
      // silently create a rule that is active on no day at all.
      days.remove(weekday);
    }
    await _saveSchedule(rule.copyWith(weekdays: days));
  }

  Future<void> _choosePause() async {
    if (_preferences.strictModeEnabled) {
      final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text(MateCopy.settingsPauseConfirmTitle),
              content: const Text(MateCopy.settingsPauseConfirmBody),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text(MateCopy.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text(MateCopy.settingsContinue),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmed) return;
      if (!mounted) return;
    }

    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(MateCopy.settingsPauseSheetTitle, style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(MateCopy.settingsPauseSheetSubtitle),
            ),
            ListTile(
              title: const Text(MateCopy.settingsPause15),
              onTap: () {
                MateFeedback.select(_preferences);
                Navigator.pop(context, '15');
              },
            ),
            ListTile(
              title: const Text(MateCopy.settingsPause30),
              onTap: () {
                MateFeedback.select(_preferences);
                Navigator.pop(context, '30');
              },
            ),
            ListTile(
              title: const Text(MateCopy.settingsPause60),
              onTap: () {
                MateFeedback.select(_preferences);
                Navigator.pop(context, '60');
              },
            ),
            ListTile(
              title: const Text(MateCopy.settingsPauseToday),
              onTap: () {
                MateFeedback.select(_preferences);
                Navigator.pop(context, 'today');
              },
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;

    final now = DateTime.now();
    final until = switch (choice) {
      '15' => now.add(const Duration(minutes: 15)),
      '30' => now.add(const Duration(minutes: 30)),
      '60' => now.add(const Duration(hours: 1)),
      'today' => DateTime(now.year, now.month, now.day + 1),
      _ => now,
    };
    await _preferences.setPausedUntil(until);
    await _coordinator.evaluate();
    if (mounted) setState(() {});
  }

  Future<void> _resumeNow() async {
    MateFeedback.tap(_preferences);
    await _preferences.setPausedUntil(null);
    await _coordinator.evaluate();
    if (mounted) setState(() {});
  }

  Future<void> _setStrictMode(bool enabled) async {
    MateFeedback.tap(_preferences);
    if (enabled) {
      await _preferences.setStrictModeEnabled(true);
      if (mounted) setState(() {});
      return;
    }

    final confirmed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const _StrictDisableDialog(),
        ) ??
        false;
    if (!confirmed) return;
    await _preferences.setStrictModeEnabled(false);
    if (mounted) setState(() {});
  }

  Future<void> _toggleSoundEffects(bool value) async {
    // Play with the *current* (pre-toggle) setting so turning it off still
    // gives one last confirming tap, matching every other switch's feel.
    MateFeedback.tap(_preferences);
    await _preferences.setSoundEffectsEnabled(value);
    if (mounted) setState(() {});
  }

  void _replayOnboarding() {
    MateFeedback.tap(_preferences);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OnboardingScreen(replay: true)),
    );
  }

  String _formatMinutes(int value) {
    final hour = (value ~/ 60).toString().padLeft(2, '0');
    final minute = (value % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _pauseLabel(DateTime until) {
    final now = DateTime.now();
    final isTomorrowMidnight = until.hour == 0 &&
        until.minute == 0 &&
        until.difference(DateTime(now.year, now.month, now.day + 1)).inMinutes.abs() < 2;
    if (isTomorrowMidnight) return MateCopy.settingsPausedUntilToday;
    return MateCopy.settingsPausedUntilTime(
      '${until.hour.toString().padLeft(2, '0')}:${until.minute.toString().padLeft(2, '0')}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();
    final hasUsageAccess = context.watch<UsageAccessController>().hasAccess;
    final hasOverlayAccess = context.watch<OverlayAccessController>().hasAccess;
    final colorScheme = Theme.of(context).colorScheme;
    final schedule = _preferences.scheduleRule;
    final pausedUntil = _preferences.pausedUntil;
    final strictModeEnabled = _preferences.strictModeEnabled;
    final soundEffectsEnabled = _preferences.soundEffectsEnabled;
    const weekdayLabels = ['月', '火', '水', '木', '金', '土', '日'];

    return Scaffold(
      appBar: AppBar(title: const Text(MateCopy.navSettings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          _SectionLabel(MateCopy.settingsRulesSection),
          Card(
            child: Column(
              children: [
                MateSwitchListTile(
                  title: const Text(MateCopy.settingsScheduleTitle),
                  subtitle: Text(
                    schedule.enabled
                        ? '${_formatMinutes(schedule.startMinutes)}〜${_formatMinutes(schedule.endMinutes)}'
                        : MateCopy.settingsScheduleSubtitleOff,
                  ),
                  value: schedule.enabled,
                  onChanged: _toggleSchedule,
                ),
                if (schedule.enabled) ...[
                  Divider(height: 1, color: colorScheme.outlineVariant),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _pickTime(start: true),
                                icon: const Icon(Icons.schedule_rounded),
                                label: Text('開始 ${_formatMinutes(schedule.startMinutes)}'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _pickTime(start: false),
                                icon: const Icon(Icons.schedule_rounded),
                                label: Text('終了 ${_formatMinutes(schedule.endMinutes)}'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (var i = 0; i < 7; i++)
                              FilterChip(
                                label: Text(weekdayLabels[i]),
                                selected: schedule.weekdays.contains(i + 1),
                                onSelected: (selected) => _toggleWeekday(i + 1, selected),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          MateCopy.settingsScheduleOvernightHint,
                          style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: pausedUntil == null
                ? ListTile(
                    leading: const Icon(Icons.pause_circle_outline_rounded),
                    title: const Text(MateCopy.settingsPauseTitle),
                    subtitle: const Text(MateCopy.settingsPauseSubtitle),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _choosePause,
                  )
                : ListTile(
                    leading: const Icon(Icons.pause_circle_filled_rounded),
                    title: Text(_pauseLabel(pausedUntil)),
                    subtitle: const Text(MateCopy.settingsPauseAutoResume),
                    trailing: TextButton(onPressed: _resumeNow, child: const Text(MateCopy.settingsResumeNow)),
                  ),
          ),
          const SizedBox(height: 12),
          Card(
            child: MateSwitchListTile(
              title: const Text(MateCopy.settingsStrictModeTitle),
              subtitle: const Text(MateCopy.settingsStrictModeSubtitle),
              value: strictModeEnabled,
              onChanged: _setStrictMode,
            ),
          ),
          const SizedBox(height: 24),
          _SectionLabel(MateCopy.settingsPermissionsSection),
          Card(
            child: Column(
              children: [
                _InfoRow(
                  icon: hasUsageAccess ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
                  title: MateCopy.settingsUsageAccessTitle,
                  subtitle: hasUsageAccess
                      ? MateCopy.settingsUsageAccessGranted
                      : MateCopy.settingsUsageAccessMissing,
                  trailing: hasUsageAccess ? null : MateCopy.settingsGoToSettingsAction,
                  onTrailingTap: hasUsageAccess
                      ? null
                      : () => context.read<UsageAccessController>().openSettings(),
                ),
                Divider(height: 1, color: colorScheme.outlineVariant),
                _InfoRow(
                  icon: hasOverlayAccess ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
                  title: MateCopy.settingsOverlayTitle,
                  subtitle: hasOverlayAccess ? MateCopy.settingsOverlayGranted : MateCopy.settingsOverlayMissing,
                  trailing: hasOverlayAccess ? null : MateCopy.settingsGoToSettingsAction,
                  onTrailingTap: hasOverlayAccess
                      ? null
                      : () => context.read<OverlayAccessController>().openSettings(),
                ),
                Divider(height: 1, color: colorScheme.outlineVariant),
                _InfoRow(
                  icon: Icons.bug_report_outlined,
                  title: MateCopy.settingsDetectionTestTitle,
                  subtitle: MateCopy.settingsDetectionTestSubtitle,
                  trailing: MateCopy.settingsOpenAction,
                  onTrailingTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DetectionTestScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _SectionLabel(MateCopy.settingsDisplaySection),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(MateCopy.settingsAppearance, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text(MateCopy.settingsThemeSystem),
                        icon: Icon(Icons.brightness_auto_rounded),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text(MateCopy.settingsThemeLight),
                        icon: Icon(Icons.light_mode_rounded),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text(MateCopy.settingsThemeDark),
                        icon: Icon(Icons.dark_mode_rounded),
                      ),
                    ],
                    selected: {themeController.mode},
                    onSelectionChanged: (selection) {
                      MateFeedback.select(_preferences);
                      themeController.setMode(selection.first);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: MateSwitchListTile(
              title: const Text('操作音（SE）'),
              subtitle: const Text('ボタン操作時に短い効果音を鳴らします'),
              value: soundEffectsEnabled,
              onChanged: _toggleSoundEffects,
            ),
          ),
          const SizedBox(height: 24),
          _SectionLabel(MateCopy.settingsAboutSection),
          Card(
            child: Column(
              children: [
                const _InfoRow(
                  icon: Icons.info_outline_rounded,
                  title: MateCopy.settingsVersion,
                  trailing: MateCopy.settingsVersionValue,
                ),
                Divider(height: 1, color: colorScheme.outlineVariant),
                const _InfoRow(
                  icon: Icons.lock_outline_rounded,
                  title: MateCopy.settingsPrivacyTitle,
                  subtitle: MateCopy.settingsPrivacyBody,
                ),
                Divider(height: 1, color: colorScheme.outlineVariant),
                _InfoRow(
                  icon: Icons.favorite_outline_rounded,
                  title: MateCopy.settingsReplayOnboarding,
                  subtitle: MateCopy.settingsReplayOnboardingSubtitle,
                  trailing: MateCopy.settingsOpenAction,
                  onTrailingTap: _replayOnboarding,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StrictDisableDialog extends StatefulWidget {
  const _StrictDisableDialog();

  @override
  State<_StrictDisableDialog> createState() => _StrictDisableDialogState();
}

class _StrictDisableDialogState extends State<_StrictDisableDialog> {
  late int _secondsLeft;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _secondsLeft = StrictModeGuard.disableDelay.inSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        _timer?.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(MateCopy.settingsStrictDisableTitle),
      content: Text(
        _secondsLeft > 0
            ? MateCopy.settingsStrictDisableWaiting(_secondsLeft)
            : MateCopy.settingsStrictDisableReady,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(MateCopy.settingsStrictDisableCancel),
        ),
        FilledButton(
          onPressed: _secondsLeft == 0 ? () => Navigator.of(context).pop(true) : null,
          child: const Text(MateCopy.settingsStrictDisableConfirm),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTrailingTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailing;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null)
            onTrailingTap != null
                ? TextButton(onPressed: onTrailingTap, child: Text(trailing!))
                : Text(
                    trailing!,
                    style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                  ),
        ],
      ),
    );
  }
}
