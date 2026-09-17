import 'dart:io';

import 'package:launcher_icons/src/config/config.dart';
import 'package:launcher_icons/src/platforms/ios/ios.dart' as ios;
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

// A custom icon_name must get its own catalog: <custom>.appiconset holding the PNGs + Contents.json, with APPICON_NAME pointing at it. Writing the PNGs into AppIcon.appiconset while naming another catalog leaves Xcode unable to resolve the set.
void main() {
  group('createIcons custom icon_name', () {
    late String originalDir;
    late String sandboxDir;

    setUp(() {
      originalDir = Directory.current.path;
      sandboxDir = path.join(
        '.dart_tool',
        'launcher_icons',
        'test',
        'ios_custom_icon_name',
      );
      final sandbox = Directory(sandboxDir);
      if (sandbox.existsSync()) {
        sandbox.deleteSync(recursive: true);
      }
      sandbox.createSync(recursive: true);
      File(path.join(originalDir, 'test', 'assets', 'master-light-1024.png')).copySync(path.join(sandboxDir, 'icon.png'));
      Directory.current = sandboxDir;
    });

    tearDown(() {
      Directory.current = originalDir;
    });

    test('writes PNGs and Contents.json to <custom>.appiconset', () async {
      await Directory(
        path.join('ios', 'Runner', 'Assets.xcassets'),
      ).create(recursive: true);
      await Directory(path.join('ios', 'Runner.xcodeproj')).create(
        recursive: true,
      );
      await File(
        path.join('ios', 'Runner.xcodeproj', 'project.pbxproj'),
      ).writeAsString(_pbxproj);

      final config = Config.fromJson(<String, dynamic>{
        'ios': {
          'generate': true,
          'image_path': 'icon.png',
          'icon_name': 'MyIcon',
        },
      });

      await ios.createIcons(config, null);

      final catalog = Directory(
        path.join('ios', 'Runner', 'Assets.xcassets', 'MyIcon.appiconset'),
      );
      expect(catalog.existsSync(), isTrue);
      expect(
        File(
          path.join(catalog.path, 'MyIcon-1024x1024@1x.png'),
        ).existsSync(),
        isTrue,
      );
      expect(
        File(path.join(catalog.path, 'Contents.json')).existsSync(),
        isTrue,
      );
      // Nothing may leak into the default catalog.
      expect(
        Directory(
          path.join('ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset'),
        ).existsSync(),
        isFalse,
      );
      // Folder name matches APPICON_NAME.
      final pbxproj = await File(
        path.join('ios', 'Runner.xcodeproj', 'project.pbxproj'),
      ).readAsString();
      expect(pbxproj, contains('APPICON_NAME = MyIcon;'));
    });
  });
}
