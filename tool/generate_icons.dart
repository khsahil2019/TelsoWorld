// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

void main() {
  const sizes = {
    'android/app/src/main/res/mipmap-mdpi/ic_launcher.png': 48,
    'android/app/src/main/res/mipmap-hdpi/ic_launcher.png': 72,
    'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': 96,
    'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': 144,
    'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': 192,
    'assets/icons/app_icon.png': 512,
  };

  for (final entry in sizes.entries) {
    final size = entry.value;
    final image = _drawTelsoAppIcon(size);
    final file = File(entry.key);
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(img.encodePng(image));
    print('Generated: ${entry.key} ($size x $size)');
  }
}

img.Image _drawTelsoAppIcon(int size) {
  final image = img.Image(width: size, height: size);
  final center = size / 2.0;
  final outerRadius = size * 0.46;
  final innerRadius = size * 0.38;

  // Background deep dark gradient circle
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      final dx = x - center;
      final dy = y - center;
      final dist = math.sqrt(dx * dx + dy * dy);

      if (dist <= outerRadius) {
        if (dist > innerRadius) {
          // Outer Neon Pink to Orange Gradient Ring
          final angle = (math.atan2(dy, dx) + math.pi) / (2 * math.pi);
          final r = (215 + 40 * angle).clamp(0, 255).toInt();
          final g = (15 + 100 * angle).clamp(0, 255).toInt();
          final b = (100 - 80 * angle).clamp(0, 255).toInt();
          image.setPixelRgba(x, y, r, g, b, 255);
        } else {
          // Inner Dark Luxury Core
          final t = y / size;
          final r = (16 + 10 * t).toInt();
          final g = (16 + 10 * t).toInt();
          final b = (24 + 16 * t).toInt();
          image.setPixelRgba(x, y, r, g, b, 255);
        }
      } else {
        // Transparent corner
        image.setPixelRgba(x, y, 0, 0, 0, 0);
      }
    }
  }

  // Draw White Play Arrow in the center
  final playSize = size * 0.32;
  final p1 = [center - playSize * 0.38, center - playSize * 0.5];
  final p2 = [center - playSize * 0.38, center + playSize * 0.5];
  final p3 = [center + playSize * 0.55, center];

  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      if (_pointInTriangle(x.toDouble(), y.toDouble(), p1[0], p1[1], p2[0], p2[1], p3[0], p3[1])) {
        image.setPixelRgba(x, y, 255, 255, 255, 255);
      }
    }
  }

  return image;
}

bool _pointInTriangle(double px, double py, double x1, double y1, double x2, double y2, double x3, double y3) {
  double sign(double p1x, double p1y, double p2x, double p2y, double p3x, double p3y) {
    return (p1x - p3x) * (p2y - p3y) - (p2x - p3x) * (p1y - p3y);
  }

  final d1 = sign(px, py, x1, y1, x2, y2);
  final d2 = sign(px, py, x2, y2, x3, y3);
  final d3 = sign(px, py, x3, y3, x1, y1);

  final hasNeg = (d1 < 0) || (d2 < 0) || (d3 < 0);
  final hasPos = (d1 > 0) || (d2 > 0) || (d3 > 0);

  return !(hasNeg && hasPos);
}
