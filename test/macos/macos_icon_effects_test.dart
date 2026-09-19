import 'package:image/image.dart';
import 'package:launcher_icons/src/config/macos_config.dart';
import 'package:launcher_icons/src/core/utils.dart' as utils;
import 'package:launcher_icons/src/platforms/macos/macos_icon_effects.dart';
import 'package:test/test.dart';

Image _solidRed([int size = 64]) {
  final image = Image(width: size, height: size, numChannels: 3);
  fill(image, color: ColorRgb8(255, 0, 0));
  return image;
}

void main() {
  Future<Image> Function(int) loaderFor(Image source) => (size) async => utils.createResizedImage(size, source);

  group('buildMacOSIconImage', () {
    test('defaults resize straight through (historical behavior)', () async {
      final source = _solidRed();
      final result = await buildMacOSIconImage(loaderFor(source), 64);
      expect(result.width, equals(64));
      expect(result.height, equals(64));
      expect(
        encodePng(result),
        equals(encodePng(utils.createResizedImage(64, source))),
      );
    });

    test('padding insets artwork on a transparent canvas', () async {
      final result = await buildMacOSIconImage(
        loaderFor(_solidRed()),
        64,
        paddingPercent: 25,
      );
      expect(result.width, equals(64));
      expect(result.height, equals(64));
      // 25% of 64 = 16px margin: corners stay transparent...
      expect(result.getPixel(0, 0).a, equals(0));
      expect(result.getPixel(63, 63).a, equals(0));
      // ...while the centered artwork is opaque red.
      final center = result.getPixel(32, 32);
      expect(center.a, equals(255));
      expect(center.r, equals(255));
    });

    test('extreme padding clamps instead of crashing', () async {
      final result = await buildMacOSIconImage(
        loaderFor(_solidRed()),
        64,
        paddingPercent: 90,
      );
      expect(result.width, equals(64));
      expect(result.height, equals(64));
    });

    test('rounded corners mask the corners, keep edges', () async {
      final result = await buildMacOSIconImage(
        loaderFor(_solidRed()),
        64,
        roundedCorners: true,
      );
      expect(result.getPixel(0, 0).a, equals(0));
      expect(result.getPixel(63, 0).a, equals(0));
      expect(result.getPixel(0, 63).a, equals(0));
      // Edge midpoints and center stay opaque red.
      for (final point in [(32, 0), (0, 32), (32, 32)]) {
        final pixel = result.getPixel(point.$1, point.$2);
        expect(pixel.a, equals(255), reason: '$point');
        expect(pixel.r, equals(255), reason: '$point');
      }
    });

    test('padding and rounding compose', () async {
      final result = await buildMacOSIconImage(
        loaderFor(_solidRed()),
        64,
        paddingPercent: 10,
        roundedCorners: true,
      );
      expect(result.width, equals(64));
      expect(result.getPixel(0, 0).a, equals(0));
      final center = result.getPixel(32, 32);
      expect(center.a, equals(255));
      expect(center.r, equals(255));
    });
  });

  group('applyRoundedCorners', () {
    test('does not mutate its input', () {
      final source = _solidRed();
      final before = encodePng(source);
      applyRoundedCorners(source);
      expect(encodePng(source), equals(before));
    });

    test('converts RGB sources to RGBA', () {
      final result = applyRoundedCorners(_solidRed());
      expect(result.numChannels, equals(4));
    });

    test('squircle keeps the diagonal a circular arc would cut', () {
      // 64px icon, 22.5% radius (14px): pixel (3,3) sits outside the circular arc (dx^2+dy^2 = 200 > 14^2) but inside the continuous corner (|dx|^4+|dy|^4 = 20000 < 14^4).
      final result = applyRoundedCorners(_solidRed());
      expect(result.getPixel(3, 3).a, equals(255));
      // Genuine corners stay transparent.
      expect(result.getPixel(0, 0).a, equals(0));
      expect(result.getPixel(63, 63).a, equals(0));
    });
  });

  group('MacOSConfig effects fields', () {
    test('padding and rounded_corners parse', () {
      final config = MacOSConfig.fromJson(<String, dynamic>{
        'generate': true,
        'image_path': 'master-light-1024.png',
        'padding': 10,
        'rounded_corners': true,
      });
      expect(config.padding, equals(10));
      expect(config.roundedCorners, isTrue);
    });

    test('effects fields default to off', () {
      const config = MacOSConfig(generate: true);
      expect(config.padding, equals(0));
      expect(config.roundedCorners, isFalse);
      expect(
        config.toJson(),
        containsPair('padding', 0),
      );
      expect(
        config.toJson(),
        containsPair('rounded_corners', false),
      );
    });
  });
}
