import 'package:launcher_icons/src/version.dart';

//* Android
/// Default Android icon resource name
const String androidDefaultIconName = 'ic_launcher';

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

/// CLI banner with the current package version.
String introMessage() => '''
  ════════════════════════════════════════════
     LAUNCHER ICONS (v$packageVersion)
  ════════════════════════════════════════════
  ''';
