import 'dart:convert';

import 'package:launcher_icons/src/cli.dart' as main_dart;
import 'package:launcher_icons/src/config/config.dart';
import 'package:launcher_icons/src/platforms/android/android.dart' as android;
import 'package:launcher_icons/src/platforms/ios/ios.dart' as ios;
import 'package:test/test.dart';

// Unit tests for main.dart
void main() {
  test('iOS single-size list contains one 1024 entry (fluttercommunity/flutter_launcher_icons#592)', () {
    final list = ios.createSingleSizeImageList('AppIcon');
    expect(list.length, equals(1));
    expect(list.single['size'], equals('1024x1024'));
    expect(list.single['filename'], equals('AppIcon-1024x1024@1x.png'));
  });

  test('generateContentsFileAsString honors single-size (fluttercommunity/flutter_launcher_icons#592)', () {
    final decoded = jsonDecode(
      ios.generateContentsFileAsString('AppIcon', 'AppIcon-Dark', null, true),
    ) as Map<String, dynamic>;
    expect((decoded['images'] as List).length, equals(1));
  });

  test('iOS icon list is correct size', () {
    expect(ios.iosIcons.length, 20);
  });

  test('iOS icon list includes 1x switcher sizes (fluttercommunity/flutter_launcher_icons#661)', () {
    for (final name in ['-20x20@1x', '-29x29@1x', '-40x40@1x', '-76x76@1x']) {
      expect(
        ios.iosIcons.map((template) => template.name),
        contains(name),
      );
    }
    // Both the base and the dark-appearance entries must exist in Contents.
    final contents = ios.createImageList('AppIcon', 'AppIcon-Dark', null);
    for (final size in ['20x20', '29x29', '40x40', '76x76']) {
      final matches = contents.where((entry) => entry['size'] == size && entry['scale'] == '1x').toList();
      expect(matches.length, equals(2), reason: size);
    }
  });

  test('Android icon list is correct size', () {
    expect(android.androidIcons.length, 5);
  });

  test('iOS image list used to generate Contents.json for icon directory is correct size (no dark or tinted icons)', () {
    expect(ios.createImageList('blah', null, null).length, 20 + 1);
  });

  test('iOS image list used to generate Contents.json for icon directory is correct size (with dark icon)', () {
    expect(
      ios.createImageList('blah', 'dark-blah', null).length,
      20 * 2 + 1,
    ); // 20 normal, 20 dark icons + 1 marketing icon
  });

  test('iOS image list used to generate Contents.json for icon directory is correct size (with tinted icon)', () {
    expect(
      ios.createImageList('blah', null, 'tinted-blah').length,
      20 * 2 + 1,
    ); // 20 normal, 20 tinted icons + 1 marketing icon
  });

  test('iOS image list used to generate Contents.json for icon directory is correct size (with dark and tinted icon)', () {
    expect(
      ios.createImageList('blah', 'dark-blah', 'tinted-blah').length,
      20 * 3 + 1,
    ); // 20 normal, 20 dark, 20 tinted icons + 1 marketing icon
  });

  group('isConfigOptionExplicit', () {
    test('is false when -c is absent', () {
      expect(main_dart.isConfigOptionExplicit([]), isFalse);
      expect(main_dart.isConfigOptionExplicit(['-v']), isFalse);
    });

    test('detects -c, --config and --config= forms', () {
      expect(main_dart.isConfigOptionExplicit(['-c', 'x.yaml']), isTrue);
      expect(main_dart.isConfigOptionExplicit(['--config', 'x.yaml']), isTrue);
      expect(main_dart.isConfigOptionExplicit(['--config=x.yaml']), isTrue);
    });
  });

  test('image_path is in config', () {
    final Map<String, dynamic> flutterIconsConfig = <String, dynamic>{
      'image_path': 'assets/images/icon-710x599.png',
      'android': {'generate': true},
      'ios': {'generate': true},
    };
    final config = Config.fromJson(flutterIconsConfig);
    expect(
      config.getImagePathAndroid(),
      equals('assets/images/icon-710x599.png'),
    );
    expect(config.getImagePathIOS(), equals('assets/images/icon-710x599.png'));
    final Map<String, dynamic> flutterIconsConfigAndroid = <String, dynamic>{
      'android': {
        'generate': true,
        'image_path': 'assets/images/icon-710x599.png',
      },
      'ios': {'generate': true},
    };
    final configAndroid = Config.fromJson(flutterIconsConfigAndroid);
    expect(
      configAndroid.getImagePathAndroid(),
      equals('assets/images/icon-710x599.png'),
    );
    expect(configAndroid.getImagePathIOS(), isNull);
    final Map<String, dynamic> flutterIconsConfigBoth = <String, dynamic>{
      'android': {
        'generate': true,
        'image_path': 'assets/images/icon-android.png',
      },
      'ios': {
        'generate': true,
        'image_path': 'assets/images/icon-ios.png',
      },
    };
    final configBoth = Config.fromJson(flutterIconsConfigBoth);
    expect(
      configBoth.getImagePathAndroid(),
      equals('assets/images/icon-android.png'),
    );
    expect(configBoth.getImagePathIOS(), equals('assets/images/icon-ios.png'));
  });

  test('At least one platform is in config file', () {
    final Map<String, dynamic> flutterIconsConfig = <String, dynamic>{
      'image_path': 'assets/images/icon-710x599.png',
      'android': {'generate': true},
      'ios': {'generate': true},
    };
    final config = Config.fromJson(flutterIconsConfig);
    expect(config.hasEnabledPlatform, isTrue);
  });

  test('No platform specified in config', () {
    final Map<String, dynamic> flutterIconsConfig = <String, dynamic>{
      'image_path': 'assets/images/icon-710x599.png',
    };
    final config = Config.fromJson(flutterIconsConfig);
    expect(config.hasEnabledPlatform, isFalse);
  });

  test('At least one platform enabled in config file', () {
    final Map<String, dynamic> flutterIconsConfig = <String, dynamic>{
      'image_path': 'assets/images/icon-710x599.png',
      'android': {'generate': false},
      'ios': {'generate': true},
    };
    final config = Config.fromJson(flutterIconsConfig);
    expect(config.hasEnabledPlatform, isTrue);
  });

  test('No platform enabled when all generate flags are false', () {
    final Map<String, dynamic> flutterIconsConfig = <String, dynamic>{
      'image_path': 'assets/images/icon-710x599.png',
      'android': {'generate': false},
      'ios': {'generate': false},
      'web': {'generate': false},
      'windows': {'generate': false},
      'macos': {'generate': false},
      'linux': {'generate': false},
    };
    final config = Config.fromJson(flutterIconsConfig);
    // Sections are present but nothing is enabled: presence is not intent.
    expect(config.hasEnabledPlatform, isFalse);
  });

  test('No platform enabled when no sections exist', () {
    final Map<String, dynamic> flutterIconsConfig = <String, dynamic>{
      'image_path': 'assets/images/icon-710x599.png',
    };
    final config = Config.fromJson(flutterIconsConfig);
    expect(config.hasEnabledPlatform, isFalse);
  });

  test('No new Android icon needed - android.generate: false', () {
    final Map<String, dynamic> flutterIconsConfig = <String, dynamic>{
      'image_path': 'assets/images/icon-710x599.png',
      'android': {'generate': false},
      'ios': {'generate': true},
    };
    final config = Config.fromJson(flutterIconsConfig);
    expect(config.isNeedingNewAndroidIcon, isFalse);
  });

  test('No new Android icon needed - no Android config', () {
    final Map<String, dynamic> flutterIconsConfig = <String, dynamic>{
      'image_path': 'assets/images/icon-710x599.png',
      'ios': {'generate': true},
    };
    final config = Config.fromJson(flutterIconsConfig);
    expect(config.isNeedingNewAndroidIcon, isFalse);
  });

  test('No new iOS icon needed - ios.generate: false', () {
    final Map<String, dynamic> flutterIconsConfig = <String, dynamic>{
      'image_path': 'assets/images/icon-710x599.png',
      'android': {'generate': true},
      'ios': {'generate': false},
    };
    final config = Config.fromJson(flutterIconsConfig);
    expect(config.isNeedingNewIOSIcon, isFalse);
  });

  test('No new iOS icon needed - no iOS config', () {
    final Map<String, dynamic> flutterIconsConfig = <String, dynamic>{
      'image_path': 'assets/images/icon-710x599.png',
      'android': {'generate': true},
    };
    final config = Config.fromJson(flutterIconsConfig);
    expect(config.isNeedingNewIOSIcon, isFalse);
  });

  group('v3 schema migration guard', () {
    test('nested android/ios maps parse without migration error', () {
      final config = Config.fromJson(<String, dynamic>{
        'image_path': 'assets/images/icon-710x599.png',
        'android': {'generate': true},
        'ios': {'generate': true},
      });
      expect(config.isNeedingNewAndroidIcon, isTrue);
      expect(config.isNeedingNewIOSIcon, isTrue);
    });
  });
}
