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
  bool get isEnabled => context.config.iosEnabled;

  @override
  bool validateRequirements() {
    // The generate flag is enforced by [isEnabled]; only filesystem and
    // config preconditions are checked here.
    context.logger.verbose('Validating iOS config...');
    final config = context.config;
    try {
      config.resolveImageFile(config.iosConfig?.imagePath, context.prefixPath);
    } on InvalidConfigException catch (e) {
      context.logger.error(e.message);
      return false;
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
