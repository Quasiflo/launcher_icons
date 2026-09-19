import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart';
import 'package:launcher_icons/src/core/constants.dart' as constants;
import 'package:launcher_icons/src/core/custom_exceptions.dart';
import 'package:launcher_icons/src/core/icon_generator.dart';
import 'package:launcher_icons/src/core/paths.dart' as paths;
import 'package:launcher_icons/src/core/utils.dart' as utils;
import 'package:path/path.dart' as path;

import 'web_template.dart';

/// Generates Web icons for flutter
class WebIconGenerator extends IconGenerator {
  static const _webIconSizeTemplates = <WebIconTemplate>[
    WebIconTemplate(size: 192),
    WebIconTemplate(size: 512),
    WebIconTemplate(size: 192, maskable: true),
    WebIconTemplate(size: 512, maskable: true),
  ];

  /// Consensus multi-frame favicon container.
  static const _faviconIcoSizes = [16, 32, 48];

  /// Creates an instance of [WebIconGenerator].
  ///
  ///
  WebIconGenerator(IconGeneratorContext context) : super(context, 'Web');

  /// Web root directory honoring `output_path` (default `web`), so flavors
  /// can target separate web roots (fluttercommunity/flutter_launcher_icons#426).
  String get _webRoot => context.config.webConfig?.outputPath ?? paths.webDirPath;

  /// All web file paths resolved under [_webRoot] via the shared path helpers.

  @override
  Future<void> createIcons() async {
    final imgFilePath = path.join(
      context.prefixPath,
      context.config.resolveImageFile(context.config.webConfig!.imagePath, context.prefixPath),
    );

    // load and decode the image file
    context.logger.verbose('Decoding and loading image file at $imgFilePath...');
    final loadBase = await utils.sizeImageLoaderFor(
      imgFilePath,
      logger: context.logger,
      cache: context.svgRasterCache,
    );

    // resolve the favicon image path and file, which is either one explicitly provided or the same as the image file loaded above
    late final String faviconImgFilePath;
    late final utils.SizeImageLoader loadFavicon;
    final faviconImagePathOverride = context.config.webConfig!.imagePathFavicon;
    if (faviconImagePathOverride != null) {
      // favicon override was specified, construct the full path and decode
      faviconImgFilePath = path.join(context.prefixPath, faviconImagePathOverride);
      loadFavicon = await utils.sizeImageLoaderFor(
        faviconImgFilePath,
        logger: context.logger,
        cache: context.svgRasterCache,
      );
    } else {
      // no favicon override, use the fallback image file
      faviconImgFilePath = imgFilePath;
      loadFavicon = loadBase;
    }

    // resolve the maskable image: a dedicated source when provided,
    // otherwise the base image with padded derivation at write time.
    // The derivation logo always comes from a 1024 render so the ~80%
    // downscale starts at full quality.
    utils.SizeImageLoader? loadMaskable;
    Image? deriveLogo;
    final maskableImagePathOverride = context.config.webConfig!.imagePathMaskable;
    final deriveMaskable = maskableImagePathOverride == null;
    if (maskableImagePathOverride != null) {
      final maskableImgFilePath = path.join(context.prefixPath, maskableImagePathOverride);
      context.logger.verbose(
        'Decoding and loading maskable image file at $maskableImgFilePath...',
      );
      loadMaskable = await utils.sizeImageLoaderFor(
        maskableImgFilePath,
        logger: context.logger,
        cache: context.svgRasterCache,
      );
    } else {
      deriveLogo = await loadBase(utils.svgMasterSize);
      if (deriveLogo.hasAlpha) {
        context.logger.info(
          'WARNING: Base image has transparency; deriving maskable icons '
          'by centering the logo at ~80% on the opaque background_color. '
          'Provide `web.image_path_maskable` for a designed full-bleed '
          'maskable source.',
        );
      }
    }

    // generate favicon in web/favicon.png
    context.logger.verbose('Generating favicon from $faviconImgFilePath...');
    await _generateFavicon(loadFavicon);

    // generate icons in web/icons/
    context.logger.verbose('Generating icons from $imgFilePath...');
    await _generateIcons(loadBase, loadMaskable, deriveLogo, deriveMaskable);

    // update manifest.json in <web root>/manifest.json
    context.logger.verbose(
      'Updating ${path.join(context.prefixPath, paths.webManifestFilePath(_webRoot))}...',
    );
    await _updateManifestFile();

    // iOS Safari needs an explicit opaque 180px touch icon.
    context.logger.verbose('Generating apple-touch-icon from $imgFilePath...');
    await _generateAppleTouchIcon(loadBase);

    // make the generated files discoverable from index.html
    context.logger.verbose(
      'Updating ${path.join(context.prefixPath, paths.webIndexFilePath(_webRoot))}...',
    );
    await _updateIndexFile();
  }

