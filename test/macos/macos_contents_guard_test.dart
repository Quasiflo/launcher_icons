import 'dart:convert';
import 'dart:io';

import 'package:launcher_icons/src/config/config.dart';
import 'package:launcher_icons/src/core/icon_generator.dart';
import 'package:launcher_icons/src/core/logger.dart';
import 'package:launcher_icons/src/platforms/macos/macos_icon_generator.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

/// Captures `info` output so warning routing can be asserted.
class _RecordingLogger extends LILogger {
  _RecordingLogger() : super(isVerbose: false);
  final List<String> messages = <String>[];

  @override
  void info(final Object? message) {
    messages.add(message.toString());
  }
}

const _corruptContentsJson = '''
{
    "info": {
        "version": 1,
        "author": "xcode"
    },
    "images": [
        {
            "size": "8x8",
            "idiom": "mac",
            "filename": "stale_8.png",
            "scale": "1x"
        },
        {
            "size": "1024x1024",
            "idiom": "mac",
            "filename": "stale_1024.png",
            "scale": "1x"
        },
        {
            "size": "64x64",
            "idiom": "iphone",
            "filename": "stale_iphone.png",
            "scale": "2x"
        }
    ]
}
''';

// A pre-existing Contents.json with non-mac entries (or garbage bytes) must warn, not crash — and the tool-owned images list is still refreshed.
void main() {
  group('MacOSIconGenerator corrupt Contents.json guard', () {
    late String prefixPath;
    late Directory sandbox;
    late _RecordingLogger logger;

    setUp(() {
      sandbox = Directory(
        path.join(
          Directory.current.path,
          '.dart_tool',
          'launcher_icons',
          'test',
          'macos_contents_guard',
        ),
      );
      if (sandbox.existsSync()) {
        sandbox.deleteSync(recursive: true);
      }
      sandbox.createSync(recursive: true);
      prefixPath = sandbox.absolute.path;
      logger = _RecordingLogger();
      File(
        path.join(
          Directory.current.path,
          'test',
          'assets',
          'master-light-1024.png',
        ),
      ).copySync(path.join(prefixPath, 'master-light-1024.png'));
    });

    tearDown(() {
      if (sandbox.existsSync()) {
        sandbox.deleteSync(recursive: true);
      }
    });

    void writeContents(final String content) {
      final dir = Directory(
        path.join(
          prefixPath,
          'macos',
          'Runner',
          'Assets.xcassets',
          'AppIcon.appiconset',
        ),
      )..createSync(recursive: true);
      File(path.join(dir.path, 'Contents.json')).writeAsStringSync(content);
    }

    MacOSIconGenerator generator() => MacOSIconGenerator(
          IconGeneratorContext(
            config: Config.fromJson(<String, dynamic>{
              'macos': {
                'generate': true,
                'image_path': 'master-light-1024.png',
              },
            }),
            logger: logger,
            prefixPath: prefixPath,
          ),
        );

    test('warns on non-mac entries and refreshes the image list', () async {
      writeContents(_corruptContentsJson);

      final gen = generator();
      expect(gen.validateRequirements(), isTrue);
      await gen.createIcons();

      expect(
        logger.messages.any((final m) => m.contains('WARNING')),
        isTrue,
      );
      final contents = jsonDecode(
        File(
          path.join(
            prefixPath,
            'macos',
            'Runner',
            'Assets.xcassets',
            'AppIcon.appiconset',
            'Contents.json',
          ),
        ).readAsStringSync(),
      ) as Map<String, dynamic>;
      final images = contents['images'] as List;
      expect(images, hasLength(10));
      expect(
        images.every((final e) => (e as Map)['idiom'] == 'mac'),
        isTrue,
      );
    });

    test('warns and writes fresh contents for unparseable JSON', () async {
      writeContents('{not valid json!!!');

      final gen = generator();
      expect(gen.validateRequirements(), isTrue);
      await gen.createIcons();

      expect(
        logger.messages.any((final m) => m.contains('WARNING')),
        isTrue,
      );
      final contents = jsonDecode(
        File(
          path.join(
            prefixPath,
            'macos',
            'Runner',
            'Assets.xcassets',
            'AppIcon.appiconset',
            'Contents.json',
          ),
        ).readAsStringSync(),
      ) as Map<String, dynamic>;
      expect(contents['images'] as List, hasLength(10));
      expect(
        contents['info'],
        equals({'version': 1, 'author': 'xcode'}),
      );
    });
  });
}
