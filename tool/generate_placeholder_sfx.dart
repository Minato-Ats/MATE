// Generates MATE's placeholder UI sound effects: short, dry, mechanical
// "click" sounds (mechanical keyboard / mouse switch character) rather than
// electronic pops or chimes. These are synthesized, not recorded — real
// sound design can replace assets/sfx/*.wav later at the same paths with no
// code change (see lib/core/sound/sound_service.dart).
//
// Run with: dart run tool/generate_placeholder_sfx.dart
//
// Synthesis approach: each click mixes (a) a very short burst of
// high-pass-filtered noise, for the broadband "dry" transient a real switch
// makes, with (b) a short damped tone for material/pitch character — both
// under a near-instant attack and a fast (a few ms) exponential decay, so
// there is essentially no ring-out, reverb, or "chime" tail. Two clicks
// differ mainly in their tone frequency and decay time, not in having a
// fundamentally different shape.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const _sampleRate = 44100;
final _random = math.Random(7); // fixed seed: reproducible output

void main() {
  final dir = Directory('assets/sfx');
  dir.createSync(recursive: true);

  // Normal tap: a plain, mid-weight dry click.
  _writeWav('${dir.path}/tap.wav', _click(toneFreq: 2600, decayMs: 9, noiseMix: 0.55, peak: 0.38));
  // Selection: a touch brighter/crisper (higher tone) so it reads as
  // distinct from tap without leaving the same click family.
  _writeWav('${dir.path}/select.wav', _click(toneFreq: 3400, decayMs: 7, noiseMix: 0.6, peak: 0.36));
  // Wait completed: two quick clicks (a "kachi-kachi"), the second a touch
  // lower/heavier — more weight than a single tap, still no chime.
  _writeWav('${dir.path}/wait_complete.wav', _doubleClick());
  // "やめとく": a single softer, duller click — lower tone, slightly longer
  // decay — distinct from tap without becoming a "sad" trailing sound.
  _writeWav('${dir.path}/give_up.wav', _click(toneFreq: 1500, decayMs: 13, noiseMix: 0.45, peak: 0.32));

  stdout.writeln('Wrote 4 placeholder SE files to ${dir.path}');
}

/// One dry mechanical click: filtered-noise transient + a short damped tone,
/// both under the same fast exponential decay envelope (in milliseconds).
Float64List _click({
  required double toneFreq,
  required double decayMs,
  required double noiseMix,
  required double peak,
}) {
  // A few decay time-constants of tail, then stop — no long ring-out.
  final totalMs = decayMs * 5 + 2;
  final n = (_sampleRate * totalMs / 1000).round();
  final samples = Float64List(n);

  final noise = _highPassNoise(n);
  final tau = decayMs / 1000;
  const attackSamples = 3; // near-instant, but avoids a hard sample-0 pop

  for (var i = 0; i < n; i++) {
    final t = i / _sampleRate;
    final attack = i < attackSamples ? i / attackSamples : 1.0;
    final decay = math.exp(-t / tau);
    final envelope = attack * decay;
    final tone = math.sin(2 * math.pi * toneFreq * t);
    samples[i] = ((1 - noiseMix) * tone + noiseMix * noise[i]) * envelope * peak;
  }
  return samples;
}

/// Two [_click]s back-to-back with a short gap, for `wait_complete.wav`.
Float64List _doubleClick() {
  final first = _click(toneFreq: 2600, decayMs: 8, noiseMix: 0.55, peak: 0.38);
  final gap = Float64List((_sampleRate * 55 / 1000).round());
  final second = _click(toneFreq: 2000, decayMs: 11, noiseMix: 0.5, peak: 0.4);

  final total = Float64List(first.length + gap.length + second.length);
  total.setAll(0, first);
  total.setAll(first.length, gap);
  total.setAll(first.length + gap.length, second);
  return total;
}

/// White noise passed through a simple one-pole high-pass filter, so it
/// reads as a crisp/dry "tick" rather than a dull thump — most of a real
/// switch's broadband click energy is in the higher frequencies.
Float64List _highPassNoise(int n) {
  final out = Float64List(n);
  var prevIn = 0.0;
  var prevOut = 0.0;
  const alpha = 0.94;
  for (var i = 0; i < n; i++) {
    final x = _random.nextDouble() * 2 - 1;
    final y = alpha * (prevOut + x - prevIn);
    out[i] = y;
    prevIn = x;
    prevOut = y;
  }
  return out;
}

void _writeWav(String path, Float64List samples) {
  final pcm = Int16List(samples.length);
  for (var i = 0; i < samples.length; i++) {
    pcm[i] = (samples[i].clamp(-1.0, 1.0) * 32767).round();
  }
  final dataBytes = pcm.buffer.asUint8List();
  const byteRate = _sampleRate * 2;
  const blockAlign = 2;

  final header = BytesBuilder();
  void writeString(String s) => header.add(s.codeUnits);
  void writeUint32(int v) => header.add([v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF]);
  void writeUint16(int v) => header.add([v & 0xFF, (v >> 8) & 0xFF]);

  writeString('RIFF');
  writeUint32(36 + dataBytes.length);
  writeString('WAVE');
  writeString('fmt ');
  writeUint32(16);
  writeUint16(1); // PCM
  writeUint16(1); // mono
  writeUint32(_sampleRate);
  writeUint32(byteRate);
  writeUint16(blockAlign);
  writeUint16(16); // bits per sample
  writeString('data');
  writeUint32(dataBytes.length);

  final sink = File(path).openSync(mode: FileMode.write);
  sink.writeFromSync(header.toBytes());
  sink.writeFromSync(dataBytes);
  sink.closeSync();
}
