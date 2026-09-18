import 'dart:convert';
import 'dart:io';

import 'package:launcher_icons/src/config/config.dart';
import 'package:launcher_icons/src/core/custom_exceptions.dart';
import 'package:launcher_icons/src/core/paths.dart' as paths;
import 'package:launcher_icons/src/platforms/ios/liquid_glass_icon_generator.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

// Unit tests for the liquid glass icon generator (lib/src/platforms/ios).
void main() {
  group('liquid glass layers presence', () {
    test('layers present when ios.liquid_glass_layers is non-empty', () {
      final config = Config.fromJson(<String, dynamic>{
        'ios': {
          'generate': true,
          'liquid_glass_layers': [
            {'image_path': 'assets/icon.png'},
          ],
        },
      });
      expect(config.iosConfig!.liquidGlassLayers, hasLength(1));
    });

    test('layers null when ios.liquid_glass_layers is not set', () {
      final config = Config.fromJson(<String, dynamic>{});
      expect(config.iosConfig?.liquidGlassLayers, isNull);
    });

    test('layers empty when ios.liquid_glass_layers is empty', () {
      final config = Config.fromJson(<String, dynamic>{
        'ios': {
          'generate': true,
          'liquid_glass_layers': <dynamic>[],
        },
      });
      expect(config.iosConfig!.liquidGlassLayers, isEmpty);
    });
  });

  group('Config liquid glass fields', () {
    test('liquid glass config fields are parsed', () {
      final config = Config.fromJson(<String, dynamic>{
        'ios': {
          'generate': true,
          'liquid_glass_layers': [
            {
              'image_path': 'assets/icon.png',
              'image_path_dark': 'assets/icon-dark.png',
              'image_path_tinted': 'assets/icon-tinted.png',
              'scale': 0.85,
              'offset_x': 0.1,
              'offset_y': -0.2,
              'glass': false,
              'opacity': 0.8,
              'blend_mode': 'multiply',
              'fill': '#FF0000',
              'fill_dark': '#00FF00',
              'fill_tinted': '#0000FF',
            },
          ],
          'remove_liquid_glass': true,
          'liquid_glass_translucency': 0.3,
          'liquid_glass_specular': false,
          'liquid_glass_shadow_kind': 'Chromatic',
          'liquid_glass_shadow_opacity': 0.7,
          'liquid_glass_blur': 0.4,
        },
      });
      final iosConfig = config.iosConfig!;
      final layer = iosConfig.liquidGlassLayers!.single;
      expect(layer.imagePath, 'assets/icon.png');
      expect(layer.imagePathDark, 'assets/icon-dark.png');
      expect(layer.imagePathTinted, 'assets/icon-tinted.png');
      expect(layer.scale, 0.85);
      expect(layer.offsetX, 0.1);
      expect(layer.offsetY, -0.2);
      expect(layer.glass, isFalse);
      expect(layer.opacity, 0.8);
      expect(layer.blendMode, 'multiply');
      expect(layer.fill, '#FF0000');
      expect(layer.fillDark, '#00FF00');
      expect(layer.fillTinted, '#0000FF');
      expect(iosConfig.removeLiquidGlass, isTrue);
      expect(iosConfig.liquidGlassTranslucency, 0.3);
      expect(iosConfig.liquidGlassSpecular, isFalse);
      expect(iosConfig.liquidGlassShadowKind, 'Chromatic');
      expect(iosConfig.liquidGlassShadowOpacity, 0.7);
      expect(iosConfig.liquidGlassBlur, 0.4);
    });

    test('liquid glass config fields have default values', () {
      final config = Config.fromJson(<String, dynamic>{
        'ios': {
          'generate': true,
          'liquid_glass_layers': [
            {'image_path': 'assets/icon.png'},
          ],
        },
      });
      final iosConfig = config.iosConfig!;
      final layer = iosConfig.liquidGlassLayers!.single;
      expect(layer.imagePathDark, isNull);
      expect(layer.imagePathTinted, isNull);
      expect(layer.scale, 1.0);
      expect(layer.offsetX, 0.0);
      expect(layer.offsetY, 0.0);
      expect(layer.glass, isTrue);
      expect(layer.opacity, isNull);
      expect(layer.blendMode, isNull);
      expect(layer.fill, isNull);
      expect(layer.fillDark, isNull);
      expect(layer.fillTinted, isNull);
      expect(iosConfig.removeLiquidGlass, isFalse);
      expect(iosConfig.liquidGlassTranslucency, 0.5);
      expect(iosConfig.liquidGlassSpecular, isTrue);
      expect(iosConfig.liquidGlassShadowKind, 'Neutral');
      expect(iosConfig.liquidGlassShadowOpacity, 0.5);
      expect(iosConfig.liquidGlassBlur, 0.5);
    });
  });

  group('convertHexToDisplayP3', () {
    test('converts hex colors to display-p3 format', () {
      expect(
        convertHexToDisplayP3('#FF0000'),
        'display-p3:1.00000,0.00000,0.00000,1.00000',
      );
      expect(
        convertHexToDisplayP3('#ffffff'),
        'display-p3:1.00000,1.00000,1.00000,1.00000',
      );
      expect(
        convertHexToDisplayP3('#000000'),
        'display-p3:0.00000,0.00000,0.00000,1.00000',
      );
      expect(
        convertHexToDisplayP3('#123456'),
        'display-p3:0.07059,0.20392,0.33725,1.00000',
      );
      expect(
        convertHexToDisplayP3('FF0000'),
        'display-p3:1.00000,0.00000,0.00000,1.00000',
      );
    });

    test('throws InvalidConfigException when hex is not 6 characters', () {
      expect(
        () => convertHexToDisplayP3('#FF00'),
        throwsA(isA<InvalidConfigException>()),
      );
      expect(
        () => convertHexToDisplayP3('#GGGGGG'),
        throwsA(isA<InvalidConfigException>()),
      );
    });
  });

  group('generateIconConfig', () {
    test('generates the expected icon.json structure', () {
      final config = Config.fromJson(<String, dynamic>{
        'ios': {
          'generate': true,
          'liquid_glass_layers': [
            {
              'image_path': 'assets/liquid_glass_icon.png',
              'scale': 0.85,
              'offset_x': 0.1,
              'offset_y': -0.2,
            },
          ],
          'liquid_glass_translucency': 0.3,
          'liquid_glass_specular': true,
          'liquid_glass_shadow_kind': 'Neutral',
          'liquid_glass_shadow_opacity': 0.7,
          'liquid_glass_blur': 0.4,
        },
      });
      expect(
        generateIconConfig(config),
        equals(<String, dynamic>{
          'fill': <String, dynamic>{
            'solid': 'display-p3:1.00000,1.00000,1.00000,1.00000',
          },
          'groups': [
            <String, dynamic>{
              'blur-material': 0.4,
              'layers': [
                <String, dynamic>{
                  'glass': true,
                  'hidden': false,
                  'image-name': 'liquid_glass_icon.png',
                  'name': 'liquid_glass_icon',
                  'position': <String, dynamic>{
                    'scale': 0.85,
                    'translation-in-points': <double>[0.1, -0.2],
                  },
                },
              ],
              'shadow': <String, dynamic>{
                'kind': 'neutral',
                'opacity': 0.7,
              },
              'specular': true,
              'translucency': <String, dynamic>{
                'enabled': true,
                'value': 0.3,
              },
            },
          ],
          'supported-platforms': <String, dynamic>{
            'circles': <String>['watchOS'],
            'squares': 'shared',
          },
        }),
      );
    });

    test('maps chromatic shadow kind to layer-color', () {
      final config = Config.fromJson(<String, dynamic>{
        'ios': {
          'generate': true,
          'liquid_glass_layers': [
            {'image_path': 'assets/icon.png'},
          ],
          'liquid_glass_shadow_kind': 'Chromatic',
        },
      });
      final groups = generateIconConfig(config)['groups'] as List;
      final shadow = (groups.first as Map<String, dynamic>)['shadow'] as Map<String, dynamic>;
      expect(shadow['kind'], 'layer-color');
    });

    test('disables glass and translucency when remove_liquid_glass is true', () {
      final config = Config.fromJson(<String, dynamic>{
        'ios': {
          'generate': true,
          'liquid_glass_layers': [
            {'image_path': 'assets/icon.png'},
          ],
          'remove_liquid_glass': true,
        },
      });
      final groups = generateIconConfig(config)['groups'] as List;
      final firstGroup = groups.first as Map<String, dynamic>;
      final layer = (firstGroup['layers'] as List).first as Map<String, dynamic>;
      final translucency = firstGroup['translucency'] as Map<String, dynamic>;
      expect(layer['glass'], isFalse);
      expect(translucency['enabled'], isFalse);
    });
  });

  group('generateLiquidGlassIcon', () {
    test('throws InvalidConfigException for invalid shadow kind', () {
      final config = Config.fromJson(<String, dynamic>{
        'ios': {
          'generate': true,
          'liquid_glass_layers': [
            {'image_path': 'missing-icon.png'},
          ],
          'liquid_glass_shadow_kind': 'Invalid',
        },
      });
      expect(
        () => generateLiquidGlassIcon(config, 'AppIcon'),
        throwsA(isA<InvalidConfigException>()),
      );
    });

    test('throws InvalidConfigException when source image is missing', () {
      final config = Config.fromJson(<String, dynamic>{
        'ios': {
          'generate': true,
          'liquid_glass_layers': [
            {'image_path': 'missing-icon.png'},
          ],
        },
      });
      expect(
        () => generateLiquidGlassIcon(config, 'AppIcon'),
        throwsA(isA<InvalidConfigException>()),
      );
    });

    group('filesystem', () {
      late String originalDir;
      late String sandboxDir;

      setUp(() {
        originalDir = Directory.current.path;
        sandboxDir = path.join(
          '.dart_tool',
          'launcher_icons',
          'test',
          'ios_liquid_glass',
        );
        final sandbox = Directory(sandboxDir);
        if (sandbox.existsSync()) {
          sandbox.deleteSync(recursive: true);
        }
        sandbox.createSync(recursive: true);
        File(path.join(originalDir, 'test', 'assets', 'master-light-1024.png')).copySync(path.join(sandboxDir, 'master-light-1024.png'));
        Directory.current = sandboxDir;
      });

      tearDown(() {
        Directory.current = originalDir;
      });

      test('creates the .icon bundle structure and icon.json', () async {
        final config = Config.fromJson(<String, dynamic>{
          'ios': {
            'generate': true,
            'liquid_glass_layers': [
              {'image_path': 'master-light-1024.png'},
            ],
            'background_color': '#FF0000',
          },
        });

        await generateLiquidGlassIcon(config, 'AppIcon');

        final assetsImage = File(
          path.join(paths.iosLiquidGlassAssetsPath('AppIcon'), 'master-light-1024.png'),
        );
        expect(assetsImage.existsSync(), isTrue);

        final configFile = File(paths.iosLiquidGlassConfigPath('AppIcon'));
        expect(configFile.existsSync(), isTrue);

        final iconJson = jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
        expect(
          iconJson['fill'],
          <String, dynamic>{
            'solid': 'display-p3:1.00000,0.00000,0.00000,1.00000',
          },
        );
        expect(
          iconJson['supported-platforms'],
          <String, dynamic>{
            'circles': <String>['watchOS'],
            'squares': 'shared',
          },
        );
      });

      test('sweeps layers orphaned by source switches', () async {
        final config = Config.fromJson(<String, dynamic>{
          'ios': {
            'generate': true,
            'liquid_glass_layers': [
              {'image_path': 'master-light-1024.png'},
            ],
            'background_color': '#FF0000',
          },
        });

        await generateLiquidGlassIcon(config, 'AppIcon');

        // Simulate a PNG -> SVG source switch: the stale copy must go.
        final stale = File(
          path.join(paths.iosLiquidGlassAssetsPath('AppIcon'), 'stale-layer.png'),
        );
        await stale.writeAsBytes([1, 2, 3]);

        await generateLiquidGlassIcon(config, 'AppIcon');

        expect(stale.existsSync(), isFalse);
        expect(
          File(
            path.join(paths.iosLiquidGlassAssetsPath('AppIcon'), 'master-light-1024.png'),
          ).existsSync(),
          isTrue,
        );
      });
    });
  });
}
