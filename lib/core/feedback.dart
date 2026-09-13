import 'dart:async';

import 'haptics.dart';
import 'sound/sound_service.dart';
import '../data/local/preferences_service.dart';

/// Combined haptic + sound feedback, one method per interaction role. This
/// is the call site API the rest of the app uses — screens should call
/// `MateFeedback.xxx(preferences)` rather than reaching for [Haptics] or
/// [SoundService] directly, so every button's feel stays consistent and
/// the sound-effects on/off setting is always respected in one place.
///
/// Haptics always fire; sound is gated by
/// [PreferencesService.soundEffectsEnabled] (a Settings toggle) since that
/// setting is specifically about sound, not touch feedback.
class MateFeedback {
  MateFeedback._();

  /// A tab, chip, or choice was selected.
  static void select(PreferencesService preferences) {
    Haptics.select();
    _play(preferences, 'sfx/select.wav', 0.3);
  }

  /// A normal toggle or confirm action.
  static void tap(PreferencesService preferences) {
    Haptics.tap();
    _play(preferences, 'sfx/tap.wav', 0.35);
  }

  /// The intervention screen's wait finished.
  static void waitComplete(PreferencesService preferences) {
    Haptics.waitComplete();
    _play(preferences, 'sfx/wait_complete.wav', 0.45);
  }

  /// The user chose "やめとく" on the intervention screen.
  static void giveUp(PreferencesService preferences) {
    Haptics.giveUp();
    _play(preferences, 'sfx/give_up.wav', 0.35);
  }

  static void _play(PreferencesService preferences, String asset, double volume) {
    if (!preferences.soundEffectsEnabled) return;
    // Fire-and-forget: a button press should never wait on audio I/O.
    unawaited(SoundService.instance.play(asset, volume: volume));
  }
}
