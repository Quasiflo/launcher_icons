import 'package:json_annotation/json_annotation.dart';

part 'windows_config.g.dart';

/// The launcher_icons configuration set for Windows
@JsonSerializable(
  anyMap: true,
  checked: true,
)
class WindowsConfig {
  /// Specifies whether to generate icons for Windows
  final bool generate;

  /// Image path for Windows
  @JsonKey(name: 'image_path')
  final String? imagePath;

  /// Output `.ico` file name inside `windows/runner/resources/`.
  ///
  /// Defaults to `app_icon.ico` (the `Runner.rc` contract). Set a per-flavor name (e.g. `app_icon_staging.ico`) so sequential flavor runs don't clobber each other; wire the name into `Runner.rc(.in)` manually (see Flutter's Windows flavors docs).
  @JsonKey(name: 'icon_filename')
  final String iconFilename;

  /// Bare-mark source for dark-shell taskbar and Start surfaces, rendered as `Square44x44Logo.targetsize-<N>_altform-unplated.png`. Falls back to [imagePath] with padding and a contrast warning.
  @JsonKey(name: 'image_path_unplated')
  final String? imagePathUnplated;

  /// Bare-mark source for light-shell taskbar and Start surfaces, rendered as `Square44x44Logo.targetsize-<N>_altform-lightunplated.png`. Falls back to [imagePath] with padding and a contrast warning.
  @JsonKey(name: 'image_path_light_unplated')
  final String? imagePathLightUnplated;

  /// Wide-tile source for `Wide310x150Logo.scale-<N>.png` (310x150 base). Falls back to [imagePath] with a center cover-crop and a warning.
  @JsonKey(name: 'image_path_wide')
  final String? imagePathWide;

  /// Creates a instance of [WindowsConfig]
  const WindowsConfig({
    this.generate = false,
    this.imagePath,
    this.iconFilename = 'app_icon.ico',
    this.imagePathUnplated,
    this.imagePathLightUnplated,
    this.imagePathWide,
  });

  /// Creates [WindowsConfig] from [json]
  factory WindowsConfig.fromJson(Map<dynamic, dynamic> json) => _$WindowsConfigFromJson(json);

  /// Creates [Map] from [WindowsConfig]
  Map<String, dynamic> toJson() => _$WindowsConfigToJson(this);

  @override
  String toString() => 'WindowsConfig: ${toJson()}';
}
