import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart';
import 'package:launcher_icons/src/config/liquid_glass_group.dart';
import 'package:launcher_icons/src/config/liquid_glass_layer.dart';
import 'package:launcher_icons/src/core/custom_exceptions.dart';
import 'package:launcher_icons/src/core/icon_generator.dart';
import 'package:launcher_icons/src/core/paths.dart' as paths;
import 'package:launcher_icons/src/core/utils.dart' as utils;
import 'package:launcher_icons/src/platforms/ios/ios.dart' as ios;
import 'package:launcher_icons/src/platforms/ios/liquid_glass_icon_generator.dart';
import 'package:launcher_icons/src/platforms/macos/macos_icon_effects.dart' as effects;
import 'package:launcher_icons/src/platforms/macos/macos_icon_template.dart';
import 'package:path/path.dart' as path;

/// A [IconGenerator] implementation for macos
class MacOSIconGenerator extends IconGenerator {
  static const _iconSizeTemplates = <MacOSIconTemplate>[
    MacOSIconTemplate(16, 1),
    MacOSIconTemplate(16, 2),
    MacOSIconTemplate(32, 1),
    MacOSIconTemplate(32, 2),
    MacOSIconTemplate(128, 1),
    MacOSIconTemplate(128, 2),
    MacOSIconTemplate(256, 1),
    MacOSIconTemplate(256, 2),
    MacOSIconTemplate(512, 1),
    MacOSIconTemplate(512, 2),
  ];

  /// Creates a instance of [MacOSIconGenerator]
  MacOSIconGenerator(IconGeneratorContext context) : super(context, 'MacOS');

  /// Catalog name for this run: a custom `icon_name` wins off-flavor (like iOS), otherwise `AppIcon-<flavor>` for flavor runs, else `AppIcon`.
  String _catalogName() {
    final iconName = context.config.macOSConfig?.iconName;
    if (iconName != null && context.flavor == null) {
      return iconName;
    }
    return paths.appIconCatalogName(context.flavor);
  }

  /// Icons directory for [_catalogName]: `AppIcon-<flavor>.appiconset` for flavor runs so macOS honors flavors like iOS does.
  String _iconsDirPath() {
    return path.join(paths.macOSAssetsDirPath, '${_catalogName()}${paths.appIconSetExtension}');
  }

  /// Contents.json path matching [_iconsDirPath].
  String _contentsFilePath() => path.join(_iconsDirPath(), paths.contentsJsonFileName);

