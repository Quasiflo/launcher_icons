import 'dart:io';

import 'package:image/image.dart';
import 'package:launcher_icons/src/config/config.dart';
import 'package:launcher_icons/src/core/icon_generator.dart';
import 'package:launcher_icons/src/core/logger.dart';
import 'package:launcher_icons/src/platforms/web/web_icon_generator.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:yaml/yaml.dart';

import '../templates.dart' as templates;

void main() {
  group('WebIconGenerator', () {
    late IconGeneratorContext context;
    late IconGenerator generator;
    late Config config;
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
      config = Config.fromJson(
        loadYaml(
          templates.liWebConfig,
        )['launcher_icons'] as Map<dynamic, dynamic>,
      );
      context = IconGeneratorContext(
        config: config,
        prefixPath: prefixPath,
        logger: LILogger(false),
      );
      generator = WebIconGenerator(context);
    });

    // end to end test
    test('should generate valid icons', () async {
      expect(generator.validateRequirements(), isTrue);
      await generator.createIcons();
      await expectLater(
        d.dir('fli_test', [
          d.dir('web', [
            d.dir('icons', [
              // this icons get created in fs
              d.file('Icon-192.png', anything),
              d.file('Icon-512.png', anything),
              d.file('Icon-maskable-192.png', anything),
              d.file('Icon-maskable-512.png', anything),
            ]),
            // this favicon get created in fs
            d.file('favicon.png', anything),
            d.file('favicon.ico', anything),
            d.file('index.html', anything),
            // this manifest.json get updated in fs
            d.file('manifest.json', anything),
          ]),
          d.file('launcher_icons.yaml', anything),
          d.file('pubspec.yaml', templates.pubspecTemplate),
        ]).validate(),
        completes,
      );
    });

    test('honors favicon_size (fluttercommunity/flutter_launcher_icons#614)', () async {
      final sizedConfig = Config.fromJson(<String, dynamic>{
        'web': {
          'generate': true,
          'image_path': 'master-light-1024.png',
          'favicon_size': 32,
        },
      });
      final sizedContext = IconGeneratorContext(
        config: sizedConfig,
        prefixPath: prefixPath,
        logger: LILogger(false),
      );
      final sizedGenerator = WebIconGenerator(sizedContext);

      expect(sizedGenerator.validateRequirements(), isTrue);
      await sizedGenerator.createIcons();

      final favicon = decodeImage(
        await File(path.join(prefixPath, 'web', 'favicon.png')).readAsBytes(),
      )!;
      expect(favicon.width, equals(32));
      expect(favicon.height, equals(32));
    });

    test('emits a decodable favicon.ico alongside favicon.png (fluttercommunity/flutter_launcher_icons#540)', () async {
      expect(generator.validateRequirements(), isTrue);
      await generator.createIcons();

      final ico = decodeIco(
        await File(path.join(prefixPath, 'web', 'favicon.ico')).readAsBytes(),
      )!;
      expect(ico.width, equals(16));
      expect(ico.height, equals(16));
    });

    test('honors output_path (fluttercommunity/flutter_launcher_icons#426)', () async {
      await d.dir('fli_test', [
        d.dir('web_prod', [
          d.dir('icons'),
          d.file('index.html', templates.webIndexTemplate),
          d.file('manifest.json', templates.webManifestTemplate),
        ]),
      ]).create();
      final outputConfig = Config.fromJson(<String, dynamic>{
        'web': {
          'generate': true,
          'image_path': 'master-light-1024.png',
          'output_path': 'web_prod',
        },
      });
      final outputContext = IconGeneratorContext(
        config: outputConfig,
        prefixPath: prefixPath,
        logger: LILogger(false),
      );
      final outputGenerator = WebIconGenerator(outputContext);

      expect(outputGenerator.validateRequirements(), isTrue);
      await outputGenerator.createIcons();

      await expectLater(
        d.dir('fli_test', [
          d.dir('web_prod', [
            d.dir('icons', [
              d.file('Icon-192.png', anything),
              d.file('Icon-512.png', anything),
            ]),
            d.file('favicon.png', anything),
            d.file('favicon.ico', anything),
            d.file('manifest.json', anything),
          ]),
        ]).validate(),
        completes,
      );
    });
  });
}
