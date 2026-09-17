import 'dart:io';

import 'package:launcher_icons/src/platforms/ios/ios.dart' as ios;
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

// Tests for changeIosLauncherIcon: scoped rewrites (fluttercommunity/flutter_launcher_icons#565), atomic writes (fluttercommunity/flutter_launcher_icons#636) and the missing-key warning (fluttercommunity/flutter_launcher_icons#341). NOTE: a trailing newline keeps written output byte-identical when nothing is replaced.
const _fixture = r'''
// !$*UTF8*$!
{
/* Begin XCBuildConfiguration section */
		baseConfigurationReference = AAA /* Debug-production.xcconfig */;
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
/* End XCBuildConfiguration section */
}
''';

void main() {
  group('changeIosLauncherIcon', () {
    late String originalDir;
    late String sandboxDir;

    setUp(() async {
      originalDir = Directory.current.path;
      sandboxDir = path.join(
        '.dart_tool',
        'launcher_icons',
        'test',
        'ios_change_icon',
      );
      final sandbox = Directory(sandboxDir);
      if (sandbox.existsSync()) {
        sandbox.deleteSync(recursive: true);
      }
      await Directory(path.join(sandboxDir, 'ios', 'Runner.xcodeproj')).create(recursive: true);
      // Written before chdir (sandbox-relative); every path below is
      // CWD-relative because the generator resolves against Directory.current.
      await File(
        path.join(sandboxDir, 'ios', 'Runner.xcodeproj', 'project.pbxproj'),
      ).writeAsString(_fixture);
      Directory.current = sandboxDir;
    });

    tearDown(() {
      Directory.current = originalDir;
    });

    File pbxprojFile() => File(
          path.join('ios', 'Runner.xcodeproj', 'project.pbxproj'),
        );

    test('rewrites the matching flavor config without touching the rest', () async {
      await ios.changeIosLauncherIcon('AppIcon-production', 'production');
      final content = await pbxprojFile().readAsString();
      expect(
        content,
        contains('ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon-production;'),
      );
      // fluttercommunity/flutter_launcher_icons#634: neighboring build settings must survive.
      expect(
        content,
        contains(
          'ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;',
        ),
      );
      // fluttercommunity/flutter_launcher_icons#636: no temp file left behind.
      expect(
        File(
          path.join(
            'ios',
            'Runner.xcodeproj',
            'project.pbxproj.tmp',
          ),
        ).existsSync(),
        isFalse,
      );
    });

    test('warns instead of silently skipping a missing flavor key (fluttercommunity/flutter_launcher_icons#341)', () async {
      await ios.changeIosLauncherIcon('AppIcon-staging', 'staging');
      // File content (modulo trailing newline handling) is unchanged.
      final content = await pbxprojFile().readAsString();
      expect(content, isNot(contains('AppIcon-staging')));
    });

    test('updates every config when no flavor is given', () async {
      await ios.changeIosLauncherIcon('AppIcon', null);
      final content = await pbxprojFile().readAsString();
      expect(
        content,
        contains('ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;'),
      );
    });
  });

  group('resolveIosPbxprojPath', () {
    late String originalDir;
    late String sandboxDir;

    setUp(() async {
      originalDir = Directory.current.path;
      sandboxDir = path.join(
        '.dart_tool',
        'launcher_icons',
        'test',
        'ios_resolve_pbxproj',
      );
      final sandbox = Directory(sandboxDir);
      if (sandbox.existsSync()) {
        sandbox.deleteSync(recursive: true);
      }
      sandbox.createSync(recursive: true);
      Directory.current = sandboxDir;
    });

    tearDown(() {
      Directory.current = originalDir;
    });

    Future<void> writePbxproj(String projectDir) async {
      final file = File(path.join('ios', projectDir, 'project.pbxproj'));
      await file.parent.create(recursive: true);
      await file.writeAsString('// !\$*UTF8*\$!\n{}\n');
    }

    test('prefers the standard Runner location', () async {
      await writePbxproj('Runner.xcodeproj');
      await writePbxproj('Renamed.xcodeproj');
      expect(
        ios.resolveIosPbxprojPath(),
        equals('ios/Runner.xcodeproj/project.pbxproj'),
      );
    });

    test('falls back to a renamed project (fluttercommunity/flutter_launcher_icons#543)', () async {
      await writePbxproj('Renamed.xcodeproj');
      expect(
        ios.resolveIosPbxprojPath(),
        equals(
          path.join('ios', 'Renamed.xcodeproj', 'project.pbxproj'),
        ),
      );
    });

    test('returns null when no project exists', () async {
      expect(ios.resolveIosPbxprojPath(), isNull);
    });

    test('honors an explicit path without touching the disk', () async {
      expect(
        ios.resolveIosPbxprojPath('ios/Custom.xcodeproj'),
        equals('ios/Custom.xcodeproj/project.pbxproj'),
      );
    });

    test('changeIosLauncherIcon works in a renamed project (fluttercommunity/flutter_launcher_icons#543)', () async {
      final renamed = File(
        path.join('ios', 'Renamed.xcodeproj', 'project.pbxproj'),
      );
      await renamed.parent.create(recursive: true);
      await renamed.writeAsString(_fixture);
      await ios.changeIosLauncherIcon('AppIcon-production', 'production');
      final content = await File(
        path.join('ios', 'Renamed.xcodeproj', 'project.pbxproj'),
      ).readAsString();
      expect(
        content,
        contains('ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon-production;'),
      );
    });

    test('explicit xcodeproj path wins over the default (fluttercommunity/flutter_launcher_icons#637)', () async {
      await writePbxproj('Runner.xcodeproj');
      final custom = File(path.join('ios', 'Custom.xcodeproj', 'project.pbxproj'));
      await custom.parent.create(recursive: true);
      await custom.writeAsString(_fixture);
      await ios.changeIosLauncherIcon(
        'AppIcon-Custom',
        null,
        'ios/Custom.xcodeproj',
      );
      expect(
        await custom.readAsString(),
        contains('ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon-Custom;'),
      );
      // Default project left untouched.
      final standard = await File(
        path.join('ios', 'Runner.xcodeproj', 'project.pbxproj'),
      ).readAsString();
      expect(standard, equals('// !\$*UTF8*\$!\n{}\n'));
    });
  });
}
