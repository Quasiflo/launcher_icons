import 'package:json_annotation/json_annotation.dart';

part 'liquid_glass_layer.g.dart';

/// One artwork layer in a liquid glass `.icon` bundle.
///
/// Layers stack bottom-to-top in list order inside a single group that
/// shares the group's Liquid Glass rendering pass. Each layer carries its
/// own artwork (with per-appearance variants) and composition.
@JsonSerializable(
  anyMap: true,
  checked: true,
)
class LiquidGlassLayer {
  /// Artwork source for the layer (PNG or SVG, copied verbatim into
  /// the bundle's `Assets/` folder).
  @JsonKey(name: 'image_path')
  final String imagePath;

  /// Dark-appearance artwork override. Falls back to the platform's dark
  /// catalog source (iOS `image_path_dark_transparent`; macOS has none).
  @JsonKey(name: 'image_path_dark')
  final String? imagePathDark;

  /// Tinted-appearance artwork override. Falls back to the platform's
  /// tinted catalog source (iOS `image_path_tinted_grayscale`; macOS
  /// has none).
  @JsonKey(name: 'image_path_tinted')
  final String? imagePathTinted;

  /// Artwork scale within the icon canvas (default `1.0`).
  @JsonKey(name: 'scale')
  final double scale;

  /// Layer offset in points (default `0.0` each).
  @JsonKey(name: 'offset_x')
  final double? offsetX;

  /// Layer offset in points (default `0.0` each).
  @JsonKey(name: 'offset_y')
  final double? offsetY;

  /// Whether the layer participates in the group's Liquid Glass effect
  /// (default `true`). Group `remove_liquid_glass` overrides this off.
  @JsonKey(name: 'glass')
  final bool glass;

  /// Artwork opacity, `0.0` (transparent) to `1.0` (opaque). Unset by
  /// default (fully opaque).
  @JsonKey(name: 'opacity')
  final double? opacity;

  /// Pixel-compositing operation against layers behind it: `normal`,
  /// `plus-lighter`, `plus-darker`, `overlay`, `multiply`, `soft-light`,
  /// `hard-light`, `darken`, `lighten`, or `screen`. Unset by default
  /// (normal compositing).
  @JsonKey(name: 'blend_mode')
  final String? blendMode;

  /// Recolor tint applied to the artwork (hex `#RRGGBB`). Unset by
  /// default (artwork colors pass through).
  @JsonKey(name: 'fill')
  final String? fill;

  /// Dark-appearance recolor tint (hex `#RRGGBB`). Falls back to `fill`
  /// when unset.
  @JsonKey(name: 'fill_dark')
  final String? fillDark;

  /// Tinted-appearance recolor tint (hex `#RRGGBB`). Falls back to `fill`
  /// when unset.
  @JsonKey(name: 'fill_tinted')
  final String? fillTinted;

  /// Creates a liquid glass layer.
  const LiquidGlassLayer({
    required this.imagePath,
    this.imagePathDark,
    this.imagePathTinted,
    this.scale = 1.0,
    this.offsetX = 0.0,
    this.offsetY = 0.0,
    this.glass = true,
    this.opacity,
    this.blendMode,
    this.fill,
    this.fillDark,
    this.fillTinted,
  });

  /// Creates [LiquidGlassLayer] from [json].
  factory LiquidGlassLayer.fromJson(Map<dynamic, dynamic> json) =>
      _$LiquidGlassLayerFromJson(json);

  /// Creates [Map] from [LiquidGlassLayer].
  Map<String, dynamic> toJson() => _$LiquidGlassLayerToJson(this);

  @override
  String toString() => 'LiquidGlassLayer: ${toJson()}';
}
