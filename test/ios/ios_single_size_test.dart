import 'dart:convert';
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

// In single-size mode dark/tinted variants must be skipped entirely: no
// decode, no PNG I/O, no Contents.json entries.
void main() {
  group('createIcons single_size', () {
    late String originalDir;
    late String sandboxDir;

    setUp(() {
      originalDir = Directory.current.path;
      sandboxDir = path.join(
        '.dart_tool',
        'launcher_icons',
        'test',
        'ios_single_size',
      );
      final sandbox = Directory(sandboxDir);
      if (sandbox.existsSync()) {
        sandbox.deleteSync(recursive: true);
      }
      sandbox.createSync(recursive: true);
      for (final name in ['icon.png', 'icon-dark.png', 'icon-tinted.png']) {
        File(path.join(originalDir, 'test', 'assets', 'master-light-1024.png')).copySync(path.join(sandboxDir, name));
      }
      Directory.current = sandboxDir;
    });

    tearDown(() {
      Directory.current = originalDir;
    });

    test('skips dark/tinted I/O and omits them from Contents.json', () async {
      await Directory(
        path.join('ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset'),
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
          'image_path_dark_transparent': 'icon-dark.png',
          'image_path_tinted_grayscale': 'icon-tinted.png',
          'single_size': true,
        },
      });

      await ios.createIcons(config, null);

      final catalog = Directory(
        path.join('ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset'),
      );
      final pngs = catalog.listSync().whereType<File>().where((f) => f.path.endsWith('.png')).map((f) => path.basename(f.path)).toList();
      expect(pngs, equals(['Icon-App-1024x1024@1x.png']));
      final contents = jsonDecode(
        File(path.join(catalog.path, 'Contents.json')).readAsStringSync(),
      ) as Map<String, dynamic>;
      expect(contents['images'] as List, hasLength(1));
    });
  });
}
