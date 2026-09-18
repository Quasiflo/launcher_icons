import 'package:json_annotation/json_annotation.dart';
import 'package:launcher_icons/src/config/android_config.dart';
import 'package:launcher_icons/src/config/ios_config.dart';
import 'package:launcher_icons/src/config/linux_config.dart';
import 'package:launcher_icons/src/config/macos_config.dart';
import 'package:launcher_icons/src/config/web_config.dart';
import 'package:launcher_icons/src/config/windows_config.dart';

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

  /// Checks if at least one platform section has `generate: true`.
  /// Presence alone is not intent: an all-`generate: false` config must fail loudly instead of exiting successfully with no work done.
  bool get hasEnabledPlatform {
    return isNeedingNewAndroidIcon || isNeedingNewIOSIcon || (webConfig?.generate ?? false) || (windowsConfig?.generate ?? false) || (macOSConfig?.generate ?? false) || (linuxConfig?.generate ?? false);
  }

  /// Whether or not configuration for generating Android icons exist
  bool get hasAndroidConfig => androidConfig != null;

  /// Whether or not configuration for generating iOS icons exist
  bool get hasIOSConfig => iosConfig != null;

  /// Whether or not configuration for generating Web icons exist
  bool get hasWebConfig => webConfig != null;

  /// Whether or not configuration for generating Windows icons exist
  bool get hasWindowsConfig => windowsConfig != null;

  /// Whether or not configuration for generating MacOS icons exists
  bool get hasMacOSConfig => macOSConfig != null;

  /// Whether or not configuration for generating Linux icons exists
  bool get hasLinuxConfig => linuxConfig != null;

  /// if we are needing a new Android icon
  bool get isNeedingNewAndroidIcon => androidConfig?.generate ?? false;

  /// if we are needing a new iOS icon
  bool get isNeedingNewIOSIcon => iosConfig?.generate ?? false;

  /// whether or not there is configuration for adaptive icons for android
  bool get hasAndroidAdaptiveConfig => isNeedingNewAndroidIcon && androidConfig?.adaptiveIconForeground != null && androidConfig?.adaptiveIconBackground != null;

  /// whether or not there is configuration for monochrome icons for android
  bool get hasAndroidAdaptiveMonochromeConfig {
    return isNeedingNewAndroidIcon && androidConfig?.adaptiveIconMonochrome != null;
  }

  /// whether or not there is configuration for round icons for android
  bool get hasAndroidAdaptiveRoundConfig {
    return isNeedingNewAndroidIcon && androidConfig?.adaptiveIconRound != null;
  }

  /// Check to see if a custom Android icon name was specified via `icon_name`. When set, a new launcher icon is generated without removing the old default existing Flutter launcher icon.
  bool get isCustomAndroidFile => androidConfig?.iconName != null;

  /// Whether or not configuration for generating liquid glass .icon exists
  bool get hasLiquidGlassIconConfig => iosConfig?.liquidGlassLayers?.isNotEmpty ?? false;

  /// Whether or not configuration for generating a macOS liquid glass .icon
  /// exists
  bool get hasMacOSLiquidGlassIconConfig => macOSConfig?.liquidGlassLayers?.isNotEmpty ?? false;

  /// Resolves the effective image path for a platform: the platform-level
  /// `image_path` wins, falling back to the top-level `image_path`.
  /// Returns null when neither is set — callers throw [errorMissingImagePath].
  String? resolveImagePath(String? platformImagePath) => platformImagePath ?? imagePath;

  /// Method for the retrieval of the Android icon path
  /// If android.image_path is found, this will be prioritised over the image_path value.
  String? getImagePathAndroid() => resolveImagePath(androidConfig?.imagePath);

  /// get the image path for IOS
  String? getImagePathIOS() => resolveImagePath(iosConfig?.imagePath);

  /// Creates [Config] icons from [json]
  factory Config.fromJson(Map<dynamic, dynamic> json) {
    return _$ConfigFromJson(json);
  }

  /// Converts config to [Map]
  Map<String, dynamic> toJson() => _$ConfigToJson(this);
}
