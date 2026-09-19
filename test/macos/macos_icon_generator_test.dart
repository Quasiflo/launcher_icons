import 'dart:io';

import 'package:image/image.dart';
import 'package:launcher_icons/src/config/config.dart';
import 'package:launcher_icons/src/config/macos_config.dart';
import 'package:launcher_icons/src/core/custom_exceptions.dart';
import 'package:launcher_icons/src/core/icon_generator.dart';
import 'package:launcher_icons/src/core/logger.dart';
import 'package:launcher_icons/src/platforms/macos/macos_icon_generator.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:yaml/yaml.dart';

import '../templates.dart' as templates;

@GenerateNiceMocks([
  MockSpec<Config>(),
  MockSpec<MacOSConfig>(),
  MockSpec<LILogger>(),
])
import 'macos_icon_generator_test.mocks.dart';

// Parses the `launcher_icons:` section of a config-file template string, mirroring what the removed file loaders extracted.
Config parseTemplateSection(String template) => Config.fromJson(
      loadYaml(template)['launcher_icons'] as Map<dynamic, dynamic>,
    );

void main() {
  group('MacOSIconGenerator', () {
    late IconGeneratorContext context;
    late IconGenerator generator;
    late Config mockConfig;
    late MacOSConfig mockMacOSConfig;
    late String prefixPath;
    late File testImageFile;
    late MockLILogger mockLogger;
    final assetPath = path.join(Directory.current.path, 'test', 'assets');

    group('#validateRequirments', () {
      setUpAll(() {
        testImageFile = File(path.join(assetPath, 'master-light-1024.png'));
        expect(testImageFile.existsSync(), isTrue);
      });
      setUp(() {
        prefixPath = path.join(d.sandbox, 'fli_test');
        mockConfig = MockConfig();
        mockMacOSConfig = MockMacOSConfig();
        mockLogger = MockLILogger();
        context = IconGeneratorContext(
          config: mockConfig,
          prefixPath: prefixPath,
          logger: mockLogger,
        );
        generator = MacOSIconGenerator(context);

        // initilize mock defaults
        when(mockLogger.error(argThat(anything))).thenReturn(anything);
        when(mockLogger.verbose(argThat(anything))).thenReturn(anything);
        when(mockLogger.isVerbose).thenReturn(false);
        when(mockConfig.macOSConfig).thenReturn(mockMacOSConfig);
        when(mockMacOSConfig.generate).thenReturn(true);
        when(mockMacOSConfig.imagePath).thenReturn(path.join(prefixPath, 'master-light-1024.png'));
        when(mockConfig.imagePath).thenReturn(path.join(prefixPath, 'master-light-1024.png'));
        // resolveImageFile is mocked: implement the real rule (platform path wins, top-level fallback, missing file throws) so the unit tests exercise the generators, not the mock default.
        when(mockConfig.resolveImageFile(argThat(anything), prefixPath)).thenAnswer(
          (invocation) {
            final platformPath = invocation.positionalArguments.first as String?;
            final resolved = platformPath ?? mockConfig.imagePath;
            if (resolved == null || !File(path.join(prefixPath, resolved)).existsSync()) {
              throw InvalidConfigException('Missing "image_path" within configuration, or the referenced image file does not exist${resolved == null ? '' : ': "$resolved"'}');
            }
            return resolved;
          },
        );
      });

      test('macOSEnabled is false with no macos section', () {
        final realContext = IconGeneratorContext(
          config: const Config(imagePath: 'icon.png'),
          prefixPath: prefixPath,
          logger: LILogger(false),
        );

        expect(realContext.config.macOSEnabled, isFalse);
      });

      test('macOSEnabled is false when macos.generate is false', () {
        final realContext = IconGeneratorContext(
          config: const Config(
            imagePath: 'icon.png',
            macOSConfig: MacOSConfig(generate: false),
          ),
          prefixPath: prefixPath,
          logger: LILogger(false),
        );

        expect(realContext.config.macOSEnabled, isFalse);
      });

      test('should return false when macos.image_path and imagePath is null', () {
        when(mockMacOSConfig.imagePath).thenReturn(null);
        when(mockConfig.imagePath).thenReturn(null);
        expect(generator.validateRequirements(), isFalse);

        verifyInOrder([
          mockMacOSConfig.imagePath,
          mockConfig.imagePath,
        ]);
      });

      test('should return false when macos dir does not exist', () async {
        await d.dir('fli_test', [
          d.file('master-light-1024.png', testImageFile.readAsBytesSync()),
        ]).create();
        await expectLater(
          d.dir('fli_test', [
            d.file('master-light-1024.png', anything),
          ]).validate(),
          completes,
        );
        expect(generator.validateRequirements(), isFalse);
      });

      test('should return false when image file does not exist', () async {
        await d.dir('fli_test', [d.dir('macos')]).create();
        await expectLater(
          d.dir('fli_test', [d.dir('macos')]).validate(),
          completes,
        );
        expect(generator.validateRequirements(), isFalse);
      });

      test('flavor validates without a pre-existing icon set', () async {
        await d.dir('fli_test', [
          d.dir('macos/Runner/Assets.xcassets'),
          d.file('master-light-1024.png', testImageFile.readAsBytesSync()),
        ]).create();
        await expectLater(
          d.dir('fli_test', [
            d.dir('macos/Runner/Assets.xcassets'),
            d.file('master-light-1024.png', anything),
          ]).validate(),
          completes,
        );
        final flavorContext = IconGeneratorContext(
          config: mockConfig,
          prefixPath: prefixPath,
          logger: mockLogger,
          flavor: 'staging',
        );
        expect(
          MacOSIconGenerator(flavorContext).validateRequirements(),
          isTrue,
        );
      });
    });
  });

  group('MacOSIconGenerator end-to-end', () {
    late IconGeneratorContext context;
    late IconGenerator generator;
    late Config config;
    late String prefixPath;
    final assetPath = path.join(Directory.current.path, 'test', 'assets');

    setUp(() async {
      final imageFile = File(path.join(assetPath, 'master-light-1024.png'));
      expect(imageFile.existsSync(), isTrue);
      await d.dir('fli_test', [
        d.dir('macos/Runner/Assets.xcassets/AppIcon.appiconset', [
          d.file('Contents.json', templates.macOSContentsJsonFile),
        ]),
        d.file('launcher_icons.yaml', templates.liConfigTemplate),
        d.file('master-light-1024.png', imageFile.readAsBytesSync()),
      ]).create();
      prefixPath = path.join(d.sandbox, 'fli_test');
      config = parseTemplateSection(templates.liConfigTemplate);
      context = IconGeneratorContext(
        config: config,
        prefixPath: prefixPath,
        logger: LILogger(false),
      );
      generator = MacOSIconGenerator(context);
    });

    test('should generate valid icons & contents.json file', () async {
      expect(generator.validateRequirements(), isTrue);
      await generator.createIcons();

      await expectLater(
        d.dir('fli_test', [
          d.dir('macos/Runner/Assets.xcassets/AppIcon.appiconset', [
            d.file('app_icon_1024.png', anything),
            d.file('app_icon_16.png', anything),
            d.file('app_icon_32.png', anything),
            d.file('app_icon_64.png', anything),
            d.file('app_icon_128.png', anything),
            d.file('app_icon_256.png', anything),
            d.file('app_icon_512.png', anything),
          ]),
        ]).validate(),
        completes,
        reason: 'All icon files are not generated',
      );

      await expectLater(
        d.dir('fli_test', [
          d.dir('macos/Runner/Assets.xcassets/AppIcon.appiconset', [
            d.file('Contents.json', equals(templates.macOSContentsJsonFile)),
          ]),
        ]).validate(),
        completes,
        reason: 'Contents.json file contents are not equal',
      );
    });

    test('should generate flavor icons into AppIcon-<flavor>.appiconset', () async {
      final imageFile = File(path.join(assetPath, 'master-light-1024.png'));
      await d.dir('fli_test_flavor', [
        d.dir('macos/Runner/Assets.xcassets/AppIcon-staging.appiconset', [
          d.file('Contents.json', templates.macOSContentsJsonFile),
        ]),
        d.file('launcher_icons.yaml', templates.liConfigTemplate),
        d.file('master-light-1024.png', imageFile.readAsBytesSync()),
      ]).create();
      final flavorPrefix = path.join(d.sandbox, 'fli_test_flavor');
      final flavorConfig = parseTemplateSection(templates.liConfigTemplate);
      final flavorContext = IconGeneratorContext(
        config: flavorConfig,
        prefixPath: flavorPrefix,
        logger: LILogger(false),
        flavor: 'staging',
      );
      final flavorGenerator = MacOSIconGenerator(flavorContext);

      expect(flavorGenerator.validateRequirements(), isTrue);
      await flavorGenerator.createIcons();

      await expectLater(
        d.dir('fli_test_flavor', [
          d.dir('macos/Runner/Assets.xcassets/AppIcon-staging.appiconset', [
            d.file('app_icon_1024.png', anything),
            d.file('app_icon_16.png', anything),
          ]),
        ]).validate(),
        completes,
        reason: 'Flavor icon files are not generated',
      );
      // The default set must be left alone.
      expect(
        Directory(
          path.join(
            flavorPrefix,
            'macos',
            'Runner',
            'Assets.xcassets',
            'AppIcon.appiconset',
          ),
        ).existsSync(),
        isFalse,
      );
    });
    test('flavor bootstraps a missing icon set from scratch', () async {
      final imageFile = File(path.join(assetPath, 'master-light-1024.png'));
      await d.dir('fli_test_fresh', [
        d.dir('macos/Runner/Assets.xcassets'),
        d.file('launcher_icons.yaml', templates.liConfigTemplate),
        d.file('master-light-1024.png', imageFile.readAsBytesSync()),
      ]).create();
      final freshPrefix = path.join(d.sandbox, 'fli_test_fresh');
      final freshConfig = parseTemplateSection(templates.liConfigTemplate);
      final freshGenerator = MacOSIconGenerator(
        IconGeneratorContext(
          config: freshConfig,
          prefixPath: freshPrefix,
          logger: LILogger(false),
          flavor: 'fresh',
        ),
      );

      expect(freshGenerator.validateRequirements(), isTrue);
      await freshGenerator.createIcons();

      await expectLater(
        d.dir('fli_test_fresh', [
          d.dir('macos/Runner/Assets.xcassets/AppIcon-fresh.appiconset', [
            d.file('Contents.json', anything),
            d.file('app_icon_16.png', anything),
          ]),
        ]).validate(),
        completes,
        reason: 'Fresh flavor icon set was not bootstrapped',
      );
    });
    test('rounded config produces transparent corners end-to-end', () async {
      final imageFile = File(path.join(assetPath, 'master-light-1024.png'));
      await d.dir('fli_test_rounded', [
        d.dir('macos/Runner/Assets.xcassets/AppIcon.appiconset', [
          d.file('Contents.json', templates.macOSContentsJsonFile),
        ]),
        d.file('master-light-1024.png', imageFile.readAsBytesSync()),
      ]).create();
      final roundedPrefix = path.join(d.sandbox, 'fli_test_rounded');
      const roundedConfig = Config(
        imagePath: 'master-light-1024.png',
        macOSConfig: MacOSConfig(generate: true, roundedCorners: true),
      );
      final roundedContext = IconGeneratorContext(
        config: roundedConfig,
        prefixPath: roundedPrefix,
        logger: LILogger(false),
      );
      final roundedGenerator = MacOSIconGenerator(roundedContext);

      expect(roundedGenerator.validateRequirements(), isTrue);
      await roundedGenerator.createIcons();

      final output = decodeImage(
        await File(
          path.join(
            roundedPrefix,
            'macos',
            'Runner',
            'Assets.xcassets',
            'AppIcon.appiconset',
            'app_icon_16.png',
          ),
        ).readAsBytes(),
      )!;
      expect(output.getPixel(0, 0).a, equals(0));
    });
  });
}
