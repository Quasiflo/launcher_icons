import 'package:image/image.dart';
import 'package:launcher_icons/src/core/constants.dart' as constants;
import 'package:launcher_icons/src/core/icon_generator.dart';
import 'package:launcher_icons/src/core/utils.dart' as utils;
import 'package:path/path.dart' as path;

/// A Implementation of [IconGenerator] for Windows
class WindowsIconGenerator extends IconGenerator {
  /// Creates a instance of [WindowsIconGenerator]
  WindowsIconGenerator(IconGeneratorContext context)
      : super(context, 'Windows');

  // Minimal, sensible defaults for Windows ICOs: the Win32 required sets
  // (app icons + Classic Mode) plus 40/64 for classic-set completeness
  // and Alt+Tab crispness. PNG-compressed frames keep the uplift small.
  static const List<int> _icoSizes = [16, 24, 32, 40, 48, 64, 256];

  @override
  bool get isEnabled => context.windowsConfig?.generate ?? false;

  @override
  Future<void> createIcons() async {
    final imgFilePath = path.join(
      context.prefixPath,
      context.config.resolveImagePath(context.windowsConfig!.imagePath),
    );

    context.logger
        .verbose('Decoding and loading image file from $imgFilePath...');
    final bool svgInput = utils.isSvgPath(imgFilePath);
    final perSize = context.config.svgRasterizePerSize && svgInput;
    utils.SizeImageLoader loadSize;
    if (perSize) {
      loadSize = await utils.sizeImageLoaderFor(
        imgFilePath,
        perSize: true,
        logger: context.logger,
        cache: context.svgRasterCache,
      );
    } else {
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

      loadSize = (size) async => utils.createResizedImage(size, imgFile);
    }

    context.logger.verbose('Generating icon from $imgFilePath...');
    await _generateIcon(loadSize);
  }

  @override
  bool validateRequirements() {
    // The generate flag is enforced by [isEnabled]; only filesystem and
    // config preconditions are checked here.
    context.logger.verbose('Validating windows config...');
    final windowsConfig = context.windowsConfig!;

    if (context.config.resolveImagePath(windowsConfig.imagePath) == null) {
      context.logger.error(
        'Invalid config. Either provide windows.image_path or image_path',
      );
      return false;
    }

    final entitesToCheck = [
      path.join(context.prefixPath, constants.windowsDirPath),
      path.join(
        context.prefixPath,
        windowsConfig.imagePath ?? context.config.imagePath,
      ),
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
        constants.windowsResourcesDirPath,
        context.windowsConfig?.iconFilename ?? 'app_icon.ico',
      ),
    );
    await iconFile.writeAsBytes(encodeIco(multi!));
  }
}
