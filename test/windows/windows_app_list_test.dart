import 'dart:io';

import 'package:image/image.dart';
import 'package:launcher_icons/src/config/config.dart';
import 'package:launcher_icons/src/core/constants.dart' as constants;
import 'package:launcher_icons/src/core/icon_generator.dart';
import 'package:launcher_icons/src/core/logger.dart';
import 'package:launcher_icons/src/platforms/windows/windows_icon_generator.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import '../templates.dart' as templates;

/// Captures `info` output so warning routing can be asserted.
class _RecordingLogger extends LILogger {
  final List<String> messages = <String>[];

  _RecordingLogger() : super(false);

  @override
  void info(Object? message) {
    messages.add(message.toString());
  }
}

void main() {
  group('WindowsIconGenerator AppList assets', () {
    late String prefixPath;
    final assetPath = path.join(Directory.current.path, 'test', 'assets');

    setUp(() async {
      final imageFile = File(path.join(assetPath, 'master-light-1024.png'));
      expect(imageFile.existsSync(), isTrue);
      // Solid-red theme overrides so tests can distinguish sources by pixel.
      final red = Image(width: 64, height: 64, numChannels: 3);
      for (var y = 0; y < 64; y++) {
        for (var x = 0; x < 64; x++) {
          red.setPixelRgb(x, y, 255, 0, 0);
        }
      }
      final redBytes = encodePng(red);
      await d.dir('fli_test', [
        d.dir('windows'),
        d.file('launcher_icons.yaml', templates.liWindowsConfig),
        d.file('pubspec.yaml', templates.pubspecTemplate),
        d.file('master-light-1024.png', imageFile.readAsBytesSync()),
        d.file('unplated.png', redBytes),
        d.file('light-unplated.png', redBytes),
      ]).create();
      prefixPath = path.join(d.sandbox, 'fli_test');
    });

    IconGenerator generatorFor(Map<String, dynamic> windows, {LILogger? logger}) => WindowsIconGenerator(
          IconGeneratorContext(
            config: Config.fromJson(<String, dynamic>{'windows': windows}),
            prefixPath: prefixPath,
            logger: logger ?? LILogger(false),
          ),
        );

    Image readAsset(String fileName) => decodeImage(
          File(path.join(prefixPath, 'windows', 'images', fileName)).readAsBytesSync(),
        )!;

    test('emits base, plated, and both unplated variants per target size', () async {
      final generator = generatorFor(<String, dynamic>{
        'generate': true,
        'image_path': 'master-light-1024.png',
        'image_path_unplated': 'unplated.png',
        'image_path_light_unplated': 'light-unplated.png',
      });

      expect(generator.validateRequirements(), isTrue);
      await generator.createIcons();

      expect(
        File(path.join(prefixPath, 'windows', 'images', constants.windowsAppListBaseName)).existsSync(),
        isTrue,
      );
      for (final size in constants.windowsAppListTargetSizes) {
        for (final suffix in ['', '_altform-unplated', '_altform-lightunplated']) {
          final file = File(
            path.join(prefixPath, 'windows', 'images', 'Square44x44Logo.targetsize-$size$suffix.png'),
          );
          expect(file.existsSync(), isTrue, reason: 'targetsize-$size$suffix');
          final decoded = decodeImage(file.readAsBytesSync())!;
          expect(decoded.width, equals(size));
          expect(decoded.height, equals(size));
        }
      }
      expect(
        File(path.join(prefixPath, 'windows', 'images', 'manifest-snippet.xml')).existsSync(),
        isTrue,
      );
    });

    test('uses dedicated theme sources for unplated variants', () async {
      final generator = generatorFor(<String, dynamic>{
        'generate': true,
        'image_path': 'master-light-1024.png',
        'image_path_unplated': 'unplated.png',
        'image_path_light_unplated': 'light-unplated.png',
      });
      await generator.createIcons();

      final unplated = readAsset('Square44x44Logo.targetsize-48_altform-unplated.png');
      final center = unplated.getPixel(24, 24);
      expect(center.r.toInt(), equals(255));
      expect(center.g.toInt(), equals(0));
    });

    test('derives padded transparent bare marks without theme sources', () async {
      final logger = _RecordingLogger();
      final generator = generatorFor(
        <String, dynamic>{
          'generate': true,
          'image_path': 'master-light-1024.png',
        },
        logger: logger,
      );
      await generator.createIcons();

      final unplated = readAsset('Square44x44Logo.targetsize-96_altform-unplated.png');
      expect(unplated.hasAlpha, isTrue);
      // Padding ring stays transparent while the centered mark fills ~75%.
      final corner = unplated.getPixel(0, 0);
      expect(corner.a.toInt(), equals(0));
      expect(
        logger.messages.any((m) => m.contains('unplated')),
        isTrue,
      );
    });

    test('manifest snippet references the emitted base file', () async {
      final generator = generatorFor(<String, dynamic>{
        'generate': true,
        'image_path': 'master-light-1024.png',
      });
      await generator.createIcons();

      final snippet = await File(
        path.join(prefixPath, 'windows', 'images', 'manifest-snippet.xml'),
      ).readAsString();
      expect(snippet, contains('Square44x44Logo="Images\\${constants.windowsAppListBaseName}"'));
    });

    test('rejects missing unplated sources', () {
      expect(
        generatorFor(<String, dynamic>{
          'generate': true,
          'image_path': 'master-light-1024.png',
          'image_path_unplated': 'does-not-exist.png',
        }).validateRequirements(),
        isFalse,
      );
      expect(
        generatorFor(<String, dynamic>{
          'generate': true,
          'image_path': 'master-light-1024.png',
          'image_path_light_unplated': 'does-not-exist.png',
        }).validateRequirements(),
        isFalse,
      );
    });
  });
}
