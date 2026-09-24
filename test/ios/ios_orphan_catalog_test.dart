import 'dart:io';

import 'package:launcher_icons/src/config/config.dart';
import 'package:launcher_icons/src/platforms/ios/ios.dart' as ios;
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

const _pbxproj = r'''
// !$*UTF8*$!
{
/* Begin XCBuildConfiguration section */
		AAA /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
			};
			name = Debug;
		};
		BBB /* Debug-staging */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon-staging;
			};
			name = Debug-staging;
		};
/* End XCBuildConfiguration section */
}
''';

// Renamed flavors leave orphaned AppIcon-<old> catalogs behind. A flavor run deletes catalogs nothing references anymore, but never the default set or catalogs the project still points at.
void main() {
  group('createIcons orphan flavor catalog cleanup', () {
    late String originalDir;
    late String sandboxDir;

    setUp(() {
      originalDir = Directory.current.path;
      sandboxDir = path.join(
        '.dart_tool',
        'launcher_icons',
        'test',
        'ios_orphan_catalog',
      );
      final sandbox = Directory(sandboxDir);
      if (sandbox.existsSync()) {
        sandbox.deleteSync(recursive: true);
      }
      sandbox.createSync(recursive: true);
      File(path.join(originalDir, 'test', 'assets', 'master-light-1024.png')).copySync(path.join(sandboxDir, 'icon.png'));
      Directory(path.join(sandboxDir, 'ios', 'Runner.xcodeproj')).createSync(recursive: true);
      File(path.join(sandboxDir, 'ios', 'Runner.xcodeproj', 'project.pbxproj')).writeAsStringSync(_pbxproj);
      for (final catalog in [
        'AppIcon',
        'AppIcon-staging',
        'AppIcon-retired',
      ]) {
        Directory(
          path.join(
            sandboxDir,
            'ios',
            'Runner',
            'Assets.xcassets',
            '$catalog.appiconset',
          ),
        ).createSync(recursive: true);
      }
      Directory.current = sandboxDir;
    });

    tearDown(() {
      Directory.current = originalDir;
    });

    test('deletes unreferenced catalogs, keeps the rest', () async {
      final config = Config.fromJson(<String, dynamic>{
        'ios': {
          'generate': true,
          'image_path': 'icon.png',
        },
      });

      // Flavor run for a new flavor: nothing references AppIcon-retired.
      await ios.createIcons(config, 'production');

      String catalog(final String name) => path.join(
            'ios',
            'Runner',
            'Assets.xcassets',
            '$name.appiconset',
          );
      expect(Directory(catalog('AppIcon-retired')).existsSync(), isFalse);
      expect(Directory(catalog('AppIcon')).existsSync(), isTrue);
      expect(Directory(catalog('AppIcon-staging')).existsSync(), isTrue);
      expect(Directory(catalog('AppIcon-production')).existsSync(), isTrue);
    });
  });
}
