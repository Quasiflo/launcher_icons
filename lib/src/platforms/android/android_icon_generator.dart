import 'package:launcher_icons/src/core/custom_exceptions.dart';
import 'package:launcher_icons/src/core/icon_generator.dart';
import 'package:launcher_icons/src/core/logger.dart';
import 'package:launcher_icons/src/core/paths.dart' as paths;
import 'package:launcher_icons/src/core/utils.dart' as utils;
import 'package:launcher_icons/src/platforms/android/android.dart' as android;

/// An implementation of [IconGenerator] for Android.
class AndroidIconGenerator extends IconGenerator {
  /// Creates an instance of [AndroidIconGenerator].
  AndroidIconGenerator(IconGeneratorContext context) : super(context, 'Android');

  @override
  bool validateRequirements() {
    // The generate flag is enforced by the caller via the config enabled flag; only filesystem and config preconditions are checked here.
    context.logger.verbose('Validating Android config...');
    final config = context.config;
    try {
      config.resolveImageFile(config.androidConfig?.imagePath, context.prefixPath);
    } on InvalidConfigException catch (e) {
      context.logger.error(e.message);
      return false;
    }

    final failedEntityPath = utils.areFSEntiesExist(
      [utils.withPrefix(context.prefixPath, paths.androidDirPath)],
    );
    if (failedEntityPath != null) {
      context.logger.error(
        '$failedEntityPath this file or folder is required to generate Android icons',
      );
      return false;
    }

    return true;
  }

  @override
  Future<void> createIcons() async {
    final config = context.config;
    final flavor = context.flavor;
    final prefixPath = context.prefixPath;
    final LILogger logger = context.logger;

    final concurrentIconCreation = <Future<void>>[];
    if (config.androidEnabled) {
      concurrentIconCreation.add(
        android.createDefaultIcons(
          config,
          flavor,
          logger: logger,
          prefixPath: prefixPath,
          cache: context.svgRasterCache,
        ),
      );
    }
    if (android.hasAndroidAdaptiveConfig(config)) {
      concurrentIconCreation.add(
        android.createAdaptiveIcons(
          config,
          flavor,
          logger: logger,
          prefixPath: prefixPath,
          cache: context.svgRasterCache,
        ),
      );
    }
    if (android.hasAndroidAdaptiveMonochromeConfig(config)) {
      concurrentIconCreation.add(
        android.createAdaptiveMonochromeIcons(
          config,
          flavor,
          logger: logger,
          prefixPath: prefixPath,
          cache: context.svgRasterCache,
        ),
      );
    }
    if (android.hasAndroidAdaptiveRoundConfig(config)) {
      concurrentIconCreation.add(
        android.createAdaptiveRoundIcons(
          config,
          flavor,
          logger: logger,
          prefixPath: prefixPath,
          cache: context.svgRasterCache,
        ),
      );
    }
    if (android.hasAndroidNotificationConfig(config)) {
      concurrentIconCreation.add(
        android.createNotificationIcons(
          config,
          flavor,
          logger: logger,
          prefixPath: prefixPath,
          cache: context.svgRasterCache,
        ),
      );
    }
    await Future.wait(concurrentIconCreation);
    if (config.androidEnabled) {
      await android.createMipmapXmlFile(
        config,
        flavor,
        logger: logger,
        prefixPath: prefixPath,
      );
    }
  }
}
