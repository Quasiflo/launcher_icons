import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart';
import 'package:launcher_icons/src/core/custom_exceptions.dart';
import 'package:launcher_icons/src/core/icon_generator.dart' show IconGeneratorContext;
import 'package:launcher_icons/src/core/logger.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;
import 'package:pure_svg/svg.dart' as pure_svg;

/// Note: Do not change interpolation unless you end up with better results: cubic interpolation produced worse results in past experiments.
Image createResizedImage(final int iconSize, final Image image) {
  if (image.width >= iconSize) {
    return copyResize(
      image,
      width: iconSize,
      height: iconSize,
      interpolation: Interpolation.average,
    );
  } else {
    return copyResize(
      image,
      width: iconSize,
      height: iconSize,
      interpolation: Interpolation.linear,
    );
  }
}

/// Center cover-crops [source] to exactly [width]×[height]: scales the image to fill the canvas, then crops the center, so any source fills a landscape canvas without stretching.
Image coverCropImage(final Image source, final int width, final int height) {
  final scale = [width / source.width, height / source.height].reduce((final a, final b) => a > b ? a : b);
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

/// Prints a status bullet, routed through [logger] when provided.
void printStatus(final String message, [final LILogger? logger]) {
  if (logger != null) {
    logger.info('• $message');
  } else {
    stdout.writeln('• $message');
  }
}

/// Decodes the image at [filePath], throwing [FileSystemException] when missing and [NoDecoderForImageFormatException] when undecodable. Never returns null.
Future<Image> decodeImageFile(final String filePath, {final SvgRasterCache? cache}) {
  if (isSvgPath(filePath)) {
    return cachedSvgRaster(
      cache,
      filePath,
      svgMasterSize,
      svgMasterSize,
      logger: null,
      message: null,
    );
  }
  return File(filePath).readAsBytes().then((final bytes) {
    final image = decodeImage(bytes);
    if (image == null) {
      throw NoDecoderForImageFormatException(filePath);
    }
    return image;
  });
}

/// Whether [imagePath] points at an SVG source (case-insensitive).
bool isSvgPath(final String imagePath) => imagePath.toLowerCase().endsWith('.svg');

/// Raster width/height for SVG sources in single-master mode. Vectors scale losslessly, so one 1024 master feeds every downscale below it.
const int svgMasterSize = 1024;

/// Rasterizes the SVG at [filePath] to exactly [width]×[height] pixels (defaulting to a [svgMasterSize] square), throwing [InvalidConfigException] when the file is missing, malformed, or declares no dimensions. Transparency is recovered by difference matting: the source renders twice (over solid white and solid black) because the renderer flattens alpha, and per-pixel alpha is derived from the channel differences.
Future<Image> rasterizeSvgFile(
  final String filePath, {
  final int width = svgMasterSize,
  final int height = svgMasterSize,
}) async {
  final source = await File(filePath).readAsString();
  _requireSvgDimensions(source, filePath);
  try {
    final white = await _renderSvg(
      _svgWithBackground(source, '#ffffff', filePath),
      width,
      height,
    );
    final black = await _renderSvg(
      _svgWithBackground(source, '#000000', filePath),
      width,
      height,
    );
    return matteWhiteBlack(white, black);
  } catch (e) {
    if (e is InvalidConfigException) {
      rethrow;
    }
    throw InvalidConfigException(
      'Cannot rasterize SVG image at "$filePath": $e',
    );
  }
}

/// Rejects SVG sources with no usable viewport before rendering: the renderer reports missing dimensions through an unhandled async error the caller cannot catch, so detect it here with a clear message instead. Only the root `<svg>` tag's attributes count.
void _requireSvgDimensions(final String source, final String filePath) {
  Never fail(final String reason) => throw InvalidConfigException(
        'Cannot rasterize SVG image at "$filePath": $reason',
      );
  final rootTag = RegExp('<svg[^>]*>').firstMatch(source)?.group(0);
  if (rootTag == null) {
    fail('no root <svg> element.');
  }
  final hasViewBox = RegExp(r'viewBox\s*=').hasMatch(rootTag);
  final hasWidthAndHeight = RegExp(r'width\s*=').hasMatch(rootTag) && RegExp(r'height\s*=').hasMatch(rootTag);
  if (!hasViewBox && !hasWidthAndHeight) {
    fail('the SVG declares no dimensions (add a viewBox or width and height).');
  }
}

/// Renders [source] to PNG bytes at [width]×[height] and decodes them.
Future<Image> _renderSvg(final String source, final int width, final int height) async {
  final pngBytes = await pure_svg.svg.toPng(
    pure_svg.SvgStringLoader(source),
    width: width,
    height: height,
  );
  final image = decodeImage(pngBytes);
  if (image == null) {
    throw StateError('SVG renderer produced undecodable output');
  }
  return image;
}

/// Paints a full-bleed [hexColor] background behind [source] by inserting a rect as the root's first child. Oversized pixel coordinates (rather than percentages, which the parser rejects) cover any viewport, including negative origins; the canvas clips the excess.
String _svgWithBackground(final String source, final String hexColor, final String filePath) {
  final openTag = RegExp('<svg[^>]*>').firstMatch(source);
  if (openTag == null) {
    throw InvalidConfigException(
      'Cannot rasterize SVG image at "$filePath": no root <svg> element',
    );
  }
  return source.replaceRange(
    openTag.end,
    openTag.end,
    '<rect x="-100000" y="-100000" width="200000" height="200000" '
    'fill="$hexColor"/>',
  );
}

/// Recovers per-pixel alpha from opaque [white]/[black] background renders of the same artwork: each render composites the art over its background (`observed = art × α + bg × (1 − α)`), so one minus the white-minus-black difference is alpha, and the black render holds the premultiplied color. The alpha channel is stripped when every pixel is opaque, so downstream `hasAlpha` checks (remove_alpha, store warnings) see opaque art as opaque.
@visibleForTesting
Image matteWhiteBlack(final Image white, final Image black) {
  assert(
    white.width == black.width && white.height == black.height,
    'matte inputs must match in size',
  );
  final out = Image(
    width: white.width,
    height: white.height,
    numChannels: 4,
  );
  var allOpaque = true;
  for (var y = 0; y < out.height; y++) {
    for (var x = 0; x < out.width; x++) {
      final w = white.getPixel(x, y);
      final b = black.getPixel(x, y);
      var maxDiff = 0;
      for (final diff in [w.r - b.r, w.g - b.g, w.b - b.b]) {
        if (diff > maxDiff) {
          maxDiff = diff.toInt();
        }
      }
      final alpha = (255 - maxDiff).clamp(0, 255);
      if (alpha <= 0) {
        allOpaque = false;
        out.setPixelRgba(x, y, 0, 0, 0, 0);
      } else if (alpha >= 255) {
        out.setPixelRgba(x, y, b.r.toInt(), b.g.toInt(), b.b.toInt(), 255);
      } else {
        allOpaque = false;
        final scale = 255 / alpha;
        out.setPixelRgba(
          x,
          y,
          (b.r * scale).round().clamp(0, 255),
          (b.g * scale).round().clamp(0, 255),
          (b.b * scale).round().clamp(0, 255),
          alpha,
        );
      }
    }
  }
  return allOpaque ? out.convert(numChannels: 3) : out;
}

/// Builds a per-size artwork loader. Raster sources decode once and resize per size. SVG sources rasterize once at [svgMasterSize] and resize — equivalent crispness for icon art at a fraction of the cost.
typedef SizeImageLoader = Future<Image> Function(int size);

/// Builds a [SizeImageLoader] for [imagePath] — see [SizeImageLoader].
Future<SizeImageLoader> sizeImageLoaderFor(
  final String imagePath, {
  final LILogger? logger,
  final SvgRasterCache? cache,
}) async {
  final master = isSvgPath(imagePath)
      ? await cachedSvgRaster(
          cache,
          imagePath,
          svgMasterSize,
          svgMasterSize,
          logger: logger,
          message: 'Rasterizing SVG source $imagePath once at ${svgMasterSize}px',
        )
      : await decodeImageFile(imagePath);
  Future<Image> load(final int size) => Future.value(createResizedImage(size, master));
  return load;
}

/// Single-run memo of SVG rasterizations, keyed by absolute path and dimensions. Lives on [IconGeneratorContext] so every platform generator in one CLI run shares rasters instead of re-rendering the same source per platform — and so nothing leaks across runs. There is intentionally no disk or process-wide cache: staleness across runs is impossible by construction.
class SvgRasterCache {
  /// In-flight and completed rasterizations by cache key.
  final Map<String, Future<Image>> _entries = {};

  /// Cache key for [filePath] rasterized at [width]×[height].
  static String key(final String filePath, final int width, final int height) => '${path.normalize(path.absolute(filePath))}:$width:$height';

  /// Whether [key] (see [key]) already has an entry.
  bool contains(final String key) => _entries.containsKey(key);

  /// Returns the entry for [key], running [load] to create it when absent. The contains-then-load sequence runs synchronously, so concurrent callers share one rasterization.
  Future<Image> load(final String key, final Future<Image> Function() load) => _entries.putIfAbsent(key, load);
}

/// Rasterizes the SVG at [filePath] to [width]×[height], sharing the rasterization work through [cache] when provided. Prints [message] (when non-null) only when a rasterization actually runs, so shared hits stay silent. Every caller receives an independent copy: downstream transforms (`grayscale`, matte blending) mutate in place, so handing out the canonical instance would corrupt later consumers.
Future<Image> cachedSvgRaster(
  final SvgRasterCache? cache,
  final String filePath,
  final int width,
  final int height, {
  required final LILogger? logger,
  required final String? message,
}) {
  if (cache == null) {
    if (message != null) {
      printStatus(message, logger);
    }
    return rasterizeSvgFile(filePath, width: width, height: height);
  }
  final key = SvgRasterCache.key(filePath, width, height);
  if (!cache.contains(key) && message != null) {
    printStatus(message, logger);
  }
  return cache.load(key, () => rasterizeSvgFile(filePath, width: width, height: height)).then((final master) => master.clone());
}

/// Joins [prefixPath] with a project-relative [target] path. The default `'.'` prefix leaves [target] untouched so default runs keep their historical relative paths; any other prefix is joined normally.
String withPrefix(final String prefixPath, final String target) => prefixPath == '.' ? target : path.join(prefixPath, target);

/// Parses a `#rrggbb` (or `rrggbb`) hex color into its channels. Only the 6-digit form is accepted; anything else throws [InvalidConfigException].
({int r, int g, int b}) parseHexColor(final String hexColor) {
  final cleanHex = hexColor.startsWith('#') ? hexColor.substring(1) : hexColor;
  final hexValue = int.tryParse(cleanHex, radix: 16);
  if (cleanHex.length != 6 || hexValue == null) {
    throw InvalidConfigException(
      'Invalid hex color "$hexColor": expected 6 hex digits (e.g. "#ffffff")',
    );
  }
  return (
    r: (hexValue >> 16) & 0xff,
    g: (hexValue >> 8) & 0xff,
    b: hexValue & 0xff,
  );
}

/// Whether [color] is a valid CSS hex color: `#rgb`, `#rgba`, `#rrggbb`, or `#rrggbbaa`.
bool isHexColor(final String color) {
  if (!color.startsWith('#')) {
    return false;
  }
  final hex = color.substring(1);
  if (![3, 4, 6, 8].contains(hex.length)) {
    return false;
  }
  return int.tryParse(hex, radix: 16) != null;
}

/// Creates [File] in the given [filePath] if not exists
Future<File> createFileIfNotExist(final String filePath) async {
  final file = File(path.joinAll(path.split(filePath)));
  // Using the sync method here due to `avoid_slow_async_io` lint suggestion.
  if (!file.existsSync()) {
    await file.create(recursive: true);
  }
  return file;
}

/// Creates [Directory] in the given [dirPath] if not exists
Future<Directory> createDirIfNotExist(final String dirPath) async {
  final dir = Directory(path.joinAll(path.split(dirPath)));
  // Using the sync method here due to `avoid_slow_async_io` lint suggestion.
  if (!dir.existsSync()) {
    await dir.create(recursive: true);
  }
  return dir;
}

/// Returns a prettified json string
String prettifyJsonEncode(final Object? map) => JsonEncoder.withIndent(' ' * 4).convert(map);

/// Check if give [File] or [Directory] exists at the give [paths], if not returns the failed [FileSystemEntity] path
String? areFSEntiesExist(final List<String> paths) {
  for (final path in paths) {
    // Using the sync method here due to `avoid_slow_async_io` lint suggestion.
    final fsType = FileSystemEntity.typeSync(path);
    if (![FileSystemEntityType.directory, FileSystemEntityType.file].contains(fsType)) {
      return path;
    }
  }
  return null;
}