  @override
  Future<void> createIcons() async {
    final macOSConfig = context.config.macOSConfig!;
    final bool iconOnly = macOSConfig.iconOnly;
    final bool hasGlass = (macOSConfig.liquidGlassLayers?.isNotEmpty ?? false) || (macOSConfig.liquidGlassGroups?.isNotEmpty ?? false);
    if (iconOnly && !hasGlass) {
      throw const InvalidConfigException(
        '`macos.icon_only` requires `liquid_glass_layers` or `liquid_glass_groups`: there is nothing else to emit.',
      );
    }
    final flavor = context.flavor;
    if (flavor != null && macOSConfig.iconName != null) {
      // A flavor run always writes `AppIcon-<flavor>`; say so instead of silently dropping the custom name.
      context.logger.info(
        'Ignoring `macos.icon_name` "${macOSConfig.iconName}" for flavor "$flavor": flavor runs always write `AppIcon-$flavor`.',
      );
    }

    if (!iconOnly) {
      final imgFilePath = path.join(
        context.prefixPath,
        context.config.resolveImageFile(macOSConfig.imagePath, context.prefixPath),
      );

      context.logger.verbose('Decoding and loading image file at $imgFilePath...');
      final loadArtwork = await utils.sizeImageLoaderFor(
        imgFilePath,
        logger: context.logger,
        cache: context.svgRasterCache,
      );

      context.logger.verbose('Generating icons $imgFilePath...');
      await _generateIcons(loadArtwork);
      context.logger.verbose('Updating contents.json');
      _updateContentsFile();
    } else {
      context.logger.info(
        'Skipping the PNG asset catalog (`macos.icon_only`): emitting ${_catalogName()}.icon only — set the target\'s App Icon to it in Xcode.',
      );
    }

    // Flavor runs write AppIcon-<flavor>.appiconset/ but Xcode keeps pointing at AppIcon until ASSETCATALOG_COMPILER_APPICON_NAME is updated — the same wiring the iOS generator performs. Default runs need no edit: the template already points at AppIcon. Icon-only runs need no edit either: the target points at the `.icon` instead. A missing project file only warns: the icons themselves are still valid.
    if (flavor != null && !iconOnly) {
      final xcodeprojPath = resolveMacOSXcodeprojPath(
        macOSConfig.xcodeprojPath,
        context.prefixPath,
      );
      final pbxprojPath = xcodeprojPath == null ? null : path.join(xcodeprojPath, paths.pbxprojFileName);
      if (pbxprojPath == null || !File(pbxprojPath).existsSync()) {
        context.logger.error(
          'macOS project.pbxproj not found${pbxprojPath == null ? '' : ' at $pbxprojPath'}: generated '
          'AppIcon-$flavor.appiconset but Xcode will keep using the '
          'previous icon set. Set the Primary App Icon Set Name to '
          '"AppIcon-$flavor" for the $flavor configurations in Xcode.',
        );
      } else {
        await ios.changeIosLauncherIcon(
          paths.appIconCatalogName(flavor),
          flavor,
          xcodeprojPath,
          // The xcodeproj path above is already resolved (and prefixed).
          '.',
          context.logger,
        );
      }
    }

    // Sweep catalogs orphaned by flavor renames. Runs after the flavor rewire above so the just-wired catalog is visible in the references (like iOS); reference-checked against the macOS project plus any xcconfigs so the build cannot break. Still-referenced sibling flavors are kept.
    await ios.removeOrphanedCatalogs(
      assetFolderRelative: paths.macOSAssetsDirPath,
      currentCatalog: _catalogName(),
      referenceTexts: await macOSCatalogReferenceTexts(prefixPath: context.prefixPath),
      prefixPath: context.prefixPath,
      logger: context.logger,
    );

    // Generate liquid glass .icon if configured (the only output in `icon_only` mode). The bundle shares the catalog name so Xcode associates it with the icon set; the PNG catalog stays the fallback on macOS older than Tahoe 26.
    if (hasGlass) {
      final glassIconName = _catalogName();
      await generateMacOSLiquidGlassIcon(
        context.config,
        glassIconName,
        logger: context.logger,
        prefixPath: context.prefixPath,
      );
      await _addLiquidGlassIconToProject(glassIconName);
    } else {
      // Dropping the layers orphans the previous bundle: collect it and its project reference so stale glass doesn't ship (sibling catalogs' bundles are left alone).
      final staleDir = Directory(
        path.join(context.prefixPath, paths.macOSLiquidGlassIconPath(_catalogName())),
      );
      if (staleDir.existsSync()) {
        context.logger.info(
          'Removing stale liquid glass bundle ${paths.macOSLiquidGlassIconPath(_catalogName())} (no layers configured for ${_catalogName()})',
        );
        await staleDir.delete(recursive: true);
        await _removeLiquidGlassIconFromProject(_catalogName());
      }
    }
  }

  /// Adds the liquid glass `.icon` file reference to the macOS project.pbxproj (same reference edit the iOS generator performs). A missing project file only warns: the icons themselves are still valid.
  Future<void> _addLiquidGlassIconToProject(String iconName) async {
    final pbxprojPath = resolveMacOSPbxprojPath(
      context.config.macOSConfig?.xcodeprojPath,
      context.prefixPath,
    );
    final pbxprojFile = pbxprojPath == null ? null : File(pbxprojPath);
    if (pbxprojFile == null || !pbxprojFile.existsSync()) {
      context.logger.verbose(
        'macOS project.pbxproj not found at $pbxprojPath: skipping .icon '
        'reference addition (add $iconName.icon to the Xcode project '
        'manually).',
      );
      return;
    }
    final wholeFile = await pbxprojFile.readAsString();
    final changedFile = ios.addLiquidGlassIconReference(wholeFile, iconName);
    if (changedFile == wholeFile) {
      context.logger.verbose(
        'Liquid glass .icon reference already exists in macOS project.pbxproj',
      );
      return;
    }
    await pbxprojFile.writeAsString(changedFile);
    context.logger.verbose(
      'Added liquid glass .icon reference to macOS project.pbxproj',
    );
  }

  /// Removes the liquid glass `.icon` file reference for [iconName] from the macOS project.pbxproj (the inverse of [_addLiquidGlassIconToProject]). A missing project file is a no-op: the icons themselves are still valid.
  Future<void> _removeLiquidGlassIconFromProject(String iconName) async {
    final pbxprojPath = resolveMacOSPbxprojPath(
      context.config.macOSConfig?.xcodeprojPath,
      context.prefixPath,
    );
    if (pbxprojPath == null || !File(pbxprojPath).existsSync()) {
      return;
    }
    final wholeFile = await File(pbxprojPath).readAsString();
    final changedFile = ios.removeLiquidGlassIconReference(wholeFile, iconName);
    if (changedFile == wholeFile) {
      return;
    }
    await File(pbxprojPath).writeAsString(changedFile);
    context.logger.verbose(
      'Removed liquid glass .icon reference to $iconName.icon from macOS project.pbxproj',
    );
  }

