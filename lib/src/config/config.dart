import 'dart:io';

import 'package:checked_yaml/checked_yaml.dart' as yaml;
import 'package:json_annotation/json_annotation.dart';
import 'package:launcher_icons/src/config/android_config.dart';
import 'package:launcher_icons/src/config/ios_config.dart';
import 'package:launcher_icons/src/config/linux_config.dart';
import 'package:launcher_icons/src/config/macos_config.dart';
import 'package:launcher_icons/src/config/web_config.dart';
import 'package:launcher_icons/src/config/windows_config.dart';
import 'package:launcher_icons/src/core/custom_exceptions.dart';
import 'package:launcher_icons/src/core/paths.dart' as paths;
import 'package:launcher_icons/src/core/utils.dart' as utils;
import 'package:path/path.dart' as path;

part 'config.g.dart';

/// Top-level key pattern for per-flavor sections
/// (`launcher_icons-<flavor>`) inside a config file or pubspec.yaml.
const flavorConfigKeyPattern = r'^launcher_icons-(.+)$';

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

  /// Creates [Config] for given [flavor] and [prefixPath]
  static Config? loadConfigFromFlavor(
    String flavor,
    String prefixPath,
  ) {
    return _getConfigFromPubspecYaml(
      prefix: prefixPath,
      pathToPubspecYamlFile: utils.flavorConfigFile(flavor),
    );
  }

  /// Loads flutter launcher icons configs from given [filePath]
  static Config? loadConfigFromPath(String filePath, String prefixPath) {
    return _getConfigFromPubspecYaml(
      prefix: prefixPath,
      pathToPubspecYamlFile: filePath,
    );
  }

  /// Loads flutter launcher icons config from `pubspec.yaml` file
  static Config? loadConfigFromPubSpec(String prefix) {
    return _getConfigFromPubspecYaml(
      prefix: prefix,
      pathToPubspecYamlFile: paths.pubspecFilePath,
    );
  }

  /// Loads every `launcher_icons-<flavor>` section from [filePath], keyed by flavor name. Each section has the same shape as the plain
  /// `launcher_icons:` config and stands alone (no merging with it).
  /// Returns an empty map when the file does not exist or declares no
  /// flavor sections.
  static Map<String, Config> loadFlavorConfigsFromPath(
    String filePath,
    String prefix,
  ) {
    final configFile = File(path.join(prefix, filePath));
    if (!configFile.existsSync()) {
      return {};
    }
    final configContent = configFile.readAsStringSync();
    if (configContent.trim().isEmpty) {
      return {};
    }
    try {
      return yaml.checkedYamlDecode<Map<String, Config>>(
        configContent,
        (Map<dynamic, dynamic>? json) {
          final flavors = <String, Config>{};
          json?.forEach((key, value) {
            final match =
                RegExp(flavorConfigKeyPattern).firstMatch(key.toString());
            if (match != null) {
              final name = match.group(1)!;
              if (value is! Map) {
                throw InvalidConfigException(
                  'Invalid `launcher_icons-$name` value `$value`: '
                  'each flavor section must be a map with the same shape '
                  'as the `launcher_icons:` config.',
                );
              }
              flavors[name] = Config.fromJson(value);
            }
          });
          return flavors;
        },
        allowNull: true,
      );
    } on yaml.ParsedYamlException catch (e) {
      throw InvalidConfigException(e.formattedMessage);
    } catch (e) {
      rethrow;
    }
  }

  static Config? _getConfigFromPubspecYaml({
    required String pathToPubspecYamlFile,
    required String prefix,
  }) {
    final configFile = File(path.join(prefix, pathToPubspecYamlFile));
    if (!configFile.existsSync()) {
      return null;
    }
    final configContent = configFile.readAsStringSync();
    try {
      return yaml.checkedYamlDecode<Config?>(
        configContent,
        (Map<dynamic, dynamic>? json) {
          if (json != null) {
            // if we have launcher_icons configuration ...
            if (json['launcher_icons'] != null) {
              return Config.fromJson(
                json['launcher_icons'] as Map<dynamic, dynamic>,
              );
            }
          }
          return null;
        },
        allowNull: true,
      );
    } on yaml.ParsedYamlException catch (e) {
      throw InvalidConfigException(e.formattedMessage);
    } catch (e) {
      rethrow;
    }
  }

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

  /// Creates [Config] icons from [json]
  ///
  /// The v2 (flat `android:`/`ios:`) schema was removed in v3. A legacy
  /// boolean or string value produces a migration error instead of being
  /// silently ignored.
  factory Config.fromJson(Map<dynamic, dynamic> json) {
    for (final key in ['android', 'ios']) {
      final value = json[key];
      if (value is bool || value is String) {
        throw InvalidConfigException(
          'Invalid `$key` value `$value`. Since v3, `$key` must be a map '
          'with `generate: true` (e.g. `$key:\n    generate: true`). '
          'See the README for the new schema.',
        );
      }
    }
    final windows = json['windows'];
    if (windows is Map && windows.containsKey('icon_size')) {
      throw const InvalidConfigException(
        'Invalid `windows.icon_size`: the key was removed. The generator '
        'always emits multi-size 16,24,32,48,256 — delete the key.',
      );
    }
    return _$ConfigFromJson(json);
  }

  /// whether or not there is configuration for adaptive icons for android
  bool get hasAndroidAdaptiveConfig =>
      isNeedingNewAndroidIcon &&
      androidConfig?.adaptiveIconForeground != null &&
      androidConfig?.adaptiveIconBackground != null;

  /// whether or not there is configuration for monochrome icons for android
  bool get hasAndroidAdaptiveMonochromeConfig {
    return isNeedingNewAndroidIcon &&
        androidConfig?.adaptiveIconMonochrome != null;
  }

  /// whether or not there is configuration for round icons for android
  bool get hasAndroidAdaptiveRoundConfig {
    return isNeedingNewAndroidIcon && androidConfig?.adaptiveIconRound != null;
  }

  /// Checks if at least one platform section has `generate: true`.
  /// Presence alone is not intent: an all-`generate: false` config must fail loudly instead of exiting successfully with no work done.
  bool get hasEnabledPlatform {
    return isNeedingNewAndroidIcon ||
        isNeedingNewIOSIcon ||
        (webConfig?.generate ?? false) ||
        (windowsConfig?.generate ?? false) ||
        (macOSConfig?.generate ?? false) ||
        (linuxConfig?.generate ?? false);
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

  /// Check to see if a custom Android icon name was specified via `icon_name`. When set, a new launcher icon is generated without removing the old default existing Flutter launcher icon.
  bool get isCustomAndroidFile => androidConfig?.iconName != null;

  /// if we are needing a new Android icon
  bool get isNeedingNewAndroidIcon => androidConfig?.generate ?? false;

  /// if we are needing a new iOS icon
  bool get isNeedingNewIOSIcon => iosConfig?.generate ?? false;

  /// Whether or not configuration for generating liquid glass .icon exists
  bool get hasLiquidGlassIconConfig =>
      iosConfig?.liquidGlassLayers?.isNotEmpty ?? false;

  /// Whether or not configuration for generating a macOS liquid glass .icon
  /// exists
  bool get hasMacOSLiquidGlassIconConfig =>
      macOSConfig?.liquidGlassLayers?.isNotEmpty ?? false;

  /// Resolves the effective image path for a platform: the platform-level
  /// `image_path` wins, falling back to the top-level `image_path`.
  /// Returns null when neither is set — callers throw [errorMissingImagePath].
  String? resolveImagePath(String? platformImagePath) =>
      platformImagePath ?? imagePath;

  /// Method for the retrieval of the Android icon path
  /// If android.image_path is found, this will be prioritised over the image_path value.
  String? getImagePathAndroid() => resolveImagePath(androidConfig?.imagePath);

  /// get the image path for IOS
  String? getImagePathIOS() => resolveImagePath(iosConfig?.imagePath);

  /// Converts config to [Map]
  Map<String, dynamic> toJson() => _$ConfigToJson(this);

  @override
  String toString() => 'LauncherIconsConfig: ${toJson()}';
}
