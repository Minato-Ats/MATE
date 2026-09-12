import 'package:flutter/material.dart';

import '../../../data/models/guarded_app.dart';

/// One row in the target-app list: icon, name, current per-app guard settings,
/// and an on/off toggle. Tapping the row opens the Phase 4 settings sheet.
class GuardedAppTile extends StatelessWidget {
  const GuardedAppTile({
    super.key,
    required this.app,
    required this.waitSeconds,
    required this.alwaysGuard,
    required this.onChanged,
    required this.onTap,
  });

  final GuardedApp app;
  final int waitSeconds;
  final bool alwaysGuard;
  final ValueChanged<bool> onChanged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconBytes = app.iconBytes;

    return Card(
      clipBehavior: Clip.antiAlias,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: colorScheme.secondaryContainer,
                backgroundImage: iconBytes != null ? MemoryImage(iconBytes) : null,
                child: iconBytes == null
                    ? Icon(Icons.apps_rounded, color: colorScheme.onSecondaryContainer, size: 20)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      app.appName,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    if (app.isGuarded) ...[
                      const SizedBox(height: 2),
                      Text(
                        alwaysGuard ? '$waitSeconds秒待機・常に見守る' : '$waitSeconds秒待機',
                        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
              // Keep the track neutral even when ON. The thumb alone carries the
              // accent color, so this reads as a normal switch rather than a fully
              // filled selection pill.
              Switch(
                value: app.isGuarded,
                onChanged: onChanged,
                thumbColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return colorScheme.primary;
                  }
                  return colorScheme.outline;
                }),
                trackColor: WidgetStateProperty.resolveWith((states) {
                  return colorScheme.surfaceContainerHighest;
                }),
                trackOutlineColor: WidgetStateProperty.resolveWith((states) {
                  return colorScheme.outlineVariant;
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
