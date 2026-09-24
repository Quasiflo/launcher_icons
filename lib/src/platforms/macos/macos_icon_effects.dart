import 'package:image/image.dart';

/// Apple-like corner radius as a fraction of the icon size.
///
/// Real Apple icons use continuous (squircle) corners; a plain rounded rectangle with this radius is a close, cheap approximation.
const double macOSCornerRadiusFraction = 0.225;

/// Builds one macOS icon of [size] pixels, loading artwork through [loadArtwork] (so vector sources rasterize at exact pixels).
///
/// When [paddingPercent] is 0 the artwork fills [size] (historical behavior, byte-identical). Otherwise the artwork is centered on a transparent canvas, leaving a safe-area margin of [paddingPercent]% on every side. When [roundedCorners] is true the canvas corners are masked off.
Future<Image> buildMacOSIconImage(
  final Future<Image> Function(int) loadArtwork,
  final int size, {
  final int paddingPercent = 0,
  final bool roundedCorners = false,
}) async {
  final maxPad = (size - 1) ~/ 2;
  final pad = (size * paddingPercent / 100).round().clamp(0, maxPad);
  final artworkSize = size - 2 * pad;
  final artwork = await loadArtwork(artworkSize);

  var canvas = artwork;
  if (artworkSize < size) {
    canvas = Image(width: size, height: size, numChannels: 4);
    compositeImage(canvas, artwork, center: true);
  }
  if (roundedCorners) {
    canvas = applyRoundedCorners(canvas);
  }
  return canvas;
}

/// Masks the corners of [image] with an Apple-like continuous corner.
///
/// Returns an RGBA image; pixels outside the rounded shape become transparent. The input is left unmodified when it already fits.
///
/// The mask is a superellipse (|x|^4 + |y|^4 <= r^4) rather than a plain circular arc: Apple uses continuous-curvature ("squircle") corners, and the superellipse keeps more of the corner diagonal at the same 22.5% radius. Only `rounded_corners: true` output changes.
Image applyRoundedCorners(final Image image) {
  final size = image.width;
  // A release-safe contract check (`assert` vanishes in release builds, so it
  // cannot guard production runs): every caller feeds square canvases.
  if (image.height != size) {
    throw ArgumentError('macOS icons must be square (got ${image.width}x${image.height})');
  }
  final radius = (size * macOSCornerRadiusFraction).round();

  var canvas = image;
  if (canvas.numChannels != 4) {
    canvas = canvas.convert(numChannels: 4);
  } else {
    canvas = canvas.clone();
  }

  final r4 = (radius * radius * radius * radius).toDouble();
  bool inside(final int x, final int y) {
    final dx = x < radius ? (radius - 1 - x).toDouble() : (x - (size - radius)).toDouble();
    final dy = y < radius ? (radius - 1 - y).toDouble() : (y - (size - radius)).toDouble();
    final nx = x < radius || x >= size - radius ? dx : -1.0;
    final ny = y < radius || y >= size - radius ? dy : -1.0;
    if (nx < 0 && ny < 0) {
      return true;
    }
    final ox = nx < 0 ? 0.0 : nx;
    final oy = ny < 0 ? 0.0 : ny;
    return ox * ox * ox * ox + oy * oy * oy * oy <= r4;
  }

  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      if (!inside(x, y)) {
        canvas.setPixelRgba(x, y, 0, 0, 0, 0);
      }
    }
  }
  return canvas;
}
