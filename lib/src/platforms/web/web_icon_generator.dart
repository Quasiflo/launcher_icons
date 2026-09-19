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
  /// Creates an instance of [WebIconGenerator].
  WebIconGenerator(IconGeneratorContext context) : super(context, 'Web');

  /// Web root directory honoring `output_path` (default `web`), so flavors can target separate web roots.
  String get _webRoot => context.config.webConfig?.outputPath ?? paths.webDirPath;

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

    // Every optional image source must exist when set
    final optionalSources = <String, String?>{
      'web.image_path_pwa': webConfig.imagePathPwa,
      'web.image_path_maskable': webConfig.imagePathMaskable,
      'web.image_path_monochrome': webConfig.imagePathMonochrome,
      'web.image_path_monochrome_maskable': webConfig.imagePathMonochromeMaskable,
      'web.image_path_favicon_svg': webConfig.imagePathFaviconSvg,
      'web.image_path_opengraph': webConfig.imagePathOpengraph,
      'web.image_path_twitter': webConfig.imagePathTwitter,
    };
    for (final entry in optionalSources.entries) {
      final value = entry.value;
      if (value != null && !File(path.join(context.prefixPath, value)).existsSync()) {
        context.logger.error('Missing "${entry.key}" image file: "$value"');
        return false;
      }
    }
    final shortcuts = webConfig.shortcutIcons ?? const [];
    for (var i = 0; i < shortcuts.length; i++) {
      final shortcut = shortcuts[i];
      if (shortcut.imagePath.isEmpty || !File(path.join(context.prefixPath, shortcut.imagePath)).existsSync()) {
        context.logger.error(
          'Missing "web.shortcut_icons[$i].image_path" image file: "${shortcut.imagePath}"',
        );
        return false;
      }
    }

    // Verify web platform related files and directories exists
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

    // Background_color and theme colors land verbatim in manifest.json and the index block, so they must be valid CSS hex colors.
    final backgroundColor = webConfig.backgroundColor;
    if (backgroundColor != null && !utils.isHexColor(backgroundColor)) {
      context.logger.error(
        'Invalid web.background_color "$backgroundColor": '
        'must be a hex color like "#ffffff".',
      );
      return false;
    }
    final themeLight = webConfig.themeColorLight;
    if (themeLight != null && !utils.isHexColor(themeLight)) {
      context.logger.error(
        'Invalid web.theme_color_light "$themeLight": '
        'must be a hex color like "#ffffff".',
      );
      return false;
    }
    final themeDark = webConfig.themeColorDark;
    if (themeDark != null && !utils.isHexColor(themeDark)) {
      context.logger.error(
        'Invalid web.theme_color_dark "$themeDark": '
        'must be a hex color like "#ffffff".',
      );
      return false;
    }

    return true;
  }

  @override
  Future<void> createIcons() async {
    final webConfig = context.config.webConfig!;
    final imgFilePath = path.join(
      context.prefixPath,
      context.config.resolveImageFile(webConfig.imagePath, context.prefixPath),
    );

    // load and decode the base image file
    context.logger.verbose('Decoding and loading image file at $imgFilePath...');
    final loadBase = await utils.sizeImageLoaderFor(
      imgFilePath,
      logger: context.logger,
      cache: context.svgRasterCache,
    );

    // resolve the PWA source: a dedicated override when provided, else base.
    utils.SizeImageLoader loadPwa = loadBase;
    if (webConfig.imagePathPwa != null) {
      final pwaImgFilePath = path.join(context.prefixPath, webConfig.imagePathPwa!);
      context.logger.verbose('Decoding and loading PWA image file at $pwaImgFilePath...');
      loadPwa = await utils.sizeImageLoaderFor(
        pwaImgFilePath,
        logger: context.logger,
        cache: context.svgRasterCache,
      );
    }

    // resolve the maskable image: a dedicated source when provided, otherwise the base image with padded derivation at write time. The derivation logo always comes from a 1024 render so the ~80% downscale starts at full quality.
    utils.SizeImageLoader? loadMaskable;
    Image? deriveLogo;
    final maskableImagePathOverride = webConfig.imagePathMaskable;
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

    // resolve the monochrome source: only emitted when explicitly provided.
    utils.SizeImageLoader? loadMonochrome;
    if (webConfig.imagePathMonochrome != null) {
      final monoImgFilePath = path.join(context.prefixPath, webConfig.imagePathMonochrome!);
      context.logger.verbose(
        'Decoding and loading monochrome image file at $monoImgFilePath...',
      );
      loadMonochrome = await utils.sizeImageLoaderFor(
        monoImgFilePath,
        logger: context.logger,
        cache: context.svgRasterCache,
      );
    }

    // resolve the monochrome-maskable source: dedicated file when provided, otherwise derived with padding from the monochrome source.
    utils.SizeImageLoader? loadMonochromeMaskable;
    Image? deriveMonoLogo;
    final monoMaskableOverride = webConfig.imagePathMonochromeMaskable;
    final deriveMonoMaskable = monoMaskableOverride == null && loadMonochrome != null;
    if (monoMaskableOverride != null) {
      final monoMaskableImgFilePath = path.join(context.prefixPath, monoMaskableOverride);
      context.logger.verbose(
        'Decoding and loading monochrome-maskable image file at $monoMaskableImgFilePath...',
      );
      loadMonochromeMaskable = await utils.sizeImageLoaderFor(
        monoMaskableImgFilePath,
        logger: context.logger,
        cache: context.svgRasterCache,
      );
    } else if (loadMonochrome != null) {
      deriveMonoLogo = await loadMonochrome(utils.svgMasterSize);
    }

    // generate favicon from the base image (favicon always follows image_path)
    context.logger.verbose('Generating favicon from $imgFilePath...');
    await _generateFavicon(loadBase);

    // copy through the SVG favicon verbatim when provided (never rasterized)
    final hasFaviconSvg = await _copyFaviconSvg();

    // generate icons in web/icons/
    context.logger.verbose('Generating icons from $imgFilePath...');
    final iconTemplates = await _generateIcons(
      loadPwa,
      loadMaskable,
      deriveLogo,
      deriveMaskable,
      loadMonochrome,
      loadMonochromeMaskable,
      deriveMonoLogo,
      deriveMonoMaskable,
    );

    // generate opt-in social link-preview images
    final hasOpengraph = await _generateSocialImage(
      overridePath: webConfig.imagePathOpengraph,
      fileName: path.basename(paths.webOpengraphFilePath(_webRoot)),
      width: constants.webOpengraphWidth,
      height: constants.webOpengraphHeight,
      label: 'opengraph',
    );
    final hasTwitter = await _generateSocialImage(
      overridePath: webConfig.imagePathTwitter,
      fileName: path.basename(paths.webTwitterFilePath(_webRoot)),
      width: constants.webTwitterWidth,
      height: constants.webTwitterHeight,
      label: 'twitter',
    );

    // generate PWA shortcut icons and collect their manifest entries
    final shortcutManifests = await _generateShortcutIcons();

    // update manifest.json in <web root>/manifest.json
    context.logger.verbose(
      'Updating ${path.join(context.prefixPath, paths.webManifestFilePath(_webRoot))}...',
    );
    await _updateManifestFile(iconTemplates, shortcutManifests);

    // iOS Safari needs an explicit opaque 180px touch icon.
    context.logger.verbose('Generating apple-touch-icon from $imgFilePath...');
    await _generateAppleTouchIcon(loadBase);

    // make the generated files discoverable from index.html
    context.logger.verbose(
      'Updating ${path.join(context.prefixPath, paths.webIndexFilePath(_webRoot))}...',
    );
    await _updateIndexFile(
      hasFaviconSvg: hasFaviconSvg,
      hasOpengraph: hasOpengraph,
      hasTwitter: hasTwitter,
    );
  }

  Future<void> _generateFavicon(utils.SizeImageLoader loadBase) async {
    final size = context.config.webConfig?.faviconSize ?? constants.faviconDefaultSize;
    final favIcon = await loadBase(
      size > 0 ? size : constants.faviconDefaultSize,
    );
    final favIconFile = await utils.createFileIfNotExist(
      path.join(context.prefixPath, paths.webFaviconFilePath(_webRoot)),
    );
    await favIconFile.writeAsBytes(encodePng(favIcon));
    if (context.config.webConfig?.faviconIco ?? true) {
      // Browsers request /favicon.ico by default; emit the consensus multi-frame container alongside the PNG.
      final multi = await loadBase(constants.webFaviconIcoSizes.first);
      for (final frameSize in constants.webFaviconIcoSizes.skip(1)) {
        multi.addFrame(await loadBase(frameSize));
      }
      final favIcoFile = await utils.createFileIfNotExist(
        path.join(context.prefixPath, paths.webFaviconIcoFilePath(_webRoot)),
      );
      await favIcoFile.writeAsBytes(encodeIco(multi));
    }
    // index.html keeps pointing at favicon.png, either file now resolves.
  }

  /// Copies the SVG favicon source verbatim to `favicon.svg`. Returns true when a copy was made.
  Future<bool> _copyFaviconSvg() async {
    final override = context.config.webConfig?.imagePathFaviconSvg;
    if (override == null) {
      return false;
    }
    final source = File(path.join(context.prefixPath, override));
    final target = await utils.createFileIfNotExist(
      path.join(context.prefixPath, paths.webFaviconSvgFilePath(_webRoot)),
    );
    await source.copy(target.path);
    return true;
  }

  Future<List<WebIconTemplate>> _generateIcons(
    utils.SizeImageLoader loadPwa,
    utils.SizeImageLoader? loadMaskable,
    Image? deriveLogo,
    bool deriveMaskable,
    utils.SizeImageLoader? loadMonochrome,
    utils.SizeImageLoader? loadMonochromeMaskable,
    Image? deriveMonoLogo,
    bool deriveMonoMaskable,
  ) async {
    final iconsDir = await utils.createDirIfNotExist(
      path.join(context.prefixPath, paths.webIconsDirPath(_webRoot)),
    );
    final templates = <WebIconTemplate>[
      for (final size in constants.webPwaIconSizes) WebIconTemplate(size: size),
      for (final size in constants.webPwaIconSizes) WebIconTemplate(size: size, maskable: true),
      if (loadMonochrome != null)
        for (final size in constants.webPwaIconSizes) WebIconTemplate(size: size, monochrome: true),
      if (loadMonochromeMaskable != null || deriveMonoMaskable)
        for (final size in constants.webPwaIconSizes) WebIconTemplate(size: size, maskable: true, monochrome: true),
    ];
    // generate icons
    for (final template in templates) {
      final Image resizedImg;
      if (template.maskable && template.monochrome) {
        if (deriveMonoMaskable) {
          resizedImg = _buildPaddedMaskable(deriveMonoLogo!, template.size);
        } else {
          resizedImg = await loadMonochromeMaskable!(template.size);
        }
      } else if (template.monochrome) {
        resizedImg = await loadMonochrome!(template.size);
      } else if (template.maskable && deriveMaskable) {
        resizedImg = _buildPaddedMaskable(deriveLogo!, template.size);
      } else if (template.maskable) {
        resizedImg = await loadMaskable!(template.size);
      } else {
        resizedImg = await loadPwa(template.size);
      }
      final iconFile = await utils.createFileIfNotExist(
        path.join(context.prefixPath, iconsDir.path, template.iconFile),
      );
      await iconFile.writeAsBytes(encodePng(resizedImg));
    }
    return templates;
  }

  /// Derives a safe-zone-compliant maskable icon: the logo scaled to ~80% and centered on the opaque `background_color` (white fallback) so the outer edge survives maskable cropping.
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

  /// Renders an opt-in social link-preview image with a cover-crop so any square icon source fills the 1200px landscape canvas without stretching. Returns true when an image was generated.
  Future<bool> _generateSocialImage({
    required String? overridePath,
    required String fileName,
    required int width,
    required int height,
    required String label,
  }) async {
    if (overridePath == null) {
      return false;
    }
    final sourcePath = path.join(context.prefixPath, overridePath);
    context.logger.verbose('Generating $label image from $sourcePath...');
    final source = await utils.decodeImageFile(sourcePath, cache: context.svgRasterCache);
    final cover = _coverCrop(source, width, height);
    final outFile = await utils.createFileIfNotExist(
      path.join(context.prefixPath, _webRoot, fileName),
    );
    await outFile.writeAsBytes(encodePng(cover));
    return true;
  }

  Image _coverCrop(Image source, int width, int height) {
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

  /// Renders each `shortcut_icons` entry at 96px and returns the manifest `shortcuts[]` payloads. Returns an empty list when none are configured.
  Future<List<Map<String, dynamic>>> _generateShortcutIcons() async {
    final shortcuts = context.config.webConfig?.shortcutIcons ?? const [];
    if (shortcuts.isEmpty) {
      return const [];
    }
    final iconsDir = await utils.createDirIfNotExist(
      path.join(context.prefixPath, paths.webIconsDirPath(_webRoot)),
    );
    final manifests = <Map<String, dynamic>>[];
    for (var i = 0; i < shortcuts.length; i++) {
      final shortcut = shortcuts[i];
      final sourcePath = path.join(context.prefixPath, shortcut.imagePath);
      final load = await utils.sizeImageLoaderFor(
        sourcePath,
        logger: context.logger,
        cache: context.svgRasterCache,
      );
      final resized = await load(constants.webShortcutIconSize);
      final fileName = 'shortcut-$i-${constants.webShortcutIconSize}.png';
      final iconFile = await utils.createFileIfNotExist(
        path.join(context.prefixPath, iconsDir.path, fileName),
      );
      await iconFile.writeAsBytes(encodePng(resized));
      manifests.add({
        if (shortcut.name != null) 'name': shortcut.name,
        if (shortcut.shortName != null) 'short_name': shortcut.shortName,
        if (shortcut.description != null) 'description': shortcut.description,
        if (shortcut.url != null) 'url': shortcut.url,
        'icons': [
          {
            'src': 'icons/$fileName',
            'sizes': '${constants.webShortcutIconSize}x${constants.webShortcutIconSize}',
            'type': 'image/png',
          },
        ],
      });
    }
    return manifests;
  }

  Future<void> _updateManifestFile(
    List<WebIconTemplate> templates,
    List<Map<String, dynamic>> shortcutManifests,
  ) async {
    final manifestFile = await utils.createFileIfNotExist(
      path.join(context.prefixPath, paths.webManifestFilePath(_webRoot)),
    );
    final manifestConfig = jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;

    // update background_color; theme_color is html-only as light/dark mode isn't supported by manifest, so drop any leftover theme_color
    if (context.config.webConfig?.backgroundColor != null) {
      manifestConfig['background_color'] = context.config.webConfig?.backgroundColor;
    }
    manifestConfig.remove('theme_color');

    // replace existing icons to eliminate conflicts
    manifestConfig
      ..remove('icons')
      ..['icons'] = templates.map<Map<String, dynamic>>((e) => e.iconManifest).toList();

    // replace shortcuts when configured, otherwise drop stale entries
    manifestConfig.remove('shortcuts');
    if (shortcutManifests.isNotEmpty) {
      manifestConfig['shortcuts'] = shortcutManifests;
    }

    await manifestFile.writeAsString(utils.prettifyJsonEncode(manifestConfig));
  }

  /// Generates an opaque 180x180 `apple-touch-icon.png` by flattening the source onto `background_color` (white fallback).
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

  /// Manages an idempotent `<!--LI-->…<!--LIEND-->` block in index.html wiring up the favicon, apple-touch-icon, manifest, background/theme colors, and social preview images. An existing block is replaced in place; otherwise the block is inserted before `</head>`.
  Future<void> _updateIndexFile({
    required bool hasFaviconSvg,
    required bool hasOpengraph,
    required bool hasTwitter,
  }) async {
    final indexFile = File(path.join(context.prefixPath, paths.webIndexFilePath(_webRoot)));
    var content = await indexFile.readAsString();

    final favSize = context.config.webConfig?.faviconSize ?? constants.faviconDefaultSize;
    final backgroundColor = context.config.webConfig?.backgroundColor;
    final themeLight = context.config.webConfig?.themeColorLight;
    final themeDark = context.config.webConfig?.themeColorDark;
    final includeIco = context.config.webConfig?.faviconIco ?? true;
    final colorLines = <String>[
      if (backgroundColor != null) '  <style>html, body { background-color: $backgroundColor; }</style>',
      if (themeLight != null && themeDark != null) '  <meta name="theme-color" media="(prefers-color-scheme: light)" content="$themeLight"/>',
      if (themeLight != null && themeDark != null) '  <meta name="theme-color" media="(prefers-color-scheme: dark)" content="$themeDark"/>',
      if (themeLight != null && themeDark == null) '  <meta name="theme-color" content="$themeLight"/>',
      if (themeDark != null && themeLight == null) '  <meta name="theme-color" content="$themeDark"/>',
    ];
    final block = '''
  <!--LI-->${includeIco ? '\n  <link rel="icon" type="image/x-icon" sizes="any" href="favicon.ico"/>' : ''}
  <link rel="icon" type="image/png" sizes="${favSize}x$favSize" href="favicon.png"/>${hasFaviconSvg ? '\n  <link rel="icon" type="image/svg+xml" href="favicon.svg"/>' : ''}
  <link rel="apple-touch-icon" href="icons/apple-touch-icon.png"/>
  <link rel="manifest" href="manifest.json"/>${colorLines.isNotEmpty ? '\n${colorLines.join('\n')}' : ''}${hasOpengraph ? '\n  <meta property="og:image" content="opengraph.png"/>' : ''}${hasTwitter ? '\n  <meta name="twitter:card" content="summary_large_image"/>\n  <meta name="twitter:image" content="twitter.png"/>' : ''}
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
