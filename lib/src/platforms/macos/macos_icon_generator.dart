import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart';
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

  @override
  bool get isEnabled => context.macOSConfig?.generate ?? false;

  /// Icons directory, flavor-aware: `AppIcon-<flavor>.appiconset` for flavor runs so macOS honors flavors like iOS does (fluttercommunity/flutter_launcher_icons#638).
  String _iconsDirPath() {
    final flavor = context.flavor;
    if (flavor == null) {
      return paths.macOSIconsDirPath;
    }
    return path.join(paths.macOSAssetsDirPath, '${paths.appIconCatalogName(flavor)}${paths.appIconSetExtension}');
  }

  /// Contents.json path matching [_iconsDirPath].
  String _contentsFilePath() => path.join(_iconsDirPath(), paths.contentsJsonFileName);

  @override
  Future<void> createIcons() async {
    final imgFilePath = path.join(
      context.prefixPath,
      context.config.resolveImageFile(context.config.macOSConfig!.imagePath, context.prefixPath),
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

    // Sweep catalogs orphaned by flavor renames (reference-checked against
    // the macOS project so the build cannot break).
    final pbxprojFile = File(
      path.join(
        context.prefixPath,
        paths.macOSConfigFile,
      ),
    );
    await ios.removeOrphanedCatalogs(
      assetFolderRelative: paths.macOSAssetsDirPath,
      currentCatalog: paths.appIconCatalogName(context.flavor),
      referenceTexts: [
        if (pbxprojFile.existsSync()) await pbxprojFile.readAsString(),
      ],
      prefixPath: context.prefixPath,
      logger: context.logger,
    );

    // Flavor runs write AppIcon-<flavor>.appiconset/ but Xcode keeps
    // pointing at AppIcon until ASSETCATALOG_COMPILER_APPICON_NAME is
    // updated — the same wiring the iOS generator performs. Default runs
    // need no edit: the template already points at AppIcon. A missing
    // project file only warns: the icons themselves are still valid.
    final flavor = context.flavor;
    if (flavor != null) {
      final pbxprojPath = path.join(
        context.prefixPath,
        paths.macOSConfigFile,
      );
      if (!File(pbxprojPath).existsSync()) {
        context.logger.error(
          'macOS project.pbxproj not found at $pbxprojPath: generated '
          'AppIcon-$flavor.appiconset but Xcode will keep using the '
          'previous icon set. Set the Primary App Icon Set Name to '
          '"AppIcon-$flavor" for the $flavor configurations in Xcode.',
        );
      } else {
        await ios.changeIosLauncherIcon(
          paths.appIconCatalogName(flavor),
          flavor,
          path.join(
            context.prefixPath,
            paths.macOSXcodeprojPath,
          ),
          // The xcodeproj path above is already prefixed.
          '.',
          context.logger,
        );
      }
    }

    // Generate liquid glass .icon if configured. The bundle shares the
    // catalog name so Xcode associates it with the icon set; the PNG
    // catalog stays the fallback on macOS older than Tahoe 26.
    if (context.config.macOSConfig?.liquidGlassLayers?.isNotEmpty ?? false) {
      final glassIconName = paths.appIconCatalogName(context.flavor);
      await generateMacOSLiquidGlassIcon(
        context.config,
        glassIconName,
        logger: context.logger,
        prefixPath: context.prefixPath,
      );
      await _addLiquidGlassIconToProject(glassIconName);
    }
  }

  /// Adds the liquid glass `.icon` file reference to the macOS
  /// project.pbxproj (same reference edit the iOS generator performs). A
  /// missing project file only warns: the icons themselves are still valid.
  Future<void> _addLiquidGlassIconToProject(String iconName) async {
    final pbxprojPath = path.join(
      context.prefixPath,
      paths.macOSConfigFile,
    );
    final pbxprojFile = File(pbxprojPath);
    if (!pbxprojFile.existsSync()) {
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

  @override
  bool validateRequirements() {
    // The generate flag is enforced by [isEnabled]; only filesystem and
    // config preconditions are checked here.
    context.logger.verbose('Checking $platformName config...');
    final macOSConfig = context.macOSConfig!;

    try {
      context.config.resolveImageFile(macOSConfig.imagePath, context.prefixPath);
    } on InvalidConfigException catch (e) {
      context.logger.error(e.message);

      return false;
    }

    // The asset catalog must exist; the (flavor) icon set inside it is
    // created on demand, so a new flavor bootstraps from the CLI.
    final enitiesToCheck = [
      path.join(context.prefixPath, paths.macOSRunnerFolder),
      path.join(context.prefixPath, paths.macOSAssetsDirPath),
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
    final padding = context.macOSConfig?.padding ?? 0;
    final roundedCorners = context.macOSConfig?.roundedCorners ?? false;

    for (final template in _iconSizeTemplates) {
      final resizedImg = await effects.buildMacOSIconImage(
        loadArtwork,
        template.scaledSize,
        paddingPercent: padding,
        roundedCorners: roundedCorners,
      );
      final iconFile = await utils.createFileIfNotExist(
        path.join(context.prefixPath, iconsDir.path, template.iconFile),
      );
      await iconFile.writeAsBytes(encodePng(resizedImg));
    }
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
      // A pre-existing Contents.json may carry entries from another
      // platform or stale sizes (8x8, 64x64, 1024x1024/idiom:mac) — a
      // real-world corruption class. Warn rather than crash, then refresh
      // the tool-owned images list below.
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
