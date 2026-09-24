import 'dart:io';

import 'package:image/image.dart';
import 'package:launcher_icons/src/config/config.dart';
import 'package:launcher_icons/src/config/windows_config.dart';
import 'package:launcher_icons/src/core/constants.dart' as constants;
import 'package:launcher_icons/src/core/custom_exceptions.dart';
import 'package:launcher_icons/src/core/icon_generator.dart';
import 'package:launcher_icons/src/core/logger.dart';
import 'package:launcher_icons/src/platforms/windows/windows_icon_generator.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:yaml/yaml.dart';

import '../templates.dart' as templates;
import 'windows_icon_generator_test.mocks.dart';

/// Parses the ICONDIR of a `.ico` file, returning one entry per embedded image. Width/height of `0` means 256 (per the ICO spec).
List<({int width, int height, int offset, int size, int planes, int bitCount})> _parseIcoDirectory(
  final List<int> bytes,
) {
  if (bytes.length < 6) {
    fail('ico is smaller than the 6 byte ICONDIR header');
  }
  final count = bytes[4] | bytes[5] << 8;
  if (6 + count * 16 > bytes.length) {
    fail('ico ICONDIR is truncated');
  }
  return [
    for (var i = 0; i < count; i++)
      (
        width: bytes[6 + i * 16],
        height: bytes[6 + i * 16 + 1],
        size: bytes[6 + i * 16 + 8] | bytes[6 + i * 16 + 9] << 8 | bytes[6 + i * 16 + 10] << 16 | bytes[6 + i * 16 + 11] << 24,
        offset: bytes[6 + i * 16 + 12] | bytes[6 + i * 16 + 13] << 8 | bytes[6 + i * 16 + 14] << 16 | bytes[6 + i * 16 + 15] << 24,
        planes: bytes[6 + i * 16 + 4] | bytes[6 + i * 16 + 5] << 8,
        bitCount: bytes[6 + i * 16 + 6] | bytes[6 + i * 16 + 7] << 8,
      ),
  ];
}

/// Captures `info` output so warning routing can be asserted.
class _RecordingLogger extends LILogger {
  _RecordingLogger() : super(isVerbose: false);
  final List<String> messages = <String>[];

  @override
  void info(final Object? message) {
    messages.add(message.toString());
  }
}

