import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' hide decodeImageFile;
import 'package:launcher_icons/src/config/config.dart';
import 'package:launcher_icons/src/core/constants.dart';
import 'package:launcher_icons/src/core/custom_exceptions.dart';
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
/// Covers the modern (Xcode 14+) universal set, including the 1x switcher sizes. The legacy iphone/ipad list was removed in v3: it emitted obsolete sizes (57x57, 50x50, 72x72) that Xcode no longer references.
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
  final Config config,
  final String? flavor, {
  final LILogger? logger,
  final String prefixPath = '.',
  final SvgRasterCache? cache,
}) async {
  // Fail fast on config errors before any decode or I/O: a bad flavor_mode
  // must not surface only after minutes of image work.
  final flavorMode = config.iosConfig?.flavorMode ?? 'pbxproj';
  if (flavorMode != 'pbxproj' && flavorMode != 'xcconfig') {
    throw InvalidConfigException(
      'Invalid `ios.flavor_mode` "$flavorMode": must be "pbxproj" or "xcconfig".',
    );
  }
  // A custom icon_name only applies to unflavored runs (flavor runs always
  // write `AppIcon-<flavor>`); hoisted so the flavor branch can warn.
  final customIconName = config.iosConfig?.iconName;
  // `.icon`-only runs skip the PNG catalog (and its base image) and emit just
  // the glass bundle; fail fast when there is nothing to emit at all.
  final iconOnly = config.iosConfig?.iconOnly ?? false;
  final hasGlass = (config.iosConfig?.liquidGlassLayers?.isNotEmpty ?? false) || (config.iosConfig?.liquidGlassGroups?.isNotEmpty ?? false);
  if (iconOnly && !hasGlass) {
    throw const InvalidConfigException(
      '`ios.icon_only` requires `liquid_glass_layers` or `liquid_glass_groups`: there is nothing else to emit.',
    );
  }

  // `.icon`-only runs emit just the bundle below: no PNG masters are decoded and the base image is optional, so the whole PNG prep is skipped.
  // `late` (not `final`: remove_alpha re-mattes in place below) keeps icon-only runs from touching the unassigned master.
  late Image image;
  Image? darkImage;
  Image? tintedImage;
  // Single-size mode generates only the 1024px marketing icon: dark/tinted variants are skipped entirely (no decode, no I/O).
  final singleSize = config.iosConfig?.singleSize ?? false;
  if (!iconOnly) {
    final filePath = config.resolveImageFile(config.iosConfig?.imagePath, prefixPath);
    final darkFilePath = config.iosConfig?.imagePathDarkTransparent;
    final tintedFilePath = config.iosConfig?.imagePathTintedGrayscale;

    // decodeImageFile throws on missing/undecodable files, so a specified but bad path is a hard error rather than a silent skip.
    image = await decodeImageFile(
      withPrefix(
        prefixPath,
        filePath,
      ),
      cache: cache,
    );
    if (singleSize && (darkFilePath != null || tintedFilePath != null)) {
      printStatus(
        'Dark/tinted variants are ignored in single-size mode',
        logger,
      );
    }

    if (darkFilePath != null && !singleSize) {
      darkImage = await decodeImageFile(
        withPrefix(prefixPath, darkFilePath),
        cache: cache,
      );
    }

    if (tintedFilePath != null && !singleSize) {
      tintedImage = await decodeImageFile(
        withPrefix(prefixPath, tintedFilePath),
        cache: cache,
      );
      if (config.iosConfig!.desaturateTintedToGrayscale) {
        printStatus('Desaturating iOS tinted image to grayscale', logger);
        tintedImage = grayscale(tintedImage);
      } else if (!isGrayscaleImage(tintedImage)) {
        // Apple's guidance (HIG > App icons, https://developer.apple.com/design/human-interface-guidelines/app-icons): the dark variant is a transparent-background design the system background shows through, while the tinted variant must read as a single-color silhouette — i.e. grayscale. Never validate dark transparency away; warn on tinted color instead.
        printStatus(
          '\nWARNING: Tinted iOS image is not grayscale.\nSet "ios.desaturate_tinted_to_grayscale: true" to desaturate it.\n',
          logger,
        );
      }
    }

    // remove_alpha mattes the base image onto the background color. The dark variant intentionally keeps its transparency (Apple: the system background shows through), while the tinted variant is forced opaque like the base image.
    if (config.iosConfig?.removeAlpha ?? false) {
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
  } else if (singleSize) {
    printStatus(
      '`ios.single_size` has no effect in `icon_only` mode (no PNG catalog is written).',
      logger,
    );
  }
  // Artwork loaders hand out the finished master for any requested size. Sizing happens exactly once at the write sites ([saveNewIcons] and [overwriteDefaultIcons] resize to the template size), so loaders must not pre-resize: a second resampling pass wastes time and softens pixels. Callers only read the shared master (resize/encode never mutate it).
  Future<Image> Function(int) sizeLoaderFor({
    required final Image master,
  }) =>
      (final size) async => master;

  // Built only for PNG runs. Icon-only runs never touch the loaders (the PNG branch below is skipped), so the unassigned `late` masters stay unread.
  late final Future<Image> Function(int) loadBase;
  late final Future<Image> Function(int)? loadDark;
  late final Future<Image> Function(int)? loadTinted;
  if (!iconOnly) {
    loadBase = sizeLoaderFor(master: image);
    // Null exactly when the matching master is null (unset source or single-size mode); call sites only run under the same guards.
    loadDark = darkImage == null ? null : sizeLoaderFor(master: darkImage);
    loadTinted = tintedImage == null ? null : sizeLoaderFor(master: tintedImage);
  }
  String iconName;
  String? darkIconName;
  String? tintedIconName;
  // Single-size mode generates only the 1024px marketing icon.
  final generateIosIcons = singleSize
      ? <IosIconTemplate>[
          IosIconTemplate(name: '-1024x1024@1x', size: 1024),
        ]
      : iosIcons;
  final concurrentIconUpdates = <Future<void>>[];
  // The name of the icon catalog the generated icons are written to. The liquid glass .icon bundle is created with the same name so Xcode associates it with the catalog.
  var catalogName = paths.appIconCatalogName(flavor);
  if (iconOnly) {
    // No PNG catalog, Contents.json, or APPICON_NAME edits: catalogName only names the `.icon` bundle below (a custom name still applies off-flavor).
    if (customIconName != null && flavor == null) {
      catalogName = customIconName;
    }
    printStatus(
      "Skipping the PNG asset catalog (`ios.icon_only`): emitting $catalogName.icon only — set the target's App Icon to it in Xcode.",
      logger,
    );
    iconName = catalogName;
  } else if (flavor != null) {
    printStatus('Building iOS launcher icon for $flavor', logger);
    if (customIconName != null) {
      // A flavor run always writes `AppIcon-<flavor>`; say so instead of silently dropping the custom name.
      printStatus(
        'Ignoring `ios.icon_name` "$customIconName" for flavor "$flavor": flavor runs always write `AppIcon-$flavor`.',
        logger,
      );
    }
    for (final template in generateIosIcons) {
      concurrentIconUpdates.add(
        loadBase(template.size).then(
          (final sized) => saveNewIcons(
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
      final darkName = '$catalogName${paths.appIconDarkSuffix}';
      darkIconName = darkName;
      printStatus('Building iOS dark launcher icon for $flavor', logger);
      for (final template in generateIosIcons) {
        concurrentIconUpdates.add(
          loadDark!(template.size).then(
            (final sized) => saveNewIcons(
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
      final tintedName = '$catalogName${paths.appIconTintedSuffix}';
      tintedIconName = tintedName;
      printStatus('Building iOS tinted launcher icon for $flavor', logger);
      for (final template in generateIosIcons) {
        concurrentIconUpdates.add(
          loadTinted!(template.size).then(
            (final sized) => saveNewIcons(
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
      singleSize: singleSize,
      prefixPath: prefixPath,
    );
  } else if (customIconName != null) {
    // If a custom icon_name is configured then the user has specified a new icon to be created and for the old icon file to be kept
    final newIconName = customIconName;
    // Like the flavor flow, a custom name gets its own catalog so the folder matches APPICON_NAME (<custom>.appiconset, not AppIcon).
    catalogName = newIconName;
    printStatus('Adding new iOS launcher icon', logger);
    for (final template in generateIosIcons) {
      concurrentIconUpdates.add(
        loadBase(template.size).then(
          (final sized) => saveNewIcons(
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
      final darkName = '$newIconName-Dark';
      darkIconName = darkName;
      printStatus('Adding new iOS dark launcher icon', logger);
      for (final template in generateIosIcons) {
        concurrentIconUpdates.add(
          loadDark!(template.size).then(
            (final sized) => saveNewIcons(
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
      final tintedName = '$newIconName-Tinted';
      tintedIconName = tintedName;
      printStatus('Adding new iOS tinted launcher icon', logger);
      for (final template in generateIosIcons) {
        concurrentIconUpdates.add(
          loadTinted!(template.size).then(
            (final sized) => saveNewIcons(
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
      singleSize: singleSize,
      prefixPath: prefixPath,
    );
  }
  // Otherwise the user wants the new icon to use the default icons name and update config file to use it
  else {
    printStatus('Overwriting default iOS launcher icon with new icon', logger);
    for (final template in generateIosIcons) {
      concurrentIconUpdates.add(
        loadBase(template.size).then(
          (final sized) => overwriteDefaultIcons(template, sized, '', prefixPath),
        ),
      );
    }
    if (darkImage != null) {
      printStatus(
        'Overwriting default iOS dark launcher icon with new icon',
        logger,
      );
      for (final template in generateIosIcons) {
        concurrentIconUpdates.add(
          loadDark!(template.size).then(
            (final sized) => overwriteDefaultIcons(template, sized, paths.appIconDarkSuffix, prefixPath),
          ),
        );
      }
      darkIconName = iosDefaultIconName + paths.appIconDarkSuffix;
    }
    if (tintedImage != null) {
      printStatus(
        'Overwriting default iOS tinted launcher icon with new icon',
        logger,
      );
      for (final template in generateIosIcons) {
        concurrentIconUpdates.add(
          loadTinted!(template.size).then(
            (final sized) => overwriteDefaultIcons(template, sized, paths.appIconTintedSuffix, prefixPath),
          ),
        );
      }
      tintedIconName = iosDefaultIconName + paths.appIconTintedSuffix;
    }
    iconName = iosDefaultIconName;
    await changeIosLauncherIcon(
      catalogName,
      flavor,
      config.iosConfig?.xcodeprojPath,
      prefixPath,
      logger,
    );
    // Still need to modify the Contents.json file since the user could have added dark and tinted icons
    await modifyDefaultContentsFile(
      iconName,
      darkIconName,
      tintedIconName,
      singleSize: singleSize,
      prefixPath: prefixPath,
    );
  }
  await Future.wait(concurrentIconUpdates);

  // Sweep catalogs orphaned by flavor renames. Reference-checked so the build cannot break; the default set is always kept.
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

  // Generate liquid glass .icon if configured (the only output in `icon_only` mode)
  if (hasGlass) {
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
  } else {
    // Dropping the layers (or switching to a flavor/custom name) orphans the previous bundle: collect it and its project reference so stale glass doesn't ship. Other catalogs' bundles are left alone — a sibling flavor's `.icon` is legitimate output, not garbage.
    await removeStaleLiquidGlassBundle(
      iconFolderRelative: paths.iosLiquidGlassIconPath(catalogName),
      catalogName: catalogName,
      xcodeprojPath: config.iosConfig?.xcodeprojPath,
      prefixPath: prefixPath,
      logger: logger,
    );
  }
}

/// Deletes a stale liquid glass `.icon` bundle at [iconFolderRelative] (when it exists) and removes its project reference.
///
/// Runs when the current catalog carries no layers/groups: without it, unsetting the layers would leave a stale bundle (and pbxproj reference) shipping old glass. Returns whether anything was removed.
Future<void> removeStaleLiquidGlassBundle({
  required final String iconFolderRelative,
  required final String catalogName,
  final String? xcodeprojPath,
  final String prefixPath = '.',
  final LILogger? logger,
}) async {
  final dir = Directory(withPrefix(prefixPath, iconFolderRelative));
  if (!dir.existsSync()) {
    return;
  }
  printStatus(
    'Removing stale liquid glass bundle $iconFolderRelative (no layers configured for $catalogName)',
    logger,
  );
  await dir.delete(recursive: true);
  await removeLiquidGlassIconFromProject(
    catalogName,
    xcodeprojPath,
    logger,
    prefixPath,
  );
}

/// Removes the liquid glass `.icon` file reference for [iconName] from project.pbxproj (the inverse of [addLiquidGlassIconToProject]). Missing files are a no-op: the icons themselves are unaffected.
Future<void> removeLiquidGlassIconFromProject(
  final String iconName, [
  final String? xcodeprojPath,
  final LILogger? logger,
  final String prefixPath = '.',
]) async {
  final resolvedPath = resolveIosPbxprojPath(xcodeprojPath, prefixPath) ?? withPrefix(prefixPath, paths.iosConfigFile);
  final iOSConfigFile = File(resolvedPath);
  if (!iOSConfigFile.existsSync()) {
    return;
  }
  final wholeFile = await iOSConfigFile.readAsString();
  final changedFile = removeLiquidGlassIconReference(wholeFile, iconName);
  if (changedFile == wholeFile) {
    return;
  }
  await iOSConfigFile.writeAsString(changedFile);
  printStatus(
    'Removed liquid glass .icon reference to $iconName.icon from project.pbxproj',
    logger,
  );
}

/// Removes the liquid glass `.icon` file references for [iconName] from the given [pbxprojContent] and returns the modified content.
///
/// Drops every line mentioning `<iconName>.icon` (every reference form [addLiquidGlassIconReference] writes carries one). The `.icon` suffix anchors the match so similarly-named bundles never shadow each other. Returns the original content unchanged when nothing references the bundle.
String removeLiquidGlassIconReference(final String pbxprojContent, final String iconName) {
  final lines = const LineSplitter().convert(pbxprojContent);
  final token = '$iconName.icon';
  final kept = lines.where((final line) => !line.contains(token)).toList();
  if (kept.length == lines.length) {
    return pbxprojContent;
  }
  return '${kept.join('\n')}\n';
}

/// Whether [image] reads as grayscale, sampled on an 8x8 grid (64 reads regardless of image size) instead of a full O(n) pixel walk.
///
/// A sample counts as colored when its channel spread exceeds 8 levels, tolerating JPEG-style compression noise around true gray. Checking one pixel (or every pixel) is the wrong trade-off: a single origin sample misses off-center color, while a full scan costs millions of reads on a 1024px source to answer a boolean.
bool isGrayscaleImage(final Image image, {final int gridDivisions = 8}) {
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
      ].reduce((final a, final c) => a > c ? a : c);
      if (spread > 8) {
        return false;
      }
    }
  }
  return true;
}

/// Overwrites the default `AppIcon` set in place, optionally suffixed for the dark/tinted variants.
Future<void> overwriteDefaultIcons(
  final IosIconTemplate template,
  final Image image, [
  final String iconNameSuffix = '',
  final String prefixPath = '.',
]) async {
  final newImage = createResizedImage(template.size, image);
  await File(
    withPrefix(
      prefixPath,
      path.join(paths.iosDefaultIconFolder, '$iosDefaultIconName$iconNameSuffix${template.name}.png'),
    ),
  ).writeAsBytes(encodePng(newImage));
}

/// Writes fresh PNGs into `<catalogName>.appiconset/` under [iconName], keeping any previous set intact.
Future<void> saveNewIcons({
  required final IosIconTemplate template,
  required final Image image,
  required final String catalogName,
  required final String iconName,
  final String prefixPath = '.',
}) async {
  final newIconFolder = path.join(paths.iosAssetFolder, '$catalogName.appiconset');
  final newImage = createResizedImage(template.size, image);
  final newFile = await createFileIfNotExist(
    withPrefix(prefixPath, path.join(newIconFolder, '$iconName${template.name}.png')),
  );
  await newFile.writeAsBytes(encodePng(newImage));
}

/// Add liquid glass .icon file reference to project.pbxproj
Future<void> addLiquidGlassIconToProject(
  final String iconName, [
  final String? xcodeprojPath,
  final LILogger? logger,
  final String prefixPath = '.',
]) async {
  final resolvedPath = resolveIosPbxprojPath(xcodeprojPath, prefixPath) ?? withPrefix(prefixPath, paths.iosConfigFile);
  final iOSConfigFile = File(resolvedPath);
  if (!iOSConfigFile.existsSync()) {
    printStatus(
      'Warning: project.pbxproj not found, skipping .icon reference addition',
      logger,
    );
    return;
  }
  final wholeFile = await iOSConfigFile.readAsString();
  final changedFile = addLiquidGlassIconReference(wholeFile, iconName);
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

/// Adds the liquid glass `.icon` file references for [iconName] to the given [pbxprojContent] and returns the modified content. If the reference already exists, the original content is returned unchanged.
String addLiquidGlassIconReference(final String pbxprojContent, final String iconName) {
  final lines = const LineSplitter().convert(pbxprojContent);
  final iconPath = '$iconName.icon';

  // Check if .icon reference already exists. Match the exact reference forms
  // this function writes (`/* <name>.icon */` comments and `path = <name>.icon;`)
  // so similarly-named bundles never shadow each other.
  final fileToken = '/* $iconPath */';
  final pathToken = 'path = $iconPath;';
  final alreadyExists = lines.any((final line) => line.contains(fileToken) || line.contains(pathToken));
  if (alreadyExists) {
    return pbxprojContent;
  }

  // Generate unique IDs for the .icon file references
  final fileRefId = _generateUniqueId('fileRef$iconName', pbxprojContent);
  final buildFileId = _generateUniqueId('buildRef$iconName', pbxprojContent);

  // Find insertion points
  int? fileRefInsertIndex;
  int? buildFileInsertIndex;
  int? resourcesBuildphaseInsertIndex;
  int? resourcesPBXGroupInsertIndex;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];

    // Find PBXFileReference section
    if (line.contains('/* Begin PBXFileReference section */') && fileRefInsertIndex == null) {
      // Insert after the first existing file reference
      for (var j = i + 1; j < lines.length; j++) {
        if (lines[j].trim().endsWith('};') && lines[j].contains('isa = PBXFileReference')) {
          fileRefInsertIndex = j + 1;
          break;
        }
      }
    }

    // Find PBXBuildFile section
    if (line.contains('/* Begin PBXBuildFile section */') && buildFileInsertIndex == null) {
      // Insert after the first existing build file
      for (var j = i + 1; j < lines.length; j++) {
        if (lines[j].trim().endsWith('};') && lines[j].contains('isa = PBXBuildFile')) {
          buildFileInsertIndex = j + 1;
          break;
        }
      }
    }

    // Find Resources section
    if (line.contains('/* Begin PBXResourcesBuildPhase section */') && resourcesBuildphaseInsertIndex == null) {
      for (var j = i + 1; j < lines.length; j++) {
        if (lines[j].trim().contains('files = (')) {
          resourcesBuildphaseInsertIndex = j + 1;
          break;
        }
      }
    }
    if (line.contains('/* Begin PBXGroup section */') && resourcesPBXGroupInsertIndex == null) {
      for (var j = i + 1; j < lines.length; j++) {
        if (lines[j].trim().contains('/* Runner */ = {')) {
          for (var h = j + 1; h < lines.length; h++) {
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
    final adjustedIndex = buildFileInsertIndex + (fileRefInsertIndex != null && buildFileInsertIndex > fileRefInsertIndex ? 1 : 0);
    lines.insert(
      adjustedIndex,
      '\t\t$buildFileId /* $iconPath in Resources */ = '
      '{isa = PBXBuildFile; fileRef = $fileRefId /* $iconPath */; };',
    );
  }

  // Add to Resources section
  if (resourcesBuildphaseInsertIndex != null) {
    final adjustedIndex = resourcesBuildphaseInsertIndex + (fileRefInsertIndex != null && resourcesBuildphaseInsertIndex > fileRefInsertIndex ? 1 : 0) + (buildFileInsertIndex != null && resourcesBuildphaseInsertIndex > buildFileInsertIndex ? 1 : 0);
    lines.insert(
      adjustedIndex,
      '\t\t\t\t$buildFileId /* $iconPath in Resources */,',
    );
  }
  if (resourcesPBXGroupInsertIndex != null) {
    final adjustedIndex = resourcesPBXGroupInsertIndex + (fileRefInsertIndex != null && resourcesPBXGroupInsertIndex > fileRefInsertIndex ? 1 : 0) + (buildFileInsertIndex != null && resourcesPBXGroupInsertIndex > buildFileInsertIndex ? 1 : 0) + (resourcesBuildphaseInsertIndex != null && resourcesPBXGroupInsertIndex > resourcesBuildphaseInsertIndex ? 1 : 0);
    lines.insert(
      adjustedIndex,
      '\t\t\t\t$fileRefId /* $iconPath */,',
    );
  }

  return '${lines.join('\n')}\n';
}

/// Generate a unique ID for Xcode project file references. Uses a format similar to existing Xcode IDs (24 character hex string)
String _generateUniqueId(final String fileName, final String projectFile) {
  String generateHash(final String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 24).toUpperCase();
  }

  bool isIdUnique(final String id, final String file) => !file.contains(id);

  var id = generateHash(fileName);
  var attempt = 0;
  while (!isIdUnique(id, projectFile)) {
    attempt++;
    id = generateHash('$fileName-$attempt');
  }
  return id;
}

/// Resolves the project.pbxproj file to edit.
///
/// Prefers an explicit [xcodeprojPath], then the standard `ios/Runner.xcodeproj` location, then the first `*.xcodeproj` found under `ios/` so renamed Runner projects keep working. Returns `null` when no project file exists.
String? resolveIosPbxprojPath([
  final String? xcodeprojPath,
  final String prefixPath = '.',
]) {
  if (xcodeprojPath != null) {
    // Explicit paths are project-relative like everything else, so they honor
    // prefixPath (notably `--prefix` runs and the macOS caller, which passes
    // an already-prefixed path with the default prefix).
    return withPrefix(prefixPath, '$xcodeprojPath/${paths.pbxprojFileName}');
  }
  final standardPath = withPrefix(prefixPath, paths.iosConfigFile);
  if (File(standardPath).existsSync()) {
    return standardPath;
  }
  final iosDir = Directory(withPrefix(prefixPath, paths.iosDirPath));
  if (iosDir.existsSync()) {
    final candidates = iosDir.listSync().whereType<Directory>().where((final dir) => dir.path.endsWith(paths.xcodeprojExtension)).toList()..sort((final a, final b) => a.path.compareTo(b.path));
    for (final dir in candidates) {
      final candidate = '${dir.path}/${paths.pbxprojFileName}';
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }
  }
  return null;
}

/// Change the iOS launcher icon
Future<void> changeIosLauncherIcon(
  final String iconName,
  final String? flavor, [
  final String? xcodeprojPath,
  final String prefixPath = '.',
  final LILogger? logger,
]) async {
  // Falls back to the standard location so a missing project still fails with the historical PathNotFoundException.
  final resolvedPath = resolveIosPbxprojPath(xcodeprojPath, prefixPath) ?? withPrefix(prefixPath, paths.iosConfigFile);
  final iOSConfigFile = File(resolvedPath);
  final lines = await iOSConfigFile.readAsLines();

  var onConfigurationSection = false;
  String? currentConfig;
  var replacedAny = false;

  for (var x = 0; x < lines.length; x++) {
    final line = lines[x];
    if (line.contains('/* Begin XCBuildConfiguration section */')) {
      onConfigurationSection = true;
    }
    if (line.contains('/* End XCBuildConfiguration section */')) {
      onConfigurationSection = false;
    }
    if (onConfigurationSection) {
      // Block headers carry the exact configuration name (`<id> /* Debug-development */ = {`). This is the primary signal: flavor-duplicated configurations usually keep sharing the base `.xcconfig`, so the reference below cannot tell them apart.
      final header = RegExp(
        r'^\s*\S+ /\* ([^*]+) \*/ = \{$',
      ).firstMatch(line);
      if (header != null) {
        currentConfig = header.group(1);
      }
      final match = RegExp(r'.*/\* (.*).xcconfig \*/;').firstMatch(line);
      if (match != null) {
        // A shared base xcconfig must not clobber a flavored block header (the common Flutter-flavors shape reuses Debug.xcconfig).
        final headerIsOurs = currentConfig != null && flavor != null && (currentConfig == flavor || currentConfig.endsWith('-$flavor'));
        if (!headerIsOurs) {
          currentConfig = match.group(1);
        }
      }

      if (currentConfig != null && (flavor == null || currentConfig == flavor || currentConfig.endsWith('-$flavor')) && line.contains('ASSETCATALOG') && line.contains('APPICON_NAME')) {
        // Targeted replacement: only the APPICON_NAME pair, leaving any other settings on the line untouched.
        lines[x] = line.replaceFirst(
          RegExp(r'ASSETCATALOG_COMPILER_APPICON_NAME\s*=\s*[^;]*;'),
          'ASSETCATALOG_COMPILER_APPICON_NAME = $iconName;',
        );
        replacedAny = true;
      }
    }
  }

  if (flavor != null && !replacedAny) {
    // The flavor catalog was generated on disk but Xcode will keep building the previous icon set. Warn loudly instead of reporting silent success.
    printStatus(
      '\nWARNING: No ASSETCATALOG_COMPILER_APPICON_NAME entry for "$flavor" '
      'configurations was found in project.pbxproj, so Xcode will keep using '
      'the previous icon set. Set the Primary App Icon Set Name to '
      '"$iconName" for the $flavor configurations in Xcode, or add the '
      'missing build setting.\n',
      logger,
    );
  }

  final entireFile = '${lines.join('\n')}\n';
  // Write via temp-file rename so a crash cannot leave a half-written, corrupt project file behind.
  final tmpFile = File('${iOSConfigFile.path}.tmp');
  await tmpFile.writeAsString(entireFile);
  await tmpFile.rename(iOSConfigFile.path);
}

/// Whether [configName] (e.g. `Debug-staging`) belongs to [flavor]: the name itself or a `-<flavor>` suffix. Substring matching collides (`tag` must not match `Debug-staging`).
bool _isFlavorConfig(final String configName, final String flavor) => configName == flavor || configName.endsWith('-$flavor');

/// Removes flavor-matching `ASSETCATALOG_COMPILER_APPICON_NAME` lines from project.pbxproj so `xcconfig` overrides take effect (pbxproj values shadow xcconfig base values — verified with `xcodebuild -showBuildSettings`). Returns the number of removed lines.
Future<int> clearIosFlavorAppIconLines(
  final String flavor, [
  final String? xcodeprojPath,
  final String prefixPath = '.',
  final LILogger? logger,
]) async {
  // Falls back to the standard location so a missing project still fails with the historical PathNotFoundException.
  final resolvedPath = resolveIosPbxprojPath(xcodeprojPath, prefixPath) ?? withPrefix(prefixPath, paths.iosConfigFile);
  final iOSConfigFile = File(resolvedPath);
  final lines = await iOSConfigFile.readAsLines();

  var onConfigurationSection = false;
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
      // Same exact-token primary signal as changeIosLauncherIcon: block headers name the configuration even when it shares a base xcconfig.
      final header = RegExp(
        r'^\s*\S+ /\* ([^*]+) \*/ = \{$',
      ).firstMatch(line);
      if (header != null) {
        currentConfig = header.group(1);
      }
      final match = RegExp(r'.*/\* (.*).xcconfig \*/;').firstMatch(line);
      if (match != null) {
        // A shared base xcconfig must not clobber a flavored block header.
        if (currentConfig == null || !_isFlavorConfig(currentConfig, flavor)) {
          currentConfig = match.group(1);
        }
      }
      if (currentConfig != null && _isFlavorConfig(currentConfig, flavor) && line.contains('ASSETCATALOG') && line.contains('APPICON_NAME')) {
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

/// Writes per-mode `ios/Flutter/<flavor>-<Mode>.xcconfig` overrides pointing `ASSETCATALOG_COMPILER_APPICON_NAME` at [catalogName], creating missing files seeded with the Generated include. Assign the files as the base configuration files in Xcode once; the tool keeps the setting in place after that.
Future<void> writeIosFlavorXcconfigs(
  final String flavor,
  final String catalogName, {
  final String prefixPath = '.',
  final LILogger? logger,
}) async {
  const setting = 'ASSETCATALOG_COMPILER_APPICON_NAME';
  for (final mode in ['Debug', 'Profile', 'Release']) {
    final relativePath = 'ios/Flutter/$flavor-$mode.xcconfig';
    final file = File(withPrefix(prefixPath, relativePath));
    final existed = file.existsSync();
    final target = existed ? file : await file.create(recursive: true);
    var xcconfigLines = existed ? await target.readAsLines() : ['#include "Generated.xcconfig"'];
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

/// Deletes `AppIcon-<flavor>` catalogs nothing references anymore (e.g. after a flavor rename), keeping [currentCatalog] and the default set.
///
/// A catalog is orphaned when its name appears in none of [referenceTexts] (project.pbxproj / xcconfig contents). Every deletion is logged loudly; a still-referenced catalog is always kept so the build cannot break.
Future<void> removeOrphanedCatalogs({
  required final String assetFolderRelative,
  required final String currentCatalog,
  required final List<String> referenceTexts,
  final String prefixPath = '.',
  final LILogger? logger,
}) async {
  final dir = Directory(withPrefix(prefixPath, assetFolderRelative));
  if (!dir.existsSync()) {
    return;
  }
  for (final entity in dir.listSync().whereType<Directory>()) {
    final dirname = path.basename(entity.path);
    if (!dirname.endsWith(paths.appIconSetExtension)) {
      continue;
    }
    final name = dirname.substring(0, dirname.length - paths.appIconSetExtension.length);
    if (name == currentCatalog || name == paths.appIconCatalogName(null)) {
      continue;
    }
    if (referenceTexts.any((final text) => _catalogIsReferenced(text, name))) {
      continue;
    }
    printStatus(
      'Removing orphaned icon catalog $dirname (no project or xcconfig references it)',
      logger,
    );
    await entity.delete(recursive: true);
  }
}

/// Whether [catalogName] (e.g. `AppIcon-staging`) is referenced by [referenceText] (project.pbxproj / xcconfig contents) as an exact token.
///
/// Substring matching over-keeps (`AppIcon-dev` would look referenced when only `AppIcon-dev2` is wired, so genuine orphans are never collected); token boundaries keep collection working while a wired set is never deleted.
bool _catalogIsReferenced(final String referenceText, final String catalogName) {
  final token = RegExp('(^|[^A-Za-z0-9_.-])${RegExp.escape(catalogName)}([^A-Za-z0-9_.-]|\$)');
  return token.hasMatch(referenceText);
}

/// Reads the reference texts for iOS catalog orphan detection: the resolved project.pbxproj plus every `ios/Flutter/*.xcconfig`.
Future<List<String>> iosCatalogReferenceTexts([
  final String? xcodeprojPath,
  final String prefixPath = '.',
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
  final String newIconName,
  final String? darkIconName,
  final String? tintedIconName, {
  final bool singleSize = false,
  final String prefixPath = '.',
}) async {
  final newContentsFilename = withPrefix(
    prefixPath,
    path.join(paths.iosAssetFolder, '$newIconName.appiconset', 'Contents.json'),
  );
  final contentsJsonFile = await createFileIfNotExist(newContentsFilename);
  final contentsFileContent = generateContentsFileAsString(
    newIconName,
    darkIconName,
    tintedIconName,
    singleSize: singleSize,
  );
  await contentsJsonFile.writeAsString(contentsFileContent);
}

/// Modify default Contents.json file
Future<void> modifyDefaultContentsFile(
  final String newIconName,
  final String? darkIconName,
  final String? tintedIconName, {
  final bool singleSize = false,
  final String prefixPath = '.',
}) async {
  final newIconFolder = withPrefix(
    prefixPath,
    path.join(paths.iosAssetFolder, 'AppIcon.appiconset', 'Contents.json'),
  );
  final contentsJsonFile = await createFileIfNotExist(newIconFolder);
  final contentsFileContent = generateContentsFileAsString(
    newIconName,
    darkIconName,
    tintedIconName,
    singleSize: singleSize,
  );
  await contentsJsonFile.writeAsString(contentsFileContent);
}

/// Serializes the `Contents.json` image list (plus `xcode` info block) to a JSON string.
String generateContentsFileAsString(
  final String newIconName,
  final String? darkIconName,
  final String? tintedIconName, {
  final bool singleSize = false,
}) {
  final imageList = singleSize ? createSingleSizeImageList(newIconName) : createImageList(newIconName, darkIconName, tintedIconName);
  final contentJson = <String, dynamic>{
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
  Map<String, String> toJson() => <String, String>{
        'appearance': appearance,
        'value': value,
      };
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
  Map<String, dynamic> toJson() => <String, dynamic>{
        'size': size,
        'idiom': idiom,
        'filename': filename,
        'scale': scale,
        if (platform != null) 'platform': platform,
        if (appearances != null) 'appearances': appearances!.map((final e) => e.toJson()).toList(),
      };
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
  Map<String, dynamic> toJson() => <String, dynamic>{
        'version': version,
        'author': author,
      };
}

/// Create a single-entry image list for `ios.single_size` mode.
List<Map<String, dynamic>> createSingleSizeImageList(final String fileNamePrefix) => <Map<String, dynamic>>[
      ContentsImageObject(
        size: '1024x1024',
        idiom: 'universal',
        filename: '$fileNamePrefix-1024x1024@1x.png',
        platform: 'ios',
        scale: '1x',
      ).toJson(),
    ];

/// Create the image list for the Contents.json file for Xcode versions Xcode 14 and above
List<Map<String, dynamic>> createImageList(
  final String fileNamePrefix,
  final String? darkFileNamePrefix,
  final String? tintedFileNamePrefix,
) {
  const imageConfigurations = <Map<String, dynamic>>[
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

  final imageList = <Map<String, dynamic>>[];

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
    for (final config in imageConfigurations.where((final e) => e['idiom'] == 'universal')) {
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
    for (final config in imageConfigurations.where((final e) => e['idiom'] == 'universal')) {
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

ColorUint8 _getBackgroundColor(final Config config) {
  final backgroundColor = config.iosConfig?.backgroundColor ?? '#ffffff';
  final (:r, :g, :b) = parseHexColor(backgroundColor);
  return ColorUint8.rgba(r, g, b, 0xff);
}

/// Mattes [source] onto the configured background color, returning an opaque 3-channel image.
Image _removeAlphaChannel(final Image source, final Config config) {
  final backgroundColor = _getBackgroundColor(config);
  final pixel = source.getPixel(0, 0);
  do {
    pixel.set(_alphaBlend(pixel, backgroundColor));
  } while (pixel.moveNext());

  return source.convert(numChannels: 3);
}

Color _alphaBlend(final Color fg, final ColorUint8 bg) {
  final converted = fg.format != Format.uint8 ? fg.convert(format: Format.uint8) : fg;
  if (converted.a == 0) {
    return bg;
  } else {
    final invAlpha = 0xff - converted.a;
    return ColorUint8.rgba(
      (converted.a * converted.r + invAlpha * bg.r) ~/ 0xff,
      (converted.a * converted.g + invAlpha * bg.g) ~/ 0xff,
      (converted.a * converted.b + invAlpha * bg.b) ~/ 0xff,
      0xff,
    );
  }
}
