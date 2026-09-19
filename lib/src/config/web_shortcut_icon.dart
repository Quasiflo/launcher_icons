import 'package:json_annotation/json_annotation.dart';

part 'web_shortcut_icon.g.dart';

/// A single PWA press-and-hold shortcut icon.
///
/// Rendered at 96px into `icons/` and wired into `manifest.json`
/// `shortcuts[]` with its own `icons` entry.
@JsonSerializable(anyMap: true, checked: true)
class WebShortcutIcon {
  /// Source image for this shortcut (PNG or SVG).
  @JsonKey(name: 'image_path')
  final String imagePath;

  /// Shortcut label shown in the quick-actions menu.
  @JsonKey(name: 'name')
  final String? name;

  /// Short label used when space is constrained.
  @JsonKey(name: 'short_name')
  final String? shortName;

  /// URL opened when the shortcut is selected.
  @JsonKey(name: 'url')
  final String? url;

  /// Longer description of the shortcut.
  @JsonKey(name: 'description')
  final String? description;

  /// Creates an instance of [WebShortcutIcon].
  const WebShortcutIcon({
    required this.imagePath,
    this.name,
    this.shortName,
    this.url,
    this.description,
  });

  /// Creates [WebShortcutIcon] from [json].
  factory WebShortcutIcon.fromJson(Map<dynamic, dynamic> json) => _$WebShortcutIconFromJson(json);

  /// Creates [Map] from [WebShortcutIcon].
  Map<String, dynamic> toJson() => _$WebShortcutIconToJson(this);
}
