# Flutter Launcher Icons

[![pub package](https://img.shields.io/pub/v/launcher_icons.svg)](https://pub.dev/packages/launcher_icons)
[![pub points](https://img.shields.io/pub/points/launcher_icons?label=pub%20points)](https://pub.dev/packages/launcher_icons/score)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/Quasiflo/launcher_icons/blob/main/LICENSE)
![CodeRabbit Pull Request Reviews](https://img.shields.io/coderabbit/prs/github/Quasiflo/dependency_sorter?utm_source=oss&utm_medium=github&utm_campaign=Quasiflo%2Fdependency_sorter&labelColor=171717&color=FF570A&link=https%3A%2F%2Fcoderabbit.ai&label=CodeRabbit+Reviews)

> **A maintained fork of [fluttercommunity/flutter_launcher_icons](https://github.com/fluttercommunity/flutter_launcher_icons).** Thank you to [@MarkOSullivan94](https://github.com/MarkOSullivan94) and all the original contributors for building the tool this continues. Bug reports, ideas, and pull requests are welcome here — see [CONTRIBUTING.md](CONTRIBUTING.md).

A command-line tool that generates your Flutter app's launcher icons from a source image. Pick which platforms to generate with `generate: true`, and use `icon_name` when you want a new icon alongside the old one instead of replacing it.

## Quickstart

Add the dependency and generate a starter config:

<!-- x-release-please-start-version -->

```yaml
dev_dependencies:
  launcher_icons: "^0.14.4"
```

<!-- x-release-please-end -->

```shell
dart run launcher_icons:generate
```

This writes `launcher_icons.yaml` in your project root. Or skip the file and configure inside `pubspec.yaml` — both work. See [the examples](https://github.com/Quasiflo/launcher_icons/tree/main/example) for complete projects.

Then run the tool:

```shell
flutter pub get
dart run launcher_icons
```

Your config file must sit next to `pubspec.yaml`. With `-f` you can point at a differently named file for both commands:

```shell
dart run launcher_icons:generate -f my_icons.yaml
dart run launcher_icons -f my_icons.yaml
```

## Source Image

Use one high-resolution **PNG** — **1024×1024 recommended**. Everything is downscaled from it (iOS needs the 1024px App Store icon), so starting smaller loses quality. JPG/JPEG/WebP are only accepted for Android adaptive backgrounds. All outputs are PNG, except the Windows `.ico`.

SVG sources are supported, but the built-in renderer is beta quality: stick to basic shapes, paths, fills, strokes, and gradients. `<text>` elements generally do not render (convert text to outlines first), advanced features like filters, masks, patterns, and embedded images may be ignored or misrendered, and very thin strokes can glitch. Transparency is recovered by compositing, so semi-transparent edges can fringe slightly, and the SVG must declare dimensions (a `viewBox` or `width` and `height`). Simple logos are usually fine — but if the output doesn't match your editor, export PNGs externally (e.g. Figma, Inkscape, Illustrator at 1024px) and feed those in instead.

| Platform | What gets generated |
| --- | --- |
| Android legacy | 48, 72, 96, 144, 192 (`mipmap-mdpi` → `mipmap-xxxhdpi`) |
| Android adaptive | 108, 162, 216, 324, 432 foreground (`drawable-*`) + `mipmap-anydpi-v26` XML |
| iOS | 20 – 1024, plus optional dark, tinted, and liquid-glass variants |
| Web | 192, 512 (+ maskable), 180px apple-touch-icon, favicon PNG + multi-size ICO |
| Windows | `.ico` with 16, 24, 32, 40, 48, 64, 256px frames |
| macOS | 16 – 1024 (`@1x`/`@2x` sets) |
| Linux | hicolor tree (16–512), `.desktop` entries, `snap/` packaging, X11 window icon |

## Configuration

Top-level `image_path` is the default for every platform; any platform-level `image_path` overrides it. Paths must be local files (PNG, JPG/JPEG/WebP where noted, or SVG — see the beta note in Source Image).

- `image_path` — default source image for every platform (see Source Image for format rules).
- `svg_rasterize_per_size` — `false` by default: each SVG rasterizes once at 1024px and every output size downscales from that master (fast, and as crisp for icon art). `true` re-rasterizes the vector at every output size (crisper pixel-aligned edges, much slower on large sets like iOS).

### Android

- `generate` — enable Android output.
- `image_path` — source for the legacy mipmap icons; falls back to top-level `image_path`.
- `icon_name` — custom resource name (lowercase letters, numbers, underscores, e.g. `"ic_launcher_xyz"`): creates a new icon and updates `AndroidManifest.xml` instead of overwriting the default.
- `adaptive_icon_background` — back layer of the adaptive icon: a hex color (`"#ffffff"`), `"transparent"` (no `colors.xml` entry), or an image (png/jpg/jpeg/webp). Adaptive icons need this **and** `adaptive_icon_foreground`.
- `adaptive_icon_foreground` — front layer image of the adaptive icon; `image_path` is never used as the foreground.
- `adaptive_icon_foreground_inset` — trims this percent off each side of the foreground (default `16`) to keep art inside the safe zone. Without both adaptive keys, round launchers may show your square icon inside a white circle — the tool never auto-rounds or pads.
- `adaptive_icon_monochrome` — Android 13+ single-color themed-icon layer image; inset `0` emits the canonical plain `<monochrome android:drawable>` form. See [Android Adaptive Icons](https://developer.android.com/develop/ui/compose/system/icon_design_adaptive).
- `adaptive_icon_round` — opt-in round-icon source image: emits round drawables plus `ic_launcher_round.xml` and wires `android:roundIcon` in the manifest. Requires the adaptive pair.
- `play_store_icon` — off by default. When `true`, writes a 512px `play_store_icon.png` sidecar next to the project for store upload (never into `android/res`; warns past the 1024KB budget).

### iOS

- `generate` — enable iOS output.
- `single_size` — when `true`, emits only the single 1024px icon; dark/tinted variants are ignored (default `false`).
- `image_path` — source image; falls back to top-level `image_path`.
- `icon_name` — writes an own `<name>.appiconset` (like flavors) instead of overwriting the default set.
- `xcodeproj_path` — path to the Xcode project (default `"ios/Runner.xcodeproj"`); set it when the project was renamed.
- `flavor_mode` — `"pbxproj"` (default) rewrites `ASSETCATALOG_COMPILER_APPICON_NAME` per build configuration; `"xcconfig"` writes `ios/Flutter/<flavor>-<Mode>.xcconfig` overrides instead (assign them as base configuration files in Xcode once).
- `image_path_dark_transparent` — iOS 18+ dark-mode source: full art on transparency, because the system background shows through it. Keep the background transparent.
- `image_path_tinted_grayscale` — iOS 18+ tinted-mode source: must read as a single-color silhouette, i.e. grayscale, or you get a warning.
- `desaturate_tinted_to_grayscale` — converts the tinted source to grayscale for you (default `false`; set it instead of hand-converting).
- `remove_alpha` — flattens transparency onto `background_color` (default `false`). The base and tinted images are flattened; the dark variant intentionally keeps its transparency. Without it, transparent art triggers an App Store alpha warning.
- `background_color` — matte color used by `remove_alpha` (`"#RRGGBB"`, default `"#ffffff"`).
- `liquid_glass_layers` — artwork layers for the liquid-glass `.icon` bundle (Apple's Icon Composer format; the PNG catalog stays the fallback on older systems). One list entry per layer, bottom-to-top; the bundle is emitted when the list is non-empty. Sources pass through verbatim, so SVGs work. Each entry supports:
- `liquid_glass_layers[].image_path` — artwork source for the layer (required).
- `liquid_glass_layers[].image_path_dark` / `image_path_tinted` — dark/tinted artwork overrides; fall back to the dark/tinted PNG sources above when unset.
- `liquid_glass_layers[].scale` — artwork scale within the canvas (default `1.0`).
- `liquid_glass_layers[].offset_x` / `offset_y` — layer offset in points (default `0.0`).
- `liquid_glass_layers[].glass` — layer participates in the glass effect (default `true`; group `remove_liquid_glass` overrides it off).
- `liquid_glass_layers[].opacity` — artwork opacity, `0.0` to `1.0`. Unset by default (opaque).
- `liquid_glass_layers[].blend_mode` — compositing against layers behind it: `"normal"`, `"plus-lighter"`, `"plus-darker"`, `"overlay"`, `"multiply"`, `"soft-light"`, `"hard-light"`, `"darken"`, `"lighten"`, `"screen"`. Unset by default (normal).
- `liquid_glass_layers[].fill` — recolor tint applied to the artwork (hex `"#RRGGBB"`). Unset by default (artwork colors pass through).
- `liquid_glass_layers[].fill_dark` / `fill_tinted` — dark/tinted recolor tints; each falls back to `fill` when unset.
- `remove_liquid_glass` — emits the `.icon` layers flat, without glass effects (default `false`).
- `liquid_glass_translucency` — how see-through the glass reads, `0.0` (opaque) to `1.0` (clear); default `0.5`.
- `liquid_glass_specular` — specular highlights on the glass (default `true`).
- `liquid_glass_shadow_kind` — drop-shadow style: `"Neutral"` or `"Chromatic"` (default `"Neutral"`).
- `liquid_glass_shadow_opacity` — drop-shadow strength (default `0.5`).
- `liquid_glass_blur` — background blur radius behind the glass (default `0.5`).
- `liquid_glass_lighting` — group lighting model: `"individual"` lights each layer separately, `"combined"` treats the group as one shape. Unset by default; only observable with 2+ layers.
- `liquid_glass_refractivity_enabled` — turns on glass distortion; requires `liquid_glass_refractivity_depth` and `liquid_glass_refractivity_strength` to be set as well.
- `liquid_glass_refractivity_depth` / `liquid_glass_refractivity_strength` — depth and strength of the refraction effect (only used when refractivity is enabled).
- `liquid_glass_specular_highlight_placement` — edge highlight position: `"inside"` or `"outside"`. Unset by default.

After generating, Xcode must point at the set: `Build Settings` > `Asset Catalog App Icon Set Name` (`AppIcon`, or `AppIcon-<flavor>`).

### Web

- `generate` — enable web output.
- `image_path` — source image; falls back to top-level `image_path`.
- `image_path_favicon` — dedicated favicon source; falls back to the web, then global, image.
- `image_path_maskable` — dedicated maskable-icon source (opaque, full-bleed, safe-zone aware). When omitted, maskable files are derived from the base image: the logo is scaled to ~80% and centered on the opaque `background_color` so the outer edge survives maskable cropping.
- `output_path` — web root directory (default `web`); set per flavor to keep outputs apart — serve that directory when building.
- `favicon_size` — PNG favicon size in pixels (default `16`; the `.ico` always holds 16+32+48).
- `favicon_ico` — emit multi-frame `favicon.ico` alongside `favicon.png` (default `true`; browsers request `/favicon.ico` by default, set `false` to ship the PNG only).
- `background_color` — must be hex when set. Written to `web/manifest.json`, used as the maskable-derivation canvas, and flattens the opaque 180px `apple-touch-icon.png`.
- `theme_color` — must be hex when set. Written to `web/manifest.json` and added as the `<meta name="theme-color">` tag. The tool manages one `<!--LI-->…<!--LIEND-->` block in `index.html`.

### Windows

- `generate` — enable Windows output.
- `image_path` — source image; falls back to top-level `image_path`. Sources under 256px warn about upscaling, because the 256px ICO frame goes soft.
- `icon_filename` — output `.ico` name inside `windows/runner/resources/` (default `app_icon.ico`, the `Runner.rc` contract). Set a per-flavor name so sequential flavor runs don't clobber each other, and wire it into `Runner.rc(.in)`.

### macOS

- `generate` — enable macOS output.
- `image_path` — source image; falls back to top-level `image_path`.
- `padding` — safe-area margin as a percent of the icon size, applied on every side (default `0`, which fills the icon edge to edge). The artwork is scaled into the remaining inner area and centered on a transparent canvas.
- `rounded_corners` — masks the canvas with an Apple-like squircle (default `false`). macOS does not shape the artwork itself, so leave this off for square art.
- `background_color` — canvas fill behind the glass in the liquid-glass bundle (`#RRGGBB`, default `#ffffff`). Transparency is otherwise preserved, never filled — prefer opaque art.
- `liquid_glass_layers` — artwork layers for the liquid-glass `.icon` bundle next to the PNG catalog (same format as iOS; the PNG set stays the fallback on macOS older than Tahoe 26). One list entry per layer, bottom-to-top; the bundle is emitted when the list is non-empty. Unlike iOS, per-layer dark/tinted sources have no fallbacks — macOS has no dark/tinted catalog variants to reuse. Each entry supports:
- `liquid_glass_layers[].image_path` — artwork source for the layer (required).
- `liquid_glass_layers[].image_path_dark` / `image_path_tinted` — dark/tinted artwork overrides (no fallbacks on macOS; each must be set explicitly to get that appearance).
- `liquid_glass_layers[].scale` — artwork scale within the canvas (default `1.0`).
- `liquid_glass_layers[].offset_x` / `offset_y` — layer offset in points (default `0.0`).
- `liquid_glass_layers[].glass` — layer participates in the glass effect (default `true`; group `remove_liquid_glass` overrides it off).
- `liquid_glass_layers[].opacity` — artwork opacity, `0.0` to `1.0`. Unset by default (opaque).
- `liquid_glass_layers[].blend_mode` — compositing against layers behind it: `"normal"`, `"plus-lighter"`, `"plus-darker"`, `"overlay"`, `"multiply"`, `"soft-light"`, `"hard-light"`, `"darken"`, `"lighten"`, `"screen"`. Unset by default (normal).
- `liquid_glass_layers[].fill` — recolor tint applied to the artwork (hex `"#RRGGBB"`). Unset by default (artwork colors pass through).
- `liquid_glass_layers[].fill_dark` / `fill_tinted` — dark/tinted recolor tints; each falls back to `fill` when unset.
- `remove_liquid_glass` — emits the `.icon` layers flat, without glass effects (default `false`).
- `liquid_glass_translucency` — how see-through the glass reads, `0.0` (opaque) to `1.0` (clear); default `0.5`.
- `liquid_glass_specular` — specular highlights on the glass (default `true`).
- `liquid_glass_shadow_kind` — drop-shadow style: `"Neutral"` or `"Chromatic"` (default `"Neutral"`).
- `liquid_glass_shadow_opacity` — drop-shadow strength (default `0.5`).
- `liquid_glass_blur` — background blur radius behind the glass (default `0.5`).
- `liquid_glass_lighting` — group lighting model: `"individual"` or `"combined"`. Unset by default; only observable with 2+ layers.
- `liquid_glass_refractivity_enabled` — turns on glass distortion; requires `liquid_glass_refractivity_depth` and `liquid_glass_refractivity_strength` to be set as well.
- `liquid_glass_refractivity_depth` / `liquid_glass_refractivity_strength` — depth and strength of the refraction effect (only used when refractivity is enabled).
- `liquid_glass_specular_highlight_placement` — edge highlight position: `"inside"` or `"outside"`. Unset by default.

After generating, add `<name>.icon` to the Xcode project (the tool registers the file reference in `project.pbxproj` automatically) and set the target's App Icon to it; the PNG set keeps working untouched. Flavors write `AppIcon-<flavor>.appiconset`; select it in Xcode like iOS.

### Linux

- `generate` — enable Linux output.
- `image_path` — source image; falls back to top-level `image_path`. Must also be declared under `flutter: assets:` in `pubspec.yaml` (any asset path, not just `assets/`) so it ships inside the bundle — the runner resolves it at runtime, so generation fails without this.

Emits the hicolor tree, `.desktop` entries, and `snap/` files — each strictly only-if-absent — and patches `my_application.cc` with an executable-relative icon path that works under `flutter run` and in release bundles.

## Flavors

Declare each variant as a `launcher_icons-<flavor>` section in your config file or `pubspec.yaml`. Each section stands alone with the same shape as `launcher_icons:`:

```yaml
launcher_icons-dev:
  image_path: "assets/icon/icon-dev.png"
  android:
    generate: true
launcher_icons-prod:
  image_path: "assets/icon/icon-prod.png"
  android:
    generate: true
```

```shell
dart run launcher_icons                  # every flavor
dart run launcher_icons --flavor dev     # one flavor
```

One `launcher_icons-<flavor>.yaml` file per flavor works too; a file wins over a section with the same name. `icon_name` is ignored inside flavor configs — the catalog is always `AppIcon-<flavor>` / `src/<flavor>/res`. See the [flavors example](https://github.com/Quasiflo/launcher_icons/tree/main/example/flavors) for the full native setup (schemes, bundle ids, display names) on every platform.

## Command-Line Options

| Option | Description |
| --- | --- |
| `-f, --file <path>` | Config file. Defaults to `launcher_icons.yaml` |
| `-o, --override` | Overwrite the `:generate` output file |
| `-v, --verbose` | Verbose output |
| `-p, --prefix <path>` | Project root. Defaults to the current directory |
| `--flavor-path <path>` | Where to search for flavor files (recursive). Defaults to `.` |
| `--flavor <name>` | Run a single flavor from a section or file |

Exit codes: `0` success, `1` a platform failed, `2` bad config or CLI usage. A failed platform never reports success, and every platform runs before the command exits.

## Troubleshooting

**Old icon still shows after regenerating.** The files are usually right and a cache is stale: `flutter clean`, uninstall the app from the device/emulator, rebuild. iOS: re-check `Asset Catalog App Icon Set Name`. Android flavors: delete leftover `mipmap-anydpi-v26/ic_launcher.xml` under `src/main/` shadowing the flavor resources.

Anything else: [open an issue](https://github.com/Quasiflo/launcher_icons/issues).

## Credits

Icon resizing via Brendan Duncan's [image package](https://pub.dev/packages/image). Full history and attributions in [CHANGELOG.md](CHANGELOG.md) and the [upstream repository](https://github.com/fluttercommunity/flutter_launcher_icons).
