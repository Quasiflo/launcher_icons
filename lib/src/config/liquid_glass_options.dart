import 'package:json_annotation/json_annotation.dart';

/// Shared Liquid Glass canvas and effect options for iOS and macOS.
///
/// Both platforms render the same Icon Composer `.icon` document from these values (see `buildLiquidGlassDocument`), so the fields live here once and the platform configs inherit them. The JSON keys stay flat on each platform section via inheritance.
abstract class LiquidGlassOptions {
  /// Creates liquid glass options shared by the iOS and macOS configs.
  const LiquidGlassOptions({
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

  /// Flat icon without glass effects (the `.icon` bundle is still emitted).
  @JsonKey(name: 'remove_liquid_glass')
  final bool removeLiquidGlass;

  /// Canvas background fill behind the glass (hex `#RRGGBB`). On iOS it doubles as the `remove_alpha` matte color. Unless a gradient pair is set, it is also the `.icon` solid fill.
  @JsonKey(name: 'background_color')
  final String backgroundColor;

  /// First color of an explicit two-stop linear canvas gradient (hex `#RRGGBB`). Requires [liquidGlassGradientTo]; when both are set the `.icon` canvas renders a top-to-bottom gradient instead of the solid [backgroundColor] (verified against Icon Composer's document model and ictool rendering).
  @JsonKey(name: 'liquid_glass_gradient_from')
  final String? liquidGlassGradientFrom;

  /// Second color of an explicit two-stop linear canvas gradient (hex `#RRGGBB`). Requires [liquidGlassGradientFrom].
  @JsonKey(name: 'liquid_glass_gradient_to')
  final String? liquidGlassGradientTo;

  /// Liquid glass translucency (`0.0` opaque to `1.0` clear).
  @JsonKey(name: 'liquid_glass_translucency')
  final double? liquidGlassTranslucency;

  /// Specular highlights on the glass.
  @JsonKey(name: 'liquid_glass_specular')
  final bool liquidGlassSpecular;

  /// Liquid glass shadow kind (`Neutral`, `Chromatic` or `None`).
  @JsonKey(name: 'liquid_glass_shadow_kind')
  final String liquidGlassShadowKind;

  /// Drop-shadow strength (`0.0` to `1.0`).
  @JsonKey(name: 'liquid_glass_shadow_opacity')
  final double? liquidGlassShadowOpacity;

  /// Background blur radius behind the glass (`0.0` to `1.0`).
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
}