  @override
  bool validateRequirements() {
    // The generate flag is enforced by the caller via the config enabled flag; only filesystem and config preconditions are checked here.
    context.logger.verbose('Checking $platformName config...');
    final macOSConfig = context.config.macOSConfig!;

    final bool iconOnly = macOSConfig.iconOnly;
    final bool hasGlass = (macOSConfig.liquidGlassLayers?.isNotEmpty ?? false) || (macOSConfig.liquidGlassGroups?.isNotEmpty ?? false);
    if (iconOnly && !hasGlass) {
      context.logger.error(
        '`macos.icon_only` requires `liquid_glass_layers` or `liquid_glass_groups`: there is nothing else to emit.',
      );
      return false;
    }

    // The PNG catalog needs a base image; icon-only runs render the `.icon` from layer sources alone.
    if (!iconOnly) {
      try {
        context.config.resolveImageFile(macOSConfig.imagePath, context.prefixPath);
      } on InvalidConfigException catch (e) {
        context.logger.error(e.message);

        return false;
      }
    }

    // Glass layer sources must exist (layers and groups alike): a missing file would otherwise surface deep inside bundle writing instead of up-front validation.
    bool glassSourceOk(String label, LiquidGlassLayer layer) {
      for (final entry in {
        'image_path': layer.imagePath,
        'image_path_dark': layer.imagePathDark,
        'image_path_tinted': layer.imagePathTinted,
      }.entries) {
        final source = entry.value;
        if (source != null && !File(utils.withPrefix(context.prefixPath, source)).existsSync()) {
          context.logger.error(
            'Invalid `$label.${entry.key}` "$source": file does not exist.',
          );
          return false;
        }
      }
      return true;
    }

    final flatLayers = macOSConfig.liquidGlassLayers ?? const <LiquidGlassLayer>[];
    for (var i = 0; i < flatLayers.length; i++) {
      if (!glassSourceOk('macos.liquid_glass_layers[$i]', flatLayers[i])) {
        return false;
      }
    }
    final explicitGroups = macOSConfig.liquidGlassGroups ?? const <LiquidGlassGroup>[];
    for (var gi = 0; gi < explicitGroups.length; gi++) {
      final groupLayers = explicitGroups[gi].layers ?? const <LiquidGlassLayer>[];
      for (var li = 0; li < groupLayers.length; li++) {
        if (!glassSourceOk('macos.liquid_glass_groups[$gi].layers[$li]', groupLayers[li])) {
          return false;
        }
      }
    }

    // The asset catalog must exist for PNG runs; the (flavor/icon_name) set inside it is created on demand, so a new flavor bootstraps from the CLI. Icon-only runs only need the Runner folder: the `.icon` bundle is created on demand.
    final enitiesToCheck = [
      path.join(context.prefixPath, paths.macOSRunnerFolder),
      if (!iconOnly) path.join(context.prefixPath, paths.macOSAssetsDirPath),
    ];

    final failedEntityPath = utils.areFSEntiesExist(enitiesToCheck);
    if (failedEntityPath != null) {
      context.logger.error(
        '$failedEntityPath this file or folder is required to generate $platformName icons',
      );
      return false;
    }

    return true;
  }

  Future<void> _generateIcons(
    Future<Image> Function(int) loadArtwork,
  ) async {
    final iconsDir = await utils.createDirIfNotExist(
      path.join(context.prefixPath, _iconsDirPath()),
    );
    final padding = context.config.macOSConfig?.padding ?? 0;
    final roundedCorners = context.config.macOSConfig?.roundedCorners ?? false;

    // Several templates share a pixel size (16@2x == 32@1x == 32px, and so on):
    // render each distinct size once and write the same bytes to every file
    // that needs it. The encoder is deterministic, so output is byte-identical
    // to the old per-template loop at a fraction of the raster cost.
    final bySize = <int, List<MacOSIconTemplate>>{};
    for (final template in _iconSizeTemplates) {
      bySize.putIfAbsent(template.scaledSize, () => <MacOSIconTemplate>[]).add(template);
    }
    await Future.wait(
      bySize.entries.map((entry) async {
        final resizedImg = await effects.buildMacOSIconImage(
          loadArtwork,
          entry.key,
          paddingPercent: padding,
          roundedCorners: roundedCorners,
        );
        final bytes = encodePng(resizedImg);
        for (final template in entry.value) {
          final iconFile = await utils.createFileIfNotExist(
            path.join(context.prefixPath, iconsDir.path, template.iconFile),
          );
          await iconFile.writeAsBytes(bytes);
        }
      }),
    );
  }