  @override
  bool validateRequirements() {
    // The generate flag is enforced by the caller via the config enabled flag; only filesystem and config preconditions are checked here.
    context.logger.verbose('Checking webconfig...');
    final webConfig = context.config.webConfig!;
    try {
      context.config.resolveImageFile(webConfig.imagePath, context.prefixPath);
    } on InvalidConfigException catch (e) {
      context.logger.error(e.message);
      return false;
    }

    // verify web platform related files and directories exists
    final entitesToCheck = [
      path.join(context.prefixPath, _webRoot),
      path.join(context.prefixPath, paths.webManifestFilePath(_webRoot)),
      path.join(context.prefixPath, paths.webIndexFilePath(_webRoot)),
    ];

    // web platform related files must exist to continue
    final failedEntityPath = utils.areFSEntiesExist(entitesToCheck);
    if (failedEntityPath != null) {
      context.logger.error(
        '$failedEntityPath this file or folder is required to generate web icons',
      );
      return false;
    }

    // background_color/theme_color land verbatim in manifest.json and the
    // index block, so they must be valid CSS hex colors.
    final backgroundColor = webConfig.backgroundColor;
    if (backgroundColor != null && !utils.isHexColor(backgroundColor)) {
      context.logger.error(
        'Invalid web.background_color "$backgroundColor": '
        'must be a hex color like "#ffffff".',
      );
      return false;
    }
    final themeColor = webConfig.themeColor;
    if (themeColor != null && !utils.isHexColor(themeColor)) {
      context.logger.error(
        'Invalid web.theme_color "$themeColor": '
        'must be a hex color like "#ffffff".',
      );
      return false;
    }

    return true;
  }

  Future<void> _generateFavicon(utils.SizeImageLoader loadFavicon) async {
    final size = context.config.webConfig?.faviconSize ?? constants.kFaviconSize;
    final favIcon = await loadFavicon(
      size > 0 ? size : constants.kFaviconSize,
    );
    final favIconFile = await utils.createFileIfNotExist(
      path.join(context.prefixPath, paths.webFaviconFilePath(_webRoot)),
    );
    await favIconFile.writeAsBytes(encodePng(favIcon));
    if (context.config.webConfig?.faviconIco ?? true) {
      // Browsers request /favicon.ico by default; emit the consensus
      // multi-frame container alongside the PNG (fluttercommunity/flutter_launcher_icons#540).
      final multi = await loadFavicon(_faviconIcoSizes.first);
      for (final frameSize in _faviconIcoSizes.skip(1)) {
        multi.addFrame(await loadFavicon(frameSize));
      }
      final favIcoFile = await utils.createFileIfNotExist(
        path.join(context.prefixPath, paths.webFaviconIcoFilePath(_webRoot)),
      );
      await favIcoFile.writeAsBytes(encodeIco(multi));
    }
    // index.html keeps pointing at favicon.png, either file now resolves.
  }

  Future<void> _generateIcons(
    utils.SizeImageLoader loadBase,
    utils.SizeImageLoader? loadMaskable,
    Image? deriveLogo,
    bool deriveMaskable,
  ) async {
    final iconsDir = await utils.createDirIfNotExist(
      path.join(context.prefixPath, paths.webIconsDirPath(_webRoot)),
    );
    // generate icons
    for (final template in _webIconSizeTemplates) {
      final Image resizedImg;
      if (template.maskable && deriveMaskable) {
        resizedImg = _buildPaddedMaskable(deriveLogo!, template.size);
      } else if (template.maskable) {
        resizedImg = await loadMaskable!(template.size);
      } else {
        resizedImg = await loadBase(template.size);
      }
      final iconFile = await utils.createFileIfNotExist(
        path.join(context.prefixPath, iconsDir.path, template.iconFile),
      );
      await iconFile.writeAsBytes(encodePng(resizedImg));
    }
  }

