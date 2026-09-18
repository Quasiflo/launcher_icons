import 'package:launcher_icons/src/version.dart';

//* Android
/// Default Android icon resource name
const String androidDefaultIconName = 'ic_launcher';

//* iOS
/// Default iOS icon file name prefix
const String iosDefaultIconName = 'Icon-App';

//* Web
/// favicon.ico size
const int kFaviconSize = 16;

/// CLI banner with the current package version.
String introMessage() => '''
  ════════════════════════════════════════════
     LAUNCHER ICONS (v$packageVersion)
  ════════════════════════════════════════════
  ''';
