import 'package:flutter/material.dart';

/// Bottom sheet for choosing how long the intervention screen makes the
/// user wait before "開く" becomes available for one app.
class WaitTimeSheet extends StatelessWidget {
  const WaitTimeSheet({
    super.key,
    required this.appName,
    required this.currentSeconds,
  });

  final String appName;
  final int currentSeconds;

  static const _options = [5, 8, 15, 30, 60];

  static Future<int?> show(BuildContext context, {required String appName, required int currentSeconds}) {
    return showModalBottomSheet<int>(
      context: context,
      builder: (_) => WaitTimeSheet(appName: appName, currentSeconds: currentSeconds),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$appNameを開く前の待機時間',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '短い一呼吸を置くための時間です',
              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final seconds in _options)
                  ChoiceChip(
                    label: Text('$seconds秒'),
                    selected: seconds == currentSeconds,
                    onSelected: (_) => Navigator.of(context).pop(seconds),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
