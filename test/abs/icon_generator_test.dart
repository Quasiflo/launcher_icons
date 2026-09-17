import 'package:launcher_icons/src/config/config.dart';
import 'package:launcher_icons/src/core/custom_exceptions.dart';
import 'package:launcher_icons/src/core/icon_generator.dart';
import 'package:launcher_icons/src/core/logger.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'icon_generator_test.mocks.dart';

@GenerateMocks([Config, IconGenerator])
void main() {
  group('#generateIconsFor', () {
    late String prefixPath;
    late LILogger logger;
    late IconGenerator mockGenerator;
    late Config mockLIConfig;
    setUp(() async {
      prefixPath = path.join(d.sandbox, 'fli_test');
      mockLIConfig = MockConfig();
      logger = LILogger(false);
      mockGenerator = MockIconGenerator();
      when(mockGenerator.platformName).thenReturn('Mock');
      when(mockGenerator.isEnabled).thenReturn(true);
      when(mockGenerator.context).thenReturn(
        IconGeneratorContext(
          config: mockLIConfig,
          prefixPath: prefixPath,
          logger: logger,
        ),
      );
    });
    test('should execute createIcons() when validateRequiremnts() returns true', () {
      when(mockGenerator.validateRequirements()).thenReturn(true);
      generateIconsFor(
        config: mockLIConfig,
        flavor: null,
        prefixPath: prefixPath,
        logger: logger,
        platforms: (context) => [mockGenerator],
      );
      verify(mockGenerator.validateRequirements()).called(equals(1));
      verify(mockGenerator.createIcons()).called(equals(1));
    });

    test('should not execute createIcons() when validateRequiremnts() returns false', () {
      when(mockGenerator.validateRequirements()).thenReturn(false);
      generateIconsFor(
        config: mockLIConfig,
        flavor: null,
        prefixPath: prefixPath,
        logger: logger,
        platforms: (context) => [mockGenerator],
      );
      verify(mockGenerator.validateRequirements()).called(equals(1));
      verifyNever(mockGenerator.createIcons());
    });

    test('should skip disabled platform without validating requirements', () {
      when(mockGenerator.isEnabled).thenReturn(false);
      generateIconsFor(
        config: mockLIConfig,
        flavor: null,
        prefixPath: prefixPath,
        logger: logger,
        platforms: (context) => [mockGenerator],
      );
      verifyNever(mockGenerator.validateRequirements());
      verifyNever(mockGenerator.createIcons());
    });

    test('a platform failure throws IconGenerationException', () async {
      when(mockGenerator.validateRequirements()).thenReturn(true);
      when(mockGenerator.createIcons()).thenThrow(Exception('should-fail-platform'));
      await expectLater(
        generateIconsFor(
          config: mockLIConfig,
          flavor: null,
          prefixPath: prefixPath,
          logger: logger,
          platforms: (context) => [mockGenerator],
        ),
        throwsA(
          isA<IconGenerationException>().having(
            (e) => e.failedPlatforms,
            'failedPlatforms',
            equals(['Mock']),
          ),
        ),
      );
      verify(mockGenerator.validateRequirements()).called(equals(1));
      verify(mockGenerator.createIcons()).called(equals(1));
    });

    test('a failing platform does not stop the remaining platforms', () async {
      final failingGenerator = MockIconGenerator();
      when(failingGenerator.platformName).thenReturn('Failing');
      when(failingGenerator.isEnabled).thenReturn(true);
      when(failingGenerator.validateRequirements()).thenReturn(true);
      when(failingGenerator.createIcons()).thenThrow(Exception('should-fail-platform'));

      when(mockGenerator.platformName).thenReturn('Healthy');
      when(mockGenerator.validateRequirements()).thenReturn(true);
      when(mockGenerator.createIcons()).thenAnswer((_) async {});

      await expectLater(
        generateIconsFor(
          config: mockLIConfig,
          flavor: null,
          prefixPath: prefixPath,
          logger: logger,
          platforms: (context) => [failingGenerator, mockGenerator],
        ),
        throwsA(
          isA<IconGenerationException>().having(
            (e) => e.failedPlatforms,
            'failedPlatforms',
            equals(['Failing']),
          ),
        ),
      );
      verify(failingGenerator.createIcons()).called(equals(1));
      verify(mockGenerator.createIcons()).called(equals(1));
    });
  });
}
