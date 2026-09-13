// Renders MATE's official app icon (M + hourglass motif) to PNG assets.
//
// Run with: flutter test tool/render_app_icon.dart
// (needs `flutter test`, not `dart run`, because it uses dart:ui's Canvas /
// PictureRecorder / image-to-PNG encoding, which requires the Flutter test
// binding's engine bindings.)
//
// Design: a single "M" silhouette (a rounded-corner block M, built as one
// polygon with a triangular notch at the top-center) with a bowtie/hourglass
// shape cut out of its center — the hourglass's waist sits exactly at the
// M's own natural pinch point, so it reads as part of the M's structure
// rather than a separate decoration. All shapes are defined once in a
// 0-100 design box and rendered at whatever final scale each output needs.
//
// Outputs:
//   assets/icon/icon_master.png      1024x1024, opaque white bg — iOS +
//                                     Android legacy/general icon source.
//   assets/icon/icon_foreground.png  1024x1024, transparent bg, content
//                                     scaled to respect Android's adaptive
//                                     icon safe zone — Android 8+ foreground
//                                     layer (paired with a solid white
//                                     adaptive background, no separate file
//                                     needed).
//   assets/icon/icon_monochrome.png  1024x1024, transparent bg, solid black
//                                     — Android 13+ themed-icon layer.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const double _kSize = 1024;
const double _kDesignBox = 100;

// Android's adaptive-icon safe zone is a 66dp circle centered in a 108dp
// canvas (radius = 33/54 = 0.6111 of the half-canvas). Our M's furthest
// corner sits at normalized distance ~0.764 of the half-canvas, so it needs
// an extra ~0.80x scale to land on that boundary; 0.78 leaves a small
// buffer instead of touching it exactly.
const double _kForegroundScale = 0.78;

enum _Fill { gradient, blackOnly }

void main() {
  test('render MATE app icon assets', () async {
    await _renderIcon(
      outputPath: 'assets/icon/icon_master.png',
      background: Colors.white,
      contentScale: 1.0,
      fill: _Fill.gradient,
    );
    await _renderIcon(
      outputPath: 'assets/icon/icon_foreground.png',
      background: null,
      contentScale: _kForegroundScale,
      fill: _Fill.gradient,
    );
    await _renderIcon(
      outputPath: 'assets/icon/icon_monochrome.png',
      background: null,
      contentScale: _kForegroundScale,
      fill: _Fill.blackOnly,
    );

    // Legibility check only (not shipped): render the master design at
    // actual small final pixel sizes, so antialiasing/downscaling at real
    // launcher sizes can be inspected directly instead of eyeballing a
    // shrunk 1024px image.
    await _renderIcon(
      outputPath: 'build/icon_preview_48.png',
      background: Colors.white,
      contentScale: 1.0,
      fill: _Fill.gradient,
      finalPixelSize: 48,
    );
    await _renderIcon(
      outputPath: 'build/icon_preview_32.png',
      background: Colors.white,
      contentScale: 1.0,
      fill: _Fill.gradient,
      finalPixelSize: 32,
    );
  });
}

Future<void> _renderIcon({
  required String outputPath,
  required Color? background,
  required double contentScale,
  required _Fill fill,
  double? finalPixelSize,
}) async {
  final canvasSize = finalPixelSize ?? _kSize;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, canvasSize, canvasSize));

  if (background != null) {
    canvas.drawRect(Rect.fromLTWH(0, 0, canvasSize, canvasSize), Paint()..color = background);
  }

  canvas.save();
  final targetSize = canvasSize * contentScale;
  final inset = (canvasSize - targetSize) / 2;
  canvas.translate(inset, inset);
  canvas.scale(targetSize / _kDesignBox);

  final mPath = _buildMPath();
  final fillPaint = Paint()..style = PaintingStyle.fill;
  if (fill == _Fill.gradient) {
    fillPaint.shader = ui.Gradient.linear(
      const Offset(24, 26),
      const Offset(76, 74),
      const [Color(0xFF3FD0B8), Color(0xFF3D8BFF)],
    );
  } else {
    fillPaint.color = Colors.black;
  }
  // Rounds the M's outer corners by stroking the same outline with a round
  // join on top of the fill.
  final mStrokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 9
    ..shader = fillPaint.shader
    ..color = fillPaint.color;

  // Composited in an offscreen layer so BlendMode.clear below only erases
  // what THIS icon has drawn so far, not the page background underneath —
  // this is the reliable way to punch a true transparent hole in a shape.
  // (Path.combine(difference, ...) was tried first but its thick rounding
  // stroke, sized for the outer M silhouette, was wide enough relative to
  // the small hourglass triangles to completely repaint over the cutout —
  // punching the hole via blend mode instead avoids that interaction
  // entirely.)
  canvas.saveLayer(const Rect.fromLTWH(0, 0, _kDesignBox, _kDesignBox), Paint());
  canvas.drawPath(mPath, fillPaint);
  canvas.drawPath(mPath, mStrokePaint);

  final clearPaint = Paint()
    ..blendMode = BlendMode.clear
    ..style = PaintingStyle.fill;
  final clearStrokePaint = Paint()
    ..blendMode = BlendMode.clear
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = 3;
  for (final triangle in [_buildHourglassTopTriangle(), _buildHourglassBottomTriangle()]) {
    canvas.drawPath(triangle, clearPaint);
    canvas.drawPath(triangle, clearStrokePaint);
  }
  canvas.restore(); // composite the layer (with its hole) onto the canvas

  canvas.restore();

  final picture = recorder.endRecording();
  final pixelSize = canvasSize.toInt();
  final image = await picture.toImage(pixelSize, pixelSize);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(outputPath);
  file.parent.createSync(recursive: true);
  await file.writeAsBytes(byteData!.buffer.asUint8List());
  // ignore: avoid_print
  print('Wrote $outputPath');
}

/// The M silhouette: a solid rectangle (22..78, 24..76) with a shallow
/// triangular notch cut from the top-center down to (50, 46) — just deep
/// enough to read as the two peaks of an "M", while leaving a solid band of
/// color below it for the hourglass to sit inside (rather than the notch's
/// own open space swallowing half of it).
Path _buildMPath() {
  return Path()
    ..moveTo(22, 24)
    ..lineTo(36, 24)
    ..lineTo(50, 46)
    ..lineTo(64, 24)
    ..lineTo(78, 24)
    ..lineTo(78, 76)
    ..lineTo(22, 76)
    ..close();
}

/// The hourglass's top and bottom triangles, kept as two independent
/// (non-self-touching) closed shapes — together they read as one bowtie,
/// fully enclosed within the M's solid lower band.
Path _buildHourglassTopTriangle() {
  return Path()
    ..moveTo(43, 52)
    ..lineTo(57, 52)
    ..lineTo(50, 60)
    ..close();
}

Path _buildHourglassBottomTriangle() {
  return Path()
    ..moveTo(58, 72)
    ..lineTo(42, 72)
    ..lineTo(50, 60)
    ..close();
}
