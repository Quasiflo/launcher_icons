import 'dart:io';

import 'package:launcher_icons/src/config/config.dart';
import 'package:launcher_icons/src/core/constants.dart';
import 'package:launcher_icons/src/core/logger.dart';
import 'package:launcher_icons/src/core/paths.dart' as paths;
import 'package:launcher_icons/src/platforms/android/android.dart' as android;
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

/// Captures `info` output so logger routing can be asserted.
class _RecordingLogger extends LILogger {
  final List<String> messages = <String>[];

  _RecordingLogger() : super(false);

  @override
  void info(Object? message) {
    messages.add(message.toString());
  }
}

// unit tests for android.dart
void main() {
  group('printStatus logger routing', () {
    test('status messages route through the provided logger', () async {
      final logger = _RecordingLogger();
      // Exercise the nested pass-through (updateColorsXmlFile) with a color background inside the adaptive sandbox below.
      final config = Config.fromJson(<String, dynamic>{
        'android': {
          'generate': true,
          'adaptive_icon_background': '#ffffff',
          'adaptive_icon_foreground': 'master-light-1024.png',
        },
      });
      // Reuse the adaptive sandbox layout: android/ + icon file.
      final sandboxDir = path.join(
        '.dart_tool',
        'launcher_icons',
        'test',
        'android_logger',
      );
      final sandbox = Directory(sandboxDir);
      if (sandbox.existsSync()) {
        sandbox.deleteSync(recursive: true);
      }
      sandbox.createSync(recursive: true);
      File(
        path.join(
          Directory.current.path,
          'test',
          'assets',
          'master-light-1024.png',
        ),
      ).copySync(path.join(sandboxDir, 'master-light-1024.png'));
      final originalDir = Directory.current.path;
      Directory.current = sandboxDir;
      try {
        await android.createAdaptiveIcons(config, null, logger: logger);
      } finally {
        Directory.current = originalDir;
      }
      expect(
        logger.messages.any((m) => m.contains('Creating adaptive icons Android')),
        isTrue,
      );
      expect(
        logger.messages.any((m) => m.contains('colors.xml')),
        isTrue,
      );
    });
  });

  test('Adaptive icon mipmap path is correct', () {
    const String path1 = 'android/app/src/main/res/';
    const String path2 = 'mipmap-anydpi-v26/';
    expect(android.isCorrectMipmapDirectoryForAdaptiveIcon(path1), false);
    expect(android.isCorrectMipmapDirectoryForAdaptiveIcon(path2), false);
    expect(
      android.isCorrectMipmapDirectoryForAdaptiveIcon(
        paths.androidAdaptiveXmlFolder(null),
      ),
      true,
    );
  });

  test('Adaptive icon background image paths are detected', () {
    expect(
      android.isAdaptiveIconConfigImageFile('assets/adaptive-bg-1024.png'),
      isTrue,
    );
    expect(
      android.isAdaptiveIconConfigImageFile('assets/adaptive-bg-1024.PNG'),
      isTrue,
    );
    expect(
      android.isAdaptiveIconConfigImageFile('assets/adaptive-bg-1024.jpg'),
      isTrue,
    );
    expect(
      android.isAdaptiveIconConfigImageFile('assets/adaptive-bg-1024.JPG'),
      isTrue,
    );
    expect(
      android.isAdaptiveIconConfigImageFile('assets/adaptive-bg-1024.jpeg'),
      isTrue,
    );
    expect(
      android.isAdaptiveIconConfigImageFile('assets/adaptive-bg-1024.Jpeg'),
      isTrue,
    );
    expect(
      android.isAdaptiveIconConfigImageFile('assets/adaptive-bg-1024.webp'),
      isTrue,
    );
    expect(
      android.isAdaptiveIconConfigImageFile('assets/background.WEBP'),
      isTrue,
    );
    expect(
      android.isAdaptiveIconConfigImageFile('assets/background.svg'),
      isTrue,
    );
    expect(
      android.isAdaptiveIconConfigImageFile('assets/background.SVG'),
      isTrue,
    );
    expect(android.isAdaptiveIconConfigImageFile('#ffffff'), isFalse);
  });

  group('adaptive icon background generation', () {
    late String originalDir;
    late String sandboxDir;

    setUp(() {
      originalDir = Directory.current.path;
      sandboxDir = path.join(
        '.dart_tool',
        'launcher_icons',
        'test',
        'android_adaptive',
      );
      final sandbox = Directory(sandboxDir);
      if (sandbox.existsSync()) {
        sandbox.deleteSync(recursive: true);
      }
      sandbox.createSync(recursive: true);
      File(path.join(originalDir, 'test', 'assets', 'master-light-1024.png')).copySync(path.join(sandboxDir, 'master-light-1024.png'));
      File(path.join(originalDir, 'test', 'assets', 'adaptive-bg-1024.jpg')).copySync(path.join(sandboxDir, 'adaptive-bg-1024.jpg'));
      File(path.join(originalDir, 'test', 'assets', 'adaptive-bg-1024.webp')).copySync(path.join(sandboxDir, 'adaptive-bg-1024.webp'));
      Directory.current = sandboxDir;
    });

    tearDown(() {
      Directory.current = originalDir;
    });

    String backgroundPngPath(android.AndroidIconTemplate template) => path.join(
          'android',
          'app',
          'src',
          'main',
          'res',
          template.directoryName,
          paths.androidAdaptiveBackgroundFileName,
        );

    test('jpg background generates background PNGs and @drawable mipmap', () async {
      final config = Config.fromJson(<String, dynamic>{
        'android': {
          'generate': true,
          'adaptive_icon_background': 'adaptive-bg-1024.jpg',
          'adaptive_icon_foreground': 'master-light-1024.png',
        },
      });

      await android.createAdaptiveIcons(config, null);

      for (final template in android.adaptiveForegroundIcons) {
        expect(
          File(backgroundPngPath(template)).existsSync(),
          isTrue,
          reason: backgroundPngPath(template),
        );
      }
      expect(
        File(paths.androidColorsFile(null)).existsSync(),
        isFalse,
        reason: 'colors.xml should not be written for an image background',
      );

      await android.createMipmapXmlFile(config, null);
      final mipmapXml = File(
        path.join(
              paths.androidAdaptiveXmlFolder(null),
              androidDefaultIconName,
            ) +
            '.xml',
      ).readAsStringSync();
      expect(mipmapXml, contains('@drawable/ic_launcher_background'));
    });

    test('webp background generates background PNGs', () async {
      final config = Config.fromJson(<String, dynamic>{
        'android': {
          'generate': true,
          'adaptive_icon_background': 'adaptive-bg-1024.webp',
          'adaptive_icon_foreground': 'master-light-1024.png',
        },
      });

      await android.createAdaptiveIcons(config, null);

      for (final template in android.adaptiveForegroundIcons) {
        expect(
          File(backgroundPngPath(template)).existsSync(),
          isTrue,
          reason: backgroundPngPath(template),
        );
      }
    });

    test('hex color background writes colors.xml and @color mipmap', () async {
      final config = Config.fromJson(<String, dynamic>{
        'android': {
          'generate': true,
          'adaptive_icon_background': '#ffffff',
          'adaptive_icon_foreground': 'master-light-1024.png',
        },
      });

      await android.createAdaptiveIcons(config, null);

      final colorsFile = File(paths.androidColorsFile(null));
      expect(colorsFile.existsSync(), isTrue);
      expect(colorsFile.readAsStringSync(), contains('#ffffff'));
      expect(
        File(backgroundPngPath(android.adaptiveForegroundIcons.first)).existsSync(),
        isFalse,
        reason: 'colors should not produce background PNGs',
      );

      await android.createMipmapXmlFile(config, null);
      final mipmapXml = File(
        path.join(
              paths.androidAdaptiveXmlFolder(null),
              androidDefaultIconName,
            ) +
            '.xml',
      ).readAsStringSync();
      expect(mipmapXml, contains('@color/ic_launcher_background'));
    });

    test('bare hex background gains a # prefix in colors.xml', () async {
      final config = Config.fromJson(<String, dynamic>{
        'android': {
          'generate': true,
          'adaptive_icon_background': 'ffffff',
          'adaptive_icon_foreground': 'master-light-1024.png',
        },
      });

      await android.createAdaptiveIcons(config, null);

      final colorsFile = File(paths.androidColorsFile(null));
      expect(colorsFile.existsSync(), isTrue);
      expect(
        colorsFile.readAsStringSync(),
        contains(
          '<color name="ic_launcher_background">#ffffff</color>',
        ),
      );
    });

    test('transparent background skips colors.xml, uses system color', () async {
      final config = Config.fromJson(<String, dynamic>{
        'android': {
          'generate': true,
          'adaptive_icon_background': 'Transparent',
          'adaptive_icon_foreground': 'master-light-1024.png',
        },
      });

      await android.createAdaptiveIcons(config, null);
      expect(File(paths.androidColorsFile(null)).existsSync(), isFalse);

      await android.createMipmapXmlFile(config, null);
      final mipmapXml = File(
        path.join(
              paths.androidAdaptiveXmlFolder(null),
              androidDefaultIconName,
            ) +
            '.xml',
      ).readAsStringSync();
      expect(
        mipmapXml,
        contains(
          '<background android:drawable="@android:color/transparent"/>',
        ),
      );
      expect(mipmapXml, isNot(contains('@color/ic_launcher_background')));
    });

    test('removes stale adaptive artifacts without adaptive config', () async {
      final staleXml = File(
        path.join(
              paths.androidAdaptiveXmlFolder(null),
              androidDefaultIconName,
            ) +
            '.xml',
      );
      await staleXml.create(recursive: true);
      await staleXml.writeAsString('<stale/>');
      final staleForeground = File(
        path.join(
          'android',
          'app',
          'src',
          'main',
          'res',
          'drawable-mdpi',
          paths.androidAdaptiveForegroundFileName,
        ),
      );
      await staleForeground.create(recursive: true);
      await staleForeground.writeAsBytes([0]);

      final config = Config.fromJson(<String, dynamic>{
        'android': {'generate': true},
      });

      await android.createMipmapXmlFile(config, null);

      expect(staleXml.existsSync(), isFalse);
      expect(staleForeground.existsSync(), isFalse);
    });
  });

  group('adaptive monochrome mipmap', () {
    late String originalDir;
    late String sandboxDir;

    setUp(() {
      originalDir = Directory.current.path;
      sandboxDir = path.join(
        '.dart_tool',
        'launcher_icons',
        'test',
        'android_monochrome',
      );
      final sandbox = Directory(sandboxDir);
      if (sandbox.existsSync()) {
        sandbox.deleteSync(recursive: true);
      }
      sandbox.createSync(recursive: true);
      File(path.join(originalDir, 'test', 'assets', 'master-light-1024.png')).copySync(path.join(sandboxDir, 'master-light-1024.png'));
      Directory.current = sandboxDir;
    });

    tearDown(() {
      Directory.current = originalDir;
    });

    String mipmapXmlPath() =>
        path.join(
          paths.androidAdaptiveXmlFolder(null),
          androidDefaultIconName,
        ) +
        '.xml';

    Future<String> mipmapXmlFor(Map<String, dynamic> androidSection) async {
      final config = Config.fromJson(<String, dynamic>{
        'android': androidSection,
      });
      await android.createAdaptiveMonochromeIcons(config, null);
      await android.createMipmapXmlFile(config, null);
      return File(mipmapXmlPath()).readAsStringSync();
    }

    test('zero inset emits the canonical plain monochrome form', () async {
      final mipmapXml = await mipmapXmlFor(<String, dynamic>{
        'generate': true,
        'adaptive_icon_monochrome': 'master-light-1024.png',
        'adaptive_icon_foreground_inset': 0,
      });
      expect(
        mipmapXml,
        contains(
          '<monochrome android:drawable="@drawable/ic_launcher_monochrome" />',
        ),
      );
      expect(mipmapXml, isNot(contains('<inset')));
    });

    test('nonzero inset wraps monochrome in an inset block', () async {
      final mipmapXml = await mipmapXmlFor(<String, dynamic>{
        'generate': true,
        'adaptive_icon_monochrome': 'master-light-1024.png',
      });
      expect(mipmapXml, contains('<monochrome>'));
      expect(
        mipmapXml,
        contains(
          '<inset\n'
          '          android:drawable="@drawable/ic_launcher_monochrome"\n'
          '          android:inset="16%" />',
        ),
      );
    });
  });

  test('Correct number of adaptive foreground icons', () {
    expect(android.adaptiveForegroundIcons.length, 5);
  });

  test('Correct number of android launcher icons', () {
    expect(android.androidIcons.length, 5);
  });

  test('Config contains string for generating new launcher icons', () {
    final Map<String, dynamic> flutterIconsConfig = <String, dynamic>{
      'image_path': 'assets/images/icon-710x599.png',
      'android': {'generate': true},
      'ios': {'generate': true},
    };
    expect(
      android.isCustomAndroidFile(Config.fromJson(flutterIconsConfig)),
      isFalse,
    );

    final Map<String, dynamic> flutterIconsNewIconConfig = <String, dynamic>{
      'image_path': 'assets/images/icon-710x599.png',
      'android': {'generate': true, 'icon_name': 'New Icon'},
      'ios': {'generate': true},
    };
    expect(
      android.isCustomAndroidFile(Config.fromJson(flutterIconsNewIconConfig)),
      isTrue,
    );
  });

  test('Transforming manifest without icon must add icon', () async {
    final String inputManifest = getAndroidManifestExample('android:icon="@mipmap/ic_launcher"');
    final String expectedManifest = getAndroidManifestExample('android:icon="@mipmap/ic_other_icon_name"');

    await withTempFile('AndroidManifest.xml', (File androidManifestFile) async {
      androidManifestFile.writeAsStringSync(inputManifest);
      await android.overwriteAndroidManifestWithNewLauncherIcon(
        'ic_other_icon_name',
        androidManifestFile,
      );
      expect(androidManifestFile.readAsStringSync(), equals(expectedManifest));
    });
  });

  test('Transforming manifest with icon already in place should leave it unchanged', () async {
    final String inputManifest = getAndroidManifestExample('android:icon="@mipmap/ic_launcher"');
    final String expectedManifest = getAndroidManifestExample('android:icon="@mipmap/ic_launcher"');

    await withTempFile('AndroidManifest.xml', (File androidManifestFile) async {
      androidManifestFile.writeAsStringSync(inputManifest);
      await android.overwriteAndroidManifestWithNewLauncherIcon(
        'ic_launcher',
        androidManifestFile,
      );
      expect(androidManifestFile.readAsStringSync(), equals(expectedManifest));
    });
  });

  test('Transforming manifest with trailing newline should keep newline untouched', () async {
    final String inputManifest = getAndroidManifestExample('android:icon="@mipmap/ic_launcher"') + '\n';
    final String expectedManifest = inputManifest;

    await withTempFile('AndroidManifest.xml', (File androidManifestFile) async {
      androidManifestFile.writeAsStringSync(inputManifest);
      await android.overwriteAndroidManifestWithNewLauncherIcon(
        'ic_launcher',
        androidManifestFile,
      );
      expect(androidManifestFile.readAsStringSync(), equals(expectedManifest));
    });
  });

  test('Transforming manifest with 3 trailing newlines should keep newlines untouched', () async {
    final String inputManifest = getAndroidManifestExample('android:icon="@mipmap/ic_launcher"') + '\n\n\n';
    final String expectedManifest = inputManifest;

    await withTempFile('AndroidManifest.xml', (File androidManifestFile) async {
      androidManifestFile.writeAsStringSync(inputManifest);
      await android.overwriteAndroidManifestWithNewLauncherIcon(
        'ic_launcher',
        androidManifestFile,
      );
      expect(androidManifestFile.readAsStringSync(), equals(expectedManifest));
    });
  });

  test('Transforming manifest with special newline characters should leave special newline characters untouched', () async {
    final String inputManifest = getAndroidManifestExample('android:icon="@mipmap/ic_launcher"').replaceAll('\n', '\r\n');
    final String expectedManifest = inputManifest;

    await withTempFile('AndroidManifest.xml', (File androidManifestFile) async {
      androidManifestFile.writeAsStringSync(inputManifest);
      await android.overwriteAndroidManifestWithNewLauncherIcon(
        'ic_launcher',
        androidManifestFile,
      );
      expect(androidManifestFile.readAsStringSync(), equals(expectedManifest));
    });
  });
}

Future<void> withTempFile(String fileName, Function block) async {
  final Directory tempDir = Directory.systemTemp.createTempSync();
  final File file = File('${tempDir.path}/$fileName')..createSync();
  if (!file.existsSync()) {
    fail('Could not create temp test file ${file.path}');
  }
  try {
    await block(file);
  } finally {
    file.deleteSync();
  }
}

String getAndroidManifestExample(String iconLine) {
  return '''
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.example.myapplication">

    <application
        android:allowBackup="true"
        $iconLine
        android:label="@string/app_name"
        android:roundIcon="@mipmap/ic_launcher_round"
        android:supportsRtl="true"
        android:theme="@style/AppTheme">
        <activity
            android:name=".MainActivity"
            android:label="@string/app_name"
            android:theme="@style/AppTheme.NoActionBar">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />

                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>

</manifest>
  '''
      .trim();
}
