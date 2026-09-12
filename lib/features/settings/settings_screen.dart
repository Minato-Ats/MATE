import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/overlay_access_controller.dart';
import '../../state/theme_controller.dart';
import '../../state/usage_access_controller.dart';
import '../detection_test/detection_test_screen.dart';

// Permission status here is refreshed by MainShell's lifecycle observer
// (this screen stays mounted inside an IndexedStack, so it doesn't need its
// own — that would just double every refresh call on every app resume).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();
    final hasUsageAccess = context.watch<UsageAccessController>().hasAccess;
    final hasOverlayAccess = context.watch<OverlayAccessController>().hasAccess;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
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
                const _InfoRow(icon: Icons.info_outline_rounded, title: 'バージョン', trailing: '0.4.0 (Phase 3)'),
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
