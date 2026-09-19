# Web

Generates favicons, PWA icons (standard, maskable, monochrome), the Apple touch icon, opt-in social preview images, and opt-in PWA shortcut icons. Patches `manifest.json` and manages one `<!--LI-->...<!--LIEND-->` block in `index.html`.

Requires the web root, `manifest.json`, and `index.html` to already exist. All optional image sources must exist when set, and `background_color` / `theme_color_*` values must be CSS hex colors.

## Outputs

All paths are under `<output_path>` (default `web`).

| Icon | Files | Purpose |
| --- | --- | --- |
| Classic favicon | `favicon.ico` (16, 32, 48 px frames) unless `favicon_ico: false` | Browser tabs, bookmarks, history. Browsers still request `/favicon.ico` from the root even with explicit `<link>` tags. |
| Modern favicon | `favicon.png` (`favicon_size`, default 32) | Sharp tab icon on high-DPI screens, with `sizes` link. |
| SVG favicon | `favicon.svg`, only when `image_path_favicon_svg` is set | Verbatim copy, never rasterized, linked with `type="image/svg+xml"`. |
| PWA icons | `icons/Icon-192.png`, `icons/Icon-512.png` | Installed PWA icon (Android, ChromeOS, desktop Chrome/Edge). Minimum practical set; PNG is safest. |
| Maskable icons | `icons/Icon-maskable-192.png`, `icons/Icon-maskable-512.png` | Adaptive icon Android can crop to circle/squircle: 512 px source, logo inside the ~80% safe zone, `"purpose": "maskable"`. Preview the safe area with [maskable.app](https://maskable.app/). |
| Monochrome icons | `icons/Icon-monochrome-192.png`, `icons/Icon-monochrome-512.png`, only when `image_path_monochrome` is set | Single-color themed PWA icon (`"purpose": "monochrome"`). |
| Maskable monochrome | `icons/Icon-maskable-monochrome-192.png`, `icons/Icon-maskable-monochrome-512.png`, only when monochrome is set | Both maskable and monochrome, for best themed results. |
| Apple touch icon | `icons/apple-touch-icon.png` (180 px, opaque) | iOS/iPadOS Add to Home Screen icon. Transparency is flattened onto `background_color`. |
| Shortcut icons | `icons/shortcut-<i>-96.png` | Each PWA `shortcuts[]` entry icon (typically 96 px). |
| Open Graph | `opengraph.png` (1200x630), only when `image_path_opengraph` is set | Link previews (Facebook, LinkedIn, Slack, Discord, iMessage, WhatsApp). Wired as `og:image`. |
| Twitter/X card | `twitter.png` (1200x600), only when `image_path_twitter` is set | Link previews on X. Wired as `twitter:image` (falls back to `og:image` when absent). |

`manifest.json` is preserved in place: `background_color` is set, legacy `theme_color` is dropped, `icons[]` is replaced (`src`, `sizes`, `type`, `purpose`), and `shortcuts[]` is replaced or dropped. `index.html` gains one idempotent `<!--LI-->...<!--LIEND-->` block before `</head>` carrying the favicon/PNG/SVG links, apple-touch link, manifest link, `background-color` style, light/dark `theme-color` metas, and social meta tags.

## Keys

| Key | Type / Default | Meaning |
| --- | --- | --- |
| `generate` | bool, `false` | Enable web output. |
| `image_path` | String, unset | Base source (PNG, JPG, WebP, or SVG) for favicon, PWA, maskable derivation, apple-touch, and social images. No top-level fallback documented beyond this — set it per web section or per override. |
| `image_path_pwa` | String, falls back to `image_path` | Override source for the standard PWA icons (`Icon-192/512.png`). |
| `image_path_maskable` | String, derived when omitted | Dedicated maskable source (opaque, full-bleed, safe-zone aware). When omitted, derived from the base image: logo scaled to ~80% and centered on the opaque `background_color` (white fallback, warns when the base is transparent). |
| `image_path_monochrome` | String, unset | Single-color source for themed icons. Nothing monochrome is emitted unless this is set. |
| `image_path_monochrome_maskable` | String, derived when omitted | Monochrome safe-zone-aware source. Derived from the monochrome source with the same ~80% padded canvas when omitted. |
| `image_path_favicon_svg` | String, unset | Copied verbatim to `favicon.svg` and linked from `index.html`; never rasterized. The PNG/ICO favicon always renders from `image_path`. |
| `image_path_opengraph` | String, unset | Rendered at 1200x630 to `opengraph.png` with an `og:image` meta tag. Only generated when set. |
| `image_path_twitter` | String, unset | Rendered at 1200x600 to `twitter.png` with a `twitter:image` meta tag. Only generated when set. |
| `shortcut_icons` | list, unset | PWA press-and-hold shortcuts. Each entry renders at 96 px into `icons/` and is wired into manifest `shortcuts[]`. Each entry: `image_path` (required, PNG or SVG), `name`, `short_name`, `url` (route opened), `description`. |
| `output_path` | String, `web` | Web root directory. Set per flavor (e.g. `web-flavors/staging`) to keep outputs apart — serve that directory when building. |
| `favicon_size` | int, `32` | PNG favicon size in pixels. The `.ico` always holds 16+32+48. |
| `favicon_ico` | bool, `true` | Emit multi-frame `favicon.ico` alongside `favicon.png`. Set `false` to ship the PNG only. |
| `background_color` | String, unset | Hex color. Written to `manifest.json`, used as the maskable-derivation canvas, flattens the opaque apple-touch icon, and is written as `html, body { background-color }`. |
| `theme_color_light` | String, unset | Hex color for the light-scheme `<meta name="theme-color" media="(prefers-color-scheme: light)">`. When only one of light/dark is set, it is emitted without a media query. |
| `theme_color_dark` | String, unset | Hex color for the dark-scheme meta. Same single-side rule as above. |

Social images use a center cover-crop (max-scale then center-crop) to reach exactly 1200x630 / 1200x600.
