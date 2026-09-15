import 'dart:io';

import 'package:args/args.dart';

import 'package:launcher_icons/src/core/constants.dart';
import 'package:launcher_icons/src/version.dart';

const _defaultConfigFileName = './launcher_icons.yaml';

/// The function will be called from command line
/// using the following command:
/// ```sh
/// dart run launcher_icons:generate
/// ```
///
/// Calling this function will generate a launcher_icons.yaml file
/// with a default config template.
///
/// This command can take 2 optional arguments:
/// - --override: This will override the current `launcher_icons.yaml`
/// file if it exists, if not provided, the file will not be overridden and
/// a message will be printed to the console.
///
/// - --fileName: This flag will take a file name as an argument and
/// will generate the config format in that file instead of the default
/// `launcher_icons.yaml` file, if not provided,
/// the default file will be used.
void main(List<String> arguments) {
  print(introMessage(packageVersion));

  final parser = ArgParser()
    ..addFlag('override', abbr: 'o', defaultsTo: false)
    ..addOption(
      'fileName',
      abbr: 'f',
      defaultsTo: _defaultConfigFileName,
    );

  final results = parser.parse(arguments);
  final override = results['override'] as bool;
  final fileName = results['fileName'] as String;

  // Check if fileName is valid and has a .yaml extension
  if (!fileName.endsWith('.yaml')) {
    print('Invalid file name, please provide a valid file name');
    return;
  }

  final file = File(fileName);
  if (file.existsSync()) {
    if (override) {
      print('File already exists, overriding...');
      _generateConfigFile(file);
    } else {
      print(
        'File already exists, use --override flag to override the file, or use --fileName flag to use a different file name',
      );
    }
  } else {
    try {
      file.createSync(recursive: true);
      _generateConfigFile(file);
    } on Exception catch (e) {
      print('Error creating file: $e');
    }
  }
}

void _generateConfigFile(File configFile) {
  try {
    configFile.writeAsStringSync(configFileTemplate);

    print('\nConfig file generated successfully 🎉');
    print(
      'You can now use this new config file by using the command below:\n\n'
      'dart run launcher_icons'
      '${configFile.path == _defaultConfigFileName ? '' : ' -f ${configFile.path}'}\n',
    );
  } on Exception catch (e) {
    print('Error generating config file: $e');
  }
}

