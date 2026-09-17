import 'dart:io';

import 'package:launcher_icons/src/config/config.dart';
import 'package:launcher_icons/src/core/custom_exceptions.dart';
import 'package:launcher_icons/src/platforms/ios/ios.dart' as ios;
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

const _pbxproj = r'''
// !$*UTF8*$!
{
/* Begin XCBuildConfiguration section */
		AAA /* Debug */ = {
			isa = XCBuildConfiguration;
			baseConfigurationReference = AAA /* Debug.xcconfig */;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
			};
			name = Debug;
		};
		BBB /* Debug-staging */ = {
			isa = XCBuildConfiguration;
			baseConfigurationReference = BBB /* Debug-staging.xcconfig */;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
			};
			name = Debug-staging;
		};
		CCC /* Debug-production */ = {
			isa = XCBuildConfiguration;
			baseConfigurationReference = CCC /* Debug-production.xcconfig */;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
			};
			name = Debug-production;
		};
/* End XCBuildConfiguration section */
}
''';

// Flavor wiring: exact-token config matching, a non-greedy APPICON_NAME
// rewrite, and the opt-in xcconfig-override mode.
void main() {
  group('changeIosLauncherIcon matching', () {
    late String originalDir;
    late String sandboxDir;

    setUp(() {
      originalDir = Directory.current.path;
      sandboxDir = path.join(
        '.dart_tool',
        'launcher_icons',
        'test',
        'ios_flavor_mode',
      );
      final sandbox = Directory(sandboxDir);
      if (sandbox.existsSync()) {
        sandbox.deleteSync(recursive: true);
      }
      Directory(path.join(sandboxDir, 'ios', 'Runner.xcodeproj')).createSync(recursive: true);
      File(path.join(sandboxDir, 'ios', 'Runner.xcodeproj', 'project.pbxproj')).writeAsStringSync(_pbxproj);
      Directory.current = sandboxDir;
    });

    tearDown(() {
      Directory.current = originalDir;
    });

    String pbxproj() => File(
          path.join('ios', 'Runner.xcodeproj', 'project.pbxproj'),
        ).readAsStringSync();

    test('substring flavors do not collide (tag vs Debug-staging)', () async {
      await ios.changeIosLauncherIcon('AppIcon-tag', 'tag');

      expect(pbxproj(), equals(_pbxproj));
    });

    test('exact flavor rewrites only its own configurations', () async {
      await ios.changeIosLauncherIcon('AppIcon-staging', 'staging');

      final content = pbxproj();
      expect(
        content,
        contains('ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon-staging;'),
      );
      // Debug + production entries keep pointing at AppIcon.
      expect(
        'ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;'.allMatches(content),
        hasLength(2),
      );
    });

    test('rewrite stops at the first semicolon', () async {
      const tricky = 'ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon; FOO = x;';
      File(path.join('ios', 'Runner.xcodeproj', 'project.pbxproj')).writeAsStringSync(
        _pbxproj.replaceAll(
          'ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;',
          tricky,
        ),
      );

      await ios.changeIosLauncherIcon('AppIcon-staging', 'staging');

      expect(pbxproj(), contains('AppIcon-staging; FOO = x;'));
    });

    test('shared base xcconfigs still wire via block headers', () async {
      // The common Flutter-flavors shape: duplicated configurations that
      // keep pointing at the base Debug/Release xcconfigs (no
      // per-flavor xcconfig files). Matching keys off the exact block
      // header names.
      const shared = r'''
// !$*UTF8*$!
{
/* Begin XCBuildConfiguration section */
		AAA /* Debug */ = {
			isa = XCBuildConfiguration;
			baseConfigurationReference = AAA /* Debug.xcconfig */;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
			};
			name = Debug;
		};
		BBB /* Debug-staging */ = {
			isa = XCBuildConfiguration;
			baseConfigurationReference = AAA /* Debug.xcconfig */;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
			};
			name = Debug-staging;
		};
		CCC /* Debug-production */ = {
			isa = XCBuildConfiguration;
			baseConfigurationReference = AAA /* Debug.xcconfig */;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
			};
			name = Debug-production;
		};
/* End XCBuildConfiguration section */
}
''';
      File(path.join('ios', 'Runner.xcodeproj', 'project.pbxproj')).writeAsStringSync(shared);

      await ios.changeIosLauncherIcon('AppIcon-staging', 'staging');

      final content = pbxproj();
      expect(
        content,
        contains('ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon-staging;'),
      );
      expect(
        'ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;'.allMatches(content),
        hasLength(2),
      );
    });
  });

  group('xcconfig flavor mode', () {
    late String originalDir;
    late String sandboxDir;

    setUp(() {
      originalDir = Directory.current.path;
      sandboxDir = path.join(
        '.dart_tool',
        'launcher_icons',
        'test',
        'ios_flavor_xcconfig',
      );
      final sandbox = Directory(sandboxDir);
      if (sandbox.existsSync()) {
        sandbox.deleteSync(recursive: true);
      }
      sandbox.createSync(recursive: true);
      File(path.join(originalDir, 'test', 'assets', 'master-light-1024.png')).copySync(path.join(sandboxDir, 'icon.png'));
      Directory(path.join(sandboxDir, 'ios', 'Runner.xcodeproj')).createSync(recursive: true);
      File(path.join(sandboxDir, 'ios', 'Runner.xcodeproj', 'project.pbxproj')).writeAsStringSync(_pbxproj);
      Directory.current = sandboxDir;
    });

    tearDown(() {
      Directory.current = originalDir;
    });

    Config xcconfig([Map<String, dynamic> extra = const {}]) => Config.fromJson(<String, dynamic>{
          'ios': {
            'generate': true,
            'image_path': 'icon.png',
            'flavor_mode': 'xcconfig',
            ...extra,
          },
        });

    test('writes xcconfigs and clears competing pbxproj lines', () async {
      await ios.createIcons(xcconfig(), 'staging');

      // Catalog still generated on disk.
      expect(
        Directory(
          path.join(
            'ios',
            'Runner',
            'Assets.xcassets',
            'AppIcon-staging.appiconset',
          ),
        ).existsSync(),
        isTrue,
      );
      // Staging lines removed from the pbxproj so the xcconfig value wins;
      // Debug + production entries untouched.
      final pbxprojContent = File(
        path.join('ios', 'Runner.xcodeproj', 'project.pbxproj'),
      ).readAsStringSync();
      expect(pbxprojContent, isNot(contains('AppIcon-staging')));
      expect(
        'ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;'.allMatches(pbxprojContent),
        hasLength(2),
      );
      // One override file per mode, seeded with the Generated include.
      for (final mode in ['Debug', 'Profile', 'Release']) {
        final file = File(
          path.join('ios', 'Flutter', 'staging-$mode.xcconfig'),
        );
        expect(file.existsSync(), isTrue);
        final content = file.readAsStringSync();
        expect(content, contains('#include "Generated.xcconfig"'));
        expect(
          content,
          contains(
            'ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon-staging',
          ),
        );
      }
    });

    test('xcconfig writes are idempotent', () async {
      await ios.createIcons(xcconfig(), 'staging');
      await ios.createIcons(xcconfig(), 'staging');

      final content = File(
        path.join('ios', 'Flutter', 'staging-Debug.xcconfig'),
      ).readAsStringSync();
      expect(
        'ASSETCATALOG_COMPILER_APPICON_NAME'.allMatches(content),
        hasLength(1),
      );
    });

    test('rejects unknown flavor modes', () {
      expect(
        () => ios.createIcons(xcconfig({'flavor_mode': 'ini'}), 'staging'),
        throwsA(isA<InvalidConfigException>()),
      );
    });
  });
}
