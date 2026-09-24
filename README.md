# Flutter Launcher Icons

[![pub package](https://img.shields.io/pub/v/launcher_icons.svg)](https://pub.dev/packages/launcher_icons)
[![pub points](https://img.shields.io/pub/points/launcher_icons?label=pub%20points)](https://pub.dev/packages/launcher_icons/score)
[![License](https://img.shields.io/badge/license-APACHE%202.0-blue.svg)](https://github.com/Quasiflo/launcher_icons/blob/main/LICENSE)

> **A maintained fork of [fluttercommunity/flutter_launcher_icons](https://github.com/fluttercommunity/flutter_launcher_icons).** Thank you to [@MarkOSullivan94](https://github.com/MarkOSullivan94) and all the original contributors for building the tool this continues. Bug reports, ideas, and pull requests are welcome here — see [CONTRIBUTING.md](CONTRIBUTING.md).

A command-line tool that generates your Flutter app's launcher icons from a source image. Enable each platform with `generate: true`, with per-platform overrides for sources, names, and appearance variants. Full reference lives in [`doc/`](doc/config.md).

## Why This Package

Compared with [flutter_launcher_icons](https://pub.dev/packages/flutter_launcher_icons) and [icons_launcher](https://pub.dev/packages/icons_launcher):

- Actively maintained! File any feature / bug reports, we'd love to keep improving this!
- Modern icon variants — Android monochrome/round/notification layers, iOS 18+ dark/tinted appearances, liquid-glass `.icon` bundles on iOS/macOS, and PWA maskable/monochrome/shortcut/social images on web.
- Flavors on every platform — sections or files, single `--flavor` runs, with flavored outputs (`src/<flavor>/res`, `AppIcon-<flavor>`, per-flavor web roots and Windows ICO names) instead of Android-only or multi-flavor flags.
- Deep native wiring with safe cleanup — manifest, `colors.xml`, pbxproj/xcconfig, `index.html`/`manifest.json`, runner patches, plus stale-output sweeping, instead of emit-only assets.
- Strict and predictable — unknown keys and type mismatches fail fast, and `dart run launcher_icons:generate` emits a template covering every key.

## Migrating from Flutter_launcher_icons

This fork has diverged heavily and is still volatile: most features from `flutter_launcher_icons` still exist, but many are renamed or have different semantics (e.g. flat `<platform>:` sections with `generate: true` instead of shorthand values, `image_path` instead of `image_path_android`/`image_path_ios`, split `theme_color_light`/`theme_color_dark` on web). After running the new tool, check `git diff` carefully — and if any change still looks incorrect, please [file an issue](https://github.com/Quasiflo/launcher_icons/issues).

## Quickstart

Add the dependency and generate a starter config:

<!-- x-release-please-start-version -->

```yaml
dev_dependencies:
  launcher_icons: "^0.15.0"
```

<!-- x-release-please-end -->

```shell
dart run launcher_icons:generate
```

This writes `launcher_icons.yaml` in your project root. Or skip the file and configure inside `pubspec.yaml` — both work.

Then run the tool:

```shell
flutter pub get
dart run launcher_icons
```

Your config file must sit next to `pubspec.yaml`. The `:generate` command takes a file name, while the main command searches a folder:

```shell
dart run launcher_icons:generate -c my_icons.yaml
dart run launcher_icons -c .
```

## Source Image

Use one high-resolution **PNG** — **1024×1024 recommended**. Everything is downscaled from it (iOS needs the 1024px App Store icon), so starting smaller loses quality. JPG/JPEG/WebP are accepted for some inputs (e.g. Android adaptive layers, web sources). Raster outputs are PNG, plus the Windows and favicon `.ico` files, verbatim `.xml` vector drawables and the `.svg` favicon, liquid-glass `.icon` bundles, and patches to manifests, HTML, and Xcode/Gradle-adjacent project files.

SVG sources are supported, but the built-in renderer is beta quality: stick to basic shapes, paths, fills, strokes, and gradients. `<text>` elements generally do not render (convert text to outlines first), advanced features like filters, masks, patterns, and embedded images may be ignored or misrendered, and very thin strokes can glitch. Transparency is recovered by compositing, so semi-transparent edges can fringe slightly, and the SVG must declare dimensions (a `viewBox` or `width` and `height`). Simple logos are usually fine — but if the output doesn't match your editor, export PNGs externally (e.g. Figma, Inkscape, Illustrator at 1024px) and feed those in instead.

## What Gets Generated

| Platform | Outputs | Reference |
| --- | --- | --- |
| Android legacy | 48, 72, 96, 144, 192 (`mipmap-mdpi` → `mipmap-xxxhdpi`) | [Android](doc/android.md) |
| Android adaptive | 108, 162, 216, 324, 432 foreground/background/monochrome (`drawable-*`) + `mipmap-anydpi-v26` XML (PNG layers, or your own `.xml` vector drawables passed through verbatim) | [Android](doc/android.md) |
| Android notification | 24, 36, 48, 72, 96 small icon (`drawable-*`) + FCM `default_notification_icon` manifest wiring | [Android](doc/android.md) |
| iOS | 20 – 1024, plus optional dark, tinted, and liquid-glass `.icon` variants | [iOS](doc/ios.md) |
| Web | PWA 192, 512 (+ maskable, optional monochrome), 180px apple-touch-icon, optional 96px shortcut icons, optional 1200x630 Open Graph and 1200x600 Twitter images, favicon PNG (default 32) + multi-size ICO + optional verbatim SVG | [Web](doc/web.md) |
| Windows | `.ico` with 16, 20, 24, 32, 40, 48, 64, 96, 128, 256px frames, plus MSIX tile / AppList assets and a manifest snippet | [Windows](doc/windows.md) |
| macOS | 16 – 1024 (`@1x`/`@2x` sets), plus an optional liquid-glass `.icon` bundle | [macOS](doc/macos.md) |
| Linux | hicolor tree (16–512), `.desktop` entries, opt-in `snap/` packaging, window-icon runner patch | [Linux](doc/linux.md) |

## Configuration

Top-level `image_path` is the default for every platform; any platform-level `image_path` overrides it. Paths are project-relative local files. At least one platform must set `generate: true`, and unknown keys or type mismatches fail instead of being ignored.

```yaml
launcher_icons:
  image_path: "assets/icon/icon.png"
  android:
    generate: true
  ios:
    generate: true
```

Each platform page documents every key: [config sources and flavors](doc/config.md), [Android](doc/android.md), [iOS](doc/ios.md), [Web](doc/web.md), [Windows](doc/windows.md), [macOS](doc/macos.md), [Linux](doc/linux.md).

## Flavors

Declare each variant as a `launcher_icons-<flavor>` section in your config file or `pubspec.yaml`, or as a `launcher_icons-<flavor>.yaml` file carrying that section. Each section stands alone with the same shape as `launcher_icons:` — declaring the same flavor twice is an error. Discovery is flat (no recursion).

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
dart run launcher_icons --flavor dev     # one flavor (bare name)
```

Flavor outputs land in the flavored locations (`src/<flavor>/res`, `AppIcon-<flavor>`, per-flavor web `output_path` / Windows `icon_filename`, and so on). Details: [Configuration and Flavors](doc/config.md).

## Command-Line Options

Two separate commands — their flags differ.

Main command (`dart run launcher_icons`):

| Option | Description |
| --- | --- |
| `-h, --help` | Usage help |
| `--version` | Tool version |
| `-v, --verbose` | Verbose output |
| `-c, --config <folder>` | Folder to search for config files. Defaults to `.` |
| `-d, --dir <path>` | Project root. Defaults to the current directory |
| `-f, --flavor <name>` | Run a single flavor (bare name) |

Template generator (`dart run launcher_icons:generate`):

| Option | Description |
| --- | --- |
| `-h, --help` | Usage help |
| `--version` | Tool version |
| `-o, --override` | Overwrite the output file |
| `-c, --config <file>` | Output file name (must end `.yaml`). Defaults to `launcher_icons.yaml` |

Exit codes: `0` success, `1` a platform failed, `2` bad config or CLI usage. A failed platform never reports success, and every platform runs before the command exits.

## Troubleshooting

**Old icon still shows after regenerating.** The files are usually right and a cache is stale: `flutter clean`, uninstall the app from the device/emulator, rebuild. iOS: re-check `Asset Catalog App Icon Set Name`. Android flavors: delete leftover `mipmap-anydpi-v26/ic_launcher.xml` under `src/main/` shadowing the flavor resources.

Anything else: [open an issue](https://github.com/Quasiflo/launcher_icons/issues).

## Credits

Icon resizing via Brendan Duncan's [image package](https://pub.dev/packages/image). Full history and attributions in [CHANGELOG.md](CHANGELOG.md) and the [upstream repository](https://github.com/fluttercommunity/flutter_launcher_icons).

## License

This repository is licensed under the Apache License 2.0. Contributions made prior to 2026-09-14 (commit 1b763c0) remain licensed under MIT, see [LICENSE-MIT](LICENSE-MIT) for the full text.

- **Copyright (c) 2026 Quasiflo**
- **Permission Granted:** You are free to use, copy, modify, distribute, and sublicense this software, including for commercial purposes, subject to the terms of the license.
- **Conditions:** You must include the original copyright notice and a copy of the license in any distribution, clearly state any significant changes made to the original files, and retain any attribution notices from a NOTICE file (if present).
- **Patent Grant:** Contributors grant a patent license covering their contributions. This patent license terminates if you institute patent litigation alleging that the Work (or a Contribution) infringes a patent.
- **No Warranty:** This software is provided "as is," without warranties or conditions of any kind, express or implied.

See the [LICENSE](LICENSE) file for the full legal text.
