import 'dart:io';

import 'package:image/image.dart';
import 'package:launcher_icons/src/core/constants.dart' as constants;
import 'package:launcher_icons/src/core/custom_exceptions.dart';
import 'package:launcher_icons/src/core/icon_generator.dart';
import 'package:launcher_icons/src/core/paths.dart' as paths;
import 'package:launcher_icons/src/core/utils.dart' as utils;
import 'package:path/path.dart' as path;

/// A Implementation of [WindowsIconGenerator] for Windows
class WindowsIconGenerator extends IconGenerator {
  /// Creates a instance of [WindowsIconGenerator]
  WindowsIconGenerator(IconGeneratorContext context) : super(context, 'Windows');

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

    // Every optional image source must exist when set.
    final optionalSources = <String, String?>{
      'windows.image_path_unplated': windowsConfig.imagePathUnplated,
      'windows.image_path_light_unplated': windowsConfig.imagePathLightUnplated,
      'windows.image_path_wide': windowsConfig.imagePathWide,
    };
    for (final entry in optionalSources.entries) {
      final value = entry.value;
      if (value != null && !File(path.join(context.prefixPath, value)).existsSync()) {
        context.logger.error('Missing "${entry.key}" image file: "$value"');
        return false;
      }
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

  @override
  Future<void> createIcons() async {
    final windowsConfig = context.config.windowsConfig!;
    final imgFilePath = path.join(
      context.prefixPath,
      context.config.resolveImageFile(windowsConfig.imagePath, context.prefixPath),
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

    context.logger.verbose('Generating AppList target-size assets from $imgFilePath...');
    final imagesDir = await _generateAppListAssets();

    context.logger.verbose('Generating tile scale assets from $imgFilePath...');
    await _generateTileAssets(imagesDir);
  }

  Future<void> _generateIcon(utils.SizeImageLoader loadSize) async {
    // Build a multi-frame ICO: one frame per target size.
    Image? multi;
    for (final sz in constants.windowsIcoSizes) {
      final resized = await loadSize(sz);
      if (multi == null) {
        multi = resized;
      } else {
        multi.addFrame(resized);
      }
    }
    // Per-flavor names (icon_filename) let sequential flavor runs target distinct resources; the default stays the Runner.rc contract.
    final iconFile = await utils.createFileIfNotExist(
      path.join(
        context.prefixPath,
        paths.windowsResourcesDirPath,
        context.config.windowsConfig?.iconFilename ?? paths.windowsDefaultIconFilename,
      ),
    );
    await iconFile.writeAsBytes(encodeIco(multi!));
  }

  /// Emits the MSIX AppList set next to a `Square44x44Logo.png` base file: plated full-bleed renders plus unpadded bare-mark variants for dark (`altform-unplated`) and light (`altform-lightunplated`) shell themes. Windows resolves the qualified variants off the manifest entry at runtime. Returns the images directory for tile generation.
  Future<Directory> _generateAppListAssets() async {
    final windowsConfig = context.config.windowsConfig!;
    final imagesDir = await utils.createDirIfNotExist(
      path.join(context.prefixPath, paths.windowsImagesDirPath),
    );

    Future<utils.SizeImageLoader> loaderFor(String? override, String label) async {
      if (override == null) {
        return (int size) async => utils.createResizedImage(size, await _paddedMark(await _baseMaster(), size));
      }
      final overridePath = path.join(context.prefixPath, override);
      context.logger.verbose('Decoding and loading $label image file from $overridePath...');
      return utils.sizeImageLoaderFor(
        overridePath,
        logger: context.logger,
        cache: context.svgRasterCache,
      );
    }

    final loadBase = await _baseLoader();
    final loadUnplated = await loaderFor(windowsConfig.imagePathUnplated, 'unplated');
    final loadLightUnplated = await loaderFor(windowsConfig.imagePathLightUnplated, 'light unplated');
    if (windowsConfig.imagePathUnplated == null || windowsConfig.imagePathLightUnplated == null) {
      context.logger.info(
        'WARNING: No dedicated unplated source; deriving bare-mark AppList assets by padding the base image to ~75% on transparency. '
        'Provide `windows.image_path_unplated` / `windows.image_path_light_unplated` for designed theme artwork.',
      );
    }

    // Base file the manifest entry points at.
    final baseFile = await utils.createFileIfNotExist(
      path.join(context.prefixPath, imagesDir.path, constants.windowsAppListBaseName),
    );
    await baseFile.writeAsBytes(encodePng(await loadBase(44)));

    // Plated full-bleed renders plus both bare-mark theme variants per target size.
    for (final size in constants.windowsAppListTargetSizes) {
      for (final entry in <({String suffix, utils.SizeImageLoader load})>[
        (suffix: '', load: loadBase),
        (suffix: '_altform-unplated', load: loadUnplated),
        (suffix: '_altform-lightunplated', load: loadLightUnplated),
      ]) {
        final file = await utils.createFileIfNotExist(
          path.join(
            context.prefixPath,
            imagesDir.path,
            'Square44x44Logo.targetsize-$size${entry.suffix}.png',
          ),
        );
        await file.writeAsBytes(encodePng(await entry.load(size)));
      }
    }

    return imagesDir;
  }

  /// Emits tile scale sets (`<Base>.scale-<N>.png`) for the `Square44x44Logo`, `Square150x150Logo`, and `Wide310x150Logo` manifest entries, plus the unqualified base file each entry points at. Pixel sizes follow `round(base * scale / 100)` per the MSIX app-icon construction table. The wide set renders from `image_path_wide` when set, otherwise from a center cover-crop of the base image. A manifest snippet for hand packaging is written alongside.
  Future<void> _generateTileAssets(Directory imagesDir) async {
    final windowsConfig = context.config.windowsConfig!;
    final loadBase = await _baseLoader();

    for (final tile in <({String base, int size})>[
      (base: 'Square44x44Logo', size: constants.windowsSquare44Base),
      (base: 'Square150x150Logo', size: constants.windowsSquare150Base),
    ]) {
      final baseFile = await utils.createFileIfNotExist(
        path.join(context.prefixPath, imagesDir.path, '${tile.base}.png'),
      );
      await baseFile.writeAsBytes(encodePng(await loadBase(tile.size)));
      for (final scale in constants.windowsTileScales) {
        final px = (tile.size * scale / 100).round();
        final file = await utils.createFileIfNotExist(
          path.join(context.prefixPath, imagesDir.path, '${tile.base}.scale-$scale.png'),
        );
        await file.writeAsBytes(encodePng(await loadBase(px)));
      }
    }

    final loadWide = await _wideLoader();
    if (windowsConfig.imagePathWide == null) {
      context.logger.info(
        'WARNING: No dedicated wide source; deriving Wide310x150Logo assets with a center cover-crop of the base image. '
        'Provide `windows.image_path_wide` for designed wide artwork.',
      );
    }
    final wideBaseFile = await utils.createFileIfNotExist(
      path.join(context.prefixPath, imagesDir.path, 'Wide310x150Logo.png'),
    );
    await wideBaseFile.writeAsBytes(
      encodePng(await loadWide(constants.windowsWide310Width, constants.windowsWide150Height)),
    );
    for (final scale in constants.windowsTileScales) {
      final width = (constants.windowsWide310Width * scale / 100).round();
      final height = (constants.windowsWide150Height * scale / 100).round();
      final file = await utils.createFileIfNotExist(
        path.join(context.prefixPath, imagesDir.path, 'Wide310x150Logo.scale-$scale.png'),
      );
      await file.writeAsBytes(encodePng(await loadWide(width, height)));
    }

    final snippetFile = await utils.createFileIfNotExist(
      path.join(context.prefixPath, imagesDir.path, paths.windowsManifestSnippetFileName),
    );
    await snippetFile.writeAsString(_manifestSnippet());
  }

  /// Rectangular loader cover-cropping a master so any source fills a landscape canvas without stretching.
  Future<Image> _coverCrop(Image source, int width, int height) async {
    final scale = [width / source.width, height / source.height].reduce((a, b) => a > b ? a : b);
    final scaled = copyResize(
      source,
      width: (source.width * scale).round(),
      height: (source.height * scale).round(),
      interpolation: Interpolation.average,
    );
    return copyCrop(
      scaled,
      x: ((scaled.width - width) / 2).round(),
      y: ((scaled.height - height) / 2).round(),
      width: width,
      height: height,
    );
  }

  /// Wide-tile loader from the dedicated source when set, otherwise from the base master.
  Future<Future<Image> Function(int width, int height)> _wideLoader() async {
    final windowsConfig = context.config.windowsConfig!;
    if (windowsConfig.imagePathWide != null) {
      final widePath = path.join(context.prefixPath, windowsConfig.imagePathWide!);
      context.logger.verbose('Decoding and loading wide image file from $widePath...');
      final master = await utils.decodeImageFile(widePath, cache: context.svgRasterCache);
      return (int width, int height) => _coverCrop(master, width, height);
    }
    final master = await _baseMaster();
    return (int width, int height) => _coverCrop(master, width, height);
  }

  Image? _baseMasterCache;

  /// 1024 master of the base image so padded derivations start at full quality.
  Future<Image> _baseMaster() async {
    if (_baseMasterCache != null) {
      return _baseMasterCache!;
    }
    final windowsConfig = context.config.windowsConfig!;
    final imgFilePath = path.join(
      context.prefixPath,
      context.config.resolveImageFile(windowsConfig.imagePath, context.prefixPath),
    );
    _baseMasterCache = await utils.decodeImageFile(imgFilePath, cache: context.svgRasterCache);
    return _baseMasterCache!;
  }

  /// Square loader over the base master.
  Future<utils.SizeImageLoader> _baseLoader() async {
    final master = await _baseMaster();
    return (int size) async => utils.createResizedImage(size, master);
  }

  /// Bare-mark derivation: artwork scaled to [windowsUnplatedArtworkScale] of the canvas and centered on transparency.
  Future<Image> _paddedMark(Image master, int size) async {
    final artwork = utils.createResizedImage((size * constants.windowsUnplatedArtworkScale).round(), master);
    final canvas = Image(width: size, height: size, numChannels: 4);
    fill(canvas, color: ColorUint8.rgba(0, 0, 0, 0));
    compositeImage(canvas, artwork, center: true);
    return canvas;
  }

  /// Manifest fragment wiring the emitted assets for hand-authored MSIX packaging. Qualified variants resolve off the base entries at runtime once `makepri` indexes the `Images` folder.
  String _manifestSnippet() => '''
<!-- Copy into your MSIX Package.appxmanifest. Copy windows/images/ next to it as Images/. -->
<uap:VisualElements DisplayName="MyApp"
                    Description="MyApp"
                    BackgroundColor="transparent"
                    Square150x150Logo="Images\\Square150x150Logo.png"
                    Square44x44Logo="Images\\${constants.windowsAppListBaseName}">
  <uap:DefaultTile Wide310x150Logo="Images\\Wide310x150Logo.png" />
</uap:VisualElements>
''';
}
