import 'dart:io';

import 'package:launcher_icons/src/config/config.dart';
import 'package:launcher_icons/src/config/linux_config.dart';
import 'package:launcher_icons/src/core/icon_generator.dart';
import 'package:launcher_icons/src/core/logger.dart';
import 'package:launcher_icons/src/platforms/linux/linux_icon_generator.dart';
import 'package:test/test.dart';

void main() {
  group('LinuxIconGenerator', () {
    late IconGeneratorContext context;
    late LinuxIconGenerator generator;
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('linux_icon_test');

      const config = Config(
        imagePath: 'assets/images/icon.png',
        linuxConfig: LinuxConfig(generate: true),
      );

      context = IconGeneratorContext(
        config: config,
        logger: LILogger(false),
        prefixPath: tempDir.path,
      );

      generator = LinuxIconGenerator(context);
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    /// Creates a minimal valid project layout (linux runner, icon file and
    /// a pubspec.yaml bundling the icon) inside [tempDir].
    Future<File> setUpValidProject({
      String iconPath = 'assets/images/icon.png',
      String? pubspecAssetsEntry,
    }) async {
      final linuxDir = Directory('${tempDir.path}/linux');
      await linuxDir.create();
      final runnerDir = Directory('${tempDir.path}/linux/runner');
      await runnerDir.create();

      final myAppFile = File('${tempDir.path}/linux/runner/my_application.cc');
      await myAppFile.create();

      final iconFile = File('${tempDir.path}/$iconPath');
      await iconFile.parent.create(recursive: true);
      // Real decodable bytes: the generator renders PNGs from the source.
      await iconFile.writeAsBytes(
        File('${Directory.current.path}/test/assets/master-light-1024.png').readAsBytesSync(),
      );

      final pubspecFile = File('${tempDir.path}/pubspec.yaml');
      await pubspecFile.writeAsString('''
name: test_app

flutter:
  assets:
    - ${pubspecAssetsEntry ?? iconPath}
''');
      return myAppFile;
    }

    test('platform name is Linux', () {
      expect(generator.platformName, equals('Linux'));
    });

    group('linuxEnabled', () {
      test('returns true when linux.generate is true', () {
        expect(context.config.linuxEnabled, isTrue);
      });

      test('returns false when linux.generate is false', () {
        const config = Config(
          imagePath: 'assets/images/icon.png',
          linuxConfig: LinuxConfig(generate: false),
        );

        final testContext = IconGeneratorContext(
          config: config,
          logger: LILogger(false),
          prefixPath: tempDir.path,
        );

        expect(testContext.config.linuxEnabled, isFalse);
      });

      test('returns false when linux config is missing', () {
        const config = Config(imagePath: 'assets/images/icon.png');

        final testContext = IconGeneratorContext(
          config: config,
          logger: LILogger(false),
          prefixPath: tempDir.path,
        );

        expect(testContext.config.linuxEnabled, isFalse);
      });
    });

    test('validateRequirements returns false when no image path provided', () {
      const config = Config(
        linuxConfig: LinuxConfig(generate: true),
      );

      final testContext = IconGeneratorContext(
        config: config,
        logger: LILogger(false),
        prefixPath: tempDir.path,
      );

      final testGenerator = LinuxIconGenerator(testContext);

      expect(testGenerator.validateRequirements(), isFalse);
    });

    test('validateRequirements accepts any pubspec-declared asset path', () async {
      const iconPath = 'images/icon.png';
      final linuxDir = Directory('${tempDir.path}/linux');
      await linuxDir.create();
      final runnerDir = Directory('${tempDir.path}/linux/runner');
      await runnerDir.create();
      await File('${tempDir.path}/linux/runner/my_application.cc').create();
      final iconFile = File('${tempDir.path}/$iconPath');
      await iconFile.parent.create(recursive: true);
      await iconFile.writeAsBytes([0]);
      await File('${tempDir.path}/pubspec.yaml').writeAsString('''
name: test_app

flutter:
  assets:
    - $iconPath
''');

      const config = Config(
        imagePath: iconPath,
        linuxConfig: LinuxConfig(generate: true),
      );
      final testContext = IconGeneratorContext(
        config: config,
        logger: LILogger(false),
        prefixPath: tempDir.path,
      );

      expect(LinuxIconGenerator(testContext).validateRequirements(), isTrue);
    });

    test('validateRequirements returns false when linux directory does not exist', () {
      expect(generator.validateRequirements(), isFalse);
    });

    test(
        'validateRequirements returns false when pubspec.yaml is missing '
        '(no .cc is written)', () async {
      // Valid on-disk layout except for pubspec.yaml.
      final linuxDir = Directory('${tempDir.path}/linux');
      await linuxDir.create();
      final runnerDir = Directory('${tempDir.path}/linux/runner');
      await runnerDir.create();
      final myAppFile = File('${tempDir.path}/linux/runner/my_application.cc');
      await myAppFile.writeAsString('// empty');

      final assetsDir = Directory('${tempDir.path}/assets/images');
      await assetsDir.create(recursive: true);
      await File('${tempDir.path}/assets/images/icon.png').writeAsBytes([0]); // dummy data

      expect(generator.validateRequirements(), isFalse);
      // Fail-fast: the .cc file must be left untouched.
      expect(await myAppFile.readAsString(), equals('// empty'));
    });

    test(
        'validateRequirements returns false when icon is missing from '
        'pubspec assets', () async {
      await setUpValidProject(pubspecAssetsEntry: 'assets/images/other.png');

      expect(generator.validateRequirements(), isFalse);
    });

    test('validateRequirements accepts a directory entry in pubspec assets', () async {
      await setUpValidProject(pubspecAssetsEntry: 'assets/images/');

      expect(generator.validateRequirements(), isTrue);
    });

    test('validateRequirements returns true when all requirements are met', () async {
      await setUpValidProject();

      expect(generator.validateRequirements(), isTrue);
    });

    test(
        'validateRequirements returns false when icon is missing from '
        'pubspec assets', () async {
      await setUpValidProject(pubspecAssetsEntry: 'assets/images/other.png');

      expect(generator.validateRequirements(), isFalse);
    });

    group('my_application.cc modifications', () {
      late File myAppFile;

      setUp(() async {
        // Create linux directory structure
        final linuxDir = Directory('${tempDir.path}/linux');
        await linuxDir.create();
        final runnerDir = Directory('${tempDir.path}/linux/runner');
        await runnerDir.create();

        // Create my_application.cc file
        myAppFile = File('${tempDir.path}/linux/runner/my_application.cc');

        // Create test icon file in assets (real decodable bytes: the
        // generator renders PNGs from the source).
        final assetsDir = Directory('${tempDir.path}/assets/images');
        await assetsDir.create(recursive: true);
        final iconFile = File('${tempDir.path}/assets/images/icon.png');
        await iconFile.writeAsBytes(
          File('${Directory.current.path}/test/assets/master-light-1024.png').readAsBytesSync(),
        );
      });

      // Canonical expectations for the default icon path.
      const canonicalUse = 'gtk_window_set_icon_from_file(window, linux_icon_path, NULL);';
      const helperSignature = 'static gchar* get_flutter_asset_path(const gchar* asset_path)';
      const exeResolution = 'g_file_read_link("/proc/self/exe"';
      const gioInclude = '#include <gio/gio.h>';

      void expectCanonicalBlock(String content, [String? iconPath]) {
        final path = iconPath ?? 'assets/images/icon.png';
        expect(
          content,
          contains('get_flutter_asset_path("$path")'),
        );
        expect(content, contains(canonicalUse));
        expect(content, contains(helperSignature));
        expect(content, contains(exeResolution));
        expect(content, contains(gioInclude));
      }

      test('adds exe-relative block before gtk_window_set_default_size', () async {
        const originalContent = '''
#include "my_application.h"

static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window = GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
  
  gtk_window_set_default_size(window, 1280, 720);
  gtk_widget_show(GTK_WIDGET(window));
}
''';

        await myAppFile.writeAsString(originalContent);
        await generator.createIcons();

        final modifiedContent = await myAppFile.readAsString();
        expectCanonicalBlock(modifiedContent);
        // Block is inserted before gtk_window_set_default_size.
        final lines = modifiedContent.split('\n');
        final iconLineIndex = lines.indexWhere(
          (line) => line.contains('get_flutter_asset_path("'),
        );
        final defaultSizeLineIndex = lines.indexWhere(
          (line) => line.contains('gtk_window_set_default_size'),
        );
        expect(iconLineIndex, lessThan(defaultSizeLineIndex));
        // No naive relative path: the call must use the resolved variable.
        expect(
          modifiedContent,
          isNot(contains('gtk_window_set_icon_from_file(window, "assets/')),
        );
      });

      test('adds gio include only once', () async {
        const originalContent = '''
#include "my_application.h"
#include <gio/gio.h>

static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window = GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
  gtk_window_set_default_size(window, 1280, 720);
  gtk_widget_show(GTK_WIDGET(window));
}
''';

        await myAppFile.writeAsString(originalContent);
        await generator.createIcons();

        final modifiedContent = await myAppFile.readAsString();
        expectCanonicalBlock(modifiedContent);
        final includeCount = modifiedContent.split('\n').where((line) => line.trim() == gioInclude).length;
        expect(includeCount, equals(1));
      });

      test('inserts asset helper before my_application_activate', () async {
        const originalContent = '''
#include "my_application.h"

static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window = GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
  gtk_window_set_default_size(window, 1280, 720);
  gtk_widget_show(GTK_WIDGET(window));
}
''';

        await myAppFile.writeAsString(originalContent);
        await generator.createIcons();

        final modifiedContent = await myAppFile.readAsString();
        final helperIndex = modifiedContent.indexOf(helperSignature);
        final activateIndex = modifiedContent.indexOf(
          'static void my_application_activate',
        );
        expect(helperIndex, isNot(equals(-1)));
        expect(helperIndex, lessThan(activateIndex));
      });

      test('uses fallback location after window declaration for single line', () async {
        const originalContent = '''
#include "my_application.h"

static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window = GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
  gtk_widget_show(GTK_WIDGET(window));
}
''';

        await myAppFile.writeAsString(originalContent);
        await generator.createIcons();

        final modifiedContent = await myAppFile.readAsString();
        expectCanonicalBlock(modifiedContent);
        // Should be inserted after the window declaration line
        final lines = modifiedContent.split('\n');
        final windowLineIndex = lines.indexWhere((line) => line.contains('GtkWindow* window ='));
        final iconLineIndex = lines.indexWhere(
          (line) => line.contains('get_flutter_asset_path("'),
        );
        expect(iconLineIndex, greaterThan(windowLineIndex));
      });

      test('handles multiline window declaration', () async {
        const originalContent = '''
#include "my_application.h"

static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(
          GTK_APPLICATION(application)));
  gtk_widget_show(GTK_WIDGET(window));
}
''';

        await myAppFile.writeAsString(originalContent);
        await generator.createIcons();

        final modifiedContent = await myAppFile.readAsString();
        expectCanonicalBlock(modifiedContent);
        // Should be inserted after the multiline window declaration
        final lines = modifiedContent.split('\n');
        final windowLineIndex = lines.indexWhere((line) => line.contains('GtkWindow* window ='));
        final iconLineIndex = lines.indexWhere(
          (line) => line.contains('get_flutter_asset_path("'),
        );
        expect(iconLineIndex, greaterThan(windowLineIndex));
      });

      test('uses custom icon path from linux config', () async {
        const config = Config(
          imagePath: 'assets/images/default.png',
          linuxConfig: LinuxConfig(
            generate: true,
            imagePath: 'assets/icons/custom.png',
          ),
        );

        final testContext = IconGeneratorContext(
          config: config,
          logger: LILogger(false),
          prefixPath: tempDir.path,
        );

        final testGenerator = LinuxIconGenerator(testContext);

        // Create custom icon file (real decodable bytes: the generator
        // renders PNGs from the source).
        final iconsDir = Directory('${tempDir.path}/assets/icons');
        await iconsDir.create(recursive: true);
        final customIconFile = File('${tempDir.path}/assets/icons/custom.png');
        await customIconFile.writeAsBytes(
          File('${Directory.current.path}/test/assets/master-light-1024.png').readAsBytesSync(),
        );

        const originalContent = '''
#include "my_application.h"

static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window = GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
  gtk_window_set_default_size(window, 1280, 720);
  gtk_widget_show(GTK_WIDGET(window));
}
''';

        await myAppFile.writeAsString(originalContent);
        await testGenerator.createIcons();

        final modifiedContent = await myAppFile.readAsString();
        expectCanonicalBlock(
          modifiedContent,
          'assets/icons/custom.png',
        );
      });

      test(
          'does not duplicate block when already present with same path '
          '(idempotent)', () async {
        const originalContent = '''
#include "my_application.h"

static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window = GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
  gtk_window_set_default_size(window, 1280, 720);
  gtk_widget_show(GTK_WIDGET(window));
}
''';

        await myAppFile.writeAsString(originalContent);
        await generator.createIcons();
        final afterFirstRun = await myAppFile.readAsString();
        await generator.createIcons();
        final afterSecondRun = await myAppFile.readAsString();

        expect(afterSecondRun, equals(afterFirstRun));
        expect(
          afterSecondRun.split(helperSignature).length - 1,
          equals(1),
        );
        expect(
          afterSecondRun.split(canonicalUse).length - 1,
          equals(1),
        );
      });

      test('no-op when canonical block already has the correct path', () async {
        const originalContent = '''
#include "my_application.h"
#include <gio/gio.h>

static gchar* get_flutter_asset_path(const gchar* asset_path) {
  g_autofree gchar* executable = g_file_read_link("/proc/self/exe", NULL);
  if (executable == NULL) {
    return g_strdup(asset_path);
  }
  g_autofree gchar* executable_dir = g_path_get_dirname(executable);
  return g_build_filename(executable_dir, "data", "flutter_assets", asset_path, NULL);
}

static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window = GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
  g_autofree gchar* linux_icon_path = get_flutter_asset_path("assets/images/icon.png");
  gtk_window_set_icon_from_file(window, linux_icon_path, NULL);
  gtk_window_set_default_size(window, 1280, 720);
  gtk_widget_show(GTK_WIDGET(window));
}
''';

        await myAppFile.writeAsString(originalContent);
        await generator.createIcons();

        final modifiedContent = await myAppFile.readAsString();
        expect(modifiedContent, equals(originalContent));
      });

      test('updates path inside canonical block when path is different', () async {
        const originalContent = '''
#include "my_application.h"
#include <gio/gio.h>

static gchar* get_flutter_asset_path(const gchar* asset_path) {
  g_autofree gchar* executable = g_file_read_link("/proc/self/exe", NULL);
  if (executable == NULL) {
    return g_strdup(asset_path);
  }
  g_autofree gchar* executable_dir = g_path_get_dirname(executable);
  return g_build_filename(executable_dir, "data", "flutter_assets", asset_path, NULL);
}

static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window = GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
  g_autofree gchar* linux_icon_path = get_flutter_asset_path("assets/images/old_icon.png");
  gtk_window_set_icon_from_file(window, linux_icon_path, NULL);
  gtk_window_set_default_size(window, 1280, 720);
  gtk_widget_show(GTK_WIDGET(window));
}
''';

        await myAppFile.writeAsString(originalContent);
        await generator.createIcons();

        final modifiedContent = await myAppFile.readAsString();
        expectCanonicalBlock(modifiedContent);
        // Should not contain the old icon path
        expect(modifiedContent, isNot(contains('old_icon.png')));
        // Helper must not be duplicated by the update.
        expect(
          modifiedContent.split(helperSignature).length - 1,
          equals(1),
        );
      });

      test('upgrades legacy single-line call to the exe-relative block', () async {
        const originalContent = '''
#include "my_application.h"

static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window = GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
  gtk_window_set_icon_from_file(window, "assets/images/old_icon.png", NULL);
  gtk_window_set_default_size(window, 1280, 720);
  gtk_widget_show(GTK_WIDGET(window));
}
''';

        await myAppFile.writeAsString(originalContent);
        await generator.createIcons();

        final modifiedContent = await myAppFile.readAsString();
        expectCanonicalBlock(modifiedContent);
        // Only the canonical call remains; the legacy literal is gone.
        expect(
          modifiedContent.split(canonicalUse).length - 1,
          equals(1),
        );
        expect(modifiedContent, isNot(contains('old_icon.png')));
      });

      test('upgrades legacy multi-line call to the exe-relative block', () async {
        const originalContent = '''
#include "my_application.h"

static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window = GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
  gtk_window_set_icon_from_file(window,
                               "assets/images/old_icon.png",
                               NULL);
  gtk_window_set_default_size(window, 1280, 720);
  gtk_widget_show(GTK_WIDGET(window));
}
''';

        await myAppFile.writeAsString(originalContent);
        await generator.createIcons();

        final modifiedContent = await myAppFile.readAsString();
        expectCanonicalBlock(modifiedContent);
        expect(
          modifiedContent.split(canonicalUse).length - 1,
          equals(1),
        );
        expect(modifiedContent, isNot(contains('old_icon.png')));
      });

      test('upgrades legacy call with extra whitespace and formatting', () async {
        const originalContent = '''
#include "my_application.h"

static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window = GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
    gtk_window_set_icon_from_file(  window  ,  "assets/images/old_icon.png"  ,  NULL  );
  gtk_window_set_default_size(window, 1280, 720);
  gtk_widget_show(GTK_WIDGET(window));
}
''';

        await myAppFile.writeAsString(originalContent);
        await generator.createIcons();

        final modifiedContent = await myAppFile.readAsString();
        expectCanonicalBlock(modifiedContent);
        expect(
          modifiedContent.split(canonicalUse).length - 1,
          equals(1),
        );
        expect(modifiedContent, isNot(contains('old_icon.png')));
      });

      test('uses fallback strategy 3: inserts before gtk_window_show', () async {
        const originalContent = '''
#include "my_application.h"

static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window = GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
  gtk_window_show(window);
}
''';

        await myAppFile.writeAsString(originalContent);
        await generator.createIcons();

        final modifiedContent = await myAppFile.readAsString();
        expectCanonicalBlock(modifiedContent);
        // Should be inserted before gtk_window_show
        final lines = modifiedContent.split('\n');
        final iconLineIndex = lines.indexWhere(
          (line) => line.contains('get_flutter_asset_path("'),
        );
        final showLineIndex = lines.indexWhere((line) => line.contains('gtk_window_show'));
        expect(iconLineIndex, lessThan(showLineIndex));
      });

      test('uses fallback strategy 3: inserts before gtk_widget_show', () async {
        const originalContent = '''
#include "my_application.h"

static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window = GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
  gtk_widget_show(GTK_WIDGET(window));
}
''';

        await myAppFile.writeAsString(originalContent);
        await generator.createIcons();

        final modifiedContent = await myAppFile.readAsString();
        expectCanonicalBlock(modifiedContent);
        // Should be inserted before gtk_widget_show
        final lines = modifiedContent.split('\n');
        final iconLineIndex = lines.indexWhere(
          (line) => line.contains('get_flutter_asset_path("'),
        );
        final showLineIndex = lines.indexWhere((line) => line.contains('gtk_widget_show'));
        expect(iconLineIndex, lessThan(showLineIndex));
      });

      test('uses fallback strategy 4: inserts after any gtk_window function', () async {
        const originalContent = '''
#include "my_application.h"

static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  // window is passed as parameter, so no window declaration to trigger strategy 2
  gtk_window_set_title(window, "My App");
  // No other gtk_window functions that would trigger earlier strategies
}
''';

        await myAppFile.writeAsString(originalContent);
        await generator.createIcons();

        final modifiedContent = await myAppFile.readAsString();
        expectCanonicalBlock(modifiedContent);
        // Should be inserted after gtk_window_set_title
        final lines = modifiedContent.split('\n');
        final titleLineIndex = lines.indexWhere((line) => line.contains('gtk_window_set_title'));
        final iconLineIndex = lines.indexWhere(
          (line) => line.contains('get_flutter_asset_path("'),
        );
        expect(iconLineIndex, greaterThan(titleLineIndex));
      });

      test('preserves indentation from surrounding code', () async {
        const originalContent = '''
#include "my_application.h"

static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
    GtkWindow* window = GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
    gtk_window_set_default_size(window, 1280, 720);
    gtk_widget_show(GTK_WIDGET(window));
}
''';

        await myAppFile.writeAsString(originalContent);
        await generator.createIcons();

        final modifiedContent = await myAppFile.readAsString();
        // Should preserve the 4-space indentation from the surrounding code
        expect(
          modifiedContent,
          contains(
            '    g_autofree gchar* linux_icon_path = get_flutter_asset_path("assets/images/icon.png");',
          ),
        );
        expect(
          modifiedContent,
          contains(
            '    gtk_window_set_icon_from_file(window, linux_icon_path, NULL);',
          ),
        );
      });

      test('handles window declaration with different pointer syntax', () async {
        const originalContent = '''
#include "my_application.h"

static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow *window = GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
  gtk_widget_show(GTK_WIDGET(window));
}
''';

        await myAppFile.writeAsString(originalContent);
        await generator.createIcons();

        final modifiedContent = await myAppFile.readAsString();
        expectCanonicalBlock(modifiedContent);
        // Should be inserted after the window declaration
        final lines = modifiedContent.split('\n');
        final windowLineIndex = lines.indexWhere((line) => line.contains('GtkWindow *window ='));
        final iconLineIndex = lines.indexWhere(
          (line) => line.contains('get_flutter_asset_path("'),
        );
        expect(iconLineIndex, greaterThan(windowLineIndex));
      });

      test('handles complex multi-line window declaration with multiple GTK calls', () async {
        const originalContent = '''
#include "my_application.h"

static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(
          gtk_application_window_new(
              GTK_APPLICATION(application)));
  gtk_widget_show(GTK_WIDGET(window));
}
''';

        await myAppFile.writeAsString(originalContent);
        await generator.createIcons();

        final modifiedContent = await myAppFile.readAsString();
        expectCanonicalBlock(modifiedContent);
        // Should be inserted after the complete window declaration
        final lines = modifiedContent.split('\n');
        final windowLineIndex = lines.indexWhere((line) => line.contains('GtkWindow* window ='));
        final iconLineIndex = lines.indexWhere(
          (line) => line.contains('get_flutter_asset_path("'),
        );
        expect(iconLineIndex, greaterThan(windowLineIndex));
        // Should be before the show call
        final showLineIndex = lines.indexWhere((line) => line.contains('gtk_widget_show'));
        expect(iconLineIndex, lessThan(showLineIndex));
      });

      test('provides helpful error message when no insertion point found', () async {
        const originalContent = '''
#include "my_application.h"

static void my_application_activate(GApplication* application) {
  // Some other content without the expected patterns
  g_print("Hello World\\n");
}
''';

        await myAppFile.writeAsString(originalContent);

        try {
          await generator.createIcons();
          fail('Expected an exception to be thrown');
        } catch (e) {
          expect(e.toString(), contains('Failed to update my_application.cc'));
          // The error message should contain the manual instructions
          expect(
            e.toString(),
            contains('get_flutter_asset_path("assets/images/icon.png")'),
          );
          expect(
            e.toString(),
            contains(
              'gtk_window_set_icon_from_file(window, linux_icon_path, NULL);',
            ),
          );
          // The 2-line call depends on the helper + include, so the message
          // must spell those out as well.
          expect(e.toString(), contains('#include <gio/gio.h>'));
          expect(
            e.toString(),
            contains('static gchar* get_flutter_asset_path'),
          );
        }
      });

      test('handles deeply nested statements with proper detection', () async {
        const originalContent = '''
#include "my_application.h"

static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window = GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
  
  if (some_condition) {
    gtk_window_set_icon_from_file(
        window,
        "assets/images/nested_icon.png",
        NULL
    );
  }
  
  gtk_window_set_default_size(window, 1280, 720);
  gtk_widget_show(GTK_WIDGET(window));
}
''';

        await myAppFile.writeAsString(originalContent);
        await generator.createIcons();

        final modifiedContent = await myAppFile.readAsString();
        // The nested legacy call is upgraded to the canonical block.
        expectCanonicalBlock(modifiedContent);
        expect(
          modifiedContent.split(canonicalUse).length - 1,
          equals(1),
        );
        // Should not contain the old icon path
        expect(modifiedContent, isNot(contains('nested_icon.png')));
      });
    });
  });
}
