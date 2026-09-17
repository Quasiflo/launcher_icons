import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' hide decodeImageFile;
import 'package:launcher_icons/src/config/config.dart';
import 'package:launcher_icons/src/core/constants.dart';
import 'package:launcher_icons/src/core/custom_exceptions.dart';
import 'package:launcher_icons/src/core/errors.dart' as errors;
import 'package:launcher_icons/src/core/logger.dart';
import 'package:launcher_icons/src/core/paths.dart' as paths;
import 'package:launcher_icons/src/core/utils.dart';
import 'package:launcher_icons/src/platforms/ios/liquid_glass_icon_generator.dart';
import 'package:path/path.dart' as path;

/// File to handle the creation of icons for iOS platform
class IosIconTemplate {
  /// constructs an instance of [IosIconTemplate]
  IosIconTemplate({required this.size, required this.name});

  /// suffix of the icon name
  final String name;

  /// the size of the icon
  final int size;
}

/// details of the ios icons which need to be generated
///
/// Covers the modern (Xcode 14+) universal set, including the 1x switcher sizes. The legacy iphone/ipad list was removed in v3 (fluttercommunity/flutter_launcher_icons#528): it emitted obsolete sizes (57x57, 50x50, 72x72) that Xcode no longer references.
List<IosIconTemplate> iosIcons = <IosIconTemplate>[
  IosIconTemplate(name: '-20x20@1x', size: 20),
  IosIconTemplate(name: '-20x20@2x', size: 40),
  IosIconTemplate(name: '-20x20@3x', size: 60),
  IosIconTemplate(name: '-29x29@1x', size: 29),
  IosIconTemplate(name: '-29x29@2x', size: 58),
  IosIconTemplate(name: '-29x29@3x', size: 87),
  IosIconTemplate(name: '-38x38@2x', size: 76),
  IosIconTemplate(name: '-38x38@3x', size: 114),
  IosIconTemplate(name: '-40x40@1x', size: 40),
  IosIconTemplate(name: '-40x40@2x', size: 80),
  IosIconTemplate(name: '-40x40@3x', size: 120),
  IosIconTemplate(name: '-60x60@2x', size: 120),
  IosIconTemplate(name: '-60x60@3x', size: 180),
  IosIconTemplate(name: '-64x64@2x', size: 128),
  IosIconTemplate(name: '-64x64@3x', size: 192),
  IosIconTemplate(name: '-68x68@2x', size: 136),
  IosIconTemplate(name: '-76x76@1x', size: 76),
  IosIconTemplate(name: '-76x76@2x', size: 152),
  IosIconTemplate(name: '-83.5x83.5@2x', size: 167),
  IosIconTemplate(name: '-1024x1024@1x', size: 1024),
];

