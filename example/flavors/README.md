# Flavors Example

A complete, runnable Flutter app (fresh `flutter create` template) with two flavors — **development** and **production** — and a `launcher_icons-*` config that fills in **every option for every platform**. Generated outputs are checked in, so you can inspect exactly what each key produces.

## Run the Icon Generation

```shell
cd example/flavors
dart pub get
dart run launcher_icons
```

Both flavors live as `launcher_icons-development:` / `launcher_icons-production:` sections in `pubspec.yaml` — no per-flavor files needed. The plain run loops over every flavor; `--flavor` runs one:

```shell
dart run launcher_icons --flavor development
```

## Run the App

```shell
flutter run --flavor development -t lib/main_development.dart
flutter run --flavor production -t lib/main_production.dart
```

## What Each Flavor Shows Off

| Area | development (transparency showcase) | production (opaque + glass showcase) |
| --- | --- | --- |
| Source art | Prism Glyph "V" (teal, transparent-leaning) | Prism Glyph "A" (indigo, opaque) |
| Android | `transparent` adaptive background keyword (no `colors.xml` entry), foreground inset, monochrome, **round icon** (`android:roundIcon` wiring), **Play Store sidecar** (`play_store_icon.png` at the root) | Image adaptive background, tighter inset, round icon, no sidecar |
| iOS | `remove_alpha` matte blended onto `#123456`, transparent dark variant (system bg shows through), desaturated tinted variant, single-layer glass bundle, `flavor_mode: pbxproj` (rewrites `ASSETCATALOG_COMPILER_APPICON_NAME`) | Opaque art, `remove_alpha: false`, two-layer glass stack (SVG background + foreground glyph with per-layer scale/offset/blend) with per-appearance variants + refractivity/lighting/specular placement, `flavor_mode: xcconfig` (`ios/Flutter/production-*.xcconfig` — assign as base configuration files in Xcode once) |
| Web | Dedicated maskable source, `favicon.ico` (16+32+48) + PNG, separate `web_development/` root | No maskable source → padded fallback derivation (watch for the warning), PNG-only favicon, separate `web_production/` root |
| Windows | Per-flavor `app_icon_development.ico` (matches `Runner.rc.in`) | Default `app_icon.ico` |
| macOS | `padding: 10` + `rounded_corners` squircle mask | Defaults (square, opaque) + liquid glass `.icon` bundle (`AppIcon-production.icon`, two-layer SVG stack with per-appearance variants + refractivity/lighting/specular placement) |
| Linux | Window icon + hicolor tree + `.desktop` + snap packaging | Same targets (strictly only-if-absent, so the first run wins) |

`icon_name` is deliberately absent from both configs: under flavors the catalog is always `AppIcon-<flavor>` (iOS/macOS) / `src/<flavor>/res` (Android), so a custom name would be ignored.

## Native Flavor Wiring (Current Flutter Pattern)

- **pubspec**: `flutter.default-flavor: development`.
- **Android** (`android/app/build.gradle.kts`): `productFlavors` with `applicationIdSuffix` + `app_name` res value; `AndroidManifest.xml` uses `@string/app_name`. Matches `docs.flutter.dev/deployment/flavors`.
- **iOS/macOS**: per-flavor build configurations (`Debug-development`, …) carrying `APP_DISPLAY_NAME` + flavor bundle-id suffix, one scheme per flavor, `Info.plist` display name `$(APP_DISPLAY_NAME)`. The tool's `pbxproj` mode wires configurations that share the base `.xcconfig`.
- **Linux**: `FLUTTER_APP_FLAVOR` application-id branches + window-title switch in `my_application.cc`.
- **Windows**: `Runner.rc.in` / `main.cpp.in` templates configured with the per-flavor title and icon name. Matches `docs.flutter.dev/deployment/flavors-windows`. (`Runner.rc` / `main.cpp` are generated at build time — the checked-in copies reflect the last flavor run.)
- **Web**: no native flavors upstream; separation is via per-flavor `output_path`. Serve that directory when building (`flutter build web` serves `web/` unless reconfigured).

## Regenerating from Scratch

Delete the generated outputs (or run the two commands above — every writer is idempotent) and re-run. All per-platform sources live under `assets/icon/` as SVGs (`*-dev*` transparent set, `*-prod*` opaque set + `*-glass*` liquid-glass layers), so this demo also exercises the vector pipeline end to end: alpha recovery, the `remove_alpha` matte, dark/tinted variants, and native SVG glass layers.
