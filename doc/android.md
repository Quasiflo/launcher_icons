# Android

Generates legacy launcher icons, adaptive icons (Android 8+), an opt-in round icon, and an opt-in notification icon, and patches `AndroidManifest.xml` (plus `colors.xml` for color backgrounds).

## Outputs

All paths are under `android/app/src/<main|flavor>/res/`, where `<flavor>` is the bare flavor name and `main` is the unflavored default.

| What | Files |
| --- | --- |
| Legacy icons | `mipmap-mdpi/hdpi/xhdpi/xxhdpi/xxxhdpi/<icon>.png` at 48, 72, 96, 144, 192 px (`<icon>` is `ic_launcher` by default, or `icon_name`) |
| Adaptive foreground/background/monochrome | `drawable-mdpi/hdpi/xhdpi/xxhdpi/xxxhdpi/<icon>_{foreground,background,monochrome}.png` at 108, 162, 216, 324, 432 px, or `drawable/<name>.xml` when that layer is a vector drawable |
| Adaptive XML | `mipmap-anydpi-v26/<icon>.xml` (plus `<icon>_round.xml` when `adaptive_icon_round` is set) |
| Background color | `values/colors.xml` gains `<color name="<icon>_background">` when the background is a color |
| Round icon | `<icon>_round` drawables plus manifest `android:roundIcon` |
| Notification icon | `drawable-mdpi/hdpi/xhdpi/xxhdpi/xxxhdpi/<notification_name>.png` at 24, 36, 48, 72, 96 px (24dp), or `drawable/<name>.xml` for vector sources |

`AndroidManifest.xml` is rewritten to point `android:icon` at `@mipmap/<icon>`. When `adaptive_icon_round` is set, `android:roundIcon` is inserted or updated. When `notification_icon` is set, `com.google.firebase.messaging.default_notification_icon` is ensured inside `<application>` (skipped with a warning when there is no manifest or no `<application>` element).

Cleanup is automatic: disabling adaptive icons deletes stale `mipmap-anydpi-v26` XML and `drawable-*/<icon>_*` files, and switching a layer between PNG and XML deletes the superseded twin. Stale legacy PNGs from a previous `icon_name` are removed based on manifest evidence (`ic_launcher` and the incoming name are never deleted).

## Keys

| Key | Type / Default | Meaning |
| --- | --- | --- |
| `generate` | bool, `false` | Enable Android output. |
| `image_path` | String, falls back to top-level `image_path` | Source for the legacy mipmap icons. PNG, JPG/JPEG, WebP, or SVG. |
| `icon_name` | String, unset | Custom resource name (`^[a-z0-9_]+$`, e.g. `ic_launcher_xyz`). Creates a new icon alongside the old one and updates the manifest instead of overwriting the default. Anything else throws `InvalidAndroidIconNameException`. |
| `adaptive_icon_background` | String, unset | Back layer: hex color (`#ffffff`, bare `ffffff` also accepted), `transparent` (maps to `@android:color/transparent` with no `colors.xml` entry), image (png/jpg/jpeg/webp/svg), or `.xml` vector drawable (copied verbatim to `drawable/`, no PNGs emitted for that layer). |
| `adaptive_icon_foreground` | String, unset | Front layer: image or `.xml` vector drawable. `image_path` is never used as the foreground. Both background and foreground are required for any adaptive output. |
| `adaptive_icon_foreground_inset` | int, `16` | Trims this percent off each side of the foreground to keep art inside the safe zone. `0` emits the canonical plain `<foreground android:drawable>` form. |
| `adaptive_icon_monochrome` | String, unset | Android 13+ themed-icon layer: image or `.xml` vector drawable. Requires the adaptive pair; set without it, generation fails. |
| `adaptive_icon_monochrome_inset` | int, `16` | Like the foreground inset, but for the monochrome layer. `0` emits the plain `<monochrome android:drawable>` form. |
| `adaptive_icon_round` | String, unset | Opt-in round-icon source: image or `.xml` vector drawable. Emits `<icon>_round` drawables plus `<icon>_round.xml` and wires `android:roundIcon`. Requires the adaptive pair. Warns when the manifest already has a `roundIcon` but no round source is configured. |
| `notification_icon` | String, unset | Small status-bar icon source: white silhouette on transparency (PNG, SVG, or `.xml` vector drawable). Emitted as the 24dp set and wired as the FCM `default_notification_icon`. |
| `notification_icon_name` | String, `ic_notification` | Resource name for the notification icon. |

Without both adaptive keys, round launchers may show the square icon inside a white circle — the tool never auto-rounds or pads legacy art. Keep foreground art inside the safe zone (`adaptive_icon_foreground_inset`) and check it with [maskable.app](https://maskable.app/). See [Adaptive Icons](https://developer.android.com/develop/ui/compose/system/icon_design_adaptive).

## Image Handling

Raster and SVG sources render through a 1024px master (downscaled with averaging, upscaled linearly). Vector `.xml` drawables pass through verbatim and the corresponding PNG set is skipped, with legacy PNGs still covering pre-API-26 devices.
