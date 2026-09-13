import 'package:flutter/material.dart';

import '../../../core/copy/mate_copy.dart';
import '../../../core/widgets/mate_switch.dart';
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
                        alwaysGuard
                            ? MateCopy.appsWaitAndAlwaysGuardSuffix(waitSeconds)
                            : MateCopy.appsWaitSuffix(waitSeconds),
                        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
              MergeSemantics(
                child: Semantics(
                  label: MateCopy.appsSwitchSemanticLabel(app.appName, app.isGuarded),
                  child: MateSwitch(value: app.isGuarded, onChanged: onChanged),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
