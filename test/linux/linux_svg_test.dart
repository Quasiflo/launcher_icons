import 'dart:io';

import 'package:image/image.dart';
import 'package:launcher_icons/src/config/config.dart';
import 'package:launcher_icons/src/config/linux_config.dart';
import 'package:launcher_icons/src/core/icon_generator.dart';
import 'package:launcher_icons/src/core/logger.dart';
import 'package:launcher_icons/src/platforms/linux/linux_icon_generator.dart';
import 'package:test/test.dart';

// Linux SVG sources: the runner loads the window icon from flutter_assets at runtime where only rasters work, so SVG sources derive a sibling `<name>.linux.png` raster that is wired and bundled instead. Desktop entries also carry StartupWMClass from the CMake application id.
void main() {
  group('LinuxIconGenerator.runtimeIconPath', () {
    test('derives a sibling raster for SVG sources', () {
      expect(
        LinuxIconGenerator.runtimeIconPath('assets/images/icon.svg'),
        equals('assets/images/icon.linux.png'),
      );
    });

    test('matches SVG case-insensitively and keeps directories', () {
      expect(
        LinuxIconGenerator.runtimeIconPath('assets/ICON.SVG'),
        equals('assets/ICON.linux.png'),
      );
    });

    test('passes raster sources through untouched', () {
      expect(
        LinuxIconGenerator.runtimeIconPath('assets/images/icon.png'),
        equals('assets/images/icon.png'),
      );
    });
  });

  group('LinuxIconGenerator SVG project', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('linux_svg_test');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    /// Minimal project with an SVG source; the pubspec bundles [pubspecAsset] (default: the derived runtime raster).
    Future<void> setUpSvgProject({
      String pubspecAsset = 'assets/images/icon.linux.png',
      String? applicationId,
    }) async {
      await Directory('${tempDir.path}/linux/runner').create(
        recursive: true,
      );
      await File('${tempDir.path}/linux/runner/my_application.cc').writeAsString('''
#include "my_application.h"

static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window = GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  gtk_window_set_default_size(window, 1280, 720);
  gtk_widget_show(GTK_WIDGET(window));
}
''');
      if (applicationId != null) {
        await File('${tempDir.path}/linux/CMakeLists.txt').writeAsString(
          'set(APPLICATION_ID "$applicationId")\n',
        );
      }
      await Directory('${tempDir.path}/assets/images').create(
        recursive: true,
      );
      await File('${tempDir.path}/assets/images/icon.svg').writeAsString(
        File('${Directory.current.path}/test/assets/vector-opaque-1024.svg').readAsStringSync(),
      );
      await File('${tempDir.path}/pubspec.yaml').writeAsString('''
name: test_app

flutter:
  assets:
    - $pubspecAsset
''');
    }

    LinuxIconGenerator generator({bool generateSnap = false}) {
      final config = Config(
        imagePath: 'assets/images/icon.svg',
        linuxConfig: LinuxConfig(generate: true, generateSnap: generateSnap),
      );
      return LinuxIconGenerator(
        IconGeneratorContext(
          config: config,
          logger: LILogger(false),
          prefixPath: tempDir.path,
        ),
      );
    }

    test('validates when the derived raster is bundled', () async {
      await setUpSvgProject();

      expect(generator().validateRequirements(), isTrue);
    });

    test('validates when the source directory is bundled', () async {
      await setUpSvgProject(pubspecAsset: 'assets/images/');

      expect(generator().validateRequirements(), isTrue);
    });

    test('fails validation when only the SVG source is bundled', () async {
      await setUpSvgProject(pubspecAsset: 'assets/images/icon.svg');

      expect(generator().validateRequirements(), isFalse);
    });

    test('derives, wires, and packages the runtime raster', () async {
      await setUpSvgProject(applicationId: 'com.example.test_app');

      await generator(generateSnap: true).createIcons();

      // Derived 512px raster next to the source.
      final derived = File('${tempDir.path}/assets/images/icon.linux.png');
      expect(derived.existsSync(), isTrue);
      final derivedImage = decodeImage(derived.readAsBytesSync())!;
      expect(derivedImage.width, equals(512));
      expect(derivedImage.height, equals(512));
      // my_application.cc wires the raster, not the SVG.
      final cc = File('${tempDir.path}/linux/runner/my_application.cc').readAsStringSync();
      expect(
        cc,
        contains('get_flutter_asset_path("assets/images/icon.linux.png")'),
      );
      expect(cc, isNot(contains('icon.svg')));
      // hicolor tree still renders from the vector source.
      expect(
        File(
          '${tempDir.path}/linux/share/icons/hicolor/512x512/apps/test_app.png',
        ).existsSync(),
        isTrue,
      );
      // Desktop entries carry the CMake application id.
      final desktop = File(
        '${tempDir.path}/linux/share/applications/test_app.desktop',
      ).readAsStringSync();
      expect(desktop, contains('StartupWMClass=com.example.test_app'));
      final snapDesktop = File(
        '${tempDir.path}/snap/gui/test_app.desktop',
      ).readAsStringSync();
      expect(snapDesktop, contains('StartupWMClass=com.example.test_app'));
    });

    test('rewrites a stale derived raster', () async {
      await setUpSvgProject();
      final derived = File('${tempDir.path}/assets/images/icon.linux.png');
      await derived.create(recursive: true);
      await derived.writeAsBytes([1, 2, 3]);

      await generator().createIcons();

      final derivedImage = decodeImage(derived.readAsBytesSync())!;
      expect(derivedImage.width, equals(512));
    });

    test('omits StartupWMClass without a CMake application id', () async {
      await setUpSvgProject();

      await generator().createIcons();

      final desktop = File(
        '${tempDir.path}/linux/share/applications/test_app.desktop',
      ).readAsStringSync();
      expect(desktop, isNot(contains('StartupWMClass')));
    });

    test('prefers the flavor-conditional application id', () async {
      await setUpSvgProject();
      await File('${tempDir.path}/linux/CMakeLists.txt').writeAsString('''
set(APPLICATION_ID "com.example.base")
if(DEFINED FLUTTER_APP_FLAVOR)
  if(FLUTTER_APP_FLAVOR STREQUAL "development")
    set(APPLICATION_ID "com.example.dev")
  elseif(FLUTTER_APP_FLAVOR STREQUAL "production")
    set(APPLICATION_ID "com.example.prod")
  endif()
endif()
''');
      LinuxIconGenerator flavorGenerator(String flavor) {
        const config = Config(
          imagePath: 'assets/images/icon.svg',
          linuxConfig: LinuxConfig(generate: true, generateSnap: true),
        );
        return LinuxIconGenerator(
          IconGeneratorContext(
            config: config,
            logger: LILogger(false),
            prefixPath: tempDir.path,
            flavor: flavor,
          ),
        );
      }

      await flavorGenerator('development').createIcons();
      expect(
        File('${tempDir.path}/linux/share/applications/test_app.desktop').readAsStringSync(),
        contains('StartupWMClass=com.example.dev'),
      );

      await File('${tempDir.path}/snap/gui/test_app.desktop').delete();
      await flavorGenerator('production').createIcons();
      expect(
        File('${tempDir.path}/snap/gui/test_app.desktop').readAsStringSync(),
        contains('StartupWMClass=com.example.prod'),
      );

      // Unflavored runs fall back to the unconditional id.
      await File('${tempDir.path}/linux/share/applications/test_app.desktop').delete();
      await generator(generateSnap: true).createIcons();
      expect(
        File('${tempDir.path}/linux/share/applications/test_app.desktop').readAsStringSync(),
        contains('StartupWMClass=com.example.base'),
      );
    });
  });
}
