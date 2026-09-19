# iOS

Generates the PNG asset catalog, optional dark/tinted appearances, and an optional liquid-glass `.icon` bundle (Apple Icon Composer format), and wires flavors through the Xcode project.

## Outputs

Catalog root: `ios/Runner/Assets.xcassets/`.

| What | Files |
| --- | --- |
| App icons | `<Catalog>.appiconset/<Icon>-<size>@<scale>.png` plus `Contents.json` (20 files, 20–1024 px, including the 1024px marketing icon) |
| Dark appearance | `<Catalog>-Dark.appiconset` (flavor), `<custom>-Dark` (custom `icon_name`), `Icon-App-Dark` (default), with appearance luminosity entries |
| Tinted appearance | Same layout with `-Tinted` suffix |
| Liquid glass | `ios/Runner/<Catalog>.icon/{Assets/<basenames>,icon.json}` plus `project.pbxproj` file references |

Catalog and icon names resolve as: default `AppIcon` / `Icon-App`; flavor runs `AppIcon-<flavor>` (off-flavor `icon_name` is ignored with a warning); non-flavor custom `icon_name` writes its own `<name>.appiconset`. The PNG catalog stays the fallback on older systems when a `.icon` bundle is also emitted.

After generating, point Xcode at the set: `Build Settings` > `Asset Catalog App Icon Set Name` (`AppIcon`, or `AppIcon-<flavor>`).

## Flavor Wiring

`xcodeproj_path` defaults to `ios/Runner.xcodeproj`, falling back to the first `ios/*.xcodeproj` when unset.

| `flavor_mode` | Behavior |
| --- | --- |
| `pbxproj` (default) | Rewrites `ASSETCATALOG_COMPILER_APPICON_NAME` per build configuration in `project.pbxproj`. Warns when a flavor was emitted but no matching entry was found. |
| `xcconfig` | Removes those `pbxproj` lines for the flavor configurations (they would shadow the xcconfig) and writes `ios/Flutter/<flavor>-{Debug,Profile,Release}.xcconfig` overrides seeded with `#include "Generated.xcconfig"`. Assign them as the base configuration files in Xcode once. |

Orphan `AppIcon-*` sets are swept when they are no longer referenced by the pbxproj or xcconfigs (the current flavor set and plain `AppIcon` are kept). Dropping or renaming layers removes the stale `.icon` bundle and its reference.

## Keys

