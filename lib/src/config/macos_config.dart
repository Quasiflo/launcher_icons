import 'package:json_annotation/json_annotation.dart';
import 'package:launcher_icons/src/config/liquid_glass_layer.dart';

part 'macos_config.g.dart';

/// The launcher_icons configuration set for MacOS
@JsonSerializable(
  anyMap: true,
  checked: true,
  explicitToJson: true,
)
class MacOSConfig {
  /// Specifies weather to generate icons for macos
  @JsonKey()
  final bool generate;

  /// Image path for macos
  @JsonKey(name: 'image_path')
  final String? imagePath;

  /// Safe-area margin as a percent of the icon size applied on every side.
  ///
  /// The artwork is scaled into the remaining inner area and centered on a transparent canvas. `0` (default) disables padding.
  @JsonKey(name: 'padding')
  final int padding;

  /// Round the icon corners with an Apple-like mask (fluttercommunity/flutter_launcher_icons#463).
  ///
  /// Disabled by default; macOS does not shape the artwork itself.
  @JsonKey(name: 'rounded_corners')
  final bool roundedCorners;

  /// Liquid glass artwork layers (bottom-to-top). The `.icon` bundle is emitted when the list is non-empty; each entry is one Icon Composer layer with its own artwork, position, and composition. Unlike iOS, per-layer dark/tinted sources have no catalog fallbacks.
  @JsonKey(name: 'liquid_glass_layers')
  final List<LiquidGlassLayer>? liquidGlassLayers;

  /// macOS remove_liquid_glass: flat icon without glass effects.
  @JsonKey(name: 'remove_liquid_glass')
  final bool removeLiquidGlass;

  /// macOS background_color: canvas fill behind the glass (hex `#RRGGBB`).
  @JsonKey(name: 'background_color')
  final String backgroundColor;

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
    this.padding = 0,
    this.roundedCorners = false,
    this.liquidGlassLayers,
    this.removeLiquidGlass = false,
    this.backgroundColor = '#ffffff',
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

  /// Creates [Map] from [WebConfig]
  Map<String, dynamic> toJson() => _$MacOSConfigToJson(this);

  @override
  String toString() => '$runtimeType: ${toJson()}';
}
