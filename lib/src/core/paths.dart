import 'package:path/path.dart' as path;

//* General
/// Default launcher_icons config file name
const defaultConfigFileName = 'launcher_icons.yaml';

/// Pubspec.yaml path
const pubspecFilePath = 'pubspec.yaml';

//* Android
/// Relative path to the android project folder
const androidDirPath = 'android';

/// Android screen densities in ascending order with their scale factors relative to mdpi
const androidDensities = <String, double>{'mdpi': 1.0, 'hdpi': 1.5, 'xhdpi': 2.0, 'xxhdpi': 3.0, 'xxxhdpi': 4.0};

/// Default Android legacy icon file name
const androidFileName = 'ic_launcher.png';

/// Default Android adaptive foreground file name
const androidAdaptiveForegroundFileName = 'ic_launcher_foreground.png';

/// Default Android adaptive background file name
const androidAdaptiveBackgroundFileName = 'ic_launcher_background.png';

/// Default Android adaptive monochrome file name
const androidAdaptiveMonochromeFileName = 'ic_launcher_monochrome.png';

/// Default Android adaptive round drawable file name
const androidAdaptiveRoundFileName = 'ic_launcher_round.png';

/// Default Android adaptive round icon resource name
const androidAdaptiveRoundIconName = 'ic_launcher_round';

/// Relative path to the AndroidManifest.xml file
final androidManifestFile = path.join('android', 'app', 'src', 'main', 'AndroidManifest.xml');

/// Relative path to android resource folder
String androidResFolder(final String? flavor) => path.join('android', 'app', 'src', flavor ?? 'main', 'res');

/// Relative path to android colors.xml file
String androidColorsFile(final String? flavor) => path.join('android', 'app', 'src', flavor ?? 'main', 'res', 'values', 'colors.xml');

/// Relative path to the adaptive-icon xml folder
String androidAdaptiveXmlFolder(final String? flavor) => path.join(androidResFolder(flavor), 'mipmap-anydpi-v26');

//* Apple Common
/// Xcode project directory extension
const xcodeprojExtension = '.xcodeproj';

/// Flutter Runner folder name
const runnerFolderName = 'Runner';

/// Xcode project directory name
const xcodeprojDirName = '$runnerFolderName$xcodeprojExtension';

/// Xcode project file name inside a Runner.xcodeproj directory
const pbxprojFileName = 'project.pbxproj';

/// Icon Composer bundle assets folder name
const iconAssetsFolderName = 'Assets';

/// Asset-catalog icon set folder extension
const appIconSetExtension = '.appiconset';

/// Asset-catalog contents file name
const contentsJsonFileName = 'Contents.json';

/// Icon Composer document file name
const iconJsonFileName = 'icon.json';

/// Default app icon catalog name, flavor-aware (`AppIcon-<flavor>` for flavor runs)
String appIconCatalogName(final String? flavor) => flavor == null ? 'AppIcon' : 'AppIcon-$flavor';

/// Dark-appearance icon name suffix
const appIconDarkSuffix = '-Dark';

/// Tinted-appearance icon name suffix
const appIconTintedSuffix = '-Tinted';

//* iOS
/// Relative path to the iOS project folder
const iosDirPath = 'ios';

/// Relative path to the iOS Runner folder
final iosRunnerFolder = path.join(iosDirPath, runnerFolderName);

/// Relative path to the iOS asset catalog folder
final iosAssetFolder = path.join(iosRunnerFolder, 'Assets.xcassets');

/// Relative path to the default iOS icon set folder
final iosDefaultIconFolder = path.join(iosAssetFolder, '${appIconCatalogName(null)}$appIconSetExtension');

/// Relative path to the iOS Xcode project file
final iosConfigFile = path.join(iosDirPath, xcodeprojDirName, pbxprojFileName);

/// Relative path to a liquid glass `.icon` bundle
String iosLiquidGlassIconPath(final String iconName) => path.join(iosRunnerFolder, '$iconName.icon');

/// Relative path to a liquid glass `.icon` assets folder
String iosLiquidGlassAssetsPath(final String iconName) => path.join(iosLiquidGlassIconPath(iconName), iconAssetsFolderName);

/// Relative path to a liquid glass `.icon` config file
String iosLiquidGlassConfigPath(final String iconName) => path.join(iosLiquidGlassIconPath(iconName), iconJsonFileName);

//* MacOS
/// Relative path to the macOS project folder
const macOSDirPath = 'macos';

/// Relative path to the macOS Runner folder
final String macOSRunnerFolder = path.join(macOSDirPath, runnerFolderName);

/// Relative path to the macOS Runner.xcodeproj directory
final macOSXcodeprojPath = path.join(macOSDirPath, xcodeprojDirName);

/// Relative path to the macOS Xcode project file
final macOSConfigFile = path.join(macOSXcodeprojPath, pbxprojFileName);

/// Relative path to the macos asset catalog: flavor runs create `AppIcon-<flavor>.appiconset` inside it, so validation only requires the catalog itself (never a pre-existing flavor set).
final macOSAssetsDirPath = path.join(macOSRunnerFolder, 'Assets.xcassets');

