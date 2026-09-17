import 'package:path/path.dart' as path;

/// Relative path to android resource folder
String androidResFolder(String? flavor) => "android/app/src/${flavor ?? 'main'}/res/";

/// Relative path to android colors.xml file
String androidColorsFile(String? flavor) => "android/app/src/${flavor ?? 'main'}/res/values/colors.xml";

/// Relative path to the AndroidManifest.xml file
const String androidManifestFile = 'android/app/src/main/AndroidManifest.xml';

/// Relative path to the adaptive-icon xml folder
String androidAdaptiveXmlFolder(String? flavor) => androidResFolder(flavor) + 'mipmap-anydpi-v26/';

/// Relative path to the default iOS icon set folder
const String iosDefaultIconFolder = 'ios/Runner/Assets.xcassets/AppIcon.appiconset/';

/// Relative path to the iOS asset catalog folder
const String iosAssetFolder = 'ios/Runner/Assets.xcassets/';

/// Relative path to the iOS Xcode project file
const String iosConfigFile = 'ios/Runner.xcodeproj/project.pbxproj';

// iOS Liquid Glass .icon constants

/// Relative path to the iOS Runner folder
const String iosRunnerFolder = 'ios/Runner/';

/// Relative path to a liquid glass `.icon` bundle
String iosLiquidGlassIconPath(String iconName) => '$iosRunnerFolder$iconName.icon/';

/// Relative path to a liquid glass `.icon` assets folder
String iosLiquidGlassAssetsPath(String iconName) => '${iosLiquidGlassIconPath(iconName)}Assets/';

/// Relative path to a liquid glass `.icon` config file
String iosLiquidGlassConfigPath(String iconName) => '${iosLiquidGlassIconPath(iconName)}icon.json';

// macOS Liquid Glass .icon constants

/// Relative path to the macOS Runner folder
const String macOSRunnerFolder = 'macos/Runner/';

/// Relative path to a macOS liquid glass `.icon` bundle
String macOSLiquidGlassIconPath(String iconName) => '$macOSRunnerFolder$iconName.icon/';

/// Relative path to a macOS liquid glass `.icon` assets folder
String macOSLiquidGlassAssetsPath(String iconName) => '${macOSLiquidGlassIconPath(iconName)}Assets/';

/// Relative path to a macOS liquid glass `.icon` config file
String macOSLiquidGlassConfigPath(String iconName) => '${macOSLiquidGlassIconPath(iconName)}icon.json';

// web

/// Relative web directory path
String webDirPath = path.join('web');

/// Relative web icons directory path
String webIconsDirPath = path.join(webDirPath, 'icons');

/// Relative web manifest.json file path
String webManifestFilePath = path.join(webDirPath, 'manifest.json');

/// Relative favicon.png path
String webFaviconFilePath = path.join(webDirPath, 'favicon.png');

/// Relative favicon.ico path (browsers request /favicon.ico by default)
String webFaviconIcoFilePath = path.join(webDirPath, 'favicon.ico');

/// Relative index.html file path
String webIndexFilePath = path.join(webDirPath, 'index.html');

/// Relative pubspec.yaml path
String pubspecFilePath = path.join('pubspec.yaml');

// Windows

/// Relative path to windows directory
String windowsDirPath = path.join('windows');

/// Relative path to windows resources directory
String windowsResourcesDirPath = path.join(windowsDirPath, 'runner', 'resources');

/// Relative path to windows icon file path
String windowsIconFilePath = path.join(windowsResourcesDirPath, 'app_icon.ico');

// MacOS

/// Relative path to macos folder
final macOSDirPath = path.join('macos');

/// Relative path to macos icons folder
final macOSIconsDirPath = path.join(macOSDirPath, 'Runner', 'Assets.xcassets', 'AppIcon.appiconset');

/// Relative path to the macos asset catalog: flavor runs create
/// `AppIcon-<flavor>.appiconset` inside it, so validation only requires the
/// catalog itself (never a pre-existing flavor set).
final macOSAssetsDirPath = path.join(macOSDirPath, 'Runner', 'Assets.xcassets');

/// Relative path to macos contents.json
final macOSContentsFilePath = path.join(macOSIconsDirPath, 'Contents.json');

// Linux

/// Relative path to linux directory
String linuxDirPath = path.join('linux');

/// Relative path to linux my_application.cc file
String linuxMyApplicationFile = path.join(linuxDirPath, 'runner', 'my_application.cc');
