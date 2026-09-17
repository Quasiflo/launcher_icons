import 'dart:io';

import 'package:image/image.dart';
import 'package:launcher_icons/src/config/config.dart';
import 'package:launcher_icons/src/core/logger.dart';
import 'package:launcher_icons/src/platforms/ios/ios.dart' as ios;
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

// Tinted validation: a sampled chroma scan (not a single pixel, not a full O(n) walk) warns when the tinted source carries real color.
void main() {
  group('isGrayscaleImage', () {
    Image solid(int size, int r, int g, int b) {
      final image = Image(width: size, height: size, numChannels: 3);
      for (var y = 0; y < size; y++) {
        for (var x = 0; x < size; x++) {
          image.setPixelRgb(x, y, r, g, b);
        }
      }
      return image;
    }

    test('accepts uniform gray', () {
      expect(ios.isGrayscaleImage(solid(64, 128, 128, 128)), isTrue);
    });

    test('rejects uniform color', () {
      expect(ios.isGrayscaleImage(solid(64, 200, 50, 50)), isFalse);
    });

    test('finds color away from the origin', () {
      final image = solid(64, 128, 128, 128);
      image.setPixelRgb(60, 60, 200, 50, 50);
      expect(ios.isGrayscaleImage(image), isFalse);
    });

    test('tolerates compression-level noise', () {
      final image = solid(64, 128, 128, 128);
      image.setPixelRgb(10, 10, 130, 128, 126);
      expect(ios.isGrayscaleImage(image), isTrue);
    });
  });

  group('createIcons tinted warning', () {
    late String originalDir;
    late String sandboxDir;

    setUp(() {
      originalDir = Directory.current.path;
      sandboxDir = path.join(
        '.dart_tool',
        'launcher_icons',
        'test',
        'ios_tinted_validation',
      );
      final sandbox = Directory(sandboxDir);
      if (sandbox.existsSync()) {
        sandbox.deleteSync(recursive: true);
      }
      sandbox.createSync(recursive: true);
      File(path.join(originalDir, 'test', 'assets', 'master-light-1024.png')).copySync(path.join(sandboxDir, 'icon.png'));
      final red = Image(width: 16, height: 16, numChannels: 3);
      for (var y = 0; y < 16; y++) {
        for (var x = 0; x < 16; x++) {
          red.setPixelRgb(x, y, 200, 50, 50);
        }
      }
      File(path.join(sandboxDir, 'tinted.png')).writeAsBytesSync(encodePng(red));
      Directory.current = sandboxDir;
    });

    tearDown(() {
      Directory.current = originalDir;
    });

    test('warns for a colored tinted source', () async {
      await Directory(
        path.join('ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset'),
      ).create(recursive: true);
      await Directory(path.join('ios', 'Runner.xcodeproj')).create(
        recursive: true,
      );
      await File(
        path.join('ios', 'Runner.xcodeproj', 'project.pbxproj'),
      ).writeAsString('// !\$*UTF8*\$!\n{}\n');
      final config = Config.fromJson(<String, dynamic>{
        'ios': {
          'generate': true,
          'image_path': 'icon.png',
          'image_path_tinted_grayscale': 'tinted.png',
        },
      });

      final messages = <String>[];
      final logger = _RecordingLogger(messages);
      await ios.createIcons(config, null, logger: logger);

      expect(
        messages.any((m) => m.contains('not grayscale')),
        isTrue,
      );
    });
  });
}

/// Captures `info` output so warning routing can be asserted.
class _RecordingLogger extends LILogger {
  _RecordingLogger(this.messages) : super(false);

  final List<String> messages;

  @override
  void info(Object? message) {
    messages.add(message.toString());
  }
}
