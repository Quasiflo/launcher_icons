import 'package:json_annotation/json_annotation.dart';
import 'package:launcher_icons/src/config/liquid_glass_group.dart';
import 'package:launcher_icons/src/config/liquid_glass_layer.dart';
import 'package:launcher_icons/src/config/liquid_glass_options.dart';

part 'macos_config.g.dart';

/// The launcher_icons configuration set for MacOS
@JsonSerializable(
  anyMap: true,
  checked: true,
  explicitToJson: true,
)
class MacOSConfig extends LiquidGlassOptions {
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
    super.removeLiquidGlass,
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

  /// Creates [MacOSConfig] from [json]
  factory MacOSConfig.fromJson(final Map<dynamic, dynamic> json) => _$MacOSConfigFromJson(json);

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

  /// Creates [Map] from [MacOSConfig]
  Map<String, dynamic> toJson() => _$MacOSConfigToJson(this);

  @override
  String toString() => 'MacOSConfig: ${toJson()}';
}