/// create the ios icons
Future<void> createIcons(
  Config config,
  String? flavor, {
  LILogger? logger,
  String prefixPath = '.',
  SvgRasterCache? cache,
}) async {
  final String? filePath = config.getImagePathIOS();
  final String? darkFilePath = config.iosConfig?.imagePathDarkTransparent;
  final String? tintedFilePath = config.iosConfig?.imagePathTintedGrayscale;

  if (filePath == null) {
    throw const InvalidConfigException(errors.errorMissingImagePath);
  }

  // decodeImageFile throws on missing/undecodable files, so a specified
  // but bad path is a hard error rather than a silent skip.
  Image image = await decodeImageFile(
    withPrefix(
      prefixPath,
      filePath,
    ),
    cache: cache,
  );
  // Single-size mode generates only the 1024px marketing icon (fluttercommunity/flutter_launcher_icons#592):
  // dark/tinted variants are skipped entirely (no decode, no I/O).
  final bool singleSize = config.iosConfig?.singleSize == true;
  if (singleSize && (darkFilePath != null || tintedFilePath != null)) {
    printStatus(
      'Dark/tinted variants are ignored in single-size mode',
      logger,
    );
  }

  Image? darkImage;
  if (darkFilePath != null && !singleSize) {
    darkImage = await decodeImageFile(
      withPrefix(prefixPath, darkFilePath),
      cache: cache,
    );
  }

  Image? tintedImage;
  if (tintedFilePath != null && !singleSize) {
    tintedImage = await decodeImageFile(
      withPrefix(prefixPath, tintedFilePath),
      cache: cache,
    );
    if (config.iosConfig!.desaturateTintedToGrayscale) {
      printStatus('Desaturating iOS tinted image to grayscale', logger);
      tintedImage = grayscale(tintedImage);
    } else if (!isGrayscaleImage(tintedImage)) {
      // Apple's guidance (HIG > App icons,
      // https://developer.apple.com/design/human-interface-guidelines/app-icons):
      // the dark variant is a transparent-background design the system
      // background shows through, while the tinted variant must read as a
      // single-color silhouette — i.e. grayscale. Never validate dark
      // transparency away; warn on tinted color instead.
      printStatus(
        '\nWARNING: Tinted iOS image is not grayscale.\nSet "ios.desaturate_tinted_to_grayscale: true" to desaturate it.\n',
        logger,
      );
    }
  }

  // remove_alpha mattes the base image onto the background color. The dark variant intentionally keeps its transparency (Apple: the system background shows through), while the tinted variant is forced opaque like the base image.
  if (config.iosConfig?.removeAlpha == true) {
    if (image.hasAlpha) {
      image = _removeAlphaChannel(image, config);
    }
    if (darkImage != null && darkImage.hasAlpha) {
      printStatus(
        'Keeping transparency in the iOS dark variant '
        '(the system background shows through)',
        logger,
      );
    }
    if (tintedImage != null && tintedImage.hasAlpha) {
      tintedImage = _removeAlphaChannel(tintedImage, config);
    }
  }
  if (image.hasAlpha) {
    printStatus(
      '\nWARNING: Icons with alpha channel are not allowed in the Apple App Store.\nSet "ios.remove_alpha: true" to remove it.\n',
      logger,
    );
  }
  // Artwork loaders resize the decoded master per output size. Master
  // pixel transforms (remove_alpha matte, tinted desaturation) already ran
  // on the masters above, so every size downscales the finished art.
  // SVG sources rasterize once at 1024px through the shared cache.
  Future<Image> Function(int) sizeLoaderFor({
    required Image master,
  }) {
    return (int size) async => createResizedImage(size, master);
  }

  final loadBase = sizeLoaderFor(master: image);
  // Null exactly when the matching master is null (unset source or
  // single-size mode); call sites only run under the same guards.
  final loadDark = darkImage == null ? null : sizeLoaderFor(master: darkImage);
  final loadTinted =
      tintedImage == null ? null : sizeLoaderFor(master: tintedImage);
  final flavorMode = config.iosConfig?.flavorMode ?? 'pbxproj';
  if (flavorMode != 'pbxproj' && flavorMode != 'xcconfig') {
    throw InvalidConfigException(
      'Invalid `ios.flavor_mode` "$flavorMode": must be "pbxproj" or "xcconfig".',
    );
  }
  String iconName;
  String? darkIconName;
  String? tintedIconName;
  // Single-size mode generates only the 1024px marketing icon (fluttercommunity/flutter_launcher_icons#592).
  final List<IosIconTemplate> generateIosIcons = singleSize
      ? <IosIconTemplate>[
          IosIconTemplate(name: '-1024x1024@1x', size: 1024),
        ]
      : iosIcons;
  final String? customIconName = config.iosConfig?.iconName;
  final concurrentIconUpdates = <Future<void>>[];
  // The name of the icon catalog the generated icons are written to. The
  // liquid glass .icon bundle is created with the same name so Xcode
  // associates it with the catalog.
  String catalogName = 'AppIcon';
  if (flavor != null) {
    catalogName = 'AppIcon-$flavor';

    printStatus('Building iOS launcher icon for $flavor', logger);
    for (IosIconTemplate template in generateIosIcons) {
      concurrentIconUpdates.add(
        loadBase(template.size).then(
          (sized) => saveNewIcons(
            template: template,
            image: sized,
            catalogName: catalogName,
            // Since this is the base icon name we are using the same name for the icon as the catalog name
            iconName: catalogName,
            prefixPath: prefixPath,
          ),
        ),
      );
    }

    if (darkImage != null) {
      final String darkName = 'AppIcon-$flavor-Dark';
      darkIconName = darkName;
      printStatus('Building iOS dark launcher icon for $flavor', logger);
      for (IosIconTemplate template in generateIosIcons) {
        concurrentIconUpdates.add(
          loadDark!(template.size).then(
            (sized) => saveNewIcons(
              template: template,
              image: sized,
              catalogName: catalogName,
              iconName: darkName,
              prefixPath: prefixPath,
            ),
          ),
        );
      }
    }
    if (tintedImage != null) {
      final String tintedName = 'AppIcon-$flavor-Tinted';
      tintedIconName = tintedName;
      printStatus('Building iOS tinted launcher icon for $flavor', logger);
      for (IosIconTemplate template in generateIosIcons) {
        concurrentIconUpdates.add(
          loadTinted!(template.size).then(
            (sized) => saveNewIcons(
              template: template,
              image: sized,
              catalogName: catalogName,
              iconName: tintedName,
              prefixPath: prefixPath,
            ),
          ),
        );
      }
    }
    iconName = iosDefaultIconName;
    if (flavorMode == 'xcconfig') {
      await clearIosFlavorAppIconLines(
        flavor,
        config.iosConfig?.xcodeprojPath,
        prefixPath,
        logger,
      );
      await writeIosFlavorXcconfigs(
        flavor,
        catalogName,
        prefixPath: prefixPath,
        logger: logger,
      );
    } else {
      await changeIosLauncherIcon(
        catalogName,
        flavor,
        config.iosConfig?.xcodeprojPath,
        prefixPath,
        logger,
      );
    }
    await modifyContentsFile(
      catalogName,
      darkIconName,
      tintedIconName,
      singleSize,
      prefixPath,
    );
  } else if (customIconName != null) {
    // If a custom icon_name is configured then the user has specified a new icon to be created and for the old icon file to be kept
    final String newIconName = customIconName;
    // Like the flavor flow, a custom name gets its own catalog so the
    // folder matches APPICON_NAME (<custom>.appiconset, not AppIcon).
    catalogName = newIconName;
    printStatus('Adding new iOS launcher icon', logger);
    for (IosIconTemplate template in generateIosIcons) {
      concurrentIconUpdates.add(
        loadBase(template.size).then(
          (sized) => saveNewIcons(
            template: template,
            image: sized,
            catalogName: catalogName,
            iconName: newIconName,
            prefixPath: prefixPath,
          ),
        ),
      );
    }
    if (darkImage != null) {
      final String darkName = newIconName + '-Dark';
      darkIconName = darkName;
      printStatus('Adding new iOS dark launcher icon', logger);
      for (IosIconTemplate template in generateIosIcons) {
        concurrentIconUpdates.add(
          loadDark!(template.size).then(
            (sized) => saveNewIcons(
              template: template,
              image: sized,
              catalogName: catalogName,
              iconName: darkName,
              prefixPath: prefixPath,
            ),
          ),
        );
      }
    }
    if (tintedImage != null) {
      final String tintedName = newIconName + '-Tinted';
      tintedIconName = tintedName;
      printStatus('Adding new iOS tinted launcher icon', logger);
      for (IosIconTemplate template in generateIosIcons) {
        concurrentIconUpdates.add(
          loadTinted!(template.size).then(
            (sized) => saveNewIcons(
              template: template,
              image: sized,
              catalogName: catalogName,
              iconName: tintedName,
              prefixPath: prefixPath,
            ),
          ),
        );
      }
    }
    iconName = newIconName;
    await changeIosLauncherIcon(
      iconName,
      flavor,
      config.iosConfig?.xcodeprojPath,
      prefixPath,
      logger,
    );
    await modifyContentsFile(
      iconName,
      darkIconName,
      tintedIconName,
      singleSize,
      prefixPath,
    );
  }
  // Otherwise the user wants the new icon to use the default icons name and update config file to use it
  else {
    printStatus('Overwriting default iOS launcher icon with new icon', logger);
    for (IosIconTemplate template in generateIosIcons) {
      concurrentIconUpdates.add(
        loadBase(template.size).then(
          (sized) => overwriteDefaultIcons(template, sized, '', prefixPath),
        ),
      );
    }
    if (darkImage != null) {
      printStatus(
        'Overwriting default iOS dark launcher icon with new icon',
        logger,
      );
      for (IosIconTemplate template in generateIosIcons) {
        concurrentIconUpdates.add(
          loadDark!(template.size).then(
            (sized) =>
                overwriteDefaultIcons(template, sized, '-Dark', prefixPath),
          ),
        );
      }
      darkIconName = iosDefaultIconName + '-Dark';
    }
    if (tintedImage != null) {
      printStatus(
        'Overwriting default iOS tinted launcher icon with new icon',
        logger,
      );
      for (IosIconTemplate template in generateIosIcons) {
        concurrentIconUpdates.add(
          loadTinted!(template.size).then(
            (sized) =>
                overwriteDefaultIcons(template, sized, '-Tinted', prefixPath),
          ),
        );
      }
      tintedIconName = iosDefaultIconName + '-Tinted';
    }
    iconName = iosDefaultIconName;
    await changeIosLauncherIcon(
      'AppIcon',
      flavor,
      config.iosConfig?.xcodeprojPath,
      prefixPath,
      logger,
    );
    // Still need to modify the Contents.json file
    // since the user could have added dark and tinted icons
    await modifyDefaultContentsFile(
      iconName,
      darkIconName,
      tintedIconName,
      singleSize,
      prefixPath,
    );
  }
  await Future.wait(concurrentIconUpdates);

  // Sweep catalogs orphaned by flavor renames. Reference-checked so the
  // build cannot break; the default set is always kept.
  await removeOrphanedCatalogs(
    assetFolderRelative: paths.iosAssetFolder,
    currentCatalog: catalogName,
    referenceTexts: await iosCatalogReferenceTexts(
      config.iosConfig?.xcodeprojPath,
      prefixPath,
    ),
    prefixPath: prefixPath,
    logger: logger,
  );

  // Generate liquid glass .icon if configured
  if (config.hasLiquidGlassIconConfig) {
    await generateLiquidGlassIcon(
      config,
      catalogName,
      logger: logger,
      prefixPath: prefixPath,
    );
    // Add .icon file reference to project.pbxproj
    await addLiquidGlassIconToProject(
      catalogName,
      config.iosConfig?.xcodeprojPath,
      logger,
      prefixPath,
    );
  }
}

