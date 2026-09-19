import 'package:json_annotation/json_annotation.dart';
import 'package:launcher_icons/src/config/liquid_glass_group.dart';
import 'package:launcher_icons/src/config/liquid_glass_layer.dart';

part 'macos_config.g.dart';

/// The launcher_icons configuration set for MacOS
@JsonSerializable(
  anyMap: true,
  checked: true,
  explicitToJson: true,
)
class MacOSConfig {
  /// Specifies whether to generate icons for macos
  @JsonKey()
  final bool generate;

  /// Image path for macos
  @JsonKey(name: 'image_path')
  final String? imagePath;

  /// Custom icon set name. When set, a new `<name>.appiconset` (and matching `<name>.icon` glass bundle) is generated without removing the default set; flavor runs always write `AppIcon-<flavor>` and ignore this.
  @JsonKey(name: 'icon_name')
  final String? iconName;

  /// Custom path to the `.xcodeproj` directory (default `macos/Runner.xcodeproj`). Set this when the Xcode project was renamed.
  @JsonKey(name: 'xcodeproj_path')
  final String? xcodeprojPath;

  /// When true, skips the PNG asset catalog entirely and emits only the liquid glass `.icon` bundle (Tahoe 26+ renders every size and appearance from it).
  ///
  /// Requires `liquid_glass_layers` (or `liquid_glass_groups`); the target's App Icon must be set to the `.icon` in Xcode.
  @JsonKey(name: 'icon_only')
  final bool iconOnly;

  /// Safe-area margin as a percent of the icon size applied on every side.
  ///
  /// The artwork is scaled into the remaining inner area and centered on a transparent canvas. `0` (default) disables padding. Applies to the PNG catalog only — glass layers position themselves via `scale`/`offset_x`/`offset_y`.
  @JsonKey(name: 'padding')
  final int padding;

  /// Round the icon corners with an Apple-like mask.
  ///
  /// Disabled by default; macOS does not shape the artwork itself. Applies to the PNG catalog only — never to glass layers.
  @JsonKey(name: 'rounded_corners')
  final bool roundedCorners;

  /// Liquid glass artwork layers (bottom-to-top). The `.icon` bundle is emitted when the list is non-empty; each entry is one Icon Composer layer with its own artwork, position, and composition. Unlike iOS, per-layer dark/tinted sources have no catalog fallbacks.
  @JsonKey(name: 'liquid_glass_layers')
  final List<LiquidGlassLayer>? liquidGlassLayers;

  /// Explicit Liquid Glass groups (bottom-to-top). When non-empty, these define the bundle's groups instead of the single group built from [liquidGlassLayers]; setting both is an error.
  @JsonKey(name: 'liquid_glass_groups')
  final List<LiquidGlassGroup>? liquidGlassGroups;

  /// macOS remove_liquid_glass: flat icon without glass effects.
  @JsonKey(name: 'remove_liquid_glass')
  final bool removeLiquidGlass;

  /// macOS background_color: canvas fill behind the glass (hex `#RRGGBB`).
  @JsonKey(name: 'background_color')
  final String backgroundColor;

  /// First color of an explicit two-stop linear canvas gradient (hex `#RRGGBB`). Requires [liquidGlassGradientTo]; when both are set the `.icon` canvas renders a top-to-bottom gradient instead of the solid [backgroundColor] (verified against Icon Composer's document model and ictool rendering).
  @JsonKey(name: 'liquid_glass_gradient_from')
  final String? liquidGlassGradientFrom;

  /// Second color of an explicit two-stop linear canvas gradient (hex `#RRGGBB`). Requires [liquidGlassGradientFrom].
  @JsonKey(name: 'liquid_glass_gradient_to')
  final String? liquidGlassGradientTo;

  /// macOS liquid glass translucency
  @JsonKey(name: 'liquid_glass_translucency')
  final double? liquidGlassTranslucency;

  /// macOS liquid glass specular
  @JsonKey(name: 'liquid_glass_specular')
  final bool liquidGlassSpecular;

  /// macOS liquid glass shadow kind (`Neutral` or `Chromatic`)
  @JsonKey(name: 'liquid_glass_shadow_kind')
  final String liquidGlassShadowKind;

  /// macOS liquid glass shadow opacity
  @JsonKey(name: 'liquid_glass_shadow_opacity')
  final double? liquidGlassShadowOpacity;

  /// macOS liquid glass blur
  @JsonKey(name: 'liquid_glass_blur')
  final double? liquidGlassBlur;

  /// Group lighting model: `individual` or `combined`. Unset by default (omitted from icon.json); only observable with 2+ layers.
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

  /// Creates a instance of [MacOSConfig]
  const MacOSConfig({
    this.generate = false,
    this.imagePath,
    this.iconName,
    this.xcodeprojPath,
    this.iconOnly = false,
    this.padding = 0,
    this.roundedCorners = false,
    this.liquidGlassLayers,
    this.liquidGlassGroups,
    this.removeLiquidGlass = false,
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

  /// Creates [MacOSConfig] from [json]
  factory MacOSConfig.fromJson(Map<dynamic, dynamic> json) => _$MacOSConfigFromJson(json);

  /// Creates [Map] from [MacOSConfig]
  Map<String, dynamic> toJson() => _$MacOSConfigToJson(this);

  @override
  String toString() => '$runtimeType: ${toJson()}';
}
