import 'dart:io';

import 'package:json_annotation/json_annotation.dart';
import 'package:launcher_icons/src/config/android_config.dart';
import 'package:launcher_icons/src/config/ios_config.dart';
import 'package:launcher_icons/src/config/linux_config.dart';
import 'package:launcher_icons/src/config/macos_config.dart';
import 'package:launcher_icons/src/config/web_config.dart';
import 'package:launcher_icons/src/config/windows_config.dart';
import 'package:launcher_icons/src/core/custom_exceptions.dart';
import 'package:path/path.dart' as path;

part 'config.g.dart';

/// A model representing the launcher_icons configuration
@JsonSerializable(
  anyMap: true,
  checked: true,
)
class Config {
  /// Creates an instance of [Config]
  const Config({
    this.imagePath,
    this.androidConfig,
    this.iosConfig,
    this.webConfig,
    this.windowsConfig,
    this.macOSConfig,
    this.linuxConfig,
  });

  /// Generic image_path
  @JsonKey(name: 'image_path')
  final String? imagePath;

  /// Android platform config
  @JsonKey(name: 'android')
  final AndroidConfig? androidConfig;

  /// iOS platform config
  @JsonKey(name: 'ios')
  final IOSConfig? iosConfig;

  /// Web platform config
  @JsonKey(name: 'web')
  final WebConfig? webConfig;

  /// Windows platform config
  @JsonKey(name: 'windows')
  final WindowsConfig? windowsConfig;

  /// MacOS platform config
  @JsonKey(name: 'macos')
  final MacOSConfig? macOSConfig;

  /// Linux platform config
  @JsonKey(name: 'linux')
  final LinuxConfig? linuxConfig;

  /// Whether Android icon generation is enabled (`android.generate`)
  bool get androidEnabled => androidConfig?.generate ?? false;

  /// Whether iOS icon generation is enabled (`ios.generate`)
  bool get iosEnabled => iosConfig?.generate ?? false;

  /// Whether web icon generation is enabled (`web.generate`)
  bool get webEnabled => webConfig?.generate ?? false;

  /// Whether Windows icon generation is enabled (`windows.generate`)
  bool get windowsEnabled => windowsConfig?.generate ?? false;

  /// Whether macOS icon generation is enabled (`macos.generate`)
  bool get macOSEnabled => macOSConfig?.generate ?? false;

  /// Whether Linux icon generation is enabled (`linux.generate`)
  bool get linuxEnabled => linuxConfig?.generate ?? false;

  /// Checks if at least one platform section has `generate: true`
  bool get hasEnabledPlatform {
    return androidEnabled || iosEnabled || webEnabled || windowsEnabled || macOSEnabled || linuxEnabled;
  }

  /// Resolves the platform `image_path` (falling back to the top-level `image_path`) to an existing file, returning its project-relative path. Throws [InvalidConfigException] when unset or when the file does not exist.
  String resolveImageFile(String? platformImagePath, String prefixPath) {
    final resolved = platformImagePath ?? imagePath;
    if (resolved == null || !File(path.join(prefixPath, resolved)).existsSync()) {
      throw InvalidConfigException('Missing "image_path" within configuration, or the referenced image file does not exist${resolved == null ? '' : ': "$resolved"'}');
    }
    return resolved;
  }

  /// Creates [Config] icons from [json]
  factory Config.fromJson(Map<dynamic, dynamic> json) {
    return _$ConfigFromJson(json);
  }

  /// Converts config to [Map]
  Map<String, dynamic> toJson() => _$ConfigToJson(this);

  @override
  String toString() => 'Config: ${toJson()}';
}
