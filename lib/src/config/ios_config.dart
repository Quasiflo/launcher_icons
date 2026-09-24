import 'package:json_annotation/json_annotation.dart';
import 'package:launcher_icons/src/config/liquid_glass_group.dart';
import 'package:launcher_icons/src/config/liquid_glass_layer.dart';
import 'package:launcher_icons/src/config/liquid_glass_options.dart';

part 'ios_config.g.dart';

/// The launcher_icons configuration set for iOS
@JsonSerializable(
  anyMap: true,
  checked: true,
  explicitToJson: true,
)
class IOSConfig extends LiquidGlassOptions {
  /// Creates a instance of [IOSConfig]
  const IOSConfig({
    this.generate = false,
    this.singleSize = false,
    this.imagePath,
    this.iconName,
    this.xcodeprojPath,
    this.flavorMode = 'pbxproj',
    this.iconOnly = false,
    this.imagePathDarkTransparent,
    this.imagePathTintedGrayscale,
    this.liquidGlassLayers,
    this.liquidGlassGroups,
    this.removeAlpha = false,
    super.removeLiquidGlass,
    this.desaturateTintedToGrayscale = false,
    super.backgroundColor,
    super.liquidGlassGradientFrom,
    super.liquidGlassGradientTo,
    super.liquidGlassTranslucency,
    super.liquidGlassSpecular,
    super.liquidGlassShadowKind,
    super.liquidGlassShadowOpacity,
    super.liquidGlassBlur,
    super.liquidGlassLighting,
    super.liquidGlassRefractivityEnabled,
    super.liquidGlassRefractivityDepth,
    super.liquidGlassRefractivityStrength,
    super.liquidGlassSpecularHighlightPlacement,
  });

  /// Creates [IOSConfig] from [json]
  factory IOSConfig.fromJson(final Map<dynamic, dynamic> json) => _$IOSConfigFromJson(json);

  /// Specifies whether to generate icons for iOS
  final bool generate;

  /// When true, generates only the single 1024px universal icon instead of the full icon set. Dark/tinted variants are ignored in this mode.
  @JsonKey(name: 'single_size')
  final bool singleSize;

  /// Image path for iOS (falls back to the global `image_path`)
  @JsonKey(name: 'image_path')
  final String? imagePath;

  /// Custom icon set name.
  ///
  /// When set, a new launcher icon is generated without removing the old default one. When `null`, the default existing icon is overridden.
  @JsonKey(name: 'icon_name')
  final String? iconName;

  /// Custom path to the `.xcodeproj` directory (default `ios/Runner.xcodeproj`). Set this when the Xcode project was renamed.
  @JsonKey(name: 'xcodeproj_path')
  final String? xcodeprojPath;

  /// Flavor wiring mode: `pbxproj` (default) rewrites `ASSETCATALOG_COMPILER_APPICON_NAME` per build configuration in `project.pbxproj` (the Flutter docs flow); `xcconfig` instead removes those lines for the flavor's configurations and writes `ios/Flutter/<flavor>-<Mode>.xcconfig` overrides (assign them as the base configuration files in Xcode once).
  @JsonKey(name: 'flavor_mode')
  final String flavorMode;

  /// Dark-appearance PNG source: full art on transparency (the system background shows through). Also feeds the dark variants of glass layers that omit `image_path_dark`. Clear renditions (ClearLight/ClearDark) derive automatically from the default/dark artwork — neither classic asset catalogs nor Icon Composer documents offer a clear slot (verified with actool/ictool against Xcode 27).
  @JsonKey(name: 'image_path_dark_transparent')
  final String? imagePathDarkTransparent;

  /// Tinted-appearance PNG source: must read as a single-color silhouette (grayscale). Also feeds the tinted variants of glass layers that omit `image_path_tinted`. Clear renditions derive automatically; no clear source key exists.
  @JsonKey(name: 'image_path_tinted_grayscale')
  final String? imagePathTintedGrayscale;

  /// When true, skips the PNG asset catalog entirely and emits only the liquid glass `.icon` bundle (Xcode renders every size and appearance from it).
  ///
  /// Requires `liquid_glass_layers` (or `liquid_glass_groups`); the target's App Icon must be set to the `.icon` in Xcode. `single_size` has no effect in this mode.
  @JsonKey(name: 'icon_only')
  final bool iconOnly;

  /// Liquid glass artwork layers (bottom-to-top). The `.icon` bundle is emitted when the list is non-empty; each entry is one Icon Composer layer with its own artwork, position, and composition.
  @JsonKey(name: 'liquid_glass_layers')
  final List<LiquidGlassLayer>? liquidGlassLayers;

  /// Explicit Liquid Glass groups (bottom-to-top). When non-empty, these define the bundle's groups instead of the single group built from [liquidGlassLayers]; setting both is an error.
  @JsonKey(name: 'liquid_glass_groups')
  final List<LiquidGlassGroup>? liquidGlassGroups;

  /// IOS remove_alpha
  @JsonKey(name: 'remove_alpha')
  final bool removeAlpha;

  /// IOS desaturate_tinted_to_grayscale
  @JsonKey(name: 'desaturate_tinted_to_grayscale')
  final bool desaturateTintedToGrayscale;

  /// Creates [Map] from [IOSConfig]
  Map<String, dynamic> toJson() => _$IOSConfigToJson(this);

  @override
  String toString() => 'IOSConfig: ${toJson()}';
}
