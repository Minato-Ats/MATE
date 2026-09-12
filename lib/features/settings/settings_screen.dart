import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/local/preferences_service.dart';
import '../../data/models/schedule_rule.dart';
import '../../data/models/strict_mode_guard.dart';
import '../../platform/watcher_coordinator.dart';
import '../../state/overlay_access_controller.dart';
import '../../state/theme_controller.dart';
import '../../state/usage_access_controller.dart';
import '../detection_test/detection_test_screen.dart';

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
              title: const Text('一時休止しますか？'),
              content: const Text('Strict Modeが有効です。一時休止中は対象アプリを開いても介入しません。'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('キャンセル'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('続ける'),
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
              title: Text('MATEを一時休止', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('終了すると自動で見守りを再開します'),
            ),
            ListTile(title: const Text('15分'), onTap: () => Navigator.pop(context, '15')),
            ListTile(title: const Text('30分'), onTap: () => Navigator.pop(context, '30')),
            ListTile(title: const Text('1時間'), onTap: () => Navigator.pop(context, '60')),
            ListTile(title: const Text('今日いっぱい'), onTap: () => Navigator.pop(context, 'today')),
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
    await _preferences.setPausedUntil(null);
    await _coordinator.evaluate();
    if (mounted) setState(() {});
  }

  Future<void> _setStrictMode(bool enabled) async {
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
    if (isTomorrowMidnight) return '今日いっぱい休止中';
    return '${until.hour.toString().padLeft(2, '0')}:${until.minute.toString().padLeft(2, '0')}まで休止中';
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
    const weekdayLabels = ['月', '火', '水', '木', '金', '土', '日'];

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          _SectionLabel('見守りルール'),
          Card(
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  title: const Text('時間帯・曜日を指定'),
                  subtitle: Text(
                    schedule.enabled
                        ? '${_formatMinutes(schedule.startMinutes)}〜${_formatMinutes(schedule.endMinutes)}'
                        : 'OFFなら24時間いつでも見守ります',
                  ),
                  value: schedule.enabled,
                  onChanged: (value) => _saveSchedule(schedule.copyWith(enabled: value)),
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
                          '終了が開始より早い場合は、日付をまたぐ時間帯として扱います',
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
                    title: const Text('一時休止'),
                    subtitle: const Text('15分・30分・1時間・今日いっぱい'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _choosePause,
                  )
                : ListTile(
                    leading: const Icon(Icons.pause_circle_filled_rounded),
                    title: Text(_pauseLabel(pausedUntil)),
                    subtitle: const Text('時間になると自動で見守りを再開します'),
                    trailing: TextButton(onPressed: _resumeNow, child: const Text('今すぐ再開')),
                  ),
          ),
          const SizedBox(height: 12),
          Card(
            child: SwitchListTile.adaptive(
              title: const Text('Strict Mode'),
              subtitle: const Text('勢いで見守り設定を弱めにくくします。解除不能にはなりません'),
              value: strictModeEnabled,
              onChanged: _setStrictMode,
            ),
          ),
          const SizedBox(height: 24),
          _SectionLabel('権限'),
          Card(
            child: Column(
              children: [
                _InfoRow(
                  icon: hasUsageAccess ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
                  title: '使用状況へのアクセス',
                  subtitle: hasUsageAccess
                      ? '対象アプリの起動を検知できます'
                      : '見守り対象アプリの起動検知に必要です（未許可）',
                  trailing: hasUsageAccess ? null : '設定',
                  onTrailingTap: hasUsageAccess
                      ? null
                      : () => context.read<UsageAccessController>().openSettings(),
                ),
                Divider(height: 1, color: colorScheme.outlineVariant),
                _InfoRow(
                  icon: hasOverlayAccess ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
                  title: '他のアプリの上に表示',
                  subtitle: hasOverlayAccess
                      ? '一呼吸おく画面をすぐに表示できます'
                      : '見守り対象アプリを開いたときの画面表示に必要です（未許可）',
                  trailing: hasOverlayAccess ? null : '設定',
                  onTrailingTap: hasOverlayAccess
                      ? null
                      : () => context.read<OverlayAccessController>().openSettings(),
                ),
                Divider(height: 1, color: colorScheme.outlineVariant),
                _InfoRow(
                  icon: Icons.bug_report_outlined,
                  title: '検知テスト（Phase 1 検証用）',
                  subtitle: '前面アプリの検知が動作しているか確認します',
                  trailing: '開く',
                  onTrailingTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DetectionTestScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _SectionLabel('表示'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('外観', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(value: ThemeMode.system, label: Text('自動'), icon: Icon(Icons.brightness_auto_rounded)),
                      ButtonSegment(value: ThemeMode.light, label: Text('ライト'), icon: Icon(Icons.light_mode_rounded)),
                      ButtonSegment(value: ThemeMode.dark, label: Text('ダーク'), icon: Icon(Icons.dark_mode_rounded)),
                    ],
                    selected: {themeController.mode},
                    onSelectionChanged: (selection) => themeController.setMode(selection.first),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _SectionLabel('このアプリについて'),
          Card(
            child: Column(
              children: [
                const _InfoRow(icon: Icons.info_outline_rounded, title: 'バージョン', trailing: '0.5.0 (Phase 4)'),
                Divider(height: 1, color: colorScheme.outlineVariant),
                const _InfoRow(
                  icon: Icons.lock_outline_rounded,
                  title: 'プライバシー',
                  subtitle: 'データは端末内にのみ保存され、外部に送信されません',
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
      title: const Text('Strict Modeを解除'),
      content: Text(
        _secondsLeft > 0
            ? '勢いで解除しないため、あと$_secondsLeft秒だけ待ってください。'
            : '解除できます。必要になったらいつでも再びONにできます。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('やめる'),
        ),
        FilledButton(
          onPressed: _secondsLeft == 0 ? () => Navigator.of(context).pop(true) : null,
          child: const Text('解除する'),
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
