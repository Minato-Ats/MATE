/// The specific limits Strict Mode enforces, kept in one place so the UI
/// code that applies them (Apps screen, Settings screen) stays simple and
/// so the actual rules are easy to audit.
///
/// Design intent: raise friction against an in-the-moment impulse to weaken
/// guarding, without ever making MATE impossible to turn off — every limit
/// here is a *delay or confirmation*, never a hard lock. Uninstalling the
/// app (always available via Android's own settings, outside MATE's
/// control) remains a genuine escape hatch no matter what.
class StrictModeGuard {
  StrictModeGuard._();

  /// How long the user must wait before Strict Mode actually turns off,
  /// once they confirm they want to (see the Settings screen's confirm
  /// dialog). Short on purpose — enough to interrupt a reflexive tap, not
  /// long enough to feel punitive.
  static const disableDelay = Duration(seconds: 10);

  /// Wait-time options a user may pick for one app, given [currentSeconds]
  /// and whether Strict Mode is on. Outside Strict Mode, all options are
  /// always available. Inside it, only [currentSeconds] and longer are —
  /// you can always make MATE more cautious, never less, while it's on.
  static List<int> selectableWaitSeconds(
    List<int> allOptions,
    int currentSeconds, {
    required bool strictModeEnabled,
  }) {
    if (!strictModeEnabled) return allOptions;
    return allOptions.where((seconds) => seconds >= currentSeconds).toList();
  }

  /// Whether removing [packageName] from the guarded list should first ask
  /// "are you sure?" — true whenever Strict Mode is on, for every app
  /// (keeping the rule simple and predictable rather than app-specific).
  static bool requiresConfirmationToUnguard({required bool strictModeEnabled}) => strictModeEnabled;
}
