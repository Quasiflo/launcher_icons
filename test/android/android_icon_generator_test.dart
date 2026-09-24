import 'dart:io';

import 'package:launcher_icons/src/config/config.dart';
import 'package:launcher_icons/src/core/icon_generator.dart';
import 'package:launcher_icons/src/core/logger.dart';
import 'package:launcher_icons/src/platforms/android/android_icon_generator.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

const _manifest = '''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application android:icon="@mipmap/ic_launcher_old">
    </application>
</manifest>
''';

// The generator must honor prefixPath: with CWD left at the repo root, all reads and writes happen under the given prefix.
void main() {
  group('AndroidIconGenerator', () {
    late String prefixPath;
    late Directory sandbox;

    setUp(() {
      sandbox = Directory(
        path.join(
          Directory.current.path,
          '.dart_tool',
          'launcher_icons',
          'test',
          'android_generator_prefix',
        ),
      );
      if (sandbox.existsSync()) {
        sandbox.deleteSync(recursive: true);
      }
      sandbox.createSync(recursive: true);
      prefixPath = sandbox.absolute.path;
    });

    tearDown(() {
      if (sandbox.existsSync()) {
        sandbox.deleteSync(recursive: true);
      }
    });

    IconGenerator generatorFor(final Config config) => AndroidIconGenerator(
          IconGeneratorContext(
            config: config,
            logger: LILogger(isVerbose: false),
            prefixPath: prefixPath,
          ),
        );

    Config configFor(final Map<String, dynamic> root) => Config.fromJson(<String, dynamic>{
          'android': {'generate': true, ...root},
        });

    void writeImage([final String name = 'icon.png']) {
      File(
        path.join(
          Directory.current.path,
          'test',
          'assets',
          'master-light-1024.png',
        ),
      ).copySync(path.join(prefixPath, name));
    }

    test('androidEnabled follows android.generate', () {
      expect(
        generatorFor(configFor({})).context.config.androidEnabled,
        isTrue,
      );
      expect(
        generatorFor(
          Config.fromJson(<String, dynamic>{
            'android': {'generate': false},
          }),
        ).context.config.androidEnabled,
        isFalse,
      );
    });

    test('validateRequirements fails without any image path', () {
      final generator = generatorFor(
        Config.fromJson(<String, dynamic>{
          'android': {'generate': true},
        }),
      );
      expect(generator.validateRequirements(), isFalse);
    });

    test('validateRequirements fails without an android directory', () {
      writeImage();
      final generator = generatorFor(
        configFor({'image_path': 'icon.png'}),
      );
      expect(generator.validateRequirements(), isFalse);
    });

    test('createIcons writes under prefixPath', () async {
      writeImage();
      await Directory(
        path.join(prefixPath, 'android', 'app', 'src', 'main'),
      ).create(recursive: true);
      await File(
        path.join(
          prefixPath,
          'android',
          'app',
          'src',
          'main',
          'AndroidManifest.xml',
        ),
      ).writeAsString(_manifest);

      final generator = generatorFor(
        configFor({'image_path': 'icon.png'}),
      );
      expect(generator.validateRequirements(), isTrue);
      await generator.createIcons();

      final launcher = File(
        path.join(
          prefixPath,
          'android',
          'app',
          'src',
          'main',
          'res',
          'mipmap-xxxhdpi',
          'ic_launcher.png',
        ),
      );
      expect(launcher.existsSync(), isTrue);
      final manifest = await File(
        path.join(
          prefixPath,
          'android',
          'app',
          'src',
          'main',
          'AndroidManifest.xml',
        ),
      ).readAsString();
      expect(manifest, contains('@mipmap/ic_launcher'));
      expect(manifest, isNot(contains('ic_launcher_old')));
    });
  });
}