/// Relative path to macos icons folder
final macOSIconsDirPath = path.join(macOSAssetsDirPath, '${appIconCatalogName(null)}$appIconSetExtension');

/// Relative path to macos contents.json
final macOSContentsFilePath = path.join(macOSIconsDirPath, 'Contents.json');

/// Relative path to a macOS liquid glass `.icon` bundle
String macOSLiquidGlassIconPath(final String iconName) => path.join(macOSRunnerFolder, '$iconName.icon');

/// Relative path to a macOS liquid glass `.icon` assets folder
String macOSLiquidGlassAssetsPath(final String iconName) => path.join(macOSLiquidGlassIconPath(iconName), iconAssetsFolderName);

/// Relative path to a macOS liquid glass `.icon` config file
String macOSLiquidGlassConfigPath(final String iconName) => path.join(macOSLiquidGlassIconPath(iconName), iconJsonFileName);

//* Windows
/// Relative path to windows directory
const windowsDirPath = 'windows';

/// Relative path to windows resources directory
String windowsResourcesDirPath = path.join(windowsDirPath, 'runner', 'resources');

/// Default Windows icon file name (the Runner.rc contract)
const windowsDefaultIconFilename = 'app_icon.ico';

/// Relative Windows MSIX image assets directory (mirrors the manifest `Images\` convention so the emitted snippet references resolve).
String windowsImagesDirPath = path.join(windowsDirPath, 'images');

/// Manifest snippet file name written next to the MSIX image assets for hand packaging.
const windowsManifestSnippetFileName = 'manifest-snippet.xml';

//* Linux
/// Relative path to linux directory
const linuxDirPath = 'linux';

/// Relative path to linux my_application.cc file
String linuxMyApplicationFile = path.join(linuxDirPath, 'runner', 'my_application.cc');

/// Relative path to linux top-level CMakeLists.txt file
final linuxTopCMakeListsFile = path.join(linuxDirPath, 'CMakeLists.txt');

/// Suffix for the runtime raster derived from SVG sources
const linuxDerivedIconSuffix = '.linux.png';

/// Joins [sharePrefix] with the freedesktop `share/` tree. An empty or `.` prefix restores the legacy top-level `share/...` layout; the default `linux` prefix yields `linux/share/...`.
String _withSharePrefix(final String sharePrefix, final List<String> tail) {
  final normalized = sharePrefix.trim();
  if (normalized.isEmpty || normalized == '.' || normalized == './') {
    return path.join('share', path.joinAll(tail));
  }
  return path.join(normalized, 'share', path.joinAll(tail));
}

/// Project-relative root of the freedesktop `share/` tree for [sharePrefix].
String linuxShareRoot([final String sharePrefix = 'linux']) => _withSharePrefix(sharePrefix, []);

/// Relative hicolor icon path for [appName] at [size]px under [sharePrefix]
String linuxHicolorIconPath(final String appName, final int size, [final String sharePrefix = 'linux']) => _withSharePrefix(sharePrefix, ['icons', 'hicolor', '${size}x$size', 'apps', '$appName.png']);

/// Relative snap icon path for [appName]
String linuxSnapIconPath(final String appName) => path.join('snap', 'gui', '$appName.png');

/// Relative freedesktop desktop entry path for [appName] under [sharePrefix]
String linuxDesktopFilePath(final String appName, [final String sharePrefix = 'linux']) => _withSharePrefix(sharePrefix, ['applications', '$appName.desktop']);

/// Relative snap desktop entry path for [appName]
String linuxSnapDesktopFilePath(final String appName) => path.join('snap', 'gui', '$appName.desktop');

/// Relative snapcraft.yaml path
final linuxSnapcraftFilePath = path.join('snap', 'snapcraft.yaml');

//* Web
/// Default web directory path
const webDirPath = 'web';

/// Relative web icons directory path under [root]
String webIconsDirPath([final String root = webDirPath]) => path.join(root, 'icons');

/// Relative web manifest.json file path under [root]
String webManifestFilePath([final String root = webDirPath]) => path.join(root, 'manifest.json');

/// Relative favicon.png path under [root]
String webFaviconFilePath([final String root = webDirPath]) => path.join(root, 'favicon.png');

/// Relative favicon.ico path (browsers request /favicon.ico by default) under [root]
String webFaviconIcoFilePath([final String root = webDirPath]) => path.join(root, 'favicon.ico');

/// Relative favicon.svg path (verbatim copy-through) under [root]
String webFaviconSvgFilePath([final String root = webDirPath]) => path.join(root, 'favicon.svg');

/// Relative Open Graph link-preview image path under [root]
String webOpengraphFilePath([final String root = webDirPath]) => path.join(root, 'opengraph.png');

/// Relative Twitter/X link-preview image path under [root]
String webTwitterFilePath([final String root = webDirPath]) => path.join(root, 'twitter.png');

/// Relative index.html file path under [root]
String webIndexFilePath([final String root = webDirPath]) => path.join(root, 'index.html');

/// Apple touch icon file name
const appleTouchIconFileName = 'apple-touch-icon.png';

/// Relative apple-touch-icon.png path under [root]
String webAppleTouchIconFilePath([final String root = webDirPath]) => path.join(webIconsDirPath(root), appleTouchIconFileName);
