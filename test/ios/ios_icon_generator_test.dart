import 'dart:io';

import 'package:launcher_icons/src/config/config.dart';
import 'package:launcher_icons/src/core/icon_generator.dart';
import 'package:launcher_icons/src/core/logger.dart';
import 'package:launcher_icons/src/platforms/ios/ios_icon_generator.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

const _pbxproj = r'''
// !$*UTF8*$!
{
/* Begin XCBuildConfiguration section */
		baseConfigurationReference = AAA /* Debug-production.xcconfig */;
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
/* End XCBuildConfiguration section */
}
''';

// The generator must honor prefixPath: with CWD left at the repo root, all reads and writes happen under the given prefix.
void main() {
  group('IosIconGenerator', () {
    late String prefixPath;
    late Directory sandbox;

    setUp(() {
      sandbox = Directory(
        path.join(
          Directory.current.path,
          '.dart_tool',
          'launcher_icons',
          'test',
          'ios_generator_prefix',
        ),
      );
      if (sandbox.existsSync()) {
        sandbox.deleteSync(recursive: true);
      }
      sandbox.createSync(recursive: true);
      prefixPath = sandbox.absolute.path;
    });

    tearDown(() {
      if (sandbox.existsSync()) {
        sandbox.deleteSync(recursive: true);
      }
    });

    IconGenerator generatorFor(Config config) => IosIconGenerator(
          IconGeneratorContext(
            config: config,
            logger: LILogger(false),
            prefixPath: prefixPath,
          ),
        );

    test('iosEnabled follows ios.generate', () {
      expect(
        generatorFor(
          Config.fromJson(<String, dynamic>{
            'ios': {'generate': true, 'image_path': 'icon.png'},
          }),
        ).context.config.iosEnabled,
        isTrue,
      );
      expect(
        generatorFor(
          Config.fromJson(<String, dynamic>{
            'ios': {'generate': false},
          }),
        ).context.config.iosEnabled,
        isFalse,
      );
    });

    test('validateRequirements fails without any image path', () {
      final generator = generatorFor(
        Config.fromJson(<String, dynamic>{
          'ios': {'generate': true},
        }),
      );
      expect(generator.validateRequirements(), isFalse);
    });

    test('validateRequirements fails without an ios directory', () {
      File(
        path.join(
          Directory.current.path,
          'test',
          'assets',
          'master-light-1024.png',
        ),
      ).copySync(path.join(prefixPath, 'icon.png'));
      final generator = generatorFor(
        Config.fromJson(<String, dynamic>{
          'ios': {'generate': true, 'image_path': 'icon.png'},
        }),
      );
      expect(generator.validateRequirements(), isFalse);
    });

    test('createIcons writes under prefixPath', () async {
      File(
        path.join(
          Directory.current.path,
          'test',
          'assets',
          'master-light-1024.png',
        ),
      ).copySync(path.join(prefixPath, 'icon.png'));
      await Directory(
        path.join(
          prefixPath,
          'ios',
          'Runner',
          'Assets.xcassets',
          'AppIcon.appiconset',
        ),
      ).create(recursive: true);
      await Directory(
        path.join(prefixPath, 'ios', 'Runner.xcodeproj'),
      ).create(recursive: true);
      await File(
        path.join(prefixPath, 'ios', 'Runner.xcodeproj', 'project.pbxproj'),
      ).writeAsString(_pbxproj);

      final generator = generatorFor(
        Config.fromJson(<String, dynamic>{
          'ios': {'generate': true, 'image_path': 'icon.png'},
        }),
      );
      expect(generator.validateRequirements(), isTrue);
      await generator.createIcons();

      final icon = File(
        path.join(
          prefixPath,
          'ios',
          'Runner',
          'Assets.xcassets',
          'AppIcon.appiconset',
          'Icon-App-1024x1024@1x.png',
        ),
      );
      expect(icon.existsSync(), isTrue);
      final contents = File(
        path.join(
          prefixPath,
          'ios',
          'Runner',
          'Assets.xcassets',
          'AppIcon.appiconset',
          'Contents.json',
        ),
      );
      expect(contents.existsSync(), isTrue);
    });
  });
}
