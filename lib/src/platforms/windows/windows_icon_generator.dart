import 'package:image/image.dart';
import 'package:launcher_icons/src/core/custom_exceptions.dart';
import 'package:launcher_icons/src/core/icon_generator.dart';
import 'package:launcher_icons/src/core/paths.dart' as paths;
import 'package:launcher_icons/src/core/utils.dart' as utils;
import 'package:path/path.dart' as path;

/// A Implementation of [IconGenerator] for Windows
class WindowsIconGenerator extends IconGenerator {
  /// Creates a instance of [WindowsIconGenerator]
  WindowsIconGenerator(IconGeneratorContext context) : super(context, 'Windows');

  // Minimal, sensible defaults for Windows ICOs: the Win32 required sets
  // (app icons + Classic Mode) plus 40/64 for classic-set completeness
  // and Alt+Tab crispness. PNG-compressed frames keep the uplift small.
  static const List<int> _icoSizes = [16, 24, 32, 40, 48, 64, 256];

  @override
  Future<void> createIcons() async {
    final imgFilePath = path.join(
      context.prefixPath,
      context.config.resolveImageFile(context.config.windowsConfig!.imagePath, context.prefixPath),
    );

    context.logger.verbose('Decoding and loading image file from $imgFilePath...');
    final bool svgInput = utils.isSvgPath(imgFilePath);
    final imgFile = await utils.decodeImageFile(
      imgFilePath,
      cache: context.svgRasterCache,
    );

    if (!svgInput && imgFile.width < 256) {
      context.logger.info(
        'WARNING: Source image is ${imgFile.width}px wide; the 256px ICO '
        'frame will be linearly upscaled and may look soft. '
        'Use a source of at least 256px for the crispest icon.',
      );
    }

    final utils.SizeImageLoader loadSize = (size) async => utils.createResizedImage(size, imgFile);

    context.logger.verbose('Generating icon from $imgFilePath...');
    await _generateIcon(loadSize);
  }

  @override
  bool validateRequirements() {
    // The generate flag is enforced by the caller via the config enabled flag; only filesystem and config preconditions are checked here.
    context.logger.verbose('Validating windows config...');
    final windowsConfig = context.config.windowsConfig!;

    try {
      context.config.resolveImageFile(windowsConfig.imagePath, context.prefixPath);
    } on InvalidConfigException catch (e) {
      context.logger.error(e.message);
      return false;
    }

    final entitesToCheck = [
      path.join(context.prefixPath, paths.windowsDirPath),
    ];

    final failedEntityPath = utils.areFSEntiesExist(entitesToCheck);
    if (failedEntityPath != null) {
      context.logger.error(
        '$failedEntityPath this file or folder is required to generate windows icons',
      );
      return false;
    }

    return true;
  }

  Future<void> _generateIcon(utils.SizeImageLoader loadSize) async {
    // Build a multi-frame ICO: one frame per target size.
    Image? multi;
    for (final sz in _icoSizes) {
      final resized = await loadSize(sz);
      if (multi == null) {
        multi = resized;
      } else {
        multi.addFrame(resized);
      }
    }
    // Per-flavor names (icon_filename) let sequential flavor runs target
    // distinct resources; the default stays the Runner.rc contract.
    final iconFile = await utils.createFileIfNotExist(
      path.join(
        context.prefixPath,
        paths.windowsResourcesDirPath,
        context.config.windowsConfig?.iconFilename ?? paths.windowsDefaultIconFilename,
      ),
    );
    await iconFile.writeAsBytes(encodeIco(multi!));
  }
}
