import 'dart:io';

import 'package:launcher_icons/src/config/config.dart';
import 'package:launcher_icons/src/config/linux_config.dart';
import 'package:launcher_icons/src/core/icon_generator.dart';
import 'package:launcher_icons/src/core/logger.dart';
import 'package:launcher_icons/src/platforms/linux/linux_icon_generator.dart';
import 'package:test/test.dart';

const _ccBody = '''
#include "my_application.h"

static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window = GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  gtk_window_set_default_size(window, 1280, 720);
  gtk_widget_show(GTK_WIDGET(window));
}
''';

// The my_application.cc inserter must round-trip foreign line endings and a missing trailing newline instead of normalizing them.
void main() {
  group('my_application.cc line endings', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('linux_eol_test');
      await Directory('${tempDir.path}/linux/runner').create(
        recursive: true,
      );
      await Directory('${tempDir.path}/assets/images').create(
        recursive: true,
      );
      await File('${tempDir.path}/assets/images/icon.png').writeAsBytes(
        File('${Directory.current.path}/test/assets/master-light-1024.png').readAsBytesSync(),
      );
      await File('${tempDir.path}/pubspec.yaml').writeAsString('''
name: test_app

flutter:
  assets:
    - assets/images/icon.png
''');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    LinuxIconGenerator generator() {
      const config = Config(
        imagePath: 'assets/images/icon.png',
        linuxConfig: LinuxConfig(generate: true),
      );
      return LinuxIconGenerator(
        IconGeneratorContext(
          config: config,
          logger: LILogger(isVerbose: false),
          prefixPath: tempDir.path,
        ),
      );
    }

    Future<String> runWithCc(final String content) async {
      final file = File('${tempDir.path}/linux/runner/my_application.cc');
      await file.writeAsString(content);
      await generator().createIcons();
      return file.readAsStringSync();
    }

    test('preserves CRLF across insertion', () async {
      final output = await runWithCc(_ccBody.replaceAll('\n', '\r\n'));

      expect(
        output,
        contains('get_flutter_asset_path("assets/images/icon.png")'),
      );
      expect(output.contains('\r\n'), isTrue);
      expect(output.replaceAll('\r\n', '\n').contains('\r'), isFalse);
    });

    test('preserves a missing trailing newline', () async {
      final output = await runWithCc(_ccBody.trimRight());

      expect(
        output,
        contains('get_flutter_asset_path("assets/images/icon.png")'),
      );
      expect(output.endsWith('\n'), isFalse);
    });
  });
}
