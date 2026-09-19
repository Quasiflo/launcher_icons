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

void main() {
  group('WebIconGenerator index.html + apple-touch-icon', () {
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
        d.file('app_icon_favicon.png', imageFile.readAsBytesSync()),
      ]).create();
      prefixPath = path.join(d.sandbox, 'fli_test');
    });

    IconGenerator generatorFor(Map<String, dynamic> web) => WebIconGenerator(
          IconGeneratorContext(
            config: Config.fromJson(<String, dynamic>{'web': web}),
            prefixPath: prefixPath,
            logger: LILogger(false),
          ),
        );

    test('emits opaque 180px apple-touch-icon and manages index block', () async {
      final generator = generatorFor(<String, dynamic>{
        'generate': true,
        'image_path': 'master-light-1024.png',
        'background_color': '#0175C2',
        'theme_color_light': '#0175C2',
      });

      expect(generator.validateRequirements(), isTrue);
      await generator.createIcons();

      // 180x180 opaque PNG.
      final touchBytes = await File(
        path.join(prefixPath, 'web', 'icons', 'apple-touch-icon.png'),
      ).readAsBytes();
      final touch = decodeImage(touchBytes)!;
      expect(touch.width, equals(180));
      expect(touch.height, equals(180));
      expect(touch.hasAlpha, isFalse);

      final index = await File(
        path.join(prefixPath, 'web', 'index.html'),
      ).readAsString();
      expect(index, contains('<!--LI-->'));
      expect(index, contains('<!--LIEND-->'));
      expect(
        index,
        contains(
          '<link rel="apple-touch-icon" href="icons/apple-touch-icon.png"/>',
        ),
      );
      expect(index, contains('<link rel="manifest" href="manifest.json"/>'));
      expect(index, contains('sizes="any" href="favicon.ico"'));
      expect(index, contains('<style>html, body { background-color: #0175C2; }</style>'));
      expect(
        index,
        contains('<meta name="theme-color" content="#0175C2"/>'),
      );
      // No deprecated tags introduced by the tool's own block.
      final block = RegExp(
        r'<!--LI-->.*?<!--LIEND-->',
        dotAll: true,
      ).firstMatch(index)![0]!;
      expect(block, isNot(contains('apple-mobile-web-app-capable')));
    });

    test('index block is idempotent across runs', () async {
      final generator = generatorFor(<String, dynamic>{
        'generate': true,
        'image_path': 'master-light-1024.png',
      });

      await generator.createIcons();
      await generator.createIcons();

      final index = await File(
        path.join(prefixPath, 'web', 'index.html'),
      ).readAsString();
      expect('<!--LI-->'.allMatches(index), hasLength(1));
      expect('<!--LIEND-->'.allMatches(index), hasLength(1));
    });
  });
}
