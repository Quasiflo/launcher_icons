import 'dart:io';

import 'package:image/image.dart';
import 'package:launcher_icons/src/config/config.dart';
import 'package:launcher_icons/src/config/linux_config.dart';
import 'package:launcher_icons/src/core/icon_generator.dart';
import 'package:launcher_icons/src/core/logger.dart';
import 'package:launcher_icons/src/platforms/linux/linux_icon_generator.dart';
import 'package:test/test.dart';

// The real Linux launcher deliverables: hicolor PNG tree, .desktop entries, and snap packaging — all strictly only-if-absent, never overwriting.
void main() {
  group('LinuxIconGenerator packaging', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('linux_pkg_test');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    /// Minimal valid project: linux runner, icon file, pubspec bundling the
    /// icon with a name + version carrying a build number.
    Future<void> setUpProject() async {
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
      final iconBytes = File(
        '${Directory.current.path}/test/assets/master-light-1024.png',
      ).readAsBytesSync();
      await Directory('${tempDir.path}/assets/images').create(
        recursive: true,
      );
      await File('${tempDir.path}/assets/images/icon.png').writeAsBytes(
        iconBytes,
      );
      await File('${tempDir.path}/pubspec.yaml').writeAsString('''
name: test_app
version: 1.2.3+4

flutter:
  assets:
    - assets/images/icon.png
''');
    }

    LinuxIconGenerator generator() {
      const config = Config(
        imagePath: 'assets/images/icon.png',
        linuxConfig: LinuxConfig(generate: true),
      );
      return LinuxIconGenerator(
        IconGeneratorContext(
          config: config,
          logger: LILogger(false),
          prefixPath: tempDir.path,
        ),
      );
    }

    test('emits hicolor tree, desktop entries, and snap files', () async {
      await setUpProject();

      await generator().createIcons();

      // hicolor tree across all sizes.
      for (final size in [16, 22, 24, 32, 48, 64, 128, 256, 512]) {
        final file = File(
          '${tempDir.path}/share/icons/hicolor/${size}x$size/apps/test_app.png',
        );
        expect(file.existsSync(), isTrue, reason: '${size}x$size');
        final image = decodeImage(file.readAsBytesSync())!;
        expect(image.width, equals(size));
        expect(image.height, equals(size));
      }
      // snap icon.
      final snapIcon = File('${tempDir.path}/snap/gui/test_app.png');
      expect(snapIcon.existsSync(), isTrue);
      final snapImage = decodeImage(snapIcon.readAsBytesSync())!;
      expect(snapImage.width, equals(256));
      // snap desktop entry points at the snap gui art.
      final snapDesktop = File('${tempDir.path}/snap/gui/test_app.desktop');
      expect(snapDesktop.existsSync(), isTrue);
      final snapContent = snapDesktop.readAsStringSync();
      expect(snapContent, contains('Name=test_app'));
      expect(
        snapContent,
        contains(r'Icon=${SNAP}/meta/gui/test_app.png'),
      );
      // freedesktop desktop entry resolves via hicolor.
      final desktopContent = File(
        '${tempDir.path}/share/applications/test_app.desktop',
      ).readAsStringSync();
      expect(desktopContent, contains('Name=test_app'));
      expect(desktopContent, contains('Icon=test_app'));
      // snapcraft.yaml interpolates the pubspec name/version (build
      // number stripped).
      final snapcraft = File(
        '${tempDir.path}/snap/snapcraft.yaml',
      ).readAsStringSync();
      expect(snapcraft, contains('name: test_app'));
      expect(snapcraft, contains('version: 1.2.3'));
      expect(snapcraft, isNot(contains('+4')));
    });

    test('never overwrites existing packaging files', () async {
      await setUpProject();
      final desktop = File('${tempDir.path}/snap/gui/test_app.desktop');
      await desktop.create(recursive: true);
      await desktop.writeAsString('[custom]\n');
      final snapcraft = File('${tempDir.path}/snap/snapcraft.yaml');
      await snapcraft.create(recursive: true);
      await snapcraft.writeAsString('custom: true\n');
      final hicolor = File(
        '${tempDir.path}/share/icons/hicolor/48x48/apps/test_app.png',
      );
      await hicolor.create(recursive: true);
      await hicolor.writeAsBytes([1, 2, 3]);

      await generator().createIcons();

      expect(desktop.readAsStringSync(), equals('[custom]\n'));
      expect(snapcraft.readAsStringSync(), equals('custom: true\n'));
      expect(hicolor.readAsBytesSync(), equals([1, 2, 3]));
      // ...while still creating the rest.
      expect(
        File(
          '${tempDir.path}/share/icons/hicolor/32x32/apps/test_app.png',
        ).existsSync(),
        isTrue,
      );
      expect(
        File('${tempDir.path}/snap/gui/test_app.png').existsSync(),
        isTrue,
      );
    });
  });
}