/// Whether [image] reads as grayscale, sampled on an 8x8 grid (64 reads
/// regardless of image size) instead of a full O(n) pixel walk.
///
/// A sample counts as colored when its channel spread exceeds 8 levels,
/// tolerating JPEG-style compression noise around true gray. Checking one pixel (or every pixel) is the wrong trade-off: a single origin sample misses off-center color, while a full scan costs millions of reads on a 1024px source to answer a boolean.
bool isGrayscaleImage(Image image, {int gridDivisions = 8}) {
  assert(gridDivisions > 0, 'gridDivisions must be positive');
  for (var row = 0; row < gridDivisions; row++) {
    final y = ((row + 0.5) * image.height / gridDivisions).floor().clamp(
          0,
          image.height - 1,
        );
    for (var col = 0; col < gridDivisions; col++) {
      final x = ((col + 0.5) * image.width / gridDivisions).floor().clamp(
            0,
            image.width - 1,
          );
      final pixel = image.getPixel(x, y);
      final r = pixel.r.toInt();
      final g = pixel.g.toInt();
      final b = pixel.b.toInt();
      final spread = [
        (r - g).abs(),
        (g - b).abs(),
        (r - b).abs(),
      ].reduce((a, c) => a > c ? a : c);
      if (spread > 8) {
        return false;
      }
    }
  }
  return true;
}

/// Overwrites the default `AppIcon` set in place, optionally suffixed for the dark/tinted variants.
Future<void> overwriteDefaultIcons(
  IosIconTemplate template,
  Image image, [
  String iconNameSuffix = '',
  String prefixPath = '.',
]) async {
  final Image newImage = createResizedImage(template.size, image);
  await File(
    withPrefix(
      prefixPath,
      paths.iosDefaultIconFolder +
          iosDefaultIconName +
          iconNameSuffix +
          template.name +
          '.png',
    ),
  ).writeAsBytes(encodePng(newImage));
}