| Key | Type / Default | Meaning |
| --- | --- | --- |
| `generate` | bool, `false` | Enable iOS output. |
| `single_size` | bool, `false` | Emit only the single 1024px icon. Dark/tinted variants are ignored. Has no effect in `icon_only` mode. |
| `image_path` | String, falls back to top-level `image_path` | Base source image. |
| `icon_name` | String, unset | Writes its own `<name>.appiconset` instead of overwriting the default set. Ignored on flavor runs (forced `AppIcon-<flavor>`). |
| `xcodeproj_path` | String, default `ios/Runner.xcodeproj` | Set when the Xcode project was renamed. |
| `flavor_mode` | String, `pbxproj` | `pbxproj` or `xcconfig` (see above). |
| `icon_only` | bool, `false` | Skip the PNG catalog and emit only the `.icon` bundle. Requires `liquid_glass_layers` or `liquid_glass_groups`, and the target App Icon must be set to the `.icon` in Xcode. |
| `image_path_dark_transparent` | String, unset | iOS 18+ dark-mode source: full art on transparency, because the system background shows through. Also feeds glass-layer `image_path_dark` fallbacks. |
| `image_path_tinted_grayscale` | String, unset | iOS 18+ tinted-mode source: must read as a single-color grayscale silhouette (warns otherwise, checked on an 8x8 grid). Also feeds glass-layer `image_path_tinted` fallbacks. |
| `desaturate_tinted_to_grayscale` | bool, `false` | Converts the tinted source to grayscale automatically instead of hand-converting. |
| `remove_alpha` | bool, `false` | Flattens transparency of the base and tinted images onto `background_color`. The dark variant intentionally keeps its transparency. Without it, transparent art triggers an App Store alpha warning. |
| `background_color` | String, `#ffffff` | Hex `#RRGGBB`. Matte color for `remove_alpha` and solid fill for the `.icon` canvas (unless a gradient pair is set). |
| `liquid_glass_gradient_from` / `liquid_glass_gradient_to` | String, unset (paired) | Two-stop top-to-bottom canvas gradient (hex `#RRGGBB` each). Both or neither; verified two-stop linear fill. |
| `remove_liquid_glass` | bool, `false` | Emits the `.icon` layers flat, without glass effects. The bundle is still emitted. |
| `liquid_glass_translucency` | double, `0.5` | How see-through the glass reads, `0.0` (opaque) to `1.0` (clear). |
| `liquid_glass_specular` | bool, `true` | Specular highlights on the glass. |
| `liquid_glass_shadow_kind` | String, `Neutral` | `Neutral`, `Chromatic`, or `None`. |
| `liquid_glass_shadow_opacity` | double, `0.5` | Drop-shadow strength. |
| `liquid_glass_blur` | double, `0.5` | Background blur radius behind the glass. |
| `liquid_glass_lighting` | String, unset | `individual` (light each layer separately) or `combined` (treat the group as one shape). Omitted from `icon.json` when unset; only observable with 2+ layers. |
| `liquid_glass_refractivity_enabled` | bool, unset | Turns on glass distortion. Requires both depth and strength. |
| `liquid_glass_refractivity_depth` / `liquid_glass_refractivity_strength` | double, unset | Depth and strength of the refraction effect. Only used when refractivity is enabled. |
| `liquid_glass_specular_highlight_placement` | String, unset | `inside` or `outside`. Omitted when unset. |
| `liquid_glass_layers` | list, unset | Artwork layers, one entry per layer bottom-to-top. The bundle is emitted when non-empty. See [Layers and Groups](#layers-and-groups). |
| `liquid_glass_groups` | list, unset | Explicit groups bottom-to-top. Replaces `liquid_glass_layers` when set; setting both is an error. See [Layers and Groups](#layers-and-groups). |

## Layers and Groups

One list entry per artwork layer, bottom-to-top. Sources pass through verbatim into the bundle `Assets/` folder (fully tool-owned; orphans are swept), so SVGs work here even though the PNG catalog always rasterizes.

Each layer supports:

| Key | Type / Default | Meaning |
| --- | --- | --- |
| `image_path` | String, required | Artwork source for the layer. |
| `image_path_dark` / `image_path_tinted` | String, unset | Dark/tinted overrides. Fall back to `image_path_dark_transparent` / `image_path_tinted_grayscale` when unset. |
| `scale` | double, `1.0` | Artwork scale within the canvas. |
| `offset_x` / `offset_y` | double, `0.0` | Layer offset in points. |
| `glass` | bool, `true` | Layer participates in the glass effect. Group `remove_liquid_glass` forces it off. |
| `opacity` | double, unset (opaque) | `0.0` to `1.0`. |
| `blend_mode` | String, unset (normal) | `normal`, `plus-lighter`, `plus-darker`, `overlay`, `multiply`, `soft-light`, `hard-light`, `darken`, `lighten`, `screen`. |
| `fill` | String, unset | Recolor tint (hex `#RRGGBB`). Artwork colors pass through when unset. |
| `fill_dark` / `fill_tinted` | String, fall back to `fill` | Dark/tinted recolor tints. |

`liquid_glass_groups` is the multi-group form: each group has a cosmetic `name`, a required non-empty `layers` list (same layer schema), and per-group overrides for `translucency`, `specular`, `shadow_kind`, `shadow_opacity`, `blur`, `lighting`, `refractivity_enabled`/`_depth`/`_strength`, `specular_highlight_placement`, and `remove_liquid_glass`. Each override falls back to the platform-level value, so a group carrying only `layers` renders exactly like the legacy single-group flow.
