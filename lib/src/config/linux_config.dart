import 'package:json_annotation/json_annotation.dart';

part 'linux_config.g.dart';

/// The launcher_icons configuration set for Linux
@JsonSerializable(
  anyMap: true,
  checked: true,
)
class LinuxConfig {
  /// Specifies whether to generate icons for Linux
  final bool generate;

  /// Image path for Linux
  @JsonKey(name: 'image_path')
  final String? imagePath;

  /// Creates a instance of [LinuxConfig]
  const LinuxConfig({
    this.generate = false,
    this.imagePath,
  });

  /// Creates [LinuxConfig] from [json]
  factory LinuxConfig.fromJson(Map<dynamic, dynamic> json) => _$LinuxConfigFromJson(json);

  /// Creates [Map] from [LinuxConfig]
  Map<String, dynamic> toJson() => _$LinuxConfigToJson(this);

  @override
  String toString() => 'LinuxConfig: ${toJson()}';
}
