import 'package:launcher_icons/src/core/icon_generator.dart';
import 'package:launcher_icons/src/core/logger.dart';
import 'package:launcher_icons/src/core/utils.dart' as utils;
import 'package:launcher_icons/src/platforms/android/android.dart' as android;

/// An implementation of [IconGenerator] for Android.
class AndroidIconGenerator extends IconGenerator {
  /// Creates an instance of [AndroidIconGenerator].
  AndroidIconGenerator(IconGeneratorContext context) : super(context, 'Android');

  @override
  bool get isEnabled => context.config.isNeedingNewAndroidIcon;

  @override
  bool validateRequirements() {
    // The generate flag is enforced by [isEnabled]; only filesystem and
    // config preconditions are checked here.
    context.logger.verbose('Validating Android config...');
    final config = context.config;
    if (config.getImagePathAndroid() == null) {
      context.logger.error(
        'Invalid config. Either provide android.image_path or image_path',
      );
      return false;
    }

    final failedEntityPath = utils.areFSEntiesExist(
      [utils.withPrefix(context.prefixPath, 'android')],
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
    if (config.isNeedingNewAndroidIcon) {
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
    if (config.hasAndroidAdaptiveConfig) {
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
    if (config.hasAndroidAdaptiveMonochromeConfig) {
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
    if (config.hasAndroidAdaptiveRoundConfig) {
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
    await Future.wait(concurrentIconCreation);
    if (config.isNeedingNewAndroidIcon) {
      await android.createMipmapXmlFile(
        config,
        flavor,
        logger: logger,
        prefixPath: prefixPath,
      );
    }
    if (config.androidConfig?.playStoreIcon == true) {
      await android.createPlayStoreIcon(
        config,
        prefixPath,
        logger,
        context.svgRasterCache,
      );
    }
  }
}
