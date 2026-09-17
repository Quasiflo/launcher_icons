import 'dart:io';

import 'package:launcher_icons/src/config/config.dart';
import 'package:launcher_icons/src/config/linux_config.dart';
import 'package:launcher_icons/src/config/macos_config.dart';
import 'package:launcher_icons/src/config/web_config.dart';
import 'package:launcher_icons/src/config/windows_config.dart';
import 'package:launcher_icons/src/core/custom_exceptions.dart';
import 'package:launcher_icons/src/core/logger.dart';
import 'package:launcher_icons/src/core/utils.dart';

/// A base class to generate icons
abstract class IconGenerator {
  /// Contains config
  final IconGeneratorContext context;

  /// Name of the platform this [IconGenerator] is created for.
  final String platformName;

  /// Creates a instance of [IconGenerator].
  ///
  /// A [context] is created and provided by [generateIconsFor],
  /// [platformName] takes the name of the platform that this [IconGenerator]
  /// is implemented for
  ///
  /// Also Refer
  /// - [WebIconGenerator] generate icons for web
  /// - [generateIconFor] generates icons for given platform
  IconGenerator(this.context, this.platformName);

  /// Creates icons for this platform.
  Future<void> createIcons();

  /// Whether icon generation is enabled in the platform configuration.
  bool get isEnabled;

  /// Should return `true` if this platform
  /// has all the requirements to create icons.
  /// This runs before to [createIcons]
  bool validateRequirements();
}

/// Provides easy access to user arguments and configuration
class IconGeneratorContext {
  /// Contains configuration from configuration file
  final Config config;

  /// A logger
  final LILogger logger;

  /// Value of `--prefix` flag
  final String prefixPath;

  /// Value of `--flavor` flag
  final String? flavor;

  /// Single-run memo of SVG rasterizations, shared by every platform
  /// generator in this run. Owned by the context (one per run) so
  /// deduplication never leaks across runs.
  final SvgRasterCache svgRasterCache;

  /// Creates an instance of [IconGeneratorContext]
  IconGeneratorContext({
    required this.config,
    required this.logger,
    required this.prefixPath,
    this.flavor,
    SvgRasterCache? svgRasterCache,
  }) : svgRasterCache = svgRasterCache ?? SvgRasterCache();

  /// Shortcut for `config.webConfig`
  WebConfig? get webConfig => config.webConfig;

  /// Shortcut for `config.windowsConfig`
  WindowsConfig? get windowsConfig => config.windowsConfig;

  /// Shortcut for `config.macOSConfig`
  MacOSConfig? get macOSConfig => config.macOSConfig;

  /// Shortcut for `config.linuxConfig`
  LinuxConfig? get linuxConfig => config.linuxConfig;
}

/// Generates Icon for given platforms
Future<void> generateIconsFor({
  required Config config,
  required String? flavor,
  required String prefixPath,
  required LILogger logger,
  required List<IconGenerator> Function(IconGeneratorContext context) platforms,
}) async {
  final failedPlatforms = <String>[];
  try {
    final platformList = platforms(
      IconGeneratorContext(
        config: config,
        logger: logger,
        prefixPath: prefixPath,
        flavor: flavor,
      ),
    );
    if (platformList.isEmpty) {
      // ? maybe we can print help
      logger.info('No platform provided');
    }

    for (final platform in platformList) {
      if (!platform.isEnabled) {
        logger.info('${platform.platformName} skipped in the config');
        continue;
      }
      final progress = logger.progress('Creating Icons for ${platform.platformName}');
      logger.verbose(
        'Validating platform requirements for ${platform.platformName}',
      );
      // A failing platform must not stop the remaining ones, but the run
      // as a whole still fails: failures are collected and reported together
      // via [IconGenerationException] below.
      try {
        if (!platform.validateRequirements()) {
          logger.error(
            'Requirements failed for platform ${platform.platformName}. Skipped',
          );
          progress.cancel();
          continue;
        }
        await platform.createIcons();
        progress.finish(message: 'done', showTiming: true);
      } catch (e, st) {
        progress.cancel();
        logger
          ..error(e.toString())
          ..verbose(st);
        failedPlatforms.add(platform.platformName);
        continue;
      }
    }
  } catch (e, st) {
    // Stacktrace only prints when verbose is turned on, else a normal help line.
    logger
      ..error(e.toString())
      ..verbose(st);
    exit(1);
  }
  if (failedPlatforms.isNotEmpty) {
    throw IconGenerationException(failedPlatforms);
  }
}
