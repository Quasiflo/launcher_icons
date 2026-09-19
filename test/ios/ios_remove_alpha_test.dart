import 'dart:io';

import 'package:image/image.dart';
import 'package:launcher_icons/src/config/config.dart';
import 'package:launcher_icons/src/platforms/ios/ios.dart' as ios;
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

// Regression tests: `_alphaBlend` mixed up the background channels (bg.g/bg.a instead of bg.r/bg.g), tinting matted edges green.
void main() {
  group('remove_alpha background blending', () {
    late String originalDir;
    late String sandboxDir;

    setUp(() {
      originalDir = Directory.current.path;
      sandboxDir = path.join(
        '.dart_tool',
        'launcher_icons',
        'test',
        'ios_remove_alpha',
      );
      final sandbox = Directory(sandboxDir);
      if (sandbox.existsSync()) {
        sandbox.deleteSync(recursive: true);
      }
      sandbox.createSync(recursive: true);
      Directory.current = sandboxDir;
    });

    tearDown(() {
      Directory.current = originalDir;
    });

    test('semi-transparent red over green matte blends to yellow-brown', () async {
      // Uniform semi-transparent red source.
      final source = Image(width: 8, height: 8, numChannels: 4);
      for (final frame in source.frames) {
        for (var y = 0; y < frame.height; y++) {
          for (var x = 0; x < frame.width; x++) {
            frame.setPixelRgba(x, y, 255, 0, 0, 128);
          }
        }
      }
      await File('icon.png').writeAsBytes(encodePng(source));

      // Minimal runner layout expected by the generator.
      await Directory(
        path.join(
          'ios',
          'Runner',
          'Assets.xcassets',
          'AppIcon.appiconset',
        ),
      ).create(recursive: true);
      final pbxproj = File(path.join('ios', 'Runner.xcodeproj', 'project.pbxproj'));
      await pbxproj.create(recursive: true);
      await pbxproj.writeAsString('// !\$*UTF8*\$!\n{}\n');

      final config = Config.fromJson(<String, dynamic>{
        'ios': {
          'generate': true,
          'image_path': 'icon.png',
          'remove_alpha': true,
          'background_color': '#00FF00',
        },
      });

      await ios.createIcons(config, null);

      final output = decodeImage(
        await File(
          path.join(
            'ios',
            'Runner',
            'Assets.xcassets',
            'AppIcon.appiconset',
            'Icon-App-1024x1024@1x.png',
          ),
        ).readAsBytes(),
      )!;
      final pixel = output.getPixel(0, 0);
      // (128*255 + 127*0)/255 = 128 red, (128*0 + 127*255)/255 = 127 green. The old channel-swapped math produced red = 255 here.
      expect(pixel.r, equals(128));
      expect(pixel.g, equals(127));
      expect(pixel.b, equals(0));
    });
  });

  // remove_alpha is per-variant: the dark image keeps its transparency (Apple: the system background shows through) while the tinted image is forced opaque like the base image.
  group('remove_alpha per-variant behavior', () {
    late String originalDir;
    late String sandboxDir;

    setUp(() {
      originalDir = Directory.current.path;
      sandboxDir = path.join(
        '.dart_tool',
        'launcher_icons',
        'test',
        'ios_remove_alpha_variants',
      );
      final sandbox = Directory(sandboxDir);
      if (sandbox.existsSync()) {
        sandbox.deleteSync(recursive: true);
      }
      sandbox.createSync(recursive: true);

      // Uniform semi-transparent red sources.
      final source = Image(width: 8, height: 8, numChannels: 4);
      for (final frame in source.frames) {
        for (var y = 0; y < frame.height; y++) {
          for (var x = 0; x < frame.width; x++) {
            frame.setPixelRgba(x, y, 255, 0, 0, 128);
          }
        }
      }
      for (final name in ['icon.png', 'icon-dark.png', 'icon-tinted.png']) {
        File(path.join(sandboxDir, name)).writeAsBytesSync(encodePng(source));
      }

      // Minimal runner layout expected by the generator.
      Directory(
        path.join(
          sandboxDir,
          'ios',
          'Runner',
          'Assets.xcassets',
          'AppIcon.appiconset',
        ),
      ).createSync(recursive: true);
      final pbxproj = File(
        path.join(sandboxDir, 'ios', 'Runner.xcodeproj', 'project.pbxproj'),
      );
      pbxproj.createSync(recursive: true);
      pbxproj.writeAsStringSync('// !\$*UTF8*\$!\n{}\n');
      Directory.current = sandboxDir;
    });

    tearDown(() {
      Directory.current = originalDir;
    });

    Image readOutput(String fileName) => decodeImage(
          File(
            path.join(
              'ios',
              'Runner',
              'Assets.xcassets',
              'AppIcon.appiconset',
              fileName,
            ),
          ).readAsBytesSync(),
        )!;

    test('dark variant keeps transparency, tinted becomes opaque', () async {
      final config = Config.fromJson(<String, dynamic>{
        'ios': {
          'generate': true,
          'image_path': 'icon.png',
          'image_path_dark_transparent': 'icon-dark.png',
          'image_path_tinted_grayscale': 'icon-tinted.png',
          'remove_alpha': true,
          'background_color': '#00FF00',
        },
      });

      await ios.createIcons(config, null);

      final dark = readOutput('Icon-App-Dark-1024x1024@1x.png');
      expect(dark.hasAlpha, isTrue);
      expect(dark.getPixel(0, 0).a, equals(128));

      final tinted = readOutput('Icon-App-Tinted-1024x1024@1x.png');
      expect(tinted.hasAlpha, isFalse);
    });
  });
}
