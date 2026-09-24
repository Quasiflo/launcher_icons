import 'dart:io';

import 'package:image/image.dart' hide decodeImageFile;
import 'package:launcher_icons/src/config/config.dart';
import 'package:launcher_icons/src/core/icon_generator.dart';
import 'package:launcher_icons/src/core/logger.dart';
import 'package:launcher_icons/src/core/utils.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

// The single-run SVG raster memo: platforms in one CLI run share rasterizations through the context-owned cache, and nothing persists across runs (there is no disk or process-wide cache by design).
void main() {
  group('SvgRasterCache', () {
    test('shares one rasterization across concurrent callers', () async {
      final cache = SvgRasterCache();
      var loads = 0;
      Future<Image> load() async {
        loads++;
        return Image(width: 8, height: 8);
      }

      final key = SvgRasterCache.key('assets/icon.svg', 1024, 1024);
      final results = await Future.wait([cache.load(key, load), cache.load(key, load)]);

      expect(loads, equals(1));
      expect(identical(results[0], results[1]), isTrue);
    });

    test('keys distinguish dimensions and normalize paths', () {
      expect(
        SvgRasterCache.key('a.svg', 16, 16) == SvgRasterCache.key('a.svg', 32, 32),
        isFalse,
      );
      expect(
        SvgRasterCache.key('sub/../a.svg', 16, 16),
        equals(SvgRasterCache.key('a.svg', 16, 16)),
      );
      expect(
        SvgRasterCache.key('./a.svg', 16, 16),
        equals(SvgRasterCache.key('a.svg', 16, 16)),
      );
    });

    test('decodeImageFile shares the raster work through the cache', () async {
      final source = path.join(
        Directory.current.path,
        'test',
        'assets',
        'vector-opaque-1024.svg',
      );
      final cache = SvgRasterCache();

      final first = await decodeImageFile(source, cache: cache);
      final second = await decodeImageFile(source, cache: cache);

      // Independent copies of one shared rasterization.
      expect(identical(first, second), isFalse);
      expect(encodePng(first), equals(encodePng(second)));
    });

    test('cached copies are independent (mutating one is safe)', () async {
      final source = path.join(
        Directory.current.path,
        'test',
        'assets',
        'vector-opaque-1024.svg',
      );
      final cache = SvgRasterCache();

      final first = await cachedSvgRaster(
        cache,
        source,
        64,
        64,
        logger: null,
        message: null,
      );
      first.setPixelRgba(0, 0, 1, 2, 3, 255);
      final second = await cachedSvgRaster(
        cache,
        source,
        64,
        64,
        logger: null,
        message: null,
      );

      expect(encodePng(first), isNot(equals(encodePng(second))));
    });

    test('without a cache every decode re-rasterizes', () async {
      final source = path.join(
        Directory.current.path,
        'test',
        'assets',
        'vector-opaque-1024.svg',
      );

      final first = await decodeImageFile(source);
      final second = await decodeImageFile(source);

      expect(identical(first, second), isFalse);
    });
  });

  group('IconGeneratorContext svgRasterCache', () {
    IconGeneratorContext context() => IconGeneratorContext(
          config: const Config(),
          logger: LILogger(isVerbose: false),
          prefixPath: '.',
        );

    test('owns one cache per context instance', () {
      final first = context();
      final second = context();

      expect(identical(first.svgRasterCache, first.svgRasterCache), isTrue);
      expect(
        identical(first.svgRasterCache, second.svgRasterCache),
        isFalse,
      );
    });
  });
}
