# Linux

Installs the runtime window icon, patches the GTK runner to load it from an executable-relative path, and creates the freedesktop packaging files — strictly only-if-absent, never overwriting your own.

Requires `linux/` and `linux/runner/my_application.cc` to exist. The icon must also be declared under `flutter: assets:` in `pubspec.yaml` (any asset path, not just `assets/`) so it ships inside the bundle — the runner resolves it at runtime, so generation fails without this. Raster sources are used as-is; SVG sources are rasterized once to a `<name>.linux.png` sibling at 512 px (always rewritten) and that file must be the listed asset.

Wayland has no window-icon concept, so there the `.desktop` entry carries the icon instead.

## Outputs and Patches

| What | Files |
| --- | --- |
| Window icon | Patched `linux/runner/my_application.cc`: ensures `#include <gio/gio.h>`, a `get_flutter_asset_path()` helper, and `gtk_window_set_icon_from_file(window, linux_icon_path)` (legacy calls are upgraded, the path is updated, insertion anchors before `set_default_size`, the window declaration, or `show`; otherwise the tool throws with a manual recipe). Works under `flutter run` and in release bundles. |
| Hicolor icons | `<share>/icons/hicolor/{16,22,24,32,48,64,128,256,512}/apps/<pubspec-name>.png` |
| Desktop entry | `<share>/applications/<pubspec-name>.desktop` (`Icon=<name>`, `StartupWMClass=<APPLICATION_ID>` when known; flavor `APPLICATION_ID` honors `if(STREQUAL "<flavor>")` overrides) |
| Snap (opt-in) | `snap/gui/<pubspec-name>.png` (256 px), `snap/gui/<pubspec-name>.desktop` (`Icon=${SNAP}/meta/gui/...`), `snap/snapcraft.yaml` |
| CMake install | Ensures the canonical `# Installed by launcher_icons` two-line `install(DIRECTORY .../icons|applications)` block in `linux/CMakeLists.txt` (added once, rewritten when `share_prefix` changes) |

`<share>` is `<share_prefix>/share` (default `linux/share/...`). Every packaging file above is created only when absent.

## Keys

| Key | Type / Default | Meaning |
| --- | --- | --- |
| `generate` | bool, `false` | Enable Linux output. |
| `image_path` | String, falls back to top-level `image_path` | Runtime icon source (raster or SVG). Must be listed in `flutter: assets:`. |
| `share_prefix` | String, `linux` | Location prefix for the freedesktop `share/` tree. Set to empty (or `.`) to restore the legacy top-level `share/...` layout. |
| `generate_snap` | bool, `false` | Emit `snap/gui/` plus `snap/snapcraft.yaml`. Off by default. |
