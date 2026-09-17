import 'dart:io';

import 'package:launcher_icons/src/config/config.dart';
import 'package:launcher_icons/src/core/paths.dart' as paths;
import 'package:launcher_icons/src/platforms/ios/liquid_glass_icon_generator.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

// Per-appearance layer specializations: dark/tinted glass sources become
// `image-name-specializations` entries (light is the unmarked entry, and no
// base `image-name` is emitted alongside the array).
void main() {
  group('generateIconConfig specializations', () {
    Map<String, dynamic> layerFor(Map<String, dynamic> ios) {
      final config = Config.fromJson(<String, dynamic>{'ios': ios});
      final groups = generateIconConfig(config)['groups'] as List;
      return (groups.first as Map<String, dynamic>)['layers'].first as Map<String, dynamic>;
    }

    test('emits image-name-specializations for dark and tinted sources', () {
      final layer = layerFor(<String, dynamic>{
        'generate': true,
        'liquid_glass_layers': [
          {
            'image_path': 'icon.png',
            'image_path_dark': 'icon-dark.png',
            'image_path_tinted': 'icon-tinted.png',
          },
        ],
      });

      expect(layer.containsKey('image-name'), isFalse);
      expect(
        layer['image-name-specializations'],
        equals([
          {'value': 'icon.png'},
          {'appearance': 'dark', 'value': 'icon-dark.png'},
          {'appearance': 'tinted', 'value': 'icon-tinted.png'},
        ]),
      );
    });

    test('falls back to the dark/tinted app artwork sources', () {
      final layer = layerFor(<String, dynamic>{
        'generate': true,
        'liquid_glass_layers': [
          {'image_path': 'icon.png'},
        ],
        'image_path_dark_transparent': 'assets/icon-dark.png',
        'image_path_tinted_grayscale': 'assets/icon-tinted.png',
      });

      expect(
        layer['image-name-specializations'],
        equals([
          {'value': 'icon.png'},
          {'appearance': 'dark', 'value': 'icon-dark.png'},
          {'appearance': 'tinted', 'value': 'icon-tinted.png'},
        ]),
      );
    });

    test('keeps the plain image-name without variants', () {
      final layer = layerFor(<String, dynamic>{
        'generate': true,
        'liquid_glass_layers': [
          {'image_path': 'icon.png'},
        ],
      });

      expect(layer['image-name'], equals('icon.png'));
      expect(layer.containsKey('image-name-specializations'), isFalse);
    });
  });

  group('generateLiquidGlassIcon filesystem', () {
    late String originalDir;
    late String sandboxDir;

    setUp(() {
      originalDir = Directory.current.path;
      sandboxDir = path.join(
        '.dart_tool',
        'launcher_icons',
        'test',
        'ios_liquid_glass_spec',
      );
      final sandbox = Directory(sandboxDir);
      if (sandbox.existsSync()) {
        sandbox.deleteSync(recursive: true);
      }
      sandbox.createSync(recursive: true);
      for (final name in ['icon.png', 'icon-dark.png', 'icon-tinted.png']) {
        File(path.join(originalDir, 'test', 'assets', 'master-light-1024.png')).copySync(path.join(sandboxDir, name));
      }
      File(path.join(sandboxDir, 'icon.svg')).writeAsStringSync('<svg xmlns="http://www.w3.org/2000/svg"/>');
      Directory.current = sandboxDir;
    });

    tearDown(() {
      Directory.current = originalDir;
    });

    test('copies variant sources into Assets/', () async {
      final config = Config.fromJson(<String, dynamic>{
        'ios': {
          'generate': true,
          'liquid_glass_layers': [
            {
              'image_path': 'icon.png',
              'image_path_dark': 'icon-dark.png',
              'image_path_tinted': 'icon-tinted.png',
            },
          ],
        },
      });

      await generateLiquidGlassIcon(config, 'AppIcon');

      final assetsDir = Directory(paths.iosLiquidGlassAssetsPath('AppIcon'));
      for (final name in ['icon.png', 'icon-dark.png', 'icon-tinted.png']) {
        expect(File(path.join(assetsDir.path, name)).existsSync(), isTrue);
      }
    });

    test('passes SVG layers through without decoding', () async {
      final config = Config.fromJson(<String, dynamic>{
        'ios': {
          'generate': true,
          'liquid_glass_layers': [
            {'image_path': 'icon.svg'},
          ],
        },
      });

      await generateLiquidGlassIcon(config, 'AppIcon');

      expect(
        File(
          path.join(paths.iosLiquidGlassAssetsPath('AppIcon'), 'icon.svg'),
        ).existsSync(),
        isTrue,
      );
      final iconJson = generateIconConfig(config);
      final groups = iconJson['groups'] as List;
      final layer = (groups.first as Map)['layers'].first as Map;
      expect(layer['image-name'], equals('icon.svg'));
    });
  });
}
