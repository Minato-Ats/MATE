import 'package:flutter/material.dart';

/// Drop-in replacement for [Switch] with MATE's unified look, used
/// everywhere in the app instead of styling each screen's switch
/// individually.
///
/// Material 3's [Switch] grows its thumb to nearly fill the track when ON
/// — by design, part of the M3 spec — and there is no [SwitchThemeData]
/// knob to opt out of that geometry; it's baked into M3's switch
/// constants. So instead this scopes Material 2's slim, constant-size
/// track+thumb geometry to just the switch itself via a local [Theme]
/// override, while every color still comes from the surrounding (M3)
/// [ColorScheme] — only the shape reverts, not the palette. On: thumb
/// alone turns [ColorScheme.primary]; off: thumb is [ColorScheme.outline].
/// The track stays the same neutral, outlined pill in both states, so
/// on/off reads from thumb color, not from the track suddenly filling in.
class MateSwitch extends StatelessWidget {
  const MateSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Theme(
      data: ThemeData(colorScheme: colorScheme, useMaterial3: false),
      child: Switch(
        value: value,
        onChanged: onChanged,
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colorScheme.onSurface.withValues(alpha: 0.3);
          }
          return states.contains(WidgetState.selected) ? colorScheme.primary : colorScheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) => colorScheme.surfaceContainerHighest),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) => colorScheme.outlineVariant),
        trackOutlineWidth: const WidgetStatePropertyAll(1),
      ),
    );
  }
}

/// Drop-in replacement for `SwitchListTile.adaptive` using [MateSwitch] as
/// its trailing control, so a full-row-tap-to-toggle tile gets the same
/// unified switch look. Deliberately a plain [ListTile] (left in the
/// app's normal M3 theme) with [MateSwitch] as its trailing widget, rather
/// than wrapping the whole tile in the M2 theme override — that would also
/// change [ListTile]'s own M3-dependent padding/density, which isn't the
/// point here.
class MateSwitchListTile extends StatelessWidget {
  const MateSwitchListTile({
    super.key,
    required this.value,
    required this.onChanged,
    required this.title,
    this.subtitle,
    this.contentPadding,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget title;
  final Widget? subtitle;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: contentPadding,
      title: title,
      subtitle: subtitle,
      trailing: MateSwitch(value: value, onChanged: onChanged),
      onTap: onChanged == null ? null : () => onChanged!(!value),
    );
  }
}