/// Writes fresh PNGs into `<catalogName>.appiconset/` under [iconName],
/// keeping any previous set intact.
Future<void> saveNewIcons({
  required IosIconTemplate template,
  required Image image,
  required String catalogName,
  required String iconName,
  String prefixPath = '.',
}) async {
  final String newIconFolder =
      paths.iosAssetFolder + catalogName + '.appiconset/';
  final Image newImage = createResizedImage(template.size, image);
  final newFile = await createFileIfNotExist(
    withPrefix(prefixPath, newIconFolder + iconName + template.name + '.png'),
  );
  await newFile.writeAsBytes(encodePng(newImage));
}

/// Add liquid glass .icon file reference to project.pbxproj
Future<void> addLiquidGlassIconToProject(
  String iconName, [
  String? xcodeprojPath,
  LILogger? logger,
  String prefixPath = '.',
]) async {
  final resolvedPath = resolveIosPbxprojPath(xcodeprojPath, prefixPath) ??
      withPrefix(prefixPath, paths.iosConfigFile);
  final File iOSConfigFile = File(resolvedPath);
  if (!iOSConfigFile.existsSync()) {
    printStatus(
      'Warning: project.pbxproj not found, skipping .icon reference addition',
      logger,
    );
    return;
  }
  final String wholeFile = await iOSConfigFile.readAsString();
  final String changedFile = addLiquidGlassIconReference(wholeFile, iconName);
  if (changedFile == wholeFile) {
    printStatus(
      'Liquid glass .icon reference already exists in project.pbxproj',
      logger,
    );
    return;
  }
  await iOSConfigFile.writeAsString(changedFile);
  printStatus(
    'Added liquid glass .icon reference to project.pbxproj',
    logger,
  );
}

/// Adds the liquid glass `.icon` file references for [iconName] to the given
/// [pbxprojContent] and returns the modified content. If the reference already
/// exists, the original content is returned unchanged.
String addLiquidGlassIconReference(String pbxprojContent, String iconName) {
  final List<String> lines = const LineSplitter().convert(pbxprojContent);
  final String iconPath = '$iconName.icon';

  // Check if .icon reference already exists
  final bool alreadyExists = lines.any((line) => line.contains(iconPath));
  if (alreadyExists) {
    return pbxprojContent;
  }

  // Generate unique IDs for the .icon file references
  final String fileRefId =
      _generateUniqueId('fileRef$iconName', pbxprojContent);
  final String buildFileId =
      _generateUniqueId('buildRef$iconName', pbxprojContent);

  // Find insertion points
  int? fileRefInsertIndex;
  int? buildFileInsertIndex;
  int? resourcesBuildphaseInsertIndex;
  int? resourcesPBXGroupInsertIndex;
  for (int i = 0; i < lines.length; i++) {
    final String line = lines[i];

    // Find PBXFileReference section
    if (line.contains('/* Begin PBXFileReference section */') &&
        fileRefInsertIndex == null) {
      // Insert after the first existing file reference
      for (int j = i + 1; j < lines.length; j++) {
        if (lines[j].trim().endsWith('};') &&
            lines[j].contains('isa = PBXFileReference')) {
          fileRefInsertIndex = j + 1;
          break;
        }
      }
    }

    // Find PBXBuildFile section
    if (line.contains('/* Begin PBXBuildFile section */') &&
        buildFileInsertIndex == null) {
      // Insert after the first existing build file
      for (int j = i + 1; j < lines.length; j++) {
        if (lines[j].trim().endsWith('};') &&
            lines[j].contains('isa = PBXBuildFile')) {
          buildFileInsertIndex = j + 1;
          break;
        }
      }
    }

    // Find Resources section
    if (line.contains('/* Begin PBXResourcesBuildPhase section */') &&
        resourcesBuildphaseInsertIndex == null) {
      for (int j = i + 1; j < lines.length; j++) {
        if (lines[j].trim().contains('files = (')) {
          resourcesBuildphaseInsertIndex = j + 1;
          break;
        }
      }
    }
    if (line.contains('/* Begin PBXGroup section */') &&
        resourcesPBXGroupInsertIndex == null) {
      for (int j = i + 1; j < lines.length; j++) {
        if (lines[j].trim().contains('/* Runner */ = {')) {
          for (int h = j + 1; h < lines.length; h++) {
            if (lines[h].trim().contains('children = (')) {
              resourcesPBXGroupInsertIndex = h + 1;
              break;
            }
          }
          break;
        }
      }
    }
  }

  // Add PBXFileReference entry
  if (fileRefInsertIndex != null) {
    lines.insert(
      fileRefInsertIndex,
      '\t\t$fileRefId /* $iconPath */ = {isa = PBXFileReference; '
      'lastKnownFileType = folder.iconcomposer.icon; path = $iconPath; '
      'sourceTree = "<group>"; };',
    );
  }

  // Add PBXBuildFile entry
  if (buildFileInsertIndex != null) {
    final adjustedIndex = buildFileInsertIndex +
        (fileRefInsertIndex != null && buildFileInsertIndex > fileRefInsertIndex
            ? 1
            : 0);
    lines.insert(
      adjustedIndex,
      '\t\t$buildFileId /* $iconPath in Resources */ = '
      '{isa = PBXBuildFile; fileRef = $fileRefId /* $iconPath */; };',
    );
  }

  // Add to Resources section
  if (resourcesBuildphaseInsertIndex != null) {
    final int adjustedIndex = resourcesBuildphaseInsertIndex +
        (fileRefInsertIndex != null &&
                resourcesBuildphaseInsertIndex > fileRefInsertIndex
            ? 1
            : 0) +
        (buildFileInsertIndex != null &&
                resourcesBuildphaseInsertIndex > buildFileInsertIndex
            ? 1
            : 0);
    lines.insert(
      adjustedIndex,
      '\t\t\t\t$buildFileId /* $iconPath in Resources */,',
    );
  }
  if (resourcesPBXGroupInsertIndex != null) {
    final int adjustedIndex = resourcesPBXGroupInsertIndex +
        (fileRefInsertIndex != null &&
                resourcesPBXGroupInsertIndex > fileRefInsertIndex
            ? 1
            : 0) +
        (buildFileInsertIndex != null &&
                resourcesPBXGroupInsertIndex > buildFileInsertIndex
            ? 1
            : 0) +
        (resourcesBuildphaseInsertIndex != null &&
                resourcesPBXGroupInsertIndex > resourcesBuildphaseInsertIndex
            ? 1
            : 0);
    lines.insert(
      adjustedIndex,
      '\t\t\t\t$fileRefId /* $iconPath */,',
    );
  }

  return '${lines.join('\n')}\n';
}

