import 'dart:io';

import 'package:image/image.dart';
import 'package:launcher_icons/src/config/config.dart';
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

/// Expected pixel sizes per the MSIX app-icon construction table: `round(base * scale / 100)`.
Map<String, Map<int, ({int width, int height})>> expectedTileSizes() => {
      'Square44x44Logo': {
        100: (width: 44, height: 44),
        125: (width: 55, height: 55),
        150: (width: 66, height: 66),
        200: (width: 88, height: 88),
        400: (width: 176, height: 176),
      },
      'Square150x150Logo': {
        100: (width: 150, height: 150),
        125: (width: 188, height: 188),
        150: (width: 225, height: 225),
        200: (width: 300, height: 300),
        400: (width: 600, height: 600),
      },
      'Wide310x150Logo': {
        100: (width: 310, height: 150),
        125: (width: 388, height: 188),
        150: (width: 465, height: 225),
        200: (width: 620, height: 300),
        400: (width: 1240, height: 600),
      },
    };

void main() {
  group('WindowsIconGenerator tile scale assets', () {
    late String prefixPath;
    final assetPath = path.join(Directory.current.path, 'test', 'assets');

    setUp(() async {
      final imageFile = File(path.join(assetPath, 'master-light-1024.png'));
      expect(imageFile.existsSync(), isTrue);
      // Solid-red wide source so tests can distinguish sources by pixel.
      final red = Image(width: 620, height: 300, numChannels: 3);
      for (var y = 0; y < 300; y++) {
        for (var x = 0; x < 620; x++) {
          red.setPixelRgb(x, y, 255, 0, 0);
        }
      }
      await d.dir('fli_test', [
        d.dir('windows'),
        d.file('launcher_icons.yaml', templates.liWindowsConfig),
        d.file('pubspec.yaml', templates.pubspecTemplate),
        d.file('master-light-1024.png', imageFile.readAsBytesSync()),
        d.file('wide.png', encodePng(red)),
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

    test('emits both square sets plus wide at MSIX construction-table sizes', () async {
      final generator = generatorFor(<String, dynamic>{
        'generate': true,
        'image_path': 'master-light-1024.png',
        'image_path_wide': 'wide.png',
      });

      expect(generator.validateRequirements(), isTrue);
      await generator.createIcons();

      // Unqualified base files each manifest entry points at.
      for (final base in ['Square44x44Logo.png', 'Square150x150Logo.png', 'Wide310x150Logo.png']) {
        expect(
          File(path.join(prefixPath, 'windows', 'images', base)).existsSync(),
          isTrue,
          reason: base,
        );
      }
      for (final tile in expectedTileSizes().entries) {
        for (final scale in tile.value.entries) {
          final decoded = readAsset('${tile.key}.scale-${scale.key}.png');
          expect(decoded.width, equals(scale.value.width), reason: '${tile.key} scale-${scale.key}');
          expect(decoded.height, equals(scale.value.height), reason: '${tile.key} scale-${scale.key}');
        }
      }
    });

    test('uses the dedicated wide source for the wide set', () async {
      final generator = generatorFor(<String, dynamic>{
        'generate': true,
        'image_path': 'master-light-1024.png',
        'image_path_wide': 'wide.png',
      });
      await generator.createIcons();

      final wide = readAsset('Wide310x150Logo.scale-200.png');
      final center = wide.getPixel(310, 150);
      expect(center.r.toInt(), equals(255));
      expect(center.g.toInt(), equals(0));
    });

    test('derives wide assets with a cover-crop without a wide source', () async {
      final logger = _RecordingLogger();
      final generator = generatorFor(
        <String, dynamic>{
          'generate': true,
          'image_path': 'master-light-1024.png',
        },
        logger: logger,
      );
      await generator.createIcons();

      final wide = readAsset('Wide310x150Logo.scale-100.png');
      expect(wide.width, equals(310));
      expect(wide.height, equals(150));
      expect(
        logger.messages.any((m) => m.contains('wide')),
        isTrue,
      );
    });

    test('manifest snippet wires all three tile entries', () async {
      final generator = generatorFor(<String, dynamic>{
        'generate': true,
        'image_path': 'master-light-1024.png',
      });
      await generator.createIcons();

      final snippet = await File(
        path.join(prefixPath, 'windows', 'images', 'manifest-snippet.xml'),
      ).readAsString();
      expect(snippet, contains('Square150x150Logo="Images\\Square150x150Logo.png"'));
      expect(snippet, contains('Square44x44Logo="Images\\Square44x44Logo.png"'));
      expect(snippet, contains('Wide310x150Logo="Images\\Wide310x150Logo.png"'));
    });

    test('rejects a missing wide source', () {
      expect(
        generatorFor(<String, dynamic>{
          'generate': true,
          'image_path': 'master-light-1024.png',
          'image_path_wide': 'does-not-exist.png',
        }).validateRequirements(),
        isFalse,
      );
    });
  });
}
