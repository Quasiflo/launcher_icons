# macOS

Generates the PNG asset catalog and an optional liquid-glass `.icon` bundle (same Icon Composer format as iOS), and registers the bundle in the Xcode project.

## Outputs

Catalog root: `macos/Runner/Assets.xcassets/`.

| What | Files |
| --- | --- |
| App icons | `<Catalog>.appiconset/app_icon_<px>.png` plus `Contents.json` (`idiom:mac`). Sizes 16, 32, 32, 64, 128, 256, 256, 512, 512, 1024 px (10 catalog entries, 7 renders). |
| Liquid glass | `macos/Runner/<Catalog>.icon/` plus a `project.pbxproj` file reference. Tahoe 26+ renders the `.icon`; the PNG catalog stays the fallback on older macOS. |

Catalog resolves as: default `AppIcon`; flavor runs `AppIcon-<flavor>`; non-flavor custom `icon_name` writes its own set. `Contents.json` keeps its non-`images` keys; invalid JSON or foreign entries (e.g. `8x8`, `1024` without mac idiom, non-mac idioms) trigger a warning and refresh.

After generating a `.icon` bundle, add `<name>.icon` to the Xcode project (the file reference is registered automatically) and set the target App Icon to it; the PNG set keeps working untouched. Flavors write `AppIcon-<flavor>.appiconset`; select it in Xcode like iOS.

## Keys

| Key | Type / Default | Meaning |
| --- | --- | --- |
| `generate` | bool, `false` | Enable macOS output. |
| `image_path` | String, falls back to top-level `image_path` | Base source image. |
| `icon_name` | String, unset | Writes its own `<name>.appiconset` (and matching `<name>.icon`) instead of the default set. Ignored on flavor runs (forced `AppIcon-<flavor>`). |
| `xcodeproj_path` | String, default `macos/Runner.xcodeproj` | Set when the Xcode project was renamed. |
| `icon_only` | bool, `false` | Skip the PNG catalog and emit only the `.icon` bundle. Requires `liquid_glass_layers` or `liquid_glass_groups`. |
| `padding` | int, `0` | Safe-area margin as a percent of the icon size, applied on every side. Artwork is scaled into the remaining inner area and centered on a transparent canvas. PNG catalog only. |
| `rounded_corners` | bool, `false` | Masks the canvas with an Apple-like squircle (22.5% superellipse). macOS does not shape artwork itself, so leave this off for square art. PNG catalog only. |
| `background_color` | String, `#ffffff` | Hex `#RRGGBB`. Canvas fill behind the glass in the bundle (or gradient pair when set). Transparency is otherwise preserved, never filled — prefer opaque art. |
| `liquid_glass_gradient_from` / `liquid_glass_gradient_to` | String, unset (paired) | Two-stop top-to-bottom canvas gradient (hex `#RRGGBB` each). Both or neither. |
| `remove_liquid_glass` | bool, `false` | Emits the `.icon` layers flat, without glass effects. The bundle is still emitted. |
| `liquid_glass_translucency` | double, `0.5` | `0.0` (opaque) to `1.0` (clear). |
| `liquid_glass_specular` | bool, `true` | Specular highlights on the glass. |
| `liquid_glass_shadow_kind` | String, `Neutral` | `Neutral` or `Chromatic`. |
| `liquid_glass_shadow_opacity` | double, `0.5` | Drop-shadow strength. |
| `liquid_glass_blur` | double, `0.5` | Background blur radius behind the glass. |
| `liquid_glass_lighting` | String, unset | `individual` or `combined`. Omitted when unset; only observable with 2+ layers. |
| `liquid_glass_refractivity_enabled` | bool, unset | Turns on glass distortion. Requires both depth and strength. |
| `liquid_glass_refractivity_depth` / `liquid_glass_refractivity_strength` | double, unset | Depth and strength of the refraction effect. |
| `liquid_glass_specular_highlight_placement` | String, unset | `inside` or `outside`. Omitted when unset. |
| `liquid_glass_layers` | list, unset | Artwork layers bottom-to-top. The bundle is emitted when non-empty. Unlike iOS, per-layer dark/tinted sources have no catalog fallbacks — each must be set explicitly. |
| `liquid_glass_groups` | list, unset | Explicit groups bottom-to-top. Replaces `liquid_glass_layers` when set; setting both is an error. |

Layer and group schemas match [iOS](ios.md#layers-and-groups): `image_path` (required), `image_path_dark` / `image_path_tinted` (explicit only on macOS), `scale` (`1.0`), `offset_x` / `offset_y` (`0.0`), `glass` (`true`), `opacity`, `blend_mode`, `fill` / `fill_dark` / `fill_tinted`, plus per-group overrides falling back to the platform values.
