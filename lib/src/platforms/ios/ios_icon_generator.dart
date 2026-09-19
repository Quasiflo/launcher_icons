import 'dart:io';

import 'package:launcher_icons/src/core/custom_exceptions.dart';
import 'package:launcher_icons/src/core/icon_generator.dart';
import 'package:launcher_icons/src/core/paths.dart' as paths;
import 'package:launcher_icons/src/core/utils.dart' as utils;
import 'package:launcher_icons/src/platforms/ios/ios.dart' as ios;

/// An implementation of [IconGenerator] for iOS.
class IosIconGenerator extends IconGenerator {
  /// Creates an instance of [IosIconGenerator].
  IosIconGenerator(IconGeneratorContext context) : super(context, 'iOS');

  @override
  bool validateRequirements() {
    // The generate flag is enforced by the caller via the config enabled flag; only filesystem and config preconditions are checked here.
    context.logger.verbose('Validating iOS config...');
    final config = context.config;

    final bool iconOnly = config.iosConfig?.iconOnly ?? false;
    final bool hasGlass = (config.iosConfig?.liquidGlassLayers?.isNotEmpty ?? false) || (config.iosConfig?.liquidGlassGroups?.isNotEmpty ?? false);
    if (iconOnly && !hasGlass) {
      context.logger.error(
        '`ios.icon_only` requires `liquid_glass_layers` or `liquid_glass_groups`: there is nothing else to emit.',
      );
      return false;
    }

    // The PNG catalog needs a base image; icon-only runs render the `.icon` from layer sources alone.
    if (!iconOnly) {
      try {
        config.resolveImageFile(config.iosConfig?.imagePath, context.prefixPath);
      } on InvalidConfigException catch (e) {
        context.logger.error(e.message);
        return false;
      }
    }

    final failedEntityPath = utils.areFSEntiesExist(
      [utils.withPrefix(context.prefixPath, paths.iosDirPath)],
    );
    if (failedEntityPath != null) {
      context.logger.error(
        '$failedEntityPath this file or folder is required to generate iOS icons',
      );
      return false;
    }

    // Config mistakes fail here (loudly, once) instead of mid-generation:
    // an unknown flavor_mode, or a dark/tinted source that does not exist.
    final flavorMode = config.iosConfig?.flavorMode ?? 'pbxproj';
    if (flavorMode != 'pbxproj' && flavorMode != 'xcconfig') {
      context.logger.error(
        'Invalid `ios.flavor_mode` "$flavorMode": must be "pbxproj" or "xcconfig".',
      );
      return false;
    }
    for (final entry in {
      'image_path_dark_transparent': config.iosConfig?.imagePathDarkTransparent,
      'image_path_tinted_grayscale': config.iosConfig?.imagePathTintedGrayscale,
    }.entries) {
      final source = entry.value;
      if (source != null && !File(utils.withPrefix(context.prefixPath, source)).existsSync()) {
        context.logger.error(
          'Invalid `ios.${entry.key}` "$source": file does not exist.',
        );
        return false;
      }
    }

    return true;
  }

  @override
  Future<void> createIcons() async {
    await ios.createIcons(
      context.config,
      context.flavor,
      logger: context.logger,
      prefixPath: context.prefixPath,
      cache: context.svgRasterCache,
    );
  }
}
