import 'dart:io';

import 'package:launcher_icons/src/config/config.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import './templates.dart' as templates;

/// Parses the `launcher_icons:` section of a config-file template string,
/// mirroring what the file loaders extracted before their removal.
Config parseTemplateSection(String template) => Config.fromJson(
      loadYaml(template)['launcher_icons'] as Map<dynamic, dynamic>,
    );

void main() {
  group('Config', () {
    group('Config file parsing', () {
      test('should return valid configs', () {
        final configs = parseTemplateSection(templates.liConfigTemplate);
        expect(configs, isNotNull);
        // android configs
        expect(configs.hasAndroidConfig, isTrue);
        expect(configs.isNeedingNewAndroidIcon, isTrue);
        expect(configs.isCustomAndroidFile, isFalse);
        expect(configs.imagePath, isNotNull);
        expect(
          configs.getImagePathAndroid(),
          equals('assets/images/icon-710x599-android.png'),
        );
        expect(configs.androidConfig!.adaptiveIconBackground, isNotNull);
        expect(configs.androidConfig!.adaptiveIconForeground, isNotNull);
        expect(
          configs.androidConfig!.toJson(),
          equals(<String, dynamic>{
            'generate': true,
            'image_path': 'assets/images/icon-710x599-android.png',
            'icon_name': null,
            'adaptive_icon_foreground': 'assets/images/icon-foreground-432x432.png',
            'adaptive_icon_foreground_inset': 16,
            'adaptive_icon_background': 'assets/images/christmas-adaptive-bg-1024.png',
            'adaptive_icon_monochrome': 'assets/images/icon-monochrome-432x432.png',
            'adaptive_icon_round': null,
            'play_store_icon': false,
          }),
        );
        // ios configs
        expect(configs.hasIOSConfig, isTrue);
        expect(configs.isNeedingNewIOSIcon, isTrue);
        expect(
          configs.getImagePathIOS(),
          equals('assets/images/icon-1024x1024.png'),
        );
        expect(configs.iosConfig!.removeAlpha, isFalse);
        expect(
          configs.iosConfig!.toJson(),
          equals(<String, dynamic>{
            'generate': true,
            'single_size': false,
            'image_path': 'assets/images/icon-1024x1024.png',
            'icon_name': null,
            'xcodeproj_path': null,
            'flavor_mode': 'pbxproj',
            'image_path_dark_transparent': null,
            'image_path_tinted_grayscale': null,
            'liquid_glass_layers': null,
            'liquid_glass_lighting': null,
            'liquid_glass_refractivity_enabled': null,
            'liquid_glass_refractivity_depth': null,
            'liquid_glass_refractivity_strength': null,
            'liquid_glass_specular_highlight_placement': null,
            'remove_alpha': false,
            'remove_liquid_glass': false,
            'desaturate_tinted_to_grayscale': false,
            'background_color': '#ffffff',
            'liquid_glass_translucency': 0.5,
            'liquid_glass_specular': true,
            'liquid_glass_shadow_kind': 'Neutral',
            'liquid_glass_shadow_opacity': 0.5,
            'liquid_glass_blur': 0.5,
          }),
        );
        // web configs
        expect(configs.webConfig, isNotNull);
        expect(configs.webConfig!.generate, isTrue);
        expect(configs.webConfig!.backgroundColor, isNotNull);
        expect(configs.webConfig!.imagePath, isNotNull);
        expect(configs.webConfig!.themeColor, isNotNull);
        expect(
          configs.webConfig!.toJson(),
          equals(<String, dynamic>{
            'generate': true,
            'image_path': 'master-light-1024.png',
            'image_path_favicon': null,
            'image_path_maskable': null,
            'favicon_size': 16,
            'favicon_ico': true,
            'output_path': 'web',
            'background_color': '#0175C2',
            'theme_color': '#0175C2',
          }),
        );
        // windows
        expect(configs.windowsConfig, isNotNull);
        expect(configs.windowsConfig!.generate, isNotNull);
        expect(configs.windowsConfig!.imagePath, isNotNull);
        expect(
          configs.windowsConfig!.toJson(),
          equals(<String, dynamic>{
            'generate': true,
            'image_path': 'master-light-1024.png',
            'icon_filename': 'app_icon.ico',
          }),
        );
        // macos
        expect(configs.macOSConfig, isNotNull);
        expect(configs.macOSConfig!.generate, isNotNull);
        expect(configs.macOSConfig!.imagePath, isNotNull);
        expect(
          configs.macOSConfig!.toJson(),
          equals(<String, dynamic>{
            'generate': true,
            'image_path': 'master-light-1024.png',
            'padding': 0,
            'rounded_corners': false,
            'liquid_glass_layers': null,
            'remove_liquid_glass': false,
            'background_color': '#ffffff',
            'liquid_glass_translucency': 0.5,
            'liquid_glass_specular': true,
            'liquid_glass_shadow_kind': 'Neutral',
            'liquid_glass_shadow_opacity': 0.5,
            'liquid_glass_blur': 0.5,
            'liquid_glass_lighting': null,
            'liquid_glass_refractivity_enabled': null,
            'liquid_glass_refractivity_depth': null,
            'liquid_glass_refractivity_strength': null,
            'liquid_glass_specular_highlight_placement': null,
          }),
        );
        // linux
        expect(configs.hasLinuxConfig, isTrue);
        expect(configs.linuxConfig, isNotNull);
        expect(configs.linuxConfig!.generate, isNotNull);
        expect(configs.linuxConfig!.imagePath, isNotNull);
        expect(
          configs.linuxConfig!.toJson(),
          equals(<String, dynamic>{
            'generate': true,
            'image_path': 'master-light-1024.png',
          }),
        );
      });
    });
    group('#loadConfigFromTestPubSpec', () {
      test('should return valid configs', () {
        const String pubspecPath = 'test/config/test_pubspec.yaml';
        final configs = parseTemplateSection(
          File(pubspecPath).readAsStringSync(),
        );
        const String imagePath = 'assets/images/icon-710x599.png';
        expect(configs.imagePath, equals(imagePath));
        // android configs
        expect(configs.hasAndroidConfig, isTrue);
        expect(configs.isNeedingNewAndroidIcon, isTrue);
        expect(configs.androidConfig!.imagePath, isNull);
        expect(configs.getImagePathAndroid(), equals(imagePath));
        expect(configs.androidConfig!.adaptiveIconBackground, isNull);
        expect(configs.androidConfig!.adaptiveIconForeground, isNull);
        // ios configs
        expect(configs.hasIOSConfig, isTrue);
        expect(configs.isNeedingNewIOSIcon, isTrue);
        expect(configs.iosConfig!.imagePath, isNull);
        expect(configs.getImagePathIOS(), equals(imagePath));
        expect(configs.iosConfig!.removeAlpha, isFalse);
        // web configs
        expect(configs.webConfig, isNull);
        // windows
        expect(configs.windowsConfig, isNull);
        // macos
        expect(configs.macOSConfig, isNull);
        // linux
        expect(configs.hasLinuxConfig, isFalse);
        expect(configs.linuxConfig, isNull);
      });
    });
    group('#loadConfigFromPubSpec', () {
      test('should return valid configs', () {
        final configs = parseTemplateSection(templates.pubspecTemplate);
        expect(configs, isNotNull);
        // android configs
        expect(configs.hasAndroidConfig, isTrue);
        expect(configs.isNeedingNewAndroidIcon, isTrue);
        expect(configs.isCustomAndroidFile, isFalse);
        expect(configs.imagePath, isNotNull);
        expect(
          configs.getImagePathAndroid(),
          equals('assets/images/icon-710x599-android.png'),
        );
        expect(configs.androidConfig!.adaptiveIconBackground, isNotNull);
        expect(configs.androidConfig!.adaptiveIconForeground, isNotNull);
        expect(
          configs.androidConfig!.toJson(),
          equals(<String, dynamic>{
            'generate': true,
            'image_path': 'assets/images/icon-710x599-android.png',
            'icon_name': null,
            'adaptive_icon_foreground': 'assets/images/icon-foreground-432x432.png',
            'adaptive_icon_foreground_inset': 16,
            'adaptive_icon_background': 'assets/images/christmas-adaptive-bg-1024.png',
            'adaptive_icon_monochrome': 'assets/images/icon-monochrome-432x432.png',
            'adaptive_icon_round': null,
            'play_store_icon': false,
          }),
        );
        // ios configs
        expect(configs.hasIOSConfig, isTrue);
        expect(configs.isNeedingNewIOSIcon, isTrue);
        expect(
          configs.getImagePathIOS(),
          equals('assets/images/icon-1024x1024.png'),
        );
        expect(configs.iosConfig!.removeAlpha, isFalse);
        expect(
          configs.iosConfig!.toJson(),
          equals(<String, dynamic>{
            'generate': true,
            'single_size': false,
            'image_path': 'assets/images/icon-1024x1024.png',
            'icon_name': null,
            'xcodeproj_path': null,
            'flavor_mode': 'pbxproj',
            'image_path_dark_transparent': null,
            'image_path_tinted_grayscale': null,
            'liquid_glass_layers': null,
            'liquid_glass_lighting': null,
            'liquid_glass_refractivity_enabled': null,
            'liquid_glass_refractivity_depth': null,
            'liquid_glass_refractivity_strength': null,
            'liquid_glass_specular_highlight_placement': null,
            'remove_alpha': false,
            'remove_liquid_glass': false,
            'desaturate_tinted_to_grayscale': false,
            'background_color': '#ffffff',
            'liquid_glass_translucency': 0.5,
            'liquid_glass_specular': true,
            'liquid_glass_shadow_kind': 'Neutral',
            'liquid_glass_shadow_opacity': 0.5,
            'liquid_glass_blur': 0.5,
          }),
        );
        // web configs
        expect(configs.webConfig, isNotNull);
        expect(configs.webConfig!.generate, isTrue);
        expect(configs.webConfig!.backgroundColor, isNotNull);
        expect(configs.webConfig!.imagePath, isNotNull);
        expect(configs.webConfig!.themeColor, isNotNull);
        expect(
          configs.webConfig!.toJson(),
          equals(<String, dynamic>{
            'generate': true,
            'image_path': 'master-light-1024.png',
            'image_path_favicon': 'app_icon_favicon.png',
            'image_path_maskable': null,
            'favicon_size': 16,
            'favicon_ico': true,
            'output_path': 'web',
            'background_color': '#0175C2',
            'theme_color': '#0175C2',
          }),
        );
        // windows
        expect(configs.windowsConfig, isNotNull);
        expect(configs.windowsConfig!.generate, isNotNull);
        expect(configs.windowsConfig!.imagePath, isNotNull);
        expect(
          configs.windowsConfig!.toJson(),
          equals(<String, dynamic>{
            'generate': true,
            'image_path': 'master-light-1024.png',
            'icon_filename': 'app_icon.ico',
          }),
        );
        // macos
        expect(configs.macOSConfig, isNotNull);
        expect(configs.macOSConfig!.generate, isNotNull);
        expect(configs.macOSConfig!.imagePath, isNotNull);
        expect(
          configs.macOSConfig!.toJson(),
          equals(<String, dynamic>{
            'generate': true,
            'image_path': 'master-light-1024.png',
            'padding': 0,
            'rounded_corners': false,
            'liquid_glass_layers': null,
            'remove_liquid_glass': false,
            'background_color': '#ffffff',
            'liquid_glass_translucency': 0.5,
            'liquid_glass_specular': true,
            'liquid_glass_shadow_kind': 'Neutral',
            'liquid_glass_shadow_opacity': 0.5,
            'liquid_glass_blur': 0.5,
            'liquid_glass_lighting': null,
            'liquid_glass_refractivity_enabled': null,
            'liquid_glass_refractivity_depth': null,
            'liquid_glass_refractivity_strength': null,
            'liquid_glass_specular_highlight_placement': null,
          }),
        );
        // linux
        expect(configs.hasLinuxConfig, isTrue);
        expect(configs.linuxConfig, isNotNull);
        expect(configs.linuxConfig!.generate, isNotNull);
        expect(configs.linuxConfig!.imagePath, isNotNull);
        expect(
          configs.linuxConfig!.toJson(),
          equals(<String, dynamic>{
            'generate': true,
            'image_path': 'master-light-1024.png',
          }),
        );
      });
    });
    group('#loadConfigFromFlavor', () {
      test('should return valid config', () {
        final configs = parseTemplateSection(templates.flavorLIConfigTemplate);
        expect(configs.hasAndroidConfig, isTrue);
        expect(configs.isNeedingNewAndroidIcon, isTrue);
        expect(configs.imagePath, isNotNull);
        expect(configs.androidConfig!.imagePath, isNotNull);
        expect(configs.androidConfig!.adaptiveIconBackground, isNotNull);
        expect(configs.androidConfig!.adaptiveIconForeground, isNotNull);
        // ios configs
        expect(configs.hasIOSConfig, isTrue);
        expect(configs.isNeedingNewIOSIcon, isTrue);
        expect(configs.iosConfig!.imagePath, isNotNull);
        // web configs
        expect(configs.webConfig, isNotNull);
        expect(configs.webConfig!.generate, isTrue);
        expect(configs.webConfig!.backgroundColor, isNotNull);
        expect(configs.webConfig!.imagePath, isNotNull);
        expect(configs.webConfig!.themeColor, isNotNull);
        expect(
          configs.webConfig!.toJson(),
          equals(<String, dynamic>{
            'generate': true,
            'image_path': 'master-light-1024.png',
            'image_path_favicon': null,
            'image_path_maskable': null,
            'favicon_size': 16,
            'favicon_ico': true,
            'output_path': 'web',
            'background_color': '#0175C2',
            'theme_color': '#0175C2',
          }),
        );
        // windows
        expect(configs.windowsConfig, isNotNull);
        expect(configs.windowsConfig!.generate, isNotNull);
        expect(configs.windowsConfig!.imagePath, isNotNull);
        expect(
          configs.windowsConfig!.toJson(),
          equals(<String, dynamic>{
            'generate': true,
            'image_path': 'master-light-1024.png',
            'icon_filename': 'app_icon.ico',
          }),
        );
        // macos
        expect(configs.macOSConfig, isNotNull);
        expect(configs.macOSConfig!.generate, isNotNull);
        expect(configs.macOSConfig!.imagePath, isNotNull);
        expect(
          configs.macOSConfig!.toJson(),
          equals(<String, dynamic>{
            'generate': true,
            'image_path': 'master-light-1024.png',
            'padding': 0,
            'rounded_corners': false,
            'liquid_glass_layers': null,
            'remove_liquid_glass': false,
            'background_color': '#ffffff',
            'liquid_glass_translucency': 0.5,
            'liquid_glass_specular': true,
            'liquid_glass_shadow_kind': 'Neutral',
            'liquid_glass_shadow_opacity': 0.5,
            'liquid_glass_blur': 0.5,
            'liquid_glass_lighting': null,
            'liquid_glass_refractivity_enabled': null,
            'liquid_glass_refractivity_depth': null,
            'liquid_glass_refractivity_strength': null,
            'liquid_glass_specular_highlight_placement': null,
          }),
        );
        // linux
        expect(configs.hasLinuxConfig, isTrue);
        expect(configs.linuxConfig, isNotNull);
        expect(configs.linuxConfig!.generate, isNotNull);
        expect(configs.linuxConfig!.imagePath, isNotNull);
        expect(
          configs.linuxConfig!.toJson(),
          equals(<String, dynamic>{
            'generate': true,
            'image_path': 'master-light-1024.png',
          }),
        );
      });
    });

    group('#resolveImagePath', () {
      test('platform path wins over the top-level path', () {
        const config = Config(imagePath: 'global.png');
        expect(config.resolveImagePath('platform.png'), equals('platform.png'));
      });

      test('falls back to the top-level path when platform path is null', () {
        const config = Config(imagePath: 'global.png');
        expect(config.resolveImagePath(null), equals('global.png'));
      });

      test('returns null when neither path is set', () {
        const config = Config();
        expect(config.resolveImagePath(null), isNull);
      });
    });
  });
}