/// Generate a unique ID for Xcode project file references
/// Uses a format similar to existing Xcode IDs (24 character hex string)
String _generateUniqueId(String fileName, String projectFile) {
  String generateHash(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 24).toUpperCase();
  }

  bool isIdUnique(String id, String file) {
    return !file.contains(id);
  }

  String id = generateHash(fileName);
  int attempt = 0;
  while (!isIdUnique(id, projectFile)) {
    attempt++;
    id = generateHash('$fileName-$attempt');
  }
  return id;
}

/// Resolves the project.pbxproj file to edit.
///
/// Prefers an explicit [xcodeprojPath], then the standard
/// `ios/Runner.xcodeproj` location, then the first `*.xcodeproj` found under
/// `ios/` so renamed Runner projects keep working (fluttercommunity/flutter_launcher_icons#543). Returns `null`
/// when no project file exists.
String? resolveIosPbxprojPath([
  String? xcodeprojPath,
  String prefixPath = '.',
]) {
  if (xcodeprojPath != null) {
    return '$xcodeprojPath/project.pbxproj';
  }
  final standardPath = withPrefix(prefixPath, paths.iosConfigFile);
  if (File(standardPath).existsSync()) {
    return standardPath;
  }
  final iosDir = Directory(withPrefix(prefixPath, 'ios'));
  if (iosDir.existsSync()) {
    final candidates = iosDir
        .listSync()
        .whereType<Directory>()
        .where((dir) => dir.path.endsWith('.xcodeproj'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final dir in candidates) {
      final candidate = '${dir.path}/project.pbxproj';
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }
  }
  return null;
}

/// Change the iOS launcher icon
Future<void> changeIosLauncherIcon(
  String iconName,
  String? flavor, [
  String? xcodeprojPath,
  String prefixPath = '.',
  LILogger? logger,
]) async {
  // Falls back to the standard location so a missing project still fails
  // with the historical PathNotFoundException.
  final resolvedPath = resolveIosPbxprojPath(xcodeprojPath, prefixPath) ??
      withPrefix(prefixPath, paths.iosConfigFile);
  final File iOSConfigFile = File(resolvedPath);
  final List<String> lines = await iOSConfigFile.readAsLines();

  bool onConfigurationSection = false;
  String? currentConfig;
  bool replacedAny = false;

  for (int x = 0; x < lines.length; x++) {
    final String line = lines[x];
    if (line.contains('/* Begin XCBuildConfiguration section */')) {
      onConfigurationSection = true;
    }
    if (line.contains('/* End XCBuildConfiguration section */')) {
      onConfigurationSection = false;
    }
    if (onConfigurationSection) {
      // Block headers carry the exact configuration name
      // (`<id> /* Debug-development */ = {`). This is the primary signal:
      // flavor-duplicated configurations usually keep sharing the base
      // `.xcconfig`, so the reference below cannot tell them apart.
      final header = RegExp(
        r'^\s*\S+ /\* ([^*]+) \*/ = \{$',
      ).firstMatch(line);
      if (header != null) {
        currentConfig = header.group(1);
      }
      final match = RegExp('.*/\\* (.*)\.xcconfig \\*/;').firstMatch(line);
      if (match != null) {
        // A shared base xcconfig must not clobber a flavored block header
        // (the common Flutter-flavors shape reuses Debug.xcconfig).
        final headerIsOurs = currentConfig != null &&
            flavor != null &&
            (currentConfig == flavor || currentConfig.endsWith('-$flavor'));
        if (!headerIsOurs) {
          currentConfig = match.group(1);
        }
      }

      if (currentConfig != null &&
          (flavor == null ||
              currentConfig == flavor ||
              currentConfig.endsWith('-$flavor')) &&
          line.contains('ASSETCATALOG') &&
          line.contains('APPICON_NAME')) {
        // Targeted replacement: only the APPICON_NAME pair, leaving any
        // other settings on the line untouched.
        lines[x] = line.replaceFirst(
          RegExp('ASSETCATALOG_COMPILER_APPICON_NAME\\s*=\\s*[^;]*;'),
          'ASSETCATALOG_COMPILER_APPICON_NAME = $iconName;',
        );
        replacedAny = true;
      }
    }
  }

  if (flavor != null && !replacedAny) {
    // The flavor catalog was generated on disk but Xcode will keep building
    // the previous icon set. Warn loudly instead of reporting silent
    // success (fluttercommunity/flutter_launcher_icons#341).
    printStatus(
      '\nWARNING: No ASSETCATALOG_COMPILER_APPICON_NAME entry for "$flavor" '
      'configurations was found in project.pbxproj, so Xcode will keep using '
      'the previous icon set. Set the Primary App Icon Set Name to '
      '"$iconName" for the $flavor configurations in Xcode, or add the '
      'missing build setting.\n',
      logger,
    );
  }

  final String entireFile = '${lines.join('\n')}\n';
  // Write via temp-file rename so a crash cannot leave a half-written,
  // corrupt project file behind (fluttercommunity/flutter_launcher_icons#636).
  final tmpFile = File('${iOSConfigFile.path}.tmp');
  await tmpFile.writeAsString(entireFile);
  await tmpFile.rename(iOSConfigFile.path);
}

/// Whether [configName] (e.g. `Debug-staging`) belongs to [flavor]:
/// the name itself or a `-<flavor>` suffix. Substring matching collides
/// (`tag` must not match `Debug-staging`).
bool _isFlavorConfig(String configName, String flavor) {
  return configName == flavor || configName.endsWith('-$flavor');
}

/// Removes flavor-matching `ASSETCATALOG_COMPILER_APPICON_NAME` lines from project.pbxproj so `xcconfig` overrides take effect (pbxproj values shadow xcconfig base values — verified with `xcodebuild
/// -showBuildSettings`). Returns the number of removed lines.
Future<int> clearIosFlavorAppIconLines(
  String flavor, [
  String? xcodeprojPath,
  String prefixPath = '.',
  LILogger? logger,
]) async {
  // Falls back to the standard location so a missing project still fails
  // with the historical PathNotFoundException.
  final resolvedPath = resolveIosPbxprojPath(xcodeprojPath, prefixPath) ??
      withPrefix(prefixPath, paths.iosConfigFile);
  final File iOSConfigFile = File(resolvedPath);
  final List<String> lines = await iOSConfigFile.readAsLines();

  bool onConfigurationSection = false;
  String? currentConfig;
  final kept = <String>[];
  var removed = 0;
  for (final line in lines) {
    if (line.contains('/* Begin XCBuildConfiguration section */')) {
      onConfigurationSection = true;
    }
    if (line.contains('/* End XCBuildConfiguration section */')) {
      onConfigurationSection = false;
    }
    if (onConfigurationSection) {
      // Same exact-token primary signal as changeIosLauncherIcon: block
      // headers name the configuration even when it shares a base xcconfig.
      final header = RegExp(
        r'^\s*\S+ /\* ([^*]+) \*/ = \{$',
      ).firstMatch(line);
      if (header != null) {
        currentConfig = header.group(1);
      }
      final match = RegExp('.*/\\* (.*)\.xcconfig \\*/;').firstMatch(line);
      if (match != null) {
        // A shared base xcconfig must not clobber a flavored block header.
        if (currentConfig == null || !_isFlavorConfig(currentConfig, flavor)) {
          currentConfig = match.group(1);
        }
      }
      if (currentConfig != null &&
          _isFlavorConfig(currentConfig, flavor) &&
          line.contains('ASSETCATALOG') &&
          line.contains('APPICON_NAME')) {
        removed++;
        continue;
      }
    }
    kept.add(line);
  }

  if (removed > 0) {
    final tmpFile = File('${iOSConfigFile.path}.tmp');
    await tmpFile.writeAsString('${kept.join('\n')}\n');
    await tmpFile.rename(iOSConfigFile.path);
    printStatus(
      'Removed $removed ASSETCATALOG_COMPILER_APPICON_NAME '
      'entries for "$flavor" from project.pbxproj so the xcconfig '
      'overrides take effect',
      logger,
    );
  }
  return removed;
}

/// Writes per-mode `ios/Flutter/<flavor>-<Mode>.xcconfig` overrides pointing
/// `ASSETCATALOG_COMPILER_APPICON_NAME` at [catalogName], creating missing
/// files seeded with the Generated include. Assign the files as the base
/// configuration files in Xcode once; the tool keeps the setting in place after that.
Future<void> writeIosFlavorXcconfigs(
  String flavor,
  String catalogName, {
  String prefixPath = '.',
  LILogger? logger,
}) async {
  const setting = 'ASSETCATALOG_COMPILER_APPICON_NAME';
  for (final mode in ['Debug', 'Profile', 'Release']) {
    final relativePath = 'ios/Flutter/$flavor-$mode.xcconfig';
    final file = File(withPrefix(prefixPath, relativePath));
    final existed = file.existsSync();
    final target = existed ? file : await file.create(recursive: true);
    var xcconfigLines = existed
        ? await target.readAsLines()
        : ['#include "Generated.xcconfig"'];
    var replaced = false;
    for (var i = 0; i < xcconfigLines.length; i++) {
      if (xcconfigLines[i].split('=').first.trim() == setting) {
        xcconfigLines[i] = '$setting = $catalogName';
        replaced = true;
      }
    }
    if (!replaced) {
      xcconfigLines = [...xcconfigLines, '$setting = $catalogName'];
    }
    await target.writeAsString('${xcconfigLines.join('\n')}\n');
  }
  printStatus(
    'Wrote $setting = $catalogName to ios/Flutter/$flavor-{Debug,Profile,Release}.xcconfig; '
    'assign them as the base configuration files in Xcode',
    logger,
  );
}

/// Deletes `AppIcon-<flavor>` catalogs nothing references anymore (e.g.
/// after a flavor rename), keeping [currentCatalog] and the default set.
///
/// A catalog is orphaned when its name appears in none of
/// [referenceTexts] (project.pbxproj / xcconfig contents). Every deletion
/// is logged loudly; a still-referenced catalog is always kept so the
/// build cannot break.
Future<void> removeOrphanedCatalogs({
  required String assetFolderRelative,
  required String currentCatalog,
  required List<String> referenceTexts,
  String prefixPath = '.',
  LILogger? logger,
}) async {
  final dir = Directory(withPrefix(prefixPath, assetFolderRelative));
  if (!dir.existsSync()) {
    return;
  }
  for (final entity in dir.listSync().whereType<Directory>()) {
    final dirname = path.basename(entity.path);
    if (!dirname.endsWith('.appiconset')) {
      continue;
    }
    final name = dirname.substring(0, dirname.length - '.appiconset'.length);
    if (name == currentCatalog || name == 'AppIcon') {
      continue;
    }
    if (referenceTexts.any((text) => text.contains(name))) {
      continue;
    }
    printStatus(
      'Removing orphaned icon catalog $dirname (no project or xcconfig references it)',
      logger,
    );
    await entity.delete(recursive: true);
  }
}

/// Reads the reference texts for iOS catalog orphan detection: the
/// resolved project.pbxproj plus every `ios/Flutter/*.xcconfig`.
Future<List<String>> iosCatalogReferenceTexts([
  String? xcodeprojPath,
  String prefixPath = '.',
]) async {
  final references = <String>[];
  final pbxprojPath = resolveIosPbxprojPath(xcodeprojPath, prefixPath);
  if (pbxprojPath != null && File(pbxprojPath).existsSync()) {
    references.add(await File(pbxprojPath).readAsString());
  }
  final flutterDir = Directory(withPrefix(prefixPath, 'ios/Flutter'));
  if (flutterDir.existsSync()) {
    for (final entity in flutterDir.listSync().whereType<File>()) {
      if (entity.path.endsWith('.xcconfig')) {
        references.add(await entity.readAsString());
      }
    }
  }
  return references;
}

/// Create the Contents.json file
Future<void> modifyContentsFile(
  String newIconName,
  String? darkIconName,
  String? tintedIconName, [
  bool singleSize = false,
  String prefixPath = '.',
]) async {
  final String newContentsFilename = withPrefix(
    prefixPath,
    paths.iosAssetFolder + newIconName + '.appiconset/Contents.json',
  );
  final contentsJsonFile = await createFileIfNotExist(newContentsFilename);
  final String contentsFileContent = generateContentsFileAsString(
    newIconName,
    darkIconName,
    tintedIconName,
    singleSize,
  );
  await contentsJsonFile.writeAsString(contentsFileContent);
}

/// Modify default Contents.json file
Future<void> modifyDefaultContentsFile(
  String newIconName,
  String? darkIconName,
  String? tintedIconName, [
  bool singleSize = false,
  String prefixPath = '.',
]) async {
  final String newIconFolder = withPrefix(
    prefixPath,
    paths.iosAssetFolder + 'AppIcon.appiconset/Contents.json',
  );
  final contentsJsonFile = await createFileIfNotExist(newIconFolder);
  final String contentsFileContent = generateContentsFileAsString(
    newIconName,
    darkIconName,
    tintedIconName,
    singleSize,
  );
  await contentsJsonFile.writeAsString(contentsFileContent);
}

/// Serializes the `Contents.json` image list (plus `xcode` info block) to a JSON string.
String generateContentsFileAsString(
  String newIconName,
  String? darkIconName,
  String? tintedIconName, [
  bool singleSize = false,
]) {
  final imageList = singleSize
      ? createSingleSizeImageList(newIconName)
      : createImageList(newIconName, darkIconName, tintedIconName);
  final Map<String, dynamic> contentJson = <String, dynamic>{
    'images': imageList,
    'info': ContentsInfoObject(version: 1, author: 'xcode').toJson(),
  };
  return json.encode(contentJson);
}

/// An appearance qualifier (e.g. luminosity/dark) for a catalog image.
class ContentsImageAppearanceObject {
  /// Creates an instance of [ContentsImageAppearanceObject].
  ContentsImageAppearanceObject({
    required this.appearance,
    required this.value,
  });

  /// Appearance axis name (e.g. `luminosity`).
  final String appearance;

  /// Appearance value (e.g. `dark`).
  final String value;

  /// Serializes to the catalog JSON form.
  Map<String, String> toJson() {
    return <String, String>{
      'appearance': appearance,
      'value': value,
    };
  }
}

/// One image entry of an asset-catalog `Contents.json`.
class ContentsImageObject {
  /// Creates an instance of [ContentsImageObject].
  ContentsImageObject({
    required this.size,
    required this.idiom,
    required this.filename,
    required this.scale,
    this.platform,
    this.appearances,
  });

  /// Point size (e.g. `20x20`).
  final String size;

  /// Device idiom (e.g. `universal`).
  final String idiom;

  /// PNG file name.
  final String filename;

  /// Display scale (e.g. `2x`).
  final String scale;

  /// Platform scope (e.g. `ios`), omitted when null.
  final String? platform;

  /// Appearance qualifiers, omitted when null.
  final List<ContentsImageAppearanceObject>? appearances;

  /// Serializes to the catalog JSON form.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'size': size,
      'idiom': idiom,
      'filename': filename,
      'scale': scale,
      if (platform != null) 'platform': platform,
      if (appearances != null)
        'appearances': appearances!.map((e) => e.toJson()).toList(),
    };
  }
}

