import 'dart:io';

import 'package:launcher_icons/src/config/config.dart';
import 'package:launcher_icons/src/platforms/ios/liquid_glass_icon_generator.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

// Validates generated macOS `.icon` bundles with Apple's own `actool`, the same compiler Xcode runs during builds. Requires macOS + Xcode; skipped elsewhere (the JSON-shape unit tests cover all platforms).
void main() {
  group(
    'generateMacOSLiquidGlassIcon actool validation',
    () {
      late String originalDir;
      late String sandboxDir;

      setUp(() {
        originalDir = Directory.current.path;
        sandboxDir = path.absolute(
          '.dart_tool',
          'launcher_icons',
          'test',
          'macos_liquid_glass_actool',
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
        final String bundleDir,
        final String iconName,
        final String outName,
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
          'mac',
          '--minimum-deployment-target',
          '26.0',
          '--platform',
          'macosx',
        ]);
      }

      test('plain bundle compiles without errors', () async {
        final config = Config.fromJson(<String, dynamic>{
          'macos': {
            'generate': true,
            'liquid_glass_layers': [
              {'image_path': 'icon.png'},
            ],
          },
        });

        await generateMacOSLiquidGlassIcon(config, 'AppIcon');

        final result = await compileIcon(
          'macos/Runner/AppIcon.icon',
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
          'macos': {
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

        await generateMacOSLiquidGlassIcon(config, 'AppIcon');

        final result = await compileIcon(
          'macos/Runner/AppIcon.icon',
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
          'macos': {
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

        await generateMacOSLiquidGlassIcon(config, 'AppIcon');

        final result = await compileIcon(
          'macos/Runner/AppIcon.icon',
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
          'macos': {
            'generate': true,
            'liquid_glass_layers': [
              {
                'image_path': 'icon.png',
                'image_path_dark': 'icon-dark.png',
                'image_path_tinted': 'icon-tinted.png',
              },
              {
                'image_path': 'glyph.png',
                'scale': 0.7,
                'glass': false,
                'opacity': 0.9,
                'blend_mode': 'screen',
                'fill': '#FF0000',
              },
            ],
            'liquid_glass_lighting': 'individual',
            'liquid_glass_shadow_kind': 'Chromatic',
          },
        });

        await generateMacOSLiquidGlassIcon(config, 'AppIcon');

        final result = await compileIcon(
          'macos/Runner/AppIcon.icon',
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

      test('multi-group gradient bundle compiles without errors', () async {
        final config = Config.fromJson(<String, dynamic>{
          'macos': {
            'generate': true,
            'liquid_glass_gradient_from': '#00FF00',
            'liquid_glass_gradient_to': '#0000FF',
            'liquid_glass_groups': [
              {
                'name': 'Background',
                'layers': [
                  {'image_path': 'icon.png'},
                ],
              },
              {
                'name': 'Glyph',
                'layers': [
                  {'image_path': 'glyph.png', 'scale': 0.7},
                ],
                'remove_liquid_glass': true,
              },
            ],
          },
        });

        await generateMacOSLiquidGlassIcon(config, 'AppIcon');

        final result = await compileIcon(
          'macos/Runner/AppIcon.icon',
          'AppIcon',
          'compiled-groups',
        );
        expect(
          result.exitCode,
          equals(0),
          reason: result.stdout.toString() + result.stderr.toString(),
        );
        expect(
          File(path.join('compiled-groups', 'Assets.car')).existsSync(),
          isTrue,
        );
      });
    },
    skip: !Platform.isMacOS ? 'requires macOS with Xcode actool' : false,
  );
}
