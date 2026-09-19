# Windows

Generates the multi-frame `.ico` plus the MSIX tile / AppList asset set and a manifest snippet. The `.ico` filename is configurable per flavor; `Runner.rc(.in)` wiring stays manual.

## Outputs

| What | Files |
| --- | --- |
| App icon | `windows/runner/resources/<icon_filename>` (default `app_icon.ico`): frames at 16, 20, 24, 32, 40, 48, 64, 96, 128, 256 px |
| AppList targets | `windows/images/Square44x44Logo.targetsize-{16,20,24,30,32,36,40,48,60,64,72,80,96,256}.png` plus `_altform-unplated` and `_altform-lightunplated` variants |
| Square tiles | `Square44x44Logo.png` (44 px manifest target), `Square44x44Logo.scale-{100,125,150,200,400}.png`, `Square150x150Logo.scale-{100,125,150,200,400}.png` (pixel sizes follow `round(base * scale / 100)`) |
| Wide tile | `Wide310x150Logo.scale-{100,125,150,200,400}.png` (310x150 base) |
| Manifest snippet | `windows/images/manifest-snippet.xml` — MSIX `VisualElements` fragment |

No `Runner.rc` or app-manifest patching is performed. Sources under 256 px warn about upscaling, because the 256 px ICO frame goes soft.

## Keys

| Key | Type / Default | Meaning |
| --- | --- | --- |
| `generate` | bool, `false` | Enable Windows output. |
| `image_path` | String, falls back to top-level `image_path` | Base source image (raster or SVG). |
| `icon_filename` | String, `app_icon.ico` | Output `.ico` name inside `windows/runner/resources/`. Set a per-flavor name (e.g. `app_icon_staging.ico`) so sequential flavor runs do not clobber each other, and wire it into `Runner.rc(.in)` manually. |
| `image_path_unplated` | String, derived when omitted | Bare-mark source for dark-shell taskbar and Start surfaces (`..._altform-unplated`). Falls back to `image_path` rendered at ~75% scale on transparency, with a contrast warning. |
| `image_path_light_unplated` | String, derived when omitted | Bare-mark source for light-shell surfaces (`..._altform-lightunplated`). Same ~75% padded fallback and warning. |
| `image_path_wide` | String, derived when omitted | Wide-tile source for the `Wide310x150Logo` scale set. Falls back to `image_path` with a center cover-crop and a warning. |
