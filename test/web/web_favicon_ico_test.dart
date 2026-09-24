import 'dart:io';

import 'package:launcher_icons/src/config/config.dart';
import 'package:launcher_icons/src/core/icon_generator.dart';
import 'package:launcher_icons/src/core/logger.dart';
import 'package:launcher_icons/src/platforms/web/web_icon_generator.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import '../templates.dart' as templates;

/// Frame widths from the ICONDIR header (`0` means 256 per the ICO spec).
List<int> _icoFrameWidths(final List<int> bytes) {
  final count = bytes[4] | bytes[5] << 8;
  return [
    for (var i = 0; i < count; i++)
      if (bytes[6 + i * 16] == 0) 256 else bytes[6 + i * 16],
  ];
}

void main() {
  group('WebIconGenerator favicon.ico + CSS colors', () {
    late String prefixPath;
    final assetPath = path.join(Directory.current.path, 'test', 'assets');

    setUp(() async {
      final imageFile = File(path.join(assetPath, 'master-light-1024.png'));
      expect(imageFile.existsSync(), isTrue);
      await d.dir('fli_test', [
        d.dir('web', [
          d.dir('icons'),
          d.file('index.html', templates.webIndexTemplate),
          d.file('manifest.json', templates.webManifestTemplate),
        ]),
        d.file('launcher_icons.yaml', templates.liWebConfig),
        d.file('pubspec.yaml', templates.pubspecTemplate),
        d.file('master-light-1024.png', imageFile.readAsBytesSync()),
        d.file('app_icon_favicon.png', imageFile.readAsBytesSync()),
      ]).create();
      prefixPath = path.join(d.sandbox, 'fli_test');
    });

    IconGenerator generatorFor(final Map<String, dynamic> web) => WebIconGenerator(
          IconGeneratorContext(
            config: Config.fromJson(<String, dynamic>{'web': web}),
            prefixPath: prefixPath,
            logger: LILogger(isVerbose: false),
          ),
        );

    test('emits a multi-size 16+32+48 favicon.ico', () async {
      final generator = generatorFor(<String, dynamic>{
        'generate': true,
        'image_path': 'master-light-1024.png',
      });

      await generator.createIcons();

      final bytes = await File(
        path.join(prefixPath, 'web', 'favicon.ico'),
      ).readAsBytes();
      expect(_icoFrameWidths(bytes), equals([16, 32, 48]));
    });

    test('favicon_ico: false skips the .ico file and index line', () async {
      final generator = generatorFor(<String, dynamic>{
        'generate': true,
        'image_path': 'master-light-1024.png',
        'favicon_ico': false,
      });

      await generator.createIcons();

      expect(
        File(path.join(prefixPath, 'web', 'favicon.ico')).existsSync(),
        isFalse,
      );
      expect(
        File(path.join(prefixPath, 'web', 'favicon.png')).existsSync(),
        isTrue,
      );
      final index = await File(
        path.join(prefixPath, 'web', 'index.html'),
      ).readAsString();
      expect(index, isNot(contains('favicon.ico')));
      expect(index, contains('favicon.png'));
    });

    test('rejects non-hex background_color/theme colors', () {
      expect(
        generatorFor(<String, dynamic>{
          'generate': true,
          'image_path': 'master-light-1024.png',
          'background_color': 'banana',
        }).validateRequirements(),
        isFalse,
      );
      expect(
        generatorFor(<String, dynamic>{
          'generate': true,
          'image_path': 'master-light-1024.png',
          'theme_color_light': 'red-ish',
        }).validateRequirements(),
        isFalse,
      );
      expect(
        generatorFor(<String, dynamic>{
          'generate': true,
          'image_path': 'master-light-1024.png',
          'theme_color_dark': 'red-ish',
        }).validateRequirements(),
        isFalse,
      );
    });

    test('accepts short, full, and alpha hex colors', () {
      for (final color in ['#fff', '#ffffff', '#ffffffff']) {
        expect(
          generatorFor(<String, dynamic>{
            'generate': true,
            'image_path': 'master-light-1024.png',
            'background_color': color,
            'theme_color_light': color,
            'theme_color_dark': color,
          }).validateRequirements(),
          isTrue,
        );
      }
    });
  });
}