/// The `info` block of an asset-catalog `Contents.json`.
class ContentsInfoObject {
  /// Creates an instance of [ContentsInfoObject].
  ContentsInfoObject({required this.version, required this.author});

  /// Schema version.
  final int version;

  /// Authoring tool name.
  final String author;

  /// Serializes to the catalog JSON form.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'version': version,
      'author': author,
    };
  }
}

/// Create a single-entry image list for `ios.single_size` mode (fluttercommunity/flutter_launcher_icons#592).
List<Map<String, dynamic>> createSingleSizeImageList(String fileNamePrefix) {
  return <Map<String, dynamic>>[
    ContentsImageObject(
      size: '1024x1024',
      idiom: 'universal',
      filename: '$fileNamePrefix-1024x1024@1x.png',
      platform: 'ios',
      scale: '1x',
    ).toJson(),
  ];
}

/// Create the image list for the Contents.json file for Xcode versions Xcode 14 and above
List<Map<String, dynamic>> createImageList(
  String fileNamePrefix,
  String? darkFileNamePrefix,
  String? tintedFileNamePrefix,
) {
  const List<Map<String, dynamic>> imageConfigurations = [
    {
      'size': '20x20',
      'idiom': 'universal',
      'platform': 'ios',
      'scales': ['1x', '2x', '3x'],
    },
    {
      'size': '29x29',
      'idiom': 'universal',
      'platform': 'ios',
      'scales': ['1x', '2x', '3x'],
    },
    {
      'size': '38x38',
      'idiom': 'universal',
      'platform': 'ios',
      'scales': ['2x', '3x'],
    },
    {
      'size': '40x40',
      'idiom': 'universal',
      'platform': 'ios',
      'scales': ['1x', '2x', '3x'],
    },
    {
      'size': '60x60',
      'idiom': 'universal',
      'platform': 'ios',
      'scales': ['2x', '3x'],
    },
    {
      'size': '64x64',
      'idiom': 'universal',
      'platform': 'ios',
      'scales': ['2x', '3x'],
    },
    {
      'size': '68x68',
      'idiom': 'universal',
      'platform': 'ios',
      'scales': ['2x'],
    },
    {
      'size': '76x76',
      'idiom': 'universal',
      'platform': 'ios',
      'scales': ['1x', '2x'],
    },
    {
      'size': '83.5x83.5',
      'idiom': 'universal',
      'platform': 'ios',
      'scales': ['2x'],
    },
    {
      'size': '1024x1024',
      'idiom': 'universal',
      'platform': 'ios',
      'scales': ['1x'],
    },
    {
      'size': '1024x1024',
      'idiom': 'ios-marketing',
      'scales': ['1x'],
    },
  ];

  final List<Map<String, dynamic>> imageList = <Map<String, dynamic>>[];

  for (final config in imageConfigurations) {
    final size = config['size']! as String;
    final idiom = config['idiom']! as String;
    final platform = config['platform'] as String?;
    final scales = config['scales'] as List<String>;

    for (final scale in scales) {
      final filename = '$fileNamePrefix-$size@$scale.png';
      imageList.add(
        ContentsImageObject(
          size: size,
          idiom: idiom,
          filename: filename,
          platform: platform,
          scale: scale,
        ).toJson(),
      );
    }
  }

  // Prevent ios-marketing icon from being tinted or dark

  if (darkFileNamePrefix != null) {
    for (final config
        in imageConfigurations.where((e) => e['idiom'] == 'universal')) {
      final size = config['size']! as String;
      final idiom = config['idiom']! as String;
      final platform = config['platform'] as String?;
      final scales = config['scales'] as List<String>;

      for (final scale in scales) {
        final filename = '$darkFileNamePrefix-$size@$scale.png';
        imageList.add(
          ContentsImageObject(
            size: size,
            idiom: idiom,
            filename: filename,
            platform: platform,
            scale: scale,
            appearances: <ContentsImageAppearanceObject>[
              ContentsImageAppearanceObject(
                appearance: 'luminosity',
                value: 'dark',
              ),
            ],
          ).toJson(),
        );
      }
    }
  }

  if (tintedFileNamePrefix != null) {
    for (final config
        in imageConfigurations.where((e) => e['idiom'] == 'universal')) {
      final size = config['size']! as String;
      final idiom = config['idiom']! as String;
      final platform = config['platform'] as String?;
      final scales = config['scales'] as List<String>;

      for (final scale in scales) {
        final filename = '$tintedFileNamePrefix-$size@$scale.png';
        imageList.add(
          ContentsImageObject(
            size: size,
            idiom: idiom,
            filename: filename,
            platform: platform,
            scale: scale,
            appearances: <ContentsImageAppearanceObject>[
              ContentsImageAppearanceObject(
                appearance: 'luminosity',
                value: 'tinted',
              ),
            ],
          ).toJson(),
        );
      }
    }
  }

  return imageList;
}

ColorUint8 _getBackgroundColor(Config config) {
  final backgroundColor = config.iosConfig?.backgroundColor ?? '#ffffff';
  final (:r, :g, :b) = parseHexColor(backgroundColor);
  return ColorUint8.rgba(r, g, b, 0xff);
}

/// Mattes [source] onto the configured background color, returning an
/// opaque 3-channel image.
Image _removeAlphaChannel(Image source, Config config) {
  final backgroundColor = _getBackgroundColor(config);
  final pixel = source.getPixel(0, 0);
  do {
    pixel.set(_alphaBlend(pixel, backgroundColor));
  } while (pixel.moveNext());

  return source.convert(numChannels: 3);
}

Color _alphaBlend(Color fg, ColorUint8 bg) {
  if (fg.format != Format.uint8) {
    fg = fg.convert(format: Format.uint8);
  }
  if (fg.a == 0) {
    return bg;
  } else {
    final invAlpha = 0xff - fg.a;
    return ColorUint8.rgba(
      (fg.a * fg.r + invAlpha * bg.r) ~/ 0xff,
      (fg.a * fg.g + invAlpha * bg.g) ~/ 0xff,
      (fg.a * fg.b + invAlpha * bg.b) ~/ 0xff,
      0xff,
    );
  }
}
