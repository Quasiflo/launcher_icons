import 'dart:io';

import 'package:image/image.dart';
import 'package:launcher_icons/src/config/config.dart';
import 'package:launcher_icons/src/core/custom_exceptions.dart';
import 'package:launcher_icons/src/core/icon_generator.dart';
import 'package:launcher_icons/src/core/logger.dart';
import 'package:launcher_icons/src/platforms/android/android.dart' as android;
import 'package:launcher_icons/src/platforms/android/android_icon_generator.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

const _manifest = '''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:label="@string/app_name"
        android:icon="@mipmap/ic_launcher">
    </application>
</manifest>
''';

const _vectorDrawable = '''
<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="108dp" android:height="108dp" android:viewportWidth="108" android:viewportHeight="108">
    <path android:fillColor="#FF000000" android:pathData="M54,10 L98,54 L54,98 L10,54 Z" />
</vector>
''';

void main() {
  late String prefixPath;
  late Directory sandbox;

  setUp(() {
    sandbox = Directory(
      path.join(
        Directory.current.path,
        '.dart_tool',
        'launcher_icons',
        'test',
        'android_layers',
      ),
    );
    if (sandbox.existsSync()) {
      sandbox.deleteSync(recursive: true);
    }
    sandbox.createSync(recursive: true);
    prefixPath = sandbox.absolute.path;
    final assets = path.join(Directory.current.path, 'test', 'assets');
    File(path.join(assets, 'master-light-1024.png')).copySync(path.join(prefixPath, 'master-light-1024.png'));
    File(path.join(prefixPath, 'foreground.xml')).writeAsStringSync(_vectorDrawable);
    Directory(
      path.join(prefixPath, 'android', 'app', 'src', 'main'),
    ).createSync(recursive: true);
    File(
      path.join(
        prefixPath,
        'android',
        'app',
        'src',
        'main',
        'AndroidManifest.xml',
      ),
    ).writeAsStringSync(_manifest);
  });

  tearDown(() {
    if (sandbox.existsSync()) {
      sandbox.deleteSync(recursive: true);
    }
  });

  String resPath(final List<String> parts) => path.join(prefixPath, 'android', 'app', 'src', 'main', 'res', path.joinAll(parts));

  Config pairConfig(final Map<String, dynamic> extra) => Config.fromJson(<String, dynamic>{
        'android': {
          'generate': true,
          'image_path': 'master-light-1024.png',
          'adaptive_icon_background': '#ffffff',
          'adaptive_icon_foreground': 'master-light-1024.png',
          ...extra,
        },
      });

  group('monochrome pair guard (hard error)', () {
    test('createAdaptiveMonochromeIcons throws without the adaptive pair', () async {
      final config = Config.fromJson(<String, dynamic>{
        'android': {
          'generate': true,
          'image_path': 'master-light-1024.png',
          'adaptive_icon_monochrome': 'master-light-1024.png',
        },
      });

      await expectLater(
        android.createAdaptiveMonochromeIcons(config, null, prefixPath: prefixPath),
        throwsA(isA<InvalidConfigException>()),
      );
    });

    test('createMipmapXmlFile throws for lone monochrome', () async {
      final config = Config.fromJson(<String, dynamic>{
        'android': {
          'generate': true,
          'image_path': 'master-light-1024.png',
          'adaptive_icon_monochrome': 'master-light-1024.png',
        },
      });

      await expectLater(
        android.createMipmapXmlFile(config, null, prefixPath: prefixPath),
        throwsA(isA<InvalidConfigException>()),
      );
    });

    test('monochrome with the pair emits the layer', () async {
      final config = pairConfig({'adaptive_icon_monochrome': 'master-light-1024.png'});

      await android.createAdaptiveMonochromeIcons(config, null, prefixPath: prefixPath);
      await android.createMipmapXmlFile(config, null, prefixPath: prefixPath);

      expect(File(resPath(['drawable-mdpi', 'ic_launcher_monochrome.png'])).existsSync(), isTrue);
      expect(
        File(resPath(['mipmap-anydpi-v26', 'ic_launcher.xml'])).readAsStringSync(),
        contains('<monochrome>'),
      );
    });

    test('monochrome_inset 0 emits the canonical plain form', () async {
      final config = pairConfig({
        'adaptive_icon_monochrome': 'master-light-1024.png',
        'adaptive_icon_monochrome_inset': 0,
      });

      await android.createMipmapXmlFile(config, null, prefixPath: prefixPath);

      final xml = File(resPath(['mipmap-anydpi-v26', 'ic_launcher.xml'])).readAsStringSync();
      expect(xml, contains('<monochrome android:drawable="@drawable/ic_launcher_monochrome" />'));
      expect(xml, isNot(contains('<monochrome>\n')));
    });

    test('monochrome_inset is honored independently of the foreground inset', () async {
      final config = pairConfig({
        'adaptive_icon_monochrome': 'master-light-1024.png',
        'adaptive_icon_foreground_inset': 16,
        'adaptive_icon_monochrome_inset': 10,
      });

      await android.createMipmapXmlFile(config, null, prefixPath: prefixPath);

      final xml = File(resPath(['mipmap-anydpi-v26', 'ic_launcher.xml'])).readAsStringSync();
      expect(xml, contains('android:inset="10%"'));
      expect(xml, contains('android:inset="16%"'));
    });
  });

  group('foreground inset 0', () {
    test('emits the canonical plain foreground form', () async {
      final config = pairConfig({'adaptive_icon_foreground_inset': 0});

      await android.createMipmapXmlFile(config, null, prefixPath: prefixPath);

      final xml = File(resPath(['mipmap-anydpi-v26', 'ic_launcher.xml'])).readAsStringSync();
      expect(xml, contains('<foreground android:drawable="@drawable/ic_launcher_foreground" />'));
      expect(xml, isNot(contains('<foreground>\n')));
    });
  });

  group('vector drawable pass-through', () {
    test('foreground xml is copied to drawable/ with no density PNGs', () async {
      final config = pairConfig({'adaptive_icon_foreground': 'foreground.xml'});

      await android.createAdaptiveIcons(config, null, prefixPath: prefixPath);
      await android.createMipmapXmlFile(config, null, prefixPath: prefixPath);

      final vector = File(resPath(['drawable', 'ic_launcher_foreground.xml']));
      expect(vector.existsSync(), isTrue);
      expect(vector.readAsStringSync(), contains('<vector'));
      expect(File(resPath(['drawable-mdpi', 'ic_launcher_foreground.png'])).existsSync(), isFalse);
      expect(
        File(resPath(['mipmap-anydpi-v26', 'ic_launcher.xml'])).readAsStringSync(),
        contains('<foreground>'),
      );
    });

    test('background xml is copied and referenced', () async {
      final config = Config.fromJson(<String, dynamic>{
        'android': {
          'generate': true,
          'image_path': 'master-light-1024.png',
          'adaptive_icon_background': 'foreground.xml',
          'adaptive_icon_foreground': 'master-light-1024.png',
        },
      });

      await android.createAdaptiveIcons(config, null, prefixPath: prefixPath);
      await android.createMipmapXmlFile(config, null, prefixPath: prefixPath);

      expect(File(resPath(['drawable', 'ic_launcher_background.xml'])).existsSync(), isTrue);
      expect(
        File(resPath(['mipmap-anydpi-v26', 'ic_launcher.xml'])).readAsStringSync(),
        contains('<background android:drawable="@drawable/ic_launcher_background"/>'),
      );
    });

    test('monochrome xml is copied with the pair present', () async {
      final config = pairConfig({'adaptive_icon_monochrome': 'foreground.xml'});

      await android.createAdaptiveMonochromeIcons(config, null, prefixPath: prefixPath);

      expect(File(resPath(['drawable', 'ic_launcher_monochrome.xml'])).existsSync(), isTrue);
      expect(File(resPath(['drawable-mdpi', 'ic_launcher_monochrome.png'])).existsSync(), isFalse);
    });

    test('missing vector source throws', () async {
      final config = pairConfig({'adaptive_icon_foreground': 'missing.xml'});

      await expectLater(
        android.createAdaptiveIcons(config, null, prefixPath: prefixPath),
        throwsA(isA<InvalidConfigException>()),
      );
    });

    test('switching vector to raster clears the stale xml twin', () async {
      await android.createAdaptiveIcons(pairConfig({'adaptive_icon_foreground': 'foreground.xml'}), null, prefixPath: prefixPath);
      expect(File(resPath(['drawable', 'ic_launcher_foreground.xml'])).existsSync(), isTrue);

      await android.createAdaptiveIcons(pairConfig({}), null, prefixPath: prefixPath);

      expect(File(resPath(['drawable', 'ic_launcher_foreground.xml'])).existsSync(), isFalse);
      expect(File(resPath(['drawable-mdpi', 'ic_launcher_foreground.png'])).existsSync(), isTrue);
    });

    test('switching raster to vector clears the stale PNGs', () async {
      await android.createAdaptiveIcons(pairConfig({}), null, prefixPath: prefixPath);
      expect(File(resPath(['drawable-mdpi', 'ic_launcher_foreground.png'])).existsSync(), isTrue);

      await android.createAdaptiveIcons(pairConfig({'adaptive_icon_foreground': 'foreground.xml'}), null, prefixPath: prefixPath);

      expect(File(resPath(['drawable-mdpi', 'ic_launcher_foreground.png'])).existsSync(), isFalse);
      expect(File(resPath(['drawable', 'ic_launcher_foreground.xml'])).existsSync(), isTrue);
    });
  });

  group('notification icons', () {
    test('emits the 24dp set and wires FCM meta-data end to end', () async {
      final config = Config.fromJson(<String, dynamic>{
        'android': {
          'generate': true,
          'image_path': 'master-light-1024.png',
          'notification_icon': 'master-light-1024.png',
        },
      });

      await AndroidIconGenerator(
        IconGeneratorContext(
          config: config,
          logger: LILogger(isVerbose: false),
          prefixPath: prefixPath,
        ),
      ).createIcons();

      const expected = {
        'drawable-mdpi': 24,
        'drawable-hdpi': 36,
        'drawable-xhdpi': 48,
        'drawable-xxhdpi': 72,
        'drawable-xxxhdpi': 96,
      };
      for (final entry in expected.entries) {
        final file = File(resPath([entry.key, 'ic_notification.png']));
        expect(file.existsSync(), isTrue, reason: entry.key);
        final image = decodeImage(file.readAsBytesSync())!;
        expect(image.width, equals(entry.value));
        expect(image.height, equals(entry.value));
      }
      final manifest = File(
        path.join(prefixPath, 'android', 'app', 'src', 'main', 'AndroidManifest.xml'),
      ).readAsStringSync();
      expect(
        manifest,
        contains('<meta-data android:name="com.google.firebase.messaging.default_notification_icon" android:resource="@drawable/ic_notification" />'),
      );
    });

    test('custom resource name is used for files and meta-data', () async {
      final config = Config.fromJson(<String, dynamic>{
        'android': {
          'generate': true,
          'image_path': 'master-light-1024.png',
          'notification_icon': 'master-light-1024.png',
          'notification_icon_name': 'ic_notif_custom',
        },
      });

      await android.createNotificationIcons(config, null, prefixPath: prefixPath);

      expect(File(resPath(['drawable-mdpi', 'ic_notif_custom.png'])).existsSync(), isTrue);
      final manifest = File(
        path.join(prefixPath, 'android', 'app', 'src', 'main', 'AndroidManifest.xml'),
      ).readAsStringSync();
      expect(manifest, contains('@drawable/ic_notif_custom'));
    });

    test('meta-data wiring is idempotent and follows renames', () async {
      final config = Config.fromJson(<String, dynamic>{
        'android': {
          'generate': true,
          'image_path': 'master-light-1024.png',
          'notification_icon': 'master-light-1024.png',
        },
      });

      await android.createNotificationIcons(config, null, prefixPath: prefixPath);
      await android.createNotificationIcons(config, null, prefixPath: prefixPath);

      final manifestFile = File(
        path.join(prefixPath, 'android', 'app', 'src', 'main', 'AndroidManifest.xml'),
      );
      expect(
        'com.google.firebase.messaging.default_notification_icon'.allMatches(manifestFile.readAsStringSync()).length,
        equals(1),
      );

      final renamed = Config.fromJson(<String, dynamic>{
        'android': {
          'generate': true,
          'image_path': 'master-light-1024.png',
          'notification_icon': 'master-light-1024.png',
          'notification_icon_name': 'ic_notif_v2',
        },
      });
      await android.createNotificationIcons(renamed, null, prefixPath: prefixPath);
      expect(manifestFile.readAsStringSync(), contains('@drawable/ic_notif_v2'));
    });

    test('vector notification source is passed through with wiring', () async {
      final config = Config.fromJson(<String, dynamic>{
        'android': {
          'generate': true,
          'image_path': 'master-light-1024.png',
          'notification_icon': 'foreground.xml',
        },
      });

      await android.createNotificationIcons(config, null, prefixPath: prefixPath);

      expect(File(resPath(['drawable', 'ic_notification.xml'])).existsSync(), isTrue);
      expect(File(resPath(['drawable-mdpi', 'ic_notification.png'])).existsSync(), isFalse);
      final manifest = File(
        path.join(prefixPath, 'android', 'app', 'src', 'main', 'AndroidManifest.xml'),
      ).readAsStringSync();
      expect(manifest, contains('@drawable/ic_notification'));
    });

    test('missing manifest skips wiring without failing', () async {
      await File(
        path.join(prefixPath, 'android', 'app', 'src', 'main', 'AndroidManifest.xml'),
      ).delete();
      final config = Config.fromJson(<String, dynamic>{
        'android': {
          'generate': true,
          'image_path': 'master-light-1024.png',
          'notification_icon': 'master-light-1024.png',
        },
      });

      await android.createNotificationIcons(config, null, prefixPath: prefixPath);

      expect(File(resPath(['drawable-mdpi', 'ic_notification.png'])).existsSync(), isTrue);
    });

    test('invalid resource name throws', () async {
      final config = Config.fromJson(<String, dynamic>{
        'android': {
          'generate': true,
          'image_path': 'master-light-1024.png',
          'notification_icon': 'master-light-1024.png',
          'notification_icon_name': 'Bad-Name',
        },
      });

      await expectLater(
        android.createNotificationIcons(config, null, prefixPath: prefixPath),
        throwsA(isA<InvalidAndroidIconNameException>()),
      );
    });
  });
}