/// Default `launcher_icons.yaml` template.
///
/// Public so tests can assert it covers every schema key the loader
/// validates (see `test/generate_template_test.dart`): add new config keys
/// here when they are introduced.
const configFileTemplate = '''
# dart run launcher_icons
launcher_icons:
  image_path: "assets/icon/icon.png" # png or svg (svg rasterizes crisply)
  # svg_rasterize_per_size: true # rasterize svg at every output size (slower)

  android:
    generate: true
    # image_path: "assets/icon/icon-android.png"
    # icon_name: "launcher_icon" # generate a new icon without removing the old default
    # adaptive_icon_background: "assets/icon/background.png"  # color or png/jpg/jpeg/webp image
    # adaptive_icon_foreground: "assets/icon/foreground.png"
    # adaptive_icon_foreground_inset: 16
    # adaptive_icon_monochrome: "assets/icon/monochrome.png"
    # adaptive_icon_round: "assets/icon/round.png" # opt-in round icon + manifest roundIcon
    # play_store_icon: true # 512px store-upload sidecar next to the project, off by default

  ios:
    generate: true
    # single_size: true # single 1024px icon; dark/tinted variants are ignored
    # image_path: "assets/icon/icon-ios.png"
    # icon_name: "My-Launcher-Icon" # generate a new icon without removing the old default
    # xcodeproj_path: "ios/Runner.xcodeproj" # set when the Xcode project was renamed
    # flavor_mode: "xcconfig" # "pbxproj" (default) or "xcconfig" flavor wiring
    remove_alpha: true
    # image_path_dark_transparent: "assets/icon/icon_dark.png"
    # image_path_tinted_grayscale: "assets/icon/icon_tinted.png"
    # desaturate_tinted_to_grayscale: true
    # background_color: "#ffffff"
    # remove_liquid_glass: true # flat icon without glass effects
    # liquid_glass_translucency: 0.5
    # liquid_glass_specular: true
    # liquid_glass_shadow_kind: "Neutral" # "Neutral" or "Chromatic"
    # liquid_glass_shadow_opacity: 0.5
    # liquid_glass_blur: 0.5
    # liquid_glass_lighting: "combined" # "individual" or "combined"
    # liquid_glass_refractivity_enabled: true # requires depth + strength
    # liquid_glass_refractivity_depth: 0.5
    # liquid_glass_refractivity_strength: 0.5
    # liquid_glass_specular_highlight_placement: "inside" # "inside" or "outside"
    # liquid_glass_layers: # one entry per artwork layer, bottom-to-top; the .icon bundle is emitted when non-empty
    #   - image_path: "assets/icon/liquid_glass_background.png"
    #     image_path_dark: "assets/icon/liquid_glass_background_dark.png" # falls back to image_path_dark_transparent
    #     image_path_tinted: "assets/icon/liquid_glass_background_tinted.png" # falls back to image_path_tinted_grayscale
    #     scale: 1.0 # artwork scale within the canvas
    #     offset_x: 0.0 # layer offset in points
    #     offset_y: 0.0 # layer offset in points
    #     glass: true # layer participates in the glass effect
    #     opacity: 1.0 # 0.0 (transparent) to 1.0 (opaque)
    #     blend_mode: "normal" # normal, plus-lighter, plus-darker, overlay, multiply, soft-light, hard-light, darken, lighten, screen
    #     fill: "#ffffff" # recolor tint applied to the artwork
    #     fill_dark: "#ffffff" # dark-appearance tint, falls back to fill
    #     fill_tinted: "#ffffff" # tinted-appearance tint, falls back to fill
    #   - image_path: "assets/icon/liquid_glass_glyph.png" # extra layers stack on top

  web:
    generate: true
    image_path: "path/to/image.png"
    # image_path_favicon: "assets/icon/icon-favicon.png"
    # image_path_maskable: "assets/icon/icon-maskable.png" # safe-zone-aware source
    # favicon_size: 16
    # favicon_ico: false # skip favicon.ico, ship the PNG only
    # output_path: "web" # custom web root, e.g. per flavor
    # background_color: "#0175C2" # hex color
    # theme_color: "#0175C2" # hex color

  windows:
    generate: true
    image_path: "path/to/image.png"
    # icon_filename: "app_icon_staging.ico" # per-flavor output name

  macos:
    generate: true
    image_path: "path/to/image.png"
    # padding: 10 # safe-area margin as % of icon size, 0 disables
    # rounded_corners: true # mask corners with an Apple-like shape
    # remove_liquid_glass: true # flat icon without glass effects
    # background_color: "#ffffff"
    # liquid_glass_translucency: 0.5
    # liquid_glass_specular: true
    # liquid_glass_shadow_kind: "Neutral" # "Neutral" or "Chromatic"
    # liquid_glass_shadow_opacity: 0.5
    # liquid_glass_blur: 0.5
    # liquid_glass_lighting: "combined" # "individual" or "combined"
    # liquid_glass_refractivity_enabled: true # requires depth + strength
    # liquid_glass_refractivity_depth: 0.5
    # liquid_glass_refractivity_strength: 0.5
    # liquid_glass_specular_highlight_placement: "inside" # "inside" or "outside"
    # liquid_glass_layers: # one entry per artwork layer, bottom-to-top; the .icon bundle is emitted when non-empty (Tahoe 26+ glass .icon; the PNG catalog stays the fallback)
    #   - image_path: "assets/icon/liquid_glass_background.png"
    #     scale: 1.0 # artwork scale within the canvas
    #     offset_x: 0.0 # layer offset in points
    #     offset_y: 0.0 # layer offset in points
    #     glass: true # layer participates in the glass effect
    #     opacity: 1.0 # 0.0 (transparent) to 1.0 (opaque)
    #     blend_mode: "normal" # normal, plus-lighter, plus-darker, overlay, multiply, soft-light, hard-light, darken, lighten, screen
    #     fill: "#ffffff" # recolor tint applied to the artwork
    #   - image_path: "assets/icon/liquid_glass_glyph.png" # extra layers stack on top

  linux:
    generate: true
    image_path: "path/to/image.png"

  # Per-flavor variants can live in this file (or pubspec.yaml) as
  # launcher_icons-<flavor> sections instead of one
  # launcher_icons-<flavor>.yaml file per flavor. Each section has the same
  # shape as launcher_icons: above and stands alone. Run all flavors with
  # `dart run launcher_icons`, or one with
  # `dart run launcher_icons --flavor <name>`.
  # launcher_icons-development:
  #   image_path: "assets/icon/icon-dev.png"
  #   android:
  #     generate: true
  # launcher_icons-production:
  #   image_path: "assets/icon/icon-prod.png"
  #   android:
  #     generate: true
''';
