import 'dart:convert';

import 'package:args/args.dart';
import 'package:launcher_icons/src/cli.dart' as main_dart;
import 'package:launcher_icons/src/config/config.dart';
import 'package:launcher_icons/src/core/constants.dart' as constants;
import 'package:launcher_icons/src/core/custom_exceptions.dart';
import 'package:launcher_icons/src/platforms/android/android.dart' as android;
import 'package:launcher_icons/src/platforms/ios/ios.dart' as ios;
import 'package:path/path.dart' show join;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

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

  group('config file from args', () {
    // Create mini parser with only the wanted option, mocking the real one
    final ArgParser parser = ArgParser()
      ..addOption(
        main_dart.configOption,
        abbr: 'c',
        defaultsTo: constants.defaultConfigFileName,
      )
      ..addOption(
        main_dart.prefixOption,
        abbr: 'r',
        defaultsTo: '.',
      );

    // NOTE: these tests never change the process working directory. Every
    // fixture lives in an absolute test_descriptor sandbox passed via `-p`.
    Future<String> createCase(
      String name,
      List<d.Descriptor> contents,
    ) async {
      await d.dir(name, contents).create();
      return join(d.sandbox, name);
    }

    test('default', () async {
      final dir = await createCase('default', [
        d.file('launcher_icons.yaml', '''
launcher_icons:
  android:
    generate: true
  ios:
    generate: false
'''),
      ]);
      final ArgResults argResults = parser.parse(<String>['-r', dir]);
      final Config? config = main_dart.loadConfigFileFromArgResults(argResults);
      expect(config, isNotNull);
      expect(config!.androidConfig!.generate, isTrue);
    });
    test('default_use_pubspec', () async {
      final dir = await createCase('pubspec_only', [
        d.file('pubspec.yaml', '''
launcher_icons:
  android:
    generate: true
  ios:
    generate: false
'''),
      ]);
      ArgResults argResults = parser.parse(<String>['-r', dir]);
      final Config? config = main_dart.loadConfigFileFromArgResults(argResults);
      expect(config, isNotNull);
      expect(config!.iosConfig!.generate, isFalse);

      // read pubspec if provided file is not found
      argResults = parser.parse(<String>['-c', constants.defaultConfigFileName, '-r', dir]);
      expect(main_dart.loadConfigFileFromArgResults(argResults), isNotNull);
    });

    group('stale template shadowing (fluttercommunity/flutter_launcher_icons#628)', () {
      Future<String> writeStaleYamlAndRealPubspec(String name) async {
        return createCase(name, [
          d.file('launcher_icons.yaml', '''
launcher_icons:
  image_path: "assets/icon/icon.png"
  android:
    generate: true
'''),
          d.file('pubspec.yaml', '''
launcher_icons:
  image_path: "real.png"
  android:
    generate: true
'''),
          d.file('real.png', 'png-bytes'),
        ]);
      }

      test('prefers pubspec when default file is a stale template', () async {
        final dir = await writeStaleYamlAndRealPubspec('stale_template');
        final ArgResults argResults = parser.parse(<String>['-r', dir]);
        final Config? config = main_dart.loadConfigFileFromArgResults(argResults);
        expect(config, isNotNull);
        expect(config!.imagePath, equals('real.png'));
      });

      test('explicit -c still honors the given file', () async {
        final dir = await writeStaleYamlAndRealPubspec('stale_template_explicit');
        final ArgResults argResults = parser.parse(
          <String>['-c', 'launcher_icons.yaml', '-r', dir],
        );
        final Config? config = main_dart.loadConfigFileFromArgResults(
          argResults,
          explicitFile: true,
        );
        expect(config, isNotNull);
        expect(config!.imagePath, equals('assets/icon/icon.png'));
      });

      test('prefers the file when its images exist', () async {
        final dir = await createCase('both_real', [
          d.file('launcher_icons.yaml', '''
launcher_icons:
  image_path: "yaml.png"
  android:
    generate: true
'''),
          d.file('pubspec.yaml', '''
launcher_icons:
  image_path: "real.png"
  android:
    generate: true
'''),
          d.file('yaml.png', 'png-bytes'),
          d.file('real.png', 'png-bytes'),
        ]);
        final ArgResults argResults = parser.parse(<String>['-r', dir]);
        final Config? config = main_dart.loadConfigFileFromArgResults(argResults);
        expect(config, isNotNull);
        expect(config!.imagePath, equals('yaml.png'));
      });
    });

    test('custom', () async {
      final dir = await createCase('custom', [
        d.file('custom.yaml', '''
launcher_icons:
  android:
    generate: true
  ios:
    generate: true
'''),
      ]);
      // if no argument set, should fail
      ArgResults argResults = parser.parse(<String>['-c', 'custom.yaml', '-r', dir]);
      final Config? config = main_dart.loadConfigFileFromArgResults(argResults);
      expect(config, isNotNull);
      expect(config!.iosConfig!.generate, isTrue);

      // should fail if no argument
      argResults = parser.parse(<String>['-r', dir]);
      expect(main_dart.loadConfigFileFromArgResults(argResults), isNull);

      // or missing file
      argResults = parser.parse(<String>['-c', 'missing_custom.yaml', '-r', dir]);
      expect(main_dart.loadConfigFileFromArgResults(argResults), isNull);
    });

    group('config folder mode (-c folder)', () {
      test('loads launcher_icons.yaml from the folder', () async {
        final dir = await createCase('folder_yaml', [
          d.dir('config', [
            d.file('launcher_icons.yaml', '''
launcher_icons:
  image_path: "folder.png"
  android:
    generate: true
'''),
          ]),
        ]);
        final ArgResults argResults = parser.parse(<String>['-c', 'config', '-r', dir]);
        final Config? config = main_dart.loadConfigFileFromArgResults(argResults);
        expect(config, isNotNull);
        expect(config!.imagePath, equals('folder.png'));
      });

      test('falls back to the project-root pubspec.yaml', () async {
        final dir = await createCase('folder_pubspec', [
          d.dir('config', [
            d.file('other.yaml', 'launcher_icons:\n'),
          ]),
          d.file('pubspec.yaml', '''
launcher_icons:
  image_path: "root-pubspec.png"
  android:
    generate: true
'''),
        ]);
        final ArgResults argResults = parser.parse(<String>['-c', 'config', '-r', dir]);
        final Config? config = main_dart.loadConfigFileFromArgResults(argResults);
        expect(config, isNotNull);
        expect(config!.imagePath, equals('root-pubspec.png'));
      });

      test('returns null when neither folder nor root has a config', () async {
        final dir = await createCase('folder_empty', [
          d.dir('config', [
            d.file('other.yaml', 'launcher_icons:\n'),
          ]),
          d.file('pubspec.yaml', '''
name: test_app
'''),
        ]);
        final ArgResults argResults = parser.parse(<String>['-c', 'config', '-r', dir]);
        expect(main_dart.loadConfigFileFromArgResults(argResults), isNull);
      });
    });
  });

  group('explicit flavor from args', () {
    final ArgParser parser = ArgParser()
      ..addOption(
        main_dart.configOption,
        abbr: 'c',
        defaultsTo: constants.defaultConfigFileName,
      );

    test('returns null when -c is not given', () {
      expect(
        main_dart.explicitFlavorFromArgs(parser.parse(<String>[])),
        isNull,
      );
    });

    test('returns null when -c names the default config file', () {
      expect(
        main_dart.explicitFlavorFromArgs(
          parser.parse(<String>['-c', constants.defaultConfigFileName]),
        ),
        isNull,
      );
    });

    test('returns null when -c names a non-flavor file', () {
      expect(
        main_dart.explicitFlavorFromArgs(
          parser.parse(<String>['-c', 'custom.yaml']),
        ),
        isNull,
      );
    });

    test('returns the flavor when -c names a flavor file', () {
      expect(
        main_dart.explicitFlavorFromArgs(
          parser.parse(<String>['-c', 'launcher_icons-staging.yaml']),
        ),
        equals('staging'),
      );
    });

    test('matches flavor files in subdirectories by basename', () {
      expect(
        main_dart.explicitFlavorFromArgs(
          parser.parse(<String>['-c', 'config/launcher_icons-prod.yaml']),
        ),
        equals('prod'),
      );
    });
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
    test('legacy boolean android/ios values throw a migration error', () {
      expect(
        () => Config.fromJson(<String, dynamic>{
          'image_path': 'assets/images/icon-710x599.png',
          'android': true,
          'ios': true,
        }),
        throwsA(isA<InvalidConfigException>()),
      );
    });

    test('legacy string android/ios values throw a migration error', () {
      expect(
        () => Config.fromJson(<String, dynamic>{
          'image_path': 'assets/images/icon-710x599.png',
          'android': 'launcher_icon',
          'ios': 'MyIcon',
        }),
        throwsA(isA<InvalidConfigException>()),
      );
    });

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