  /// Derives a safe-zone-compliant maskable icon: the logo scaled to ~80%
  /// and centered on the opaque `background_color` (white fallback) so the
  /// outer edge survives maskable cropping.
  Image _buildPaddedMaskable(Image source, int size) {
    var bg = (r: 255, g: 255, b: 255);
    final bgRaw = context.config.webConfig?.backgroundColor;
    if (bgRaw != null) {
      try {
        bg = utils.parseHexColor(bgRaw);
      } catch (_) {
        context.logger.verbose(
          'Ignoring non-hex background_color "$bgRaw" for maskable icons; using white.',
        );
      }
    }
    final artwork = utils.createResizedImage((size * 0.8).round(), source);
    final canvas = Image(width: size, height: size, numChannels: 4);
    fill(canvas, color: ColorUint8.rgb(bg.r, bg.g, bg.b));
    compositeImage(canvas, artwork, center: true);
    return canvas.convert(numChannels: 3);
  }

  Future<void> _updateManifestFile() async {
    final manifestFile = await utils.createFileIfNotExist(
      path.join(context.prefixPath, paths.webManifestFilePath(_webRoot)),
    );
    final manifestConfig = jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;

    // update background_color
    if (context.config.webConfig?.backgroundColor != null) {
      manifestConfig['background_color'] = context.config.webConfig?.backgroundColor;
    }

    // update theme_color
    if (context.config.webConfig?.themeColor != null) {
      manifestConfig['theme_color'] = context.config.webConfig?.themeColor;
    }

    // replace existing icons to eliminate conflicts
    manifestConfig
      ..remove('icons')
      ..['icons'] = _webIconSizeTemplates.map<Map<String, dynamic>>((e) => e.iconManifest).toList();

    await manifestFile.writeAsString(utils.prettifyJsonEncode(manifestConfig));
  }

  /// Generates an opaque 180x180 `apple-touch-icon.png` by flattening the
  /// source onto `background_color` (white fallback).
  Future<void> _generateAppleTouchIcon(
    utils.SizeImageLoader loadBase,
  ) async {
    const size = 180;
    final resized = await loadBase(size);
    final rgba = resized.numChannels == 4 ? resized : resized.convert(numChannels: 4);

    var bg = (r: 255, g: 255, b: 255);
    final bgRaw = context.config.webConfig?.backgroundColor;
    if (bgRaw != null) {
      try {
        bg = utils.parseHexColor(bgRaw);
      } catch (_) {
        context.logger.verbose(
          'Ignoring non-hex background_color "$bgRaw" for apple-touch-icon; using white.',
        );
      }
    }

    final flat = Image(width: size, height: size, numChannels: 3);
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final pixel = rgba.getPixel(x, y);
        final alpha = pixel.a.toInt().clamp(0, 255);
        final invAlpha = 255 - alpha;
        flat.setPixelRgb(
          x,
          y,
          (pixel.r.toInt() * alpha + bg.r * invAlpha) ~/ 255,
          (pixel.g.toInt() * alpha + bg.g * invAlpha) ~/ 255,
          (pixel.b.toInt() * alpha + bg.b * invAlpha) ~/ 255,
        );
      }
    }

    final iconFile = await utils.createFileIfNotExist(
      path.join(context.prefixPath, paths.webAppleTouchIconFilePath(_webRoot)),
    );
    await iconFile.writeAsBytes(encodePng(flat));
  }

  /// Manages an idempotent `<!--LI-->…<!--LIEND-->` block in index.html
  /// wiring up the favicon, apple-touch-icon, manifest, and theme-color.
  /// An existing block is replaced in place; otherwise the block is
  /// inserted before `</head>`.
  Future<void> _updateIndexFile() async {
    final indexFile = File(path.join(context.prefixPath, paths.webIndexFilePath(_webRoot)));
    var content = await indexFile.readAsString();

    final favSize = context.config.webConfig?.faviconSize ?? constants.kFaviconSize;
    final themeColor = context.config.webConfig?.themeColor;
    final includeIco = context.config.webConfig?.faviconIco ?? true;
    final block = '''
  <!--LI-->${includeIco ? '\n  <link rel="icon" type="image/x-icon" sizes="any" href="favicon.ico"/>' : ''}
  <link rel="icon" type="image/png" sizes="${favSize}x$favSize" href="favicon.png"/>
  <link rel="apple-touch-icon" href="icons/apple-touch-icon.png"/>
  <link rel="manifest" href="manifest.json"/>${themeColor != null ? '\n  <meta name="theme-color" content="$themeColor"/>' : ''}
  <!--LIEND-->''';

    final pattern = RegExp(r'<!--LI-->.*?<!--LIEND-->', dotAll: true);
    if (pattern.hasMatch(content)) {
      content = content.replaceAll(pattern, block);
    } else if (content.contains('</head>')) {
      content = content.replaceFirst('</head>', '$block\n</head>');
    } else {
      content = '$content\n$block\n';
    }
    await indexFile.writeAsString(content);
  }
}
