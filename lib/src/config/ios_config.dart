import 'package:json_annotation/json_annotation.dart';
import 'package:launcher_icons/src/config/liquid_glass_group.dart';
import 'package:launcher_icons/src/config/liquid_glass_layer.dart';

part 'ios_config.g.dart';

/// The launcher_icons configuration set for iOS
@JsonSerializable(
  anyMap: true,
  checked: true,
  explicitToJson: true,
)
class IOSConfig {
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

  /// IOS remove_liquid_glass
  @JsonKey(name: 'remove_liquid_glass')
  final bool removeLiquidGlass;

  /// IOS desaturate_tinted_to_grayscale
  @JsonKey(name: 'desaturate_tinted_to_grayscale')
  final bool desaturateTintedToGrayscale;

  /// Canvas background: doubles as the `remove_alpha` matte color and the `.icon` solid fill (unless a gradient pair is set). Hex `#RRGGBB`.
  @JsonKey(name: 'background_color')
  final String backgroundColor;

  /// First color of an explicit two-stop linear canvas gradient (hex `#RRGGBB`). Requires [liquidGlassGradientTo]; when both are set the `.icon` canvas renders a top-to-bottom gradient instead of the solid [backgroundColor] (verified against Icon Composer's document model and ictool rendering).
  @JsonKey(name: 'liquid_glass_gradient_from')
  final String? liquidGlassGradientFrom;

  /// Second color of an explicit two-stop linear canvas gradient (hex `#RRGGBB`). Requires [liquidGlassGradientFrom].
  @JsonKey(name: 'liquid_glass_gradient_to')
  final String? liquidGlassGradientTo;

  /// IOS liquid glass translucency
  @JsonKey(name: 'liquid_glass_translucency')
  final double? liquidGlassTranslucency;

  /// IOS liquid glass specular
  @JsonKey(name: 'liquid_glass_specular')
  final bool liquidGlassSpecular;

  /// IOS liquid glass shadow kind
  @JsonKey(name: 'liquid_glass_shadow_kind')
  final String liquidGlassShadowKind;

  /// IOS liquid glass shadow opacity
  @JsonKey(name: 'liquid_glass_shadow_opacity')
  final double? liquidGlassShadowOpacity;

  /// IOS liquid glass blur
  @JsonKey(name: 'liquid_glass_blur')
  final double? liquidGlassBlur;

  /// Group lighting model: `individual` lights each layer separately, `combined` treats the group as one shape. Unset by default (omitted from icon.json); only observable with 2+ layers.
  @JsonKey(name: 'liquid_glass_lighting')
  final String? liquidGlassLighting;

  /// Enables group refractivity (`depth` + `strength` required).
  @JsonKey(name: 'liquid_glass_refractivity_enabled')
  final bool? liquidGlassRefractivityEnabled;

  /// Refractivity depth (required when refractivity is enabled).
  @JsonKey(name: 'liquid_glass_refractivity_depth')
  final double? liquidGlassRefractivityDepth;

  /// Refractivity strength (required when refractivity is enabled).
  @JsonKey(name: 'liquid_glass_refractivity_strength')
  final double? liquidGlassRefractivityStrength;

  /// Specular highlight placement: `inside` or `outside`. Unset by default.
  @JsonKey(name: 'liquid_glass_specular_highlight_placement')
  final String? liquidGlassSpecularHighlightPlacement;

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
    this.removeLiquidGlass = false,
    this.desaturateTintedToGrayscale = false,
    this.backgroundColor = '#ffffff',
    this.liquidGlassGradientFrom,
    this.liquidGlassGradientTo,
    this.liquidGlassTranslucency = 0.5,
    this.liquidGlassSpecular = true,
    this.liquidGlassShadowKind = 'Neutral',
    this.liquidGlassShadowOpacity = 0.5,
    this.liquidGlassBlur = 0.5,
    this.liquidGlassLighting,
    this.liquidGlassRefractivityEnabled,
    this.liquidGlassRefractivityDepth,
    this.liquidGlassRefractivityStrength,
    this.liquidGlassSpecularHighlightPlacement,
  });

  /// Creates [IOSConfig] from [json]
  factory IOSConfig.fromJson(Map<dynamic, dynamic> json) => _$IOSConfigFromJson(json);

  /// Creates [Map] from [IOSConfig]
  Map<String, dynamic> toJson() => _$IOSConfigToJson(this);

  @override
  String toString() => 'IOSConfig: ${toJson()}';
}
