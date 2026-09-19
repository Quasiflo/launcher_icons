# Configuration and Flavors

How config files are found, how flavor sections work, and the one inheritance rule (`image_path` fallback). Per-platform keys live in the platform pages.

## Config Sources

The main command reads YAML from up to three places, in this order:

1. `<configDir>/launcher_icons.yaml` — the `launcher_icons` section plus any `launcher_icons-<flavor>` sections in the same file.
2. `<configDir>/launcher_icons-<flavor>.yaml` files — flat listing only (no recursion). Each file must contain its matching `launcher_icons-<flavor>:` section; files without it are ignored.
3. `<projectRoot>/pubspec.yaml` — project root only, never `<configDir>`. Same section extraction; other keys (e.g. `flutter:`) are ignored.

Only keys named exactly `launcher_icons` or starting with `launcher_icons-` are kept. Anything else is skipped.

```yaml
launcher_icons:
  image_path: "assets/icon/icon.png"
  android:
    generate: true

launcher_icons-dev:
  image_path: "assets/icon/icon-dev.png"
  android:
    generate: true
```

A flavor section has the same shape as `launcher_icons:` and stands alone — it does not inherit anything from the default section except through the `image_path` fallback described below. Declaring the same flavor in two sources is an error:

```text
InvalidConfigException: Configuration found both as launcher_icons-dev in launcher_icons-dev.yaml and as a dedicated config file! Choose one!
```

No config at all is also an error (`Configuration or Flavor not found!`), as is a config with no platform set to `generate: true`.

## Image Path Fallback

Top-level `image_path` is the default source for every platform. Any platform-level `image_path` overrides it for that platform only:

```yaml
launcher_icons:
  image_path: "assets/icon/icon.png"
  android:
    generate: true
    image_path: "assets/icon/icon-android.png"
```

Resolution is `platform.image_path ?? top-level image_path`. When neither is set, or the file does not exist under the project root, generation fails with `Missing "image_path" ...`. Paths are project-relative local files. See [Source Image](../README.md#source-image) for format rules.

On top of that fallback, individual platforms add their own nested fallbacks — for example web PWA/maskable sources fall back to `web.image_path`, Windows unplated/wide sources fall back to `windows.image_path`, and iOS glass-layer dark/tinted sources fall back to the iOS dark/tinted catalog sources. Those are documented on each platform page.

## Flavors

Declare each variant as a `launcher_icons-<flavor>` section (in `launcher_icons.yaml` or `pubspec.yaml`) or as a `launcher_icons-<flavor>.yaml` file carrying that section:

```yaml
launcher_icons-prod:
  image_path: "assets/icon/icon-prod.png"
  android:
    generate: true
  ios:
    generate: true
```

```shell
dart run launcher_icons                  # every flavor, plus the default section if present
dart run launcher_icons --flavor dev     # one flavor only (bare name, no prefix)
```

The default `launcher_icons` section runs nameless (unflavored outputs). Every other entry runs under its bare flavor name, so outputs land in the flavored locations (`android/app/src/<flavor>/res`, `AppIcon-<flavor>`, per-flavor web `output_path`, per-flavor Windows `icon_filename`, and so on). Requesting an unknown flavor fails before anything runs and lists the known flavors.

`dart_test.yaml` aside: flavor runs are sequential, so per-flavor Windows ICO names and web output paths must differ or later runs clobber earlier ones. See [Android](android.md), [iOS](ios.md), [macOS](macos.md), [Web](web.md), [Windows](windows.md), and [Linux](linux.md) for the per-platform flavor behavior.

## Validation

Configs are parsed with strict checked deserialization: unknown keys and type mismatches throw instead of being ignored. At least one platform must set `generate: true`, otherwise generation fails with `No platform enabled within config ...`.
