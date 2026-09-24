import 'dart:convert';
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
  group('WebIconGenerator new preferences', () {
    late String prefixPath;
    final assetPath = path.join(Directory.current.path, 'test', 'assets');

    setUp(() async {
      final imageFile = File(path.join(assetPath, 'master-light-1024.png'));
      final svgFile = File(path.join(assetPath, 'master-light-1024.svg'));
      expect(imageFile.existsSync(), isTrue);
      expect(svgFile.existsSync(), isTrue);
      // solid-red PWA override so tests can distinguish sources by pixel.
      final red = Image(width: 64, height: 64);
      for (var y = 0; y < 64; y++) {
        for (var x = 0; x < 64; x++) {
          red.setPixelRgb(x, y, 255, 0, 0);
        }
      }
      final redBytes = encodePng(red);
      await d.dir('fli_test', [
        d.dir('web', [
          d.dir('icons'),
          d.file('index.html', templates.webIndexTemplate),
          d.file('manifest.json', templates.webManifestTemplate),
        ]),
        d.file('launcher_icons.yaml', templates.liWebConfig),
        d.file('pubspec.yaml', templates.pubspecTemplate),
        d.file('master-light-1024.png', imageFile.readAsBytesSync()),
        d.file('pwa-override.png', redBytes),
        d.file('mono.png', redBytes),
        d.file('mono-maskable.png', redBytes),
        d.file('og.png', redBytes),
        d.file('twitter.png', redBytes),
        d.file('shortcut.png', redBytes),
        d.file('icon-favicon.svg', svgFile.readAsBytesSync()),
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

    test('favicon always renders from image_path (no override key)', () async {
      final generator = generatorFor(<String, dynamic>{
        'generate': true,
        'image_path': 'master-light-1024.png',
        'favicon_size': 32,
      });
      expect(generator.validateRequirements(), isTrue);
      await generator.createIcons();
      final favicon = decodeImage(
        await File(path.join(prefixPath, 'web', 'favicon.png')).readAsBytes(),
      )!;
      expect(favicon.width, equals(32));
    });

    test('copies favicon svg verbatim and links it', () async {
      final generator = generatorFor(<String, dynamic>{
        'generate': true,
        'image_path': 'master-light-1024.png',
        'image_path_favicon_svg': 'icon-favicon.svg',
      });
      expect(generator.validateRequirements(), isTrue);
      await generator.createIcons();
      final source = await File(path.join(prefixPath, 'icon-favicon.svg')).readAsString();
      final copied = await File(path.join(prefixPath, 'web', 'favicon.svg')).readAsString();
      expect(copied, equals(source));
      final index = await File(path.join(prefixPath, 'web', 'index.html')).readAsString();
      expect(index, contains('<link rel="icon" type="image/svg+xml" href="favicon.svg"/>'));
      // PNG favicon still rendered from the base image.
      expect(File(path.join(prefixPath, 'web', 'favicon.png')).existsSync(), isTrue);
    });

    test('uses image_path_pwa for standard icons only', () async {
      final generator = generatorFor(<String, dynamic>{
        'generate': true,
        'image_path': 'master-light-1024.png',
        'image_path_pwa': 'pwa-override.png',
      });
      await generator.createIcons();
      final pwa = decodeImage(
        File(path.join(prefixPath, 'web', 'icons', 'Icon-192.png')).readAsBytesSync(),
      )!;
      expect(pwa.getPixel(96, 96).r.toInt(), equals(255));
      expect(pwa.getPixel(96, 96).g.toInt(), equals(0));
    });

    test('emits monochrome icons with manifest purposes', () async {
      final generator = generatorFor(<String, dynamic>{
        'generate': true,
        'image_path': 'master-light-1024.png',
        'image_path_monochrome': 'mono.png',
        'image_path_monochrome_maskable': 'mono-maskable.png',
      });
      await generator.createIcons();
      expect(File(path.join(prefixPath, 'web', 'icons', 'Icon-monochrome-192.png')).existsSync(), isTrue);
      expect(
        File(path.join(prefixPath, 'web', 'icons', 'Icon-maskable-monochrome-192.png')).existsSync(),
        isTrue,
      );
      final manifest = jsonDecode(
        await File(path.join(prefixPath, 'web', 'manifest.json')).readAsString(),
      ) as Map<String, dynamic>;
      final icons = (manifest['icons'] as List).cast<Map<String, dynamic>>();
      expect(icons.any((final e) => e['purpose'] == 'monochrome'), isTrue);
      expect(icons.any((final e) => e['purpose'] == 'maskable monochrome'), isTrue);
    });

    test('generates opengraph/twitter images with meta tags', () async {
      final generator = generatorFor(<String, dynamic>{
        'generate': true,
        'image_path': 'master-light-1024.png',
        'image_path_opengraph': 'og.png',
        'image_path_twitter': 'twitter.png',
      });
      await generator.createIcons();
      final og = decodeImage(
        await File(path.join(prefixPath, 'web', 'opengraph.png')).readAsBytes(),
      )!;
      expect(og.width, equals(1200));
      expect(og.height, equals(630));
      final twitter = decodeImage(
        await File(path.join(prefixPath, 'web', 'twitter.png')).readAsBytes(),
      )!;
      expect(twitter.width, equals(1200));
      expect(twitter.height, equals(600));
      final index = await File(path.join(prefixPath, 'web', 'index.html')).readAsString();
      expect(index, contains('<meta property="og:image" content="opengraph.png"/>'));
      expect(index, contains('<meta name="twitter:image" content="twitter.png"/>'));
    });

    test('generates shortcut icons and manifest shortcuts', () async {
      final generator = generatorFor(<String, dynamic>{
        'generate': true,
        'image_path': 'master-light-1024.png',
        'shortcut_icons': [
          {'image_path': 'shortcut.png', 'name': 'Search', 'url': '/search'},
        ],
      });
      expect(generator.validateRequirements(), isTrue);
      await generator.createIcons();
      final shortcut = decodeImage(
        await File(path.join(prefixPath, 'web', 'icons', 'shortcut-0-96.png')).readAsBytes(),
      )!;
      expect(shortcut.width, equals(96));
      final manifest = jsonDecode(
        await File(path.join(prefixPath, 'web', 'manifest.json')).readAsString(),
      ) as Map<String, dynamic>;
      final shortcuts = (manifest['shortcuts'] as List).cast<Map<String, dynamic>>();
      expect(shortcuts, hasLength(1));
      expect(shortcuts.first['name'], equals('Search'));
      expect(shortcuts.first['url'], equals('/search'));
    });

    test('theme colors move to index with media queries, manifest drops theme', () async {
      final generator = generatorFor(<String, dynamic>{
        'generate': true,
        'image_path': 'master-light-1024.png',
        'background_color': '#0175C2',
        'theme_color_light': '#0175C2',
        'theme_color_dark': '#000000',
      });
      await generator.createIcons();
      final manifest = jsonDecode(
        await File(path.join(prefixPath, 'web', 'manifest.json')).readAsString(),
      ) as Map<String, dynamic>;
      expect(manifest['background_color'], equals('#0175C2'));
      expect(manifest.containsKey('theme_color'), isFalse);
      final index = await File(path.join(prefixPath, 'web', 'index.html')).readAsString();
      expect(index, contains('<style>html, body { background-color: #0175C2; }</style>'));
      expect(
        index,
        contains(
          '<meta name="theme-color" media="(prefers-color-scheme: light)" content="#0175C2"/>',
        ),
      );
      expect(
        index,
        contains(
          '<meta name="theme-color" media="(prefers-color-scheme: dark)" content="#000000"/>',
        ),
      );
    });

    test('rejects missing optional sources', () {
      expect(
        generatorFor(<String, dynamic>{
          'generate': true,
          'image_path': 'master-light-1024.png',
          'image_path_pwa': 'does-not-exist.png',
        }).validateRequirements(),
        isFalse,
      );
      expect(
        generatorFor(<String, dynamic>{
          'generate': true,
          'image_path': 'master-light-1024.png',
          'shortcut_icons': [
            {'image_path': 'does-not-exist.png', 'name': 'X'},
          ],
        }).validateRequirements(),
        isFalse,
      );
    });
  });
}
