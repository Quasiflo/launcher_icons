import 'dart:io';

import 'package:launcher_icons/src/config/config.dart';
import 'package:launcher_icons/src/core/custom_exceptions.dart';
import 'package:launcher_icons/src/platforms/ios/ios.dart' as ios;
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

// iOS used to bypass the shared loader with a direct `decodeImage(File().readAsBytes())`, silently returning on undecodable images. It now routes through `decodeImageFile`, so bad inputs throw.
void main() {
  group('createIcons loader errors', () {
    late String originalDir;
    late String sandboxDir;

    setUp(() {
      originalDir = Directory.current.path;
      sandboxDir = path.join(
        '.dart_tool',
        'launcher_icons',
        'test',
        'ios_loader_error',
      );
      final sandbox = Directory(sandboxDir);
      if (sandbox.existsSync()) {
        sandbox.deleteSync(recursive: true);
      }
      sandbox.createSync(recursive: true);
      Directory.current = sandboxDir;
    });

    tearDown(() {
      Directory.current = originalDir;
    });

    test('throws NoDecoderForImageFormatException for garbage image', () async {
      final garbage = File('icon.png')..createSync();
      // Plain text: every decoder probe rejects it and decodeImage returns null (short binary blobs can throw inside a probe instead).
      await garbage.writeAsString(
        'this is definitely not an image file, just plain text....',
      );

      final config = Config.fromJson(<String, dynamic>{
        'ios': {
          'generate': true,
          'image_path': 'icon.png',
        },
      });

      await expectLater(
        ios.createIcons(config, null),
        throwsA(isA<NoDecoderForImageFormatException>()),
      );
    });
  });
}
