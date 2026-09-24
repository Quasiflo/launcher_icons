import 'dart:io';

import 'package:launcher_icons/src/config/config.dart';
import 'package:launcher_icons/src/core/logger.dart';
import 'package:launcher_icons/src/core/paths.dart' as paths;
import 'package:launcher_icons/src/platforms/android/android.dart' as android;
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

/// Captures `info` output so warning routing can be asserted.
class _RecordingLogger extends LILogger {
  _RecordingLogger() : super(isVerbose: false);
  final List<String> messages = <String>[];

  @override
  void info(final Object? message) {
    messages.add(message.toString());
  }
}

void main() {
  group('Android adaptive round icon (opt-in)', () {
    late String prefixPath;
    late Directory sandbox;

    setUp(() {
      sandbox = Directory(
        path.join(
          Directory.current.path,
          '.dart_tool',
          'launcher_icons',
          'test',
          'android_round',
        ),
      );
      if (sandbox.existsSync()) {
        sandbox.deleteSync(recursive: true);
      }
      sandbox.createSync(recursive: true);
      prefixPath = sandbox.absolute.path;
      final assets = path.join(Directory.current.path, 'test', 'assets');
      File(path.join(assets, 'master-light-1024.png')).copySync(path.join(prefixPath, 'master-light-1024.png'));
      File(path.join(assets, 'master-light-1024.png')).copySync(path.join(prefixPath, 'round.png'));
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

    Config roundConfig() => Config.fromJson(<String, dynamic>{
          'android': {
            'generate': true,
            'image_path': 'master-light-1024.png',
            'adaptive_icon_background': '#ffffff',
            'adaptive_icon_foreground': 'master-light-1024.png',
            'adaptive_icon_round': 'round.png',
          },
        });

    test('writes round drawables, round xml, and roundIcon wiring', () async {
      final config = roundConfig();

      await android.createAdaptiveRoundIcons(
        config,
        null,
        prefixPath: prefixPath,
      );
      await android.createMipmapXmlFile(config, null, prefixPath: prefixPath);
      await android.createDefaultIcons(config, null, prefixPath: prefixPath);

      for (final template in [
        'drawable-mdpi',
        'drawable-xxxhdpi',
      ]) {
        expect(
          File(
            path.join(
              prefixPath,
              'android',
              'app',
              'src',
              'main',
              'res',
              template,
              paths.androidAdaptiveRoundFileName,
            ),
          ).existsSync(),
          isTrue,
        );
      }
      final roundXml = File(
        path.join(
          prefixPath,
          'android',
          'app',
          'src',
          'main',
          'res',
          'mipmap-anydpi-v26',
          'ic_launcher_round.xml',
        ),
      );
      expect(roundXml.existsSync(), isTrue);
      expect(roundXml.readAsStringSync(), contains('<adaptive-icon'));
      final manifest = File(
        path.join(
          prefixPath,
          'android',
          'app',
          'src',
          'main',
          'AndroidManifest.xml',
        ),
      ).readAsStringSync();
      expect(
        manifest,
        contains('android:roundIcon="@mipmap/ic_launcher_round"'),
      );
    });

    test('removes stale round artifacts without round config', () async {
      final staleXml = File(
        path.join(
          prefixPath,
          'android',
          'app',
          'src',
          'main',
          'res',
          'mipmap-anydpi-v26',
          'ic_launcher_round.xml',
        ),
      );
      await staleXml.create(recursive: true);
      await staleXml.writeAsString('<stale/>');
      final stalePng = File(
        path.join(
          prefixPath,
          'android',
          'app',
          'src',
          'main',
          'res',
          'drawable-mdpi',
          paths.androidAdaptiveRoundFileName,
        ),
      );
      await stalePng.create(recursive: true);
      await stalePng.writeAsBytes([0]);

      final config = Config.fromJson(<String, dynamic>{
        'android': {'generate': true, 'image_path': 'master-light-1024.png'},
      });
      await android.createMipmapXmlFile(config, null, prefixPath: prefixPath);

      expect(staleXml.existsSync(), isFalse);
      expect(stalePng.existsSync(), isFalse);
    });

    test('round drawables honor a custom icon_name', () async {
      final config = Config.fromJson(<String, dynamic>{
        'android': {
          'generate': true,
          'image_path': 'master-light-1024.png',
          'icon_name': 'ic_launcher_custom',
          'adaptive_icon_background': '#ffffff',
          'adaptive_icon_foreground': 'master-light-1024.png',
          'adaptive_icon_round': 'round.png',
        },
      });

      await android.createAdaptiveRoundIcons(
        config,
        null,
        prefixPath: prefixPath,
      );

      expect(
        File(
          path.join(
            prefixPath,
            'android',
            'app',
            'src',
            'main',
            'res',
            'drawable-mdpi',
            'ic_launcher_custom_round.png',
          ),
        ).existsSync(),
        isTrue,
      );
      expect(
        File(
          path.join(
            prefixPath,
            'android',
            'app',
            'src',
            'main',
            'res',
            'drawable-mdpi',
            paths.androidAdaptiveRoundFileName,
          ),
        ).existsSync(),
        isFalse,
      );
    });

    test('warns when a pre-existing roundIcon may shadow themed icons', () async {
      const shadowManifest = '''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:label="@string/app_name"
        android:icon="@mipmap/ic_launcher"
        android:roundIcon="@mipmap/ic_launcher_round">
    </application>
</manifest>
''';
      File(
        path.join(
          prefixPath,
          'android',
          'app',
          'src',
          'main',
          'AndroidManifest.xml',
        ),
      ).writeAsStringSync(shadowManifest);

      final config = Config.fromJson(<String, dynamic>{
        'android': {'generate': true, 'image_path': 'master-light-1024.png'},
      });
      final logger = _RecordingLogger();
      await android.createDefaultIcons(
        config,
        null,
        logger: logger,
        prefixPath: prefixPath,
      );

      expect(
        logger.messages.any((final m) => m.contains('roundIcon')),
        isTrue,
      );
    });
  });
}
