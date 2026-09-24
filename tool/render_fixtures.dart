// Developer tool: re-renders derived fixture artwork from the SVG masters.
//
// The PNG/JPG/WebP inputs under test/assets and example/default/assets/icon are build artifacts of the SVG masters checked in next to them. Edit the SVG, then run:
//
//   dart run tool/render_fixtures.dart [--check]
//
// With --check, renders in memory and verifies the test-critical pixel contracts without writing (handy for art PRs). Without it, writes the outputs and gates on the same contracts, so a bad master fails loudly instead of silently breaking the suite. Uses the repo's own rasterizer, so rendering also dogfoods the SVG pipeline under test.
import 'dart:io';

import 'package:image/image.dart';
import 'package:launcher_icons/src/core/utils.dart' as utils;

/// One derived fixture: [svg] master rendered at [width]x[height], encoded with [encode], asserting [gate] on the raster before writing.
///
/// [gate] is the test-contract check and only applies to `test/assets` fixtures. Example projects render like a normal user project would — no gates — so their art stays free to follow product rules (e.g. full-bleed squares) instead of test rules.
class _Job {
  const _Job({
    required this.svg,
    required this.out,
    required this.width,
    required this.height,
    required this.encode,
    this.gate,
  });

  final String svg;
  final String out;
  final int width;
  final int height;
  final List<int> Function(Image image) encode;
  final void Function(Image image)? gate;
}

void _opaque(final Image image, final String name) {
  if (image.numChannels != 3) {
    throw StateError('$name must rasterize fully opaque');
  }
}

void _expect(final bool cond, final String message) {
  if (!cond) {
    throw StateError(message);
  }
}

Future<void> main(final List<String> arguments) async {
  final checkOnly = arguments.contains('--check');

  final jobs = <_Job>[
    // test/assets: opaque vector keeps the white ring over (24,14) at 48px.
    _Job(
      svg: 'test/assets/vector-opaque-1024.svg',
      out: '',
      width: 48,
      height: 48,
      encode: (final _) => const <int>[],
      gate: (final image) {
        _opaque(image, 'vector-opaque-1024.svg');
        final ring = image.getPixel(24, 14);
        _expect(
          ring.r > 200 && ring.g > 200 && ring.b > 200,
          'ring pixel dark: $ring',
        );
        _expect(image.getPixel(2, 2).a == 255, 'corner must be opaque');
      },
    ),
    // test/assets: transparent vector keeps a transparent corner + teal center.
    _Job(
      svg: 'test/assets/vector-transparent-1024.svg',
      out: '',
      width: 64,
      height: 64,
      encode: (final _) => const <int>[],
      gate: (final image) {
        _expect(image.numChannels == 4, 'must keep alpha');
        _expect(image.getPixel(0, 0).a == 0, 'corner must be transparent');
        final center = image.getPixel(32, 32);
        _expect(
          (center.r - 0).abs() <= 2 && (center.g - 188).abs() <= 2 && (center.b - 212).abs() <= 2 && center.a == 255,
          'center must be teal: $center',
        );
      },
    ),
    _Job(
      svg: 'test/assets/master-light-1024.svg',
      out: 'test/assets/master-light-1024.png',
      width: 1024,
      height: 1024,
      encode: encodePng,
      gate: (final image) {
        _expect(image.numChannels == 4, 'master must keep alpha');
        // Transparent corners (maskable-derivation warning path) + opaque art.
        _expect(image.getPixel(0, 0).a == 0, 'corner must be transparent');
        _expect(image.getPixel(512, 512).a == 255, 'center must be opaque');
      },
    ),
    _Job(
      svg: 'test/assets/adaptive-bg-1024.svg',
      out: 'test/assets/adaptive-bg-1024.jpg',
      width: 1024,
      height: 1024,
      encode: (final image) => encodeJpg(image, quality: 90),
      gate: (final image) => _opaque(image, 'adaptive-bg-1024.svg'),
    ),
    _Job(
      svg: 'test/assets/adaptive-bg-1024.svg',
      out: 'test/assets/adaptive-bg-1024.webp',
      width: 1024,
      height: 1024,
      encode: encodeWebP,
      gate: (final image) => _opaque(image, 'adaptive-bg-1024.svg'),
    ),
    const _Job(
      svg: 'example/minimal/assets/icon/icon-master-1024.svg',
      out: 'example/minimal/assets/icon/icon-master-1024.png',
      width: 1024,
      height: 1024,
      encode: encodePng,
    ),
    const _Job(
      svg: 'example/default/assets/icon/icon-master-1024.svg',
      out: 'example/default/assets/icon/icon-master-1024.png',
      width: 1024,
      height: 1024,
      encode: encodePng,
    ),
    const _Job(
      svg: 'example/default/assets/icon/icon-android-710x599.svg',
      out: 'example/default/assets/icon/icon-android-710x599.png',
      width: 710,
      height: 599,
      encode: encodePng,
    ),
    const _Job(
      svg: 'example/default/assets/icon/icon-ios-710x599.svg',
      out: 'example/default/assets/icon/icon-ios-710x599.png',
      width: 710,
      height: 599,
      encode: encodePng,
    ),
    const _Job(
      svg: 'example/default/assets/icon/icon-foreground-432.svg',
      out: 'example/default/assets/icon/icon-foreground-432.png',
      width: 432,
      height: 432,
      encode: encodePng,
    ),
    const _Job(
      svg: 'example/default/assets/icon/icon-monochrome-432.svg',
      out: 'example/default/assets/icon/icon-monochrome-432.png',
      width: 432,
      height: 432,
      encode: encodePng,
    ),
    const _Job(
      svg: 'example/default/assets/icon/bg-christmas-620x420.svg',
      out: 'example/default/assets/icon/bg-christmas-620x420.png',
      width: 620,
      height: 420,
      encode: encodePng,
    ),
  ];

  for (final job in jobs) {
    final image = await utils.rasterizeSvgFile(
      job.svg,
      width: job.width,
      height: job.height,
    );
    job.gate?.call(image);
    if (job.out.isEmpty) {
      continue; // gate-only job: no derived file to write.
    }
    if (checkOnly) {
      continue;
    }
    await File(job.out).writeAsBytes(job.encode(image));
    stdout.writeln('wrote ${job.out}');
  }
  stdout.writeln(checkOnly ? 'all gates passed' : 'rendered ${jobs.length} fixtures');
}
