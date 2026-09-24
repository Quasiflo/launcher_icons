import 'package:launcher_icons/src/config/config.dart';
import 'package:launcher_icons/src/core/logger.dart';
import 'package:launcher_icons/src/core/utils.dart';

/// A base class to generate icons
abstract class IconGenerator {
  /// Creates a instance of [IconGenerator].
  ///
  /// A [context] is created and provided, [platformName] takes the name of the platform that this [IconGenerator] is implemented for
  IconGenerator(this.context, this.platformName);

  /// Contains config
  final IconGeneratorContext context;

  /// Name of the platform this [IconGenerator] is created for.
  final String platformName;

  /// Creates icons for this platform.
  Future<void> createIcons();

  /// Should return `true` if this platform has all the requirements to create icons. This runs before to [createIcons]
  bool validateRequirements();
}

/// Provides easy access to user arguments and configuration
class IconGeneratorContext {
  /// Creates an instance of [IconGeneratorContext]
  IconGeneratorContext({
    required this.config,
    required this.logger,
    required this.prefixPath,
    this.flavor,
    final SvgRasterCache? svgRasterCache,
  }) : svgRasterCache = svgRasterCache ?? SvgRasterCache();

  /// Contains configuration from configuration file
  final Config config;

  /// A logger
  final LILogger logger;

  /// Value of `--prefix` flag
  final String prefixPath;

  /// Value of `--flavor` flag
  final String? flavor;

  /// Single-run memo of SVG rasterizations, shared by every platform generator in this run. Owned by the context (one per run) so deduplication never leaks across runs.
  final SvgRasterCache svgRasterCache;
}
