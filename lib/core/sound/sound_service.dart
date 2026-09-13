import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

/// Plays MATE's short local UI sound effects.
///
/// One [AudioPlayer] per asset, stopped and replayed on every trigger
/// (rather than one shared player) so a rapid retrigger — e.g. mashing a
/// toggle — restarts cleanly instead of queuing or being dropped. Assets
/// are short WAV files (see `tool/generate_placeholder_sfx.dart` for the
/// current placeholders); swapping in real sound design later is just
/// replacing those files at the same paths, no code change needed here.
class SoundService {
  SoundService._();

  static final SoundService instance = SoundService._();

  final Map<String, AudioPlayer> _players = {};

  Future<void> play(String asset, {double volume = 0.4}) async {
    try {
      final player = _players.putIfAbsent(asset, () {
        final player = AudioPlayer(playerId: asset);
        unawaited(player.setReleaseMode(ReleaseMode.stop));
        unawaited(player.setPlayerMode(PlayerMode.lowLatency));
        return player;
      });
      await player.stop();
      await player.play(AssetSource(asset), volume: volume);
    } catch (_) {
      // Best-effort: a missing asset or unsupported audio backend (e.g. some
      // test/CI environments with no audio device) should never crash a
      // button press. Silence is an acceptable fallback; a broken button
      // isn't.
    }
  }
}