  void _updateContentsFile() {
    final contentsFilePath = File(path.join(context.prefixPath, _contentsFilePath()));
    Map<String, dynamic>? contentsConfig;
    try {
      contentsConfig = jsonDecode(contentsFilePath.readAsStringSync()) as Map<String, dynamic>;
    } on FormatException catch (_) {
      contentsConfig = null;
    } on FileSystemException catch (_) {
      // No pre-existing set (e.g. a brand-new flavor): start fresh.
      contentsConfig = null;
    }
    if (contentsConfig == null) {
      if (contentsFilePath.existsSync()) {
        context.logger.info(
          'WARNING: ${_contentsFilePath()} is not valid JSON; '
          'writing a fresh image list.',
        );
      }
      contentsConfig = {
        'info': {'version': 1, 'author': 'xcode'},
      };
    } else {
      // A pre-existing Contents.json may carry entries from another platform or stale sizes (8x8, 64x64, 1024x1024/idiom:mac) — a real-world corruption class. Warn rather than crash, then refresh the tool-owned images list below.
      final existing = contentsConfig['images'];
      if (existing is List) {
        final foreign = <String>[];
        for (final entry in existing) {
          if (entry is! Map) {
            continue;
          }
          final idiom = entry['idiom'];
          final size = entry['size'];
          if (idiom != 'mac' || size == '8x8' || size == '64x64' || size == '1024x1024') {
            foreign.add('${size ?? '?'}${idiom == null ? '' : '/$idiom'}');
          }
        }
        if (foreign.isNotEmpty) {
          context.logger.info(
            'WARNING: ${_contentsFilePath()} contains non-mac entries '
            '(${foreign.join(', ')}); replacing the image list.',
          );
        }
      }
    }
    contentsConfig
      ..remove('images')
      ..['images'] = _iconSizeTemplates.map<Map<String, dynamic>>((e) => e.iconContent).toList();

    contentsFilePath.writeAsStringSync(utils.prettifyJsonEncode(contentsConfig));
  }
}

/// Resolves the macOS Xcode project directory to edit.
///
/// Prefers an explicit [xcodeprojPath] (`macos.xcodeproj_path`), then the standard `macos/Runner.xcodeproj` location, then the first `*.xcodeproj` found under `macos/` so renamed Runner projects keep working (the iOS generator's `resolveIosPbxprojPath` equivalent). Returns `null` when no project exists.
String? resolveMacOSXcodeprojPath([
  String? xcodeprojPath,
  String prefixPath = '.',
]) {
  if (xcodeprojPath != null) {
    return utils.withPrefix(prefixPath, xcodeprojPath);
  }
  final standardDir = utils.withPrefix(prefixPath, paths.macOSXcodeprojPath);
  if (File(path.join(standardDir, paths.pbxprojFileName)).existsSync()) {
    return standardDir;
  }
  final macosDir = Directory(utils.withPrefix(prefixPath, paths.macOSDirPath));
  if (macosDir.existsSync()) {
    final candidates = macosDir.listSync().whereType<Directory>().where((dir) => dir.path.endsWith(paths.xcodeprojExtension)).toList()..sort((a, b) => a.path.compareTo(b.path));
    for (final dir in candidates) {
      if (File(path.join(dir.path, paths.pbxprojFileName)).existsSync()) {
        return dir.path;
      }
    }
  }
  return null;
}

/// Resolves the macOS project.pbxproj file to edit (see [resolveMacOSXcodeprojPath]). Returns `null` when no project exists.
String? resolveMacOSPbxprojPath([
  String? xcodeprojPath,
  String prefixPath = '.',
]) {
  final dir = resolveMacOSXcodeprojPath(xcodeprojPath, prefixPath);
  return dir == null ? null : path.join(dir, paths.pbxprojFileName);
}

/// Reads the reference texts for macOS catalog orphan detection: the macOS
/// project.pbxproj plus every `macos/Flutter/*.xcconfig` when present
/// (macOS flavors are pbxproj-wired today; the xcconfig scan future-proofs a
/// flavor_mode port and costs nothing when the directory is absent).
Future<List<String>> macOSCatalogReferenceTexts({String prefixPath = '.'}) async {
  final references = <String>[];
  final pbxprojFile = File(path.join(prefixPath, paths.macOSConfigFile));
  if (pbxprojFile.existsSync()) {
    references.add(await pbxprojFile.readAsString());
  }
  final flutterDir = Directory(path.join(prefixPath, 'macos', 'Flutter'));
  if (flutterDir.existsSync()) {
    for (final entity in flutterDir.listSync().whereType<File>()) {
      if (entity.path.endsWith('.xcconfig')) {
        references.add(await entity.readAsString());
      }
    }
  }
  return references;
}
