import 'dart:io';

import 'package:launcher_icons/src/config/config.dart';
import 'package:launcher_icons/src/platforms/android/android.dart' as android;
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

const _manifest = '''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:label="@string/app_name"
        android:icon="@mipmap/ICON">
    </application>
</manifest>
''';

// Switching custom icon names must not pile up stale legacy PNGs: the manifest's previous icon name is the source of truth for what the tool managed before. The default ic_launcher set is never touched (it may be Flutter's originals).
void main() {
  group('createDefaultIcons legacy switch cleanup', () {
    late String prefixPath;
    late Directory sandbox;

    setUp(() {
      sandbox = Directory(
        path.join(
          Directory.current.path,
          '.dart_tool',
          'launcher_icons',
          'test',
          'android_stale_legacy',
        ),
      );
      if (sandbox.existsSync()) {
        sandbox.deleteSync(recursive: true);
      }
      sandbox.createSync(recursive: true);
      prefixPath = sandbox.absolute.path;
      final assets = path.join(Directory.current.path, 'test', 'assets');
      File(path.join(assets, 'master-light-1024.png')).copySync(path.join(prefixPath, 'master-light-1024.png'));
      Directory(
        path.join(prefixPath, 'android', 'app', 'src', 'main'),
      ).createSync(recursive: true);
    });

    tearDown(() {
      if (sandbox.existsSync()) {
        sandbox.deleteSync(recursive: true);
      }
    });

    void writeManifest(final String iconName) {
      File(
        path.join(
          prefixPath,
          'android',
          'app',
          'src',
          'main',
          'AndroidManifest.xml',
        ),
      ).writeAsStringSync(_manifest.replaceAll('ICON', iconName));
    }

    void writeLegacyPngs(final String iconName) {
      for (final template in android.androidIcons) {
        File(
          path.join(
            prefixPath,
            'android',
            'app',
            'src',
            'main',
            'res',
            template.directoryName,
            '$iconName.png',
          ),
        )
          ..createSync(recursive: true)
          ..writeAsBytesSync([0]);
      }
    }

    bool legacyPngExists(final String iconName, final String density) => File(
          path.join(
            prefixPath,
            'android',
            'app',
            'src',
            'main',
            'res',
            density,
            '$iconName.png',
          ),
        ).existsSync();

    Config customConfig(final String iconName) => Config.fromJson(<String, dynamic>{
          'android': {
            'generate': true,
            'image_path': 'master-light-1024.png',
            'icon_name': iconName,
          },
        });

    test('custom-A to custom-B removes A legacy PNGs', () async {
      writeManifest('old_custom');
      writeLegacyPngs('old_custom');

      await android.createDefaultIcons(
        customConfig('new_custom'),
        null,
        prefixPath: prefixPath,
      );

      for (final template in android.androidIcons) {
        expect(
          legacyPngExists('old_custom', template.directoryName),
          isFalse,
        );
        expect(
          legacyPngExists('new_custom', template.directoryName),
          isTrue,
        );
      }
    });

    test('custom to default removes the custom legacy PNGs', () async {
      writeManifest('old_custom');
      writeLegacyPngs('old_custom');

      await android.createDefaultIcons(
        Config.fromJson(<String, dynamic>{
          'android': {'generate': true, 'image_path': 'master-light-1024.png'},
        }),
        null,
        prefixPath: prefixPath,
      );

      for (final template in android.androidIcons) {
        expect(
          legacyPngExists('old_custom', template.directoryName),
          isFalse,
        );
      }
    });

    test('default ic_launcher files are never deleted', () async {
      writeManifest('ic_launcher');
      writeLegacyPngs('ic_launcher');

      await android.createDefaultIcons(
        customConfig('new_custom'),
        null,
        prefixPath: prefixPath,
      );

      for (final template in android.androidIcons) {
        expect(
          legacyPngExists('ic_launcher', template.directoryName),
          isTrue,
        );
      }
    });
  });
}
