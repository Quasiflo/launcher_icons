import 'package:launcher_icons/src/version.dart';

//* Android
/// Default Android icon resource name
const String androidDefaultIconName = 'ic_launcher';

/// Default Android notification icon resource name
const String androidDefaultNotificationIconName = 'ic_notification';

/// Notification (status-bar) small-icon size in dp, scaled per density (24/36/48/72/96 px).
const int androidNotificationIconDp = 24;

//* iOS
/// Default iOS icon file name prefix
const String iosDefaultIconName = 'Icon-App';

//* Web
/// favicon.png default size if unspecified
const int faviconDefaultSize = 32;

/// Standard PWA icon sizes (the `any` purpose set).
const List<int> webPwaIconSizes = [192, 512];

/// Consensus multi-frame favicon container.
const List<int> webFaviconIcoSizes = [16, 32, 48];

/// PWA shortcut icon size.
const int webShortcutIconSize = 96;

/// Open Graph link-preview width (1200x630, 1.91:1).
const int webOpengraphWidth = 1200;

/// Open Graph link-preview height (1200x630, 1.91:1).
const int webOpengraphHeight = 630;

/// Twitter/X link-preview width.
const int webTwitterWidth = 1200;

/// Twitter/X link-preview height.
const int webTwitterHeight = 600;

//* Windows
/// Standard ICO frame sizes: Win32 full set (app icons + Classic Mode) plus 40/64 for Alt+Tab crispness and 256 for Explorer thumbnails.
const List<int> windowsIcoSizes = [16, 20, 24, 32, 40, 48, 64, 96, 128, 256];

/// App-list target sizes from the MSIX app-icon construction table. Target-size assets use exact pixel dimensions rather than scale factors.
const List<int> windowsAppListTargetSizes = [16, 20, 24, 30, 32, 36, 40, 48, 60, 64, 72, 80, 96, 256];

/// Share of the canvas the bare mark fills in unplated AppList assets (VS-generator parity: inner graphic ~70-75% with centered transparent padding).
const double windowsUnplatedArtworkScale = 0.75;

/// Base file name all AppList target-size variants qualify off. The MSIX manifest points at this file and Windows resolves the qualified variants at runtime.
const String windowsAppListBaseName = 'Square44x44Logo.png';

/// Tile scale factors (VS-generator parity). Pixel sizes follow `round(base * scale / 100)`, matching the MSIX app-icon construction table.
const List<int> windowsTileScales = [100, 125, 150, 200, 400];

/// Base size for the small square tile entry.
const int windowsSquare44Base = 44;

/// Base size for the medium square tile entry.
const int windowsSquare150Base = 150;

/// Base width for the wide tile entry.
const int windowsWide310Width = 310;

/// Base height for the wide tile entry.
const int windowsWide150Height = 150;

//* Linux
/// hicolor theme sizes (conventional full set).
const List<int> linuxHicolorSizes = [16, 22, 24, 32, 48, 64, 128, 256, 512];

/// Edge length of the derived runtime raster for SVG sources. The runner loads the window icon from flutter_assets at runtime, where only rasters work — so SVG sources are rasterized once to a `<name>.linux.png` sibling at this size and wired instead.
const int linuxRuntimeSize = 512;

/// CLI banner with the current package version.
String introMessage() => '''
  ════════════════════════════════════════════
     LAUNCHER ICONS (v$packageVersion)
  ════════════════════════════════════════════
  ''';
