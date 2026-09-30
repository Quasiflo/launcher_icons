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

    IconGenerator generatorFor(final Map<String, dynamic> web) => WebIconGenerator(
          IconGeneratorContext(
            config: Config.fromJson(<String, dynamic>{'web': web}),
            prefixPath: prefixPath,
            logger: LILogger(isVerbose: false),
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
        '<!--LI-->.*?<!--LIEND-->',
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
      final first = await File(
        path.join(prefixPath, 'web', 'index.html'),
      ).readAsString();
      await generator.createIcons();
      final second = await File(
        path.join(prefixPath, 'web', 'index.html'),
      ).readAsString();
      await generator.createIcons();
      final third = await File(
        path.join(prefixPath, 'web', 'index.html'),
      ).readAsString();

      expect('<!--LI-->'.allMatches(third), hasLength(1));
      expect('<!--LIEND-->'.allMatches(third), hasLength(1));
      // Regression for https://github.com/Quasiflo/launcher_icons/issues/29:
      // repeated runs must leave the file byte-identical (no growing indent).
      expect(second, equals(first));
      expect(third, equals(first));
    });

    test('index block delimiters default to two leading spaces', () async {
      final generator = generatorFor(<String, dynamic>{
        'generate': true,
        'image_path': 'master-light-1024.png',
      });

      await generator.createIcons();
      final index = await File(
        path.join(prefixPath, 'web', 'index.html'),
      ).readAsString();
      final liLine = index.split('\n').firstWhere((final l) => l.contains('<!--LI-->') && !l.contains('LIEND'));
      final liendLine = index.split('\n').firstWhere((final l) => l.contains('<!--LIEND-->'));
      expect(liLine, equals('  <!--LI-->'));
      expect(liendLine, equals('  <!--LIEND-->'));
    });

    test('index block disregards whitespace-only custom formatting', () async {
      final generator = generatorFor(<String, dynamic>{
        'generate': true,
        'image_path': 'master-light-1024.png',
      });

      await generator.createIcons();
      final indexFile = File(path.join(prefixPath, 'web', 'index.html'));
      final first = await indexFile.readAsString();

      // Simulate a custom formatter re-indenting the managed block.
      final reformatted = first.replaceAll('\n  <!--LI-->', '\n    <!--LI-->').replaceAll('\n  <link', '\n    <link').replaceAll('\n  <!--LIEND-->', '\n    <!--LIEND-->');
      expect(reformatted, isNot(equals(first)));
      await indexFile.writeAsString(reformatted);

      await generator.createIcons();
      final second = await indexFile.readAsString();
      expect(second, equals(reformatted));
    });
  });
}
