import 'package:json_annotation/json_annotation.dart';

part 'linux_config.g.dart';

/// The launcher_icons configuration set for Linux
@JsonSerializable(
  anyMap: true,
  checked: true,
)
class LinuxConfig {
  /// Creates a instance of [LinuxConfig]
  const LinuxConfig({
    this.generate = false,
    this.imagePath,
    this.sharePrefix = 'linux',
    this.generateSnap = false,
  });

  /// Creates [LinuxConfig] from [json]
  factory LinuxConfig.fromJson(final Map<dynamic, dynamic> json) => _$LinuxConfigFromJson(json);

  /// Specifies whether to generate icons for Linux
  final bool generate;

  /// Image path for Linux
  @JsonKey(name: 'image_path')
  final String? imagePath;

  /// Location prefix for the freedesktop `share/` tree (default `linux`, yielding `linux/share/...`). Set to empty to restore the legacy top-level `share/...` layout.
  @JsonKey(name: 'share_prefix')
  final String sharePrefix;

  /// Whether to emit snap packaging (`snap/gui/` + `snap/snapcraft.yaml`, default false).
  @JsonKey(name: 'generate_snap')
  final bool generateSnap;

  /// Creates [Map] from [LinuxConfig]
  Map<String, dynamic> toJson() => _$LinuxConfigToJson(this);

  @override
  String toString() => 'LinuxConfig: ${toJson()}';
}
