import 'package:json_annotation/json_annotation.dart';

part 'android_config.g.dart';

/// The launcher_icons configuration set for Android
@JsonSerializable(
  anyMap: true,
  checked: true,
)
class AndroidConfig {
  /// Specifies whether to generate icons for Android
  final bool generate;

  /// Image path for Android (falls back to the global `image_path`)
  @JsonKey(name: 'image_path')
  final String? imagePath;

  /// Custom icon name (e.g. `"ic_launcher"`). When set, a new launcher icon is generated without removing the old default one. When `null`, the default existing icon is overridden.
  @JsonKey(name: 'icon_name')
  final String? iconName;

  /// android adaptive_icon_foreground image
  @JsonKey(name: 'adaptive_icon_foreground')
  final String? adaptiveIconForeground;

  /// android adaptive_icon_foreground inset
  @JsonKey(name: 'adaptive_icon_foreground_inset')
  final int adaptiveIconForegroundInset;

  /// android adaptive_icon_background: color, image, or `transparent`.
  ///
  /// The keyword `transparent` (case-insensitive) maps to `@android:color/transparent` with no colors.xml entry.
  @JsonKey(name: 'adaptive_icon_background')
  final String? adaptiveIconBackground;

  /// android adaptive_icon_monochrome image
  @JsonKey(name: 'adaptive_icon_monochrome')
  final String? adaptiveIconMonochrome;

  /// android adaptive_icon_monochrome inset (defaults to 16 like the foreground inset; 0 emits the canonical plain `<monochrome android:drawable>` form).
  @JsonKey(name: 'adaptive_icon_monochrome_inset')
  final int adaptiveIconMonochromeInset;

  /// android adaptive_icon_round image (opt-in round icon).
  ///
  /// When set, `<icon>_round.png` drawables plus an `<icon>_round.xml` adaptive icon are generated and the manifest gains `android:roundIcon`. Requires the adaptive pair (`adaptive_icon_background` + `adaptive_icon_foreground`).
  @JsonKey(name: 'adaptive_icon_round')
  final String? adaptiveIconRound;

  /// android notification icon image (small status-bar icon, white silhouette on transparency). Rendered at 24dp across densities into `drawable-*` and wired as the FCM `default_notification_icon` in the manifest.
  @JsonKey(name: 'notification_icon')
  final String? notificationIcon;

  /// android notification icon resource name (defaults to `ic_notification`).
  @JsonKey(name: 'notification_icon_name')
  final String notificationIconName;

  /// Creates a instance of [AndroidConfig]
  const AndroidConfig({
    this.generate = false,
    this.imagePath,
    this.iconName,
    this.adaptiveIconForeground,
    this.adaptiveIconForegroundInset = 16,
    this.adaptiveIconBackground,
    this.adaptiveIconMonochrome,
    this.adaptiveIconMonochromeInset = 16,
    this.adaptiveIconRound,
    this.notificationIcon,
    this.notificationIconName = 'ic_notification',
  });

  /// Creates [AndroidConfig] from [json]
  factory AndroidConfig.fromJson(Map<dynamic, dynamic> json) => _$AndroidConfigFromJson(json);

  /// Creates [Map] from [AndroidConfig]
  Map<String, dynamic> toJson() => _$AndroidConfigToJson(this);

  @override
  String toString() => 'AndroidConfig: ${toJson()}';
}