@GenerateMocks([Config, WindowsConfig, LILogger])
void main() {
  group('WindowsIconGenerator', () {
    late IconGeneratorContext context;
    late IconGenerator generator;
    late Config mockConfig;
    late WindowsConfig mockWindowsConfig;
    late String prefixPath;
    late File testImageFile;
    late MockLILogger mockLogger;
    final assetPath = path.join(Directory.current.path, 'test', 'assets');

    group('#validateRequirments', () {
      setUpAll(() {
        // make sure test file exists before starting test
        testImageFile = File(path.join(assetPath, 'master-light-1024.png'));
        expect(testImageFile.existsSync(), isTrue);
      });
      setUp(() {
        prefixPath = path.join(d.sandbox, 'fli_test');
        mockConfig = MockConfig();
        mockWindowsConfig = MockWindowsConfig();
        mockLogger = MockLILogger();
        context = IconGeneratorContext(
          config: mockConfig,
          prefixPath: prefixPath,
          logger: mockLogger,
        );
        generator = WindowsIconGenerator(context);
        // initilize mock defaults
        when(mockLogger.error(argThat(anything))).thenAnswer((final _) {});
        when(mockLogger.info(argThat(anything))).thenAnswer((final _) {});
        when(mockLogger.verbose(argThat(anything))).thenAnswer((final _) {});
        when(mockLogger.isVerbose).thenReturn(false);
        when(mockConfig.windowsConfig).thenReturn(mockWindowsConfig);
        when(mockWindowsConfig.generate).thenReturn(true);
        when(mockWindowsConfig.imagePath).thenReturn(path.join(prefixPath, 'master-light-1024.png'));
        when(mockWindowsConfig.imagePathUnplated).thenReturn(null);
        when(mockWindowsConfig.imagePathLightUnplated).thenReturn(null);
        when(mockWindowsConfig.imagePathWide).thenReturn(null);
        when(mockConfig.imagePath).thenReturn(path.join(prefixPath, 'master-light-1024.png'));
        // resolveImageFile is mocked: implement the real rule (platform path wins, top-level fallback, missing file throws) so the unit tests exercise the generators, not the mock default.
        when(mockConfig.resolveImageFile(argThat(anything), prefixPath)).thenAnswer(
          (final invocation) {
            final platformPath = invocation.positionalArguments.first as String?;
            final resolved = platformPath ?? mockConfig.imagePath;
            if (resolved == null || !File(path.join(prefixPath, resolved)).existsSync()) {
              throw InvalidConfigException('Missing "image_path" within configuration, or the referenced image file does not exist${resolved == null ? '' : ': "$resolved"'}');
            }
            return resolved;
          },
        );
      });

      test('windowsEnabled is false with no windows section', () {
        final realContext = IconGeneratorContext(
          config: const Config(imagePath: 'icon.png'),
          prefixPath: prefixPath,
          logger: LILogger(isVerbose: false),
        );

        expect(realContext.config.windowsEnabled, isFalse);
      });

      test('windowsEnabled is false when windows.generate is false', () {
        final realContext = IconGeneratorContext(
          config: const Config(
            imagePath: 'icon.png',
            windowsConfig: WindowsConfig(),
          ),
          prefixPath: prefixPath,
          logger: LILogger(isVerbose: false),
        );

        expect(realContext.config.windowsEnabled, isFalse);
      });

      test('should return false when windows.image_path and imagePath is null', () {
        when(mockWindowsConfig.imagePath).thenReturn(null);
        when(mockConfig.imagePath).thenReturn(null);
        expect(generator.validateRequirements(), isFalse);

        verifyInOrder([
          mockWindowsConfig.imagePath,
          mockConfig.imagePath,
        ]);
      });

      test('should return false when windows dir does not exist', () async {
        await d.dir('fli_test', [
          d.file('master-light-1024.png', testImageFile.readAsBytesSync()),
        ]).create();
        await expectLater(
          d.dir('fli_test', [
            d.file('master-light-1024.png', anything),
          ]).validate(),
          completes,
        );
        expect(generator.validateRequirements(), isFalse);
      });

      test('should return false when image file does not exist', () async {
        await d.dir('fli_test', [d.dir('windows')]).create();
        await expectLater(
          d.dir('fli_test', [d.dir('windows')]).validate(),
          completes,
        );
        expect(generator.validateRequirements(), isFalse);
      });
    });
  });

  group('WindowsIconGenerator end-to-end', () {
    late IconGeneratorContext context;
    late IconGenerator generator;
    late Config config;
    late String prefixPath;
    final assetPath = path.join(Directory.current.path, 'test', 'assets');

    setUp(() async {
      final imageFile = File(path.join(assetPath, 'master-light-1024.png'));
      expect(imageFile.existsSync(), isTrue);
      await d.dir('fli_test', [
        d.dir('windows'),
        d.file('launcher_icons.yaml', templates.liWindowsConfig),
        d.file('pubspec.yaml', templates.pubspecTemplate),
        d.file('master-light-1024.png', imageFile.readAsBytesSync()),
      ]).create();
      prefixPath = path.join(d.sandbox, 'fli_test');
      final windowsYaml = loadYaml(
        templates.liWindowsConfig,
      ) as Map<dynamic, dynamic>;
      config = Config.fromJson(
        windowsYaml['launcher_icons'] as Map<dynamic, dynamic>,
      );
      context = IconGeneratorContext(
        config: config,
        prefixPath: prefixPath,
        logger: LILogger(isVerbose: false),
      );
      generator = WindowsIconGenerator(context);
    });

    test('should generate valid icons', () async {
      expect(generator.validateRequirements(), isTrue);
      await generator.createIcons();
      await expectLater(
        d.dir('fli_test', [
          d.dir('windows', [
            d.dir('runner', [
              d.dir('resources', [
                d.file('app_icon.ico', anything),
              ]),
            ]),
          ]),
        ]).validate(),
        completes,
      );

      final icoBytes = File(
        path.join(
          prefixPath,
          'windows',
          'runner',
          'resources',
          'app_icon.ico',
        ),
      ).readAsBytesSync();
      expect(icoBytes.length, greaterThan(6));

      final entries = _parseIcoDirectory(icoBytes);
      int toPixels(final int byte) => byte == 0 ? 256 : byte;
      expect(
        entries.map((final e) => toPixels(e.width)).toList(),
        constants.windowsIcoSizes,
      );
      expect(
        entries.map((final e) => toPixels(e.height)).toList(),
        constants.windowsIcoSizes,
      );

      final firstDataOffset = 6 + entries.length * 16;
      expect(entries.first.offset, firstDataOffset);
      for (var i = 1; i < entries.length; i++) {
        expect(entries[i].offset, entries[i - 1].offset + entries[i - 1].size);
      }
      expect(entries.last.offset + entries.last.size, icoBytes.length);

      // Every frame must stay PNG-compressed 32bpp so a `package:image` upgrade cannot silently regress to BMP. (`package:image` emits planes=0, which Windows accepts; locked here to detect change.)
      for (final entry in entries) {
        expect(
          icoBytes.sublist(entry.offset, entry.offset + 4),
          [0x89, 0x50, 0x4E, 0x47],
        );
        expect(entry.planes, equals(0));
        expect(entry.bitCount, equals(32));
      }
    });

    test('icon_filename overrides the output name (flavors)', () async {
      final config = Config.fromJson(<String, dynamic>{
        'windows': {
          'generate': true,
          'image_path': 'master-light-1024.png',
          'icon_filename': 'app_icon_staging.ico',
        },
      });
      final customGenerator = WindowsIconGenerator(
        IconGeneratorContext(
          config: config,
          prefixPath: prefixPath,
          logger: LILogger(isVerbose: false),
        ),
      );

      expect(customGenerator.validateRequirements(), isTrue);
      await customGenerator.createIcons();

      expect(
        File(
          path.join(
            prefixPath,
            'windows',
            'runner',
            'resources',
            'app_icon_staging.ico',
          ),
        ).existsSync(),
        isTrue,
      );
    });

    test('warns when the source is smaller than 256px', () async {
      final small = Image(width: 64, height: 64);
      await File(path.join(prefixPath, 'small.png')).writeAsBytes(encodePng(small));
      final config = Config.fromJson(<String, dynamic>{
        'windows': {
          'generate': true,
          'image_path': 'small.png',
        },
      });
      final logger = _RecordingLogger();
      final smallGenerator = WindowsIconGenerator(
        IconGeneratorContext(
          config: config,
          prefixPath: prefixPath,
          logger: logger,
        ),
      );

      await smallGenerator.createIcons();

      expect(
        logger.messages.any((final m) => m.contains('256')),
        isTrue,
      );
    });
  });
}
