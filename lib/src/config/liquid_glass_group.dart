import 'package:json_annotation/json_annotation.dart';
import 'package:launcher_icons/src/config/liquid_glass_layer.dart';

part 'liquid_glass_group.g.dart';

/// One Liquid Glass group in an Icon Composer `.icon` bundle.
///
/// Groups stack bottom-to-top in list order, each with its own artwork layers
/// and rendering pass (verified: Icon Composer accepts any number of groups;
/// Apple's guidance caps useful complexity at four). Every option is optional
/// and falls back to the platform-level value when unset, so a group carrying
/// only `layers` renders exactly like the legacy single-group flow.
@JsonSerializable(
  anyMap: true,
  checked: true,
  explicitToJson: true,
)
class LiquidGlassGroup {
  /// Creates a liquid glass group.
  const LiquidGlassGroup({
    this.name,
    this.layers,
    this.translucency,
    this.specular,
    this.shadowKind,
    this.shadowOpacity,
    this.blur,
    this.lighting,
    this.refractivityEnabled,
    this.refractivityDepth,
    this.refractivityStrength,
    this.specularHighlightPlacement,
    this.removeLiquidGlass,
  });

  /// Creates [LiquidGlassGroup] from [json].
  factory LiquidGlassGroup.fromJson(final Map<dynamic, dynamic> json) => _$LiquidGlassGroupFromJson(json);

  /// Group display name shown in Icon Composer (optional, cosmetic).
  @JsonKey(name: 'name')
  final String? name;

  /// Artwork layers for this group, bottom-to-top (required, non-empty).
  @JsonKey(name: 'layers')
  final List<LiquidGlassLayer>? layers;

  /// Group translucency override (`0.0` opaque to `1.0` clear).
  @JsonKey(name: 'liquid_glass_translucency')
  final double? translucency;

  /// Group specular-highlights override.
  @JsonKey(name: 'liquid_glass_specular')
  final bool? specular;

  /// Group shadow-style override (`Neutral`, `Chromatic` or `None`).
  @JsonKey(name: 'liquid_glass_shadow_kind')
  final String? shadowKind;

  /// Group shadow-strength override (`0.0` to `1.0`).
  @JsonKey(name: 'liquid_glass_shadow_opacity')
  final double? shadowOpacity;

  /// Group background-blur override (`0.0` to `1.0`).
  @JsonKey(name: 'liquid_glass_blur')
  final double? blur;

  /// Group lighting-model override (`individual` or `combined`).
  @JsonKey(name: 'liquid_glass_lighting')
  final String? lighting;

  /// Group refractivity override (requires `depth` + `strength`).
  @JsonKey(name: 'liquid_glass_refractivity_enabled')
  final bool? refractivityEnabled;

  /// Refractivity depth override (required when refractivity is enabled).
  @JsonKey(name: 'liquid_glass_refractivity_depth')
  final double? refractivityDepth;

  /// Refractivity strength override (required when refractivity is enabled).
  @JsonKey(name: 'liquid_glass_refractivity_strength')
  final double? refractivityStrength;

  /// Edge-highlight placement override (`inside` or `outside`).
  @JsonKey(name: 'liquid_glass_specular_highlight_placement')
  final String? specularHighlightPlacement;

  /// Group glass-effect override (forces this group's layers flat).
  @JsonKey(name: 'remove_liquid_glass')
  final bool? removeLiquidGlass;

  /// Creates [Map] from [LiquidGlassGroup].
  Map<String, dynamic> toJson() => _$LiquidGlassGroupToJson(this);

  @override
  String toString() => 'LiquidGlassGroup: ${toJson()}';
}
