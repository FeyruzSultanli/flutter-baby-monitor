// Renders the Ninni mark (AppIconPainter) to the PNGs used by
// flutter_launcher_icons and flutter_native_splash:
//
//   flutter test tool/gen_icons_test.dart
//   dart run flutter_launcher_icons
//   dart run flutter_native_splash:create
//
// Outputs (assets/icon/):
//   ninni_icon_1024.png        full-bleed square (iOS masks it itself)
//   ninni_foreground_1024.png  Android adaptive foreground (safe zone)
//   ninni_splash_768.png       splash mark on transparent background

import 'dart:io';
import 'dart:ui' as ui;

import 'package:bebek_monitor_clean/theme/components/brand.dart';
import 'package:bebek_monitor_clean/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _render(String path, double size, void Function(Canvas c, Size s) paint) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  paint(canvas, Size.square(size));
  final image = await recorder.endRecording().toImage(size.toInt(), size.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(path)..createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  test('generate icon PNGs', () async {
    const dir = 'assets/icon';
    // iOS / legacy: full-bleed night background, mark like the 160 grid
    // (the system applies the rounded mask).
    await _render('$dir/ninni_icon_1024.png', 1024, (c, s) {
      c.drawRect(Offset.zero & s, Paint()..color = NinniColors.night900);
      const AppIconPainter(showBackground: false).paint(c, s);
    });
    // Android adaptive foreground: the mark in the central 2/3 safe zone.
    await _render('$dir/ninni_foreground_1024.png', 1024, (c, s) {
      const inner = 1024 * 0.62;
      c.translate((1024 - inner) / 2, (1024 - inner) / 2);
      const AppIconPainter(showBackground: false).paint(c, const Size.square(inner));
    });
    // Splash: mark only (background color from flutter_native_splash).
    await _render('$dir/ninni_splash_768.png', 768, (c, s) {
      const inner = 768 * 0.7;
      c.translate((768 - inner) / 2, (768 - inner) / 2);
      const AppIconPainter(showBackground: false).paint(c, const Size.square(inner));
    });
  });
}
