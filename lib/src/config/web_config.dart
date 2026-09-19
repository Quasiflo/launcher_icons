import 'package:json_annotation/json_annotation.dart';
import 'package:launcher_icons/src/config/web_shortcut_icon.dart';
import 'package:launcher_icons/src/core/constants.dart' as constants;

part 'web_config.g.dart';

/// The launcher_icons configuration set for Web
@JsonSerializable(anyMap: true, checked: true)
class WebConfig {
  /// Specifies weather to generate icons for web
  final bool generate;

  /// Base image path for web. The favicon, PWA icons, maskable
  /// derivation, apple-touch-icon and social images all fall back to
  /// this source unless overridden individually below.
  @JsonKey(name: 'image_path')
  final String? imagePath;

  /// Override source for the standard PWA icons (`Icon-192/512.png`).
  /// Falls back to [imagePath].
  @JsonKey(name: 'image_path_pwa')
  final String? imagePathPwa;

  /// Dedicated maskable-icon source (opaque, full-bleed, safe-zone aware).
  /// When omitted, the maskable files are derived from the base image: the logo is scaled to ~80% and centered on the opaque `background_color` (white fallback) so the outer edge survives maskable cropping.
  @JsonKey(name: 'image_path_maskable')
  final String? imagePathMaskable;

  /// Dedicated monochrome-icon source (single-color artwork for
  /// themed PWA icons). Only emitted when set.
  @JsonKey(name: 'image_path_monochrome')
  final String? imagePathMonochrome;

  /// Dedicated monochrome + maskable source. When omitted but
  /// [imagePathMonochrome] is set, derived with the same ~80% padded
  /// canvas as maskable. Only emitted when one of the two is set.
  @JsonKey(name: 'image_path_monochrome_maskable')
  final String? imagePathMonochromeMaskable;

  /// SVG favicon source. Copied verbatim to `favicon.svg` and linked
  /// from `index.html`; never rasterized. The PNG/ICO favicon is always
  /// rendered from [imagePath].
  @JsonKey(name: 'image_path_favicon_svg')
  final String? imagePathFaviconSvg;

  /// Override source for the Open Graph link-preview image
  /// (rendered at 1200x630). Only generated when set.
  @JsonKey(name: 'image_path_opengraph')
  final String? imagePathOpengraph;

  /// Override source for the Twitter/X link-preview image
  /// (rendered at 1200x600). Only generated when set.
  @JsonKey(name: 'image_path_twitter')
  final String? imagePathTwitter;

  /// PWA press-and-hold shortcut icons. Each entry is rendered at 96px
  /// into `icons/` and wired into `manifest.json` `shortcuts[]`.
  @JsonKey(name: 'shortcut_icons')
  final List<WebShortcutIcon>? shortcutIcons;

  /// Output directory for web icons (default `web`).
  /// Lets flavors (or custom setups) target different web roots, e.g. `output_path: web_prod`.
  @JsonKey(name: 'output_path')
  final String outputPath;

  /// Favicon PNG size in pixels. The `.ico` always holds 16+32+48.
  @JsonKey(name: 'favicon_size')
  final int faviconSize;

  /// Whether to emit `favicon.ico` alongside `favicon.png` (default true).
  /// Browsers request `/favicon.ico` by default; set to `false` to opt out and ship the PNG only.
  @JsonKey(name: 'favicon_ico')
  final bool faviconIco;

  /// Splash / canvas color, written to `manifest.json` `background_color` and as `html, body { background-color }` in `index.html`.
  @JsonKey(name: 'background_color')
  final String? backgroundColor;

  /// Light-scheme theme color, emitted as
  /// `<meta name="theme-color" media="(prefers-color-scheme: light)">`.
  @JsonKey(name: 'theme_color_light')
  final String? themeColorLight;

  /// Dark-scheme theme color, emitted as
  /// `<meta name="theme-color" media="(prefers-color-scheme: dark)">`.
  /// When only one of light/dark is set, it is emitted without a media query.
  @JsonKey(name: 'theme_color_dark')
  final String? themeColorDark;

  /// Creates an instance of [WebConfig]
  const WebConfig({
    this.generate = false,
    this.imagePath,
    this.imagePathPwa,
    this.imagePathMaskable,
    this.imagePathMonochrome,
    this.imagePathMonochromeMaskable,
    this.imagePathFaviconSvg,
    this.imagePathOpengraph,
    this.imagePathTwitter,
    this.shortcutIcons,
    this.faviconSize = constants.faviconDefaultSize,
    this.faviconIco = true,
    this.outputPath = 'web',
    this.backgroundColor,
    this.themeColorLight,
    this.themeColorDark,
  });

  /// Creates [WebConfig] from [json]
  factory WebConfig.fromJson(Map<dynamic, dynamic> json) => _$WebConfigFromJson(json);

  /// Creates [Map] from [WebConfig]
  Map<String, dynamic> toJson() => _$WebConfigToJson(this);

  @override
  String toString() => 'WebConfig: ${toJson()}';
}
