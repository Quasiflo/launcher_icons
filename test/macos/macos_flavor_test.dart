import 'dart:io';

import 'package:launcher_icons/src/config/config.dart';
import 'package:launcher_icons/src/core/icon_generator.dart';
import 'package:launcher_icons/src/core/logger.dart';
import 'package:launcher_icons/src/platforms/macos/macos_icon_generator.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

import '../templates.dart' as templates;

const _pbxproj = r'''
// !$*UTF8*$!
{
/* Begin XCBuildConfiguration section */
		baseConfigurationReference = AAA /* Debug-staging.xcconfig */;
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
/* End XCBuildConfiguration section */
}
''';

// Flavor runs write AppIcon-<flavor>.appiconset/ but the built app keeps showing the old icon unless the macOS pbxproj is rewired to the flavor catalog — the same wiring iOS performs.
void main() {
  group('MacOSIconGenerator flavors', () {
    late String prefixPath;
    late Directory sandbox;

    setUp(() async {
      sandbox = Directory(
        path.join(
          Directory.current.path,
          '.dart_tool',
          'launcher_icons',
          'test',
          'macos_flavor',
        ),
      );
      if (sandbox.existsSync()) {
        sandbox.deleteSync(recursive: true);
      }
      await Directory(
        path.join(
          sandbox.path,
          'macos',
          'Runner',
          'Assets.xcassets',
          'AppIcon-staging.appiconset',
        ),
      ).create(recursive: true);
      await Directory(
        path.join(sandbox.path, 'macos', 'Runner.xcodeproj'),
      ).create(recursive: true);
      await File(
        path.join(
          sandbox.path,
          'macos',
          'Runner',
          'Assets.xcassets',
          'AppIcon-staging.appiconset',
          'Contents.json',
        ),
      ).writeAsString(templates.macOSContentsJsonFile);
      await File(
        path.join(
          sandbox.path,
          'macos',
          'Runner.xcodeproj',
          'project.pbxproj',
        ),
      ).writeAsString(_pbxproj);
      File(
        path.join(
          Directory.current.path,
          'test',
          'assets',
          'master-light-1024.png',
        ),
      ).copySync(path.join(sandbox.path, 'master-light-1024.png'));
      prefixPath = sandbox.absolute.path;
    });

    tearDown(() {
      if (sandbox.existsSync()) {
        sandbox.deleteSync(recursive: true);
      }
    });

    test('rewires the macOS pbxproj to the flavor catalog', () async {
      final config = Config.fromJson(<String, dynamic>{
        'macos': {
          'generate': true,
          'image_path': 'master-light-1024.png',
        },
      });
      final generator = MacOSIconGenerator(
        IconGeneratorContext(
          config: config,
          logger: LILogger(false),
          prefixPath: prefixPath,
          flavor: 'staging',
        ),
      );

      expect(generator.context.config.macOSEnabled, isTrue);
      expect(generator.validateRequirements(), isTrue);
      await generator.createIcons();

      expect(
        File(
          path.join(
            prefixPath,
            'macos',
            'Runner',
            'Assets.xcassets',
            'AppIcon-staging.appiconset',
            'app_icon_512.png',
          ),
        ).existsSync(),
        isTrue,
      );
      final pbxproj = await File(
        path.join(
          prefixPath,
          'macos',
          'Runner.xcodeproj',
          'project.pbxproj',
        ),
      ).readAsString();
      expect(pbxproj, contains('APPICON_NAME = AppIcon-staging;'));
    });
  });
}
