import 'dart:io';

import 'package:image/image.dart';
import 'package:launcher_icons/src/config/config.dart';
import 'package:launcher_icons/src/core/icon_generator.dart';
import 'package:launcher_icons/src/core/logger.dart';
import 'package:launcher_icons/src/platforms/web/web_icon_generator.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import '../templates.dart' as templates;

/// Captures `info` output so warning routing can be asserted.
class _RecordingLogger extends LILogger {
  _RecordingLogger() : super(isVerbose: false);
  final List<String> messages = <String>[];

  @override
  void info(final Object? message) {
    messages.add(message.toString());
  }
}

void main() {
  group('WebIconGenerator maskable source', () {
    late String prefixPath;
    final assetPath = path.join(Directory.current.path, 'test', 'assets');

    setUp(() async {
      final imageFile = File(path.join(assetPath, 'master-light-1024.png'));
      expect(imageFile.existsSync(), isTrue);
      await d.dir('fli_test', [
        d.dir('web', [
          d.dir('icons'),
          d.file('index.html', templates.webIndexTemplate),
          d.file('manifest.json', templates.webManifestTemplate),
        ]),
        d.file('launcher_icons.yaml', templates.liWebConfig),
        d.file('pubspec.yaml', templates.pubspecTemplate),
        d.file('master-light-1024.png', imageFile.readAsBytesSync()),
      ]).create();
      prefixPath = path.join(d.sandbox, 'fli_test');

      // Opaque solid-red dedicated maskable source.
      final red = Image(width: 64, height: 64);
      for (var y = 0; y < 64; y++) {
        for (var x = 0; x < 64; x++) {
          red.setPixelRgb(x, y, 255, 0, 0);
        }
      }
      await File(path.join(prefixPath, 'maskable.png')).writeAsBytes(encodePng(red));
    });

    IconGenerator generatorFor(
      final Map<String, dynamic> web, {
      final LILogger? logger,
    }) =>
        WebIconGenerator(
          IconGeneratorContext(
            config: Config.fromJson(<String, dynamic>{'web': web}),
            prefixPath: prefixPath,
            logger: logger ?? LILogger(isVerbose: false),
          ),
        );

    Image readIcon(final String fileName) => decodeImage(
          File(path.join(prefixPath, 'web', 'icons', fileName)).readAsBytesSync(),
        )!;

    test('uses image_path_maskable when provided', () async {
      final generator = generatorFor(<String, dynamic>{
        'generate': true,
        'image_path': 'master-light-1024.png',
        'image_path_maskable': 'maskable.png',
        'background_color': '#0175C2',
        'theme_color_light': '#0175C2',
      });

      await generator.createIcons();

      final maskable = readIcon('Icon-maskable-192.png');
      final center = maskable.getPixel(96, 96);
      expect(center.r.toInt(), equals(255));
      expect(center.g.toInt(), equals(0));
      expect(center.b.toInt(), equals(0));
    });

    test('derives opaque padded maskable art without a source', () async {
      final generator = generatorFor(<String, dynamic>{
        'generate': true,
        'image_path': 'master-light-1024.png',
        'background_color': '#ff0000',
      });

      await generator.createIcons();

      final maskable = readIcon('Icon-maskable-192.png');
      expect(maskable.hasAlpha, isFalse);
      // Outer edge survives cropping: corners are the opaque background.
      final corner = maskable.getPixel(0, 0);
      expect(corner.r.toInt(), equals(255));
      expect(corner.g.toInt(), equals(0));
      expect(corner.b.toInt(), equals(0));
    });

    test('warns when deriving maskable art from a transparent source', () async {
      final logger = _RecordingLogger();
      final generator = generatorFor(
        <String, dynamic>{
          'generate': true,
          'image_path': 'master-light-1024.png',
          'background_color': '#ff0000',
        },
        logger: logger,
      );

      await generator.createIcons();

      expect(
        logger.messages.any(
          (final m) => m.contains('maskable') && m.contains('transparen'),
        ),
        isTrue,
      );
    });
  });
}
