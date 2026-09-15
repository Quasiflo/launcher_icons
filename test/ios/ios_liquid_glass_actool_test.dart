import 'dart:io';

import 'package:launcher_icons/src/config/config.dart';
import 'package:launcher_icons/src/platforms/ios/liquid_glass_icon_generator.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

// Validates generated `.icon` bundles with Apple's own `actool`, the same compiler Xcode runs during builds. Requires macOS + Xcode; skipped elsewhere (the JSON-shape unit tests cover all platforms).
void main() {
  group(
    'generateLiquidGlassIcon actool validation',
    () {
      late String originalDir;
      late String sandboxDir;

      setUp(() {
        originalDir = Directory.current.path;
        sandboxDir = path.absolute(
          '.dart_tool',
          'launcher_icons',
          'test',
          'ios_liquid_glass_actool',
        );
        final sandbox = Directory(sandboxDir);
        if (sandbox.existsSync()) {
          sandbox.deleteSync(recursive: true);
        }
        sandbox.createSync(recursive: true);
        for (final name in [
          'icon.png',
          'icon-dark.png',
          'icon-tinted.png',
          'glyph.png',
          'glyph-tinted.png',
        ]) {
          File(
            path.join(
              originalDir,
              'test',
              'assets',
              'master-light-1024.png',
            ),
          ).copySync(path.join(sandboxDir, name));
        }
        Directory.current = sandboxDir;
      });

      tearDown(() {
        Directory.current = originalDir;
      });

      Future<ProcessResult> compileIcon(
        String bundleDir,
        String iconName,
        String outName,
      ) {
        final outDir = path.join(sandboxDir, outName);
        Directory(outDir).createSync();
        return Process.run('xcrun', [
          'actool',
          path.join(sandboxDir, bundleDir),
          '--app-icon',
          iconName,
          '--compile',
          outDir,
          '--output-partial-info-plist',
          path.join(sandboxDir, '$outName-info.plist'),
          '--output-format',
          'human-readable-text',
          '--target-device',
          'iphone',
          '--target-device',
          'ipad',
          '--minimum-deployment-target',
          '18.0',
          '--platform',
          'iphoneos',
        ]);
      }

      test('plain bundle compiles without errors', () async {
        final config = Config.fromJson(<String, dynamic>{
          'ios': {
            'generate': true,
            'liquid_glass_layers': [
              {'image_path': 'icon.png'},
            ],
          },
        });

        await generateLiquidGlassIcon(config, 'AppIcon');

        final result = await compileIcon(
          'ios/Runner/AppIcon.icon',
          'AppIcon',
          'compiled-plain',
        );
        expect(
          result.exitCode,
          equals(0),
          reason: result.stdout.toString() + result.stderr.toString(),
        );
        expect(
          File(path.join('compiled-plain', 'Assets.car')).existsSync(),
          isTrue,
        );
      });

      test('specialized bundle compiles without errors', () async {
        final config = Config.fromJson(<String, dynamic>{
          'ios': {
            'generate': true,
            'liquid_glass_layers': [
              {
                'image_path': 'icon.png',
                'image_path_dark': 'icon-dark.png',
                'image_path_tinted': 'icon-tinted.png',
              },
            ],
            'liquid_glass_shadow_kind': 'Chromatic',
          },
        });

        await generateLiquidGlassIcon(config, 'AppIcon');

        final result = await compileIcon(
          'ios/Runner/AppIcon.icon',
          'AppIcon',
          'compiled-spec',
        );
        expect(
          result.exitCode,
          equals(0),
          reason: result.stdout.toString() + result.stderr.toString(),
        );
        expect(
          File(path.join('compiled-spec', 'Assets.car')).existsSync(),
          isTrue,
        );
      });

      test('fully-loaded bundle compiles without errors', () async {
        final config = Config.fromJson(<String, dynamic>{
          'ios': {
            'generate': true,
            'liquid_glass_layers': [
              {
                'image_path': 'icon.png',
                'image_path_dark': 'icon-dark.png',
                'image_path_tinted': 'icon-tinted.png',
              },
            ],
            'liquid_glass_lighting': 'combined',
            'liquid_glass_refractivity_enabled': true,
            'liquid_glass_refractivity_depth': 0.6,
            'liquid_glass_refractivity_strength': 0.7,
            'liquid_glass_specular_highlight_placement': 'inside',
            'liquid_glass_shadow_kind': 'Chromatic',
          },
        });

        await generateLiquidGlassIcon(config, 'AppIcon');

        final result = await compileIcon(
          'ios/Runner/AppIcon.icon',
          'AppIcon',
          'compiled-full',
        );
        expect(
          result.exitCode,
          equals(0),
          reason: result.stdout.toString() + result.stderr.toString(),
        );
        expect(
          File(path.join('compiled-full', 'Assets.car')).existsSync(),
          isTrue,
        );
      });

      test('multi-layer bundle compiles without errors', () async {
        final config = Config.fromJson(<String, dynamic>{
          'ios': {
            'generate': true,
            'liquid_glass_layers': [
              {
                'image_path': 'icon.png',
                'image_path_dark': 'icon-dark.png',
                'image_path_tinted': 'icon-tinted.png',
              },
              {
                'image_path': 'glyph.png',
                'image_path_tinted': 'glyph-tinted.png',
                'scale': 0.7,
                'offset_x': 4.0,
                'offset_y': -4.0,
                'opacity': 0.9,
                'blend_mode': 'multiply',
                'fill': '#FF0000',
                'fill_dark': '#00FF00',
              },
            ],
            'liquid_glass_lighting': 'individual',
            'liquid_glass_shadow_kind': 'Chromatic',
          },
        });

        await generateLiquidGlassIcon(config, 'AppIcon');

        final result = await compileIcon(
          'ios/Runner/AppIcon.icon',
          'AppIcon',
          'compiled-layers',
        );
        expect(
          result.exitCode,
          equals(0),
          reason: result.stdout.toString() + result.stderr.toString(),
        );
        expect(
          File(path.join('compiled-layers', 'Assets.car')).existsSync(),
          isTrue,
        );
      });
    },
    skip: !Platform.isMacOS ? 'requires macOS with Xcode actool' : false,
  );
}
