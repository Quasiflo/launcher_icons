import 'dart:io';

import 'package:launcher_icons/src/config/config.dart';
import 'package:launcher_icons/src/config/ios_config.dart';
import 'package:launcher_icons/src/config/liquid_glass_layer.dart';
import 'package:launcher_icons/src/config/macos_config.dart';
import 'package:launcher_icons/src/core/custom_exceptions.dart';
import 'package:launcher_icons/src/core/logger.dart';
import 'package:launcher_icons/src/core/paths.dart' as paths;
import 'package:launcher_icons/src/core/utils.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;

/// Generate liquid glass .icon file for iOS
Future<void> generateLiquidGlassIcon(
  Config config,
  String iconName, {
  LILogger? logger,
  String prefixPath = '.',
}) async {
  // The bundle exists exactly when the iOS struct carries layers.
  final layers = config.iosConfig?.liquidGlassLayers;
  if (layers == null || layers.isEmpty) {
    return;
  }
  final iosConfig = config.iosConfig!;

  printStatus('Creating liquid glass .icon for $iconName', logger);

  // Resolve per-appearance sources. Variants fall back to the dark/tinted app artwork so one file serves both unless explicitly overridden.
  final darkFallback = iosConfig.imagePathDarkTransparent;
  final tintedFallback = iosConfig.imagePathTintedGrayscale;

  await _writeLiquidGlassBundle(
    sources: {
      for (final layer in layers) ...[
        layer.imagePath,
        if ((layer.imagePathDark ?? darkFallback) != null) (layer.imagePathDark ?? darkFallback)!,
        if ((layer.imagePathTinted ?? tintedFallback) != null) (layer.imagePathTinted ?? tintedFallback)!,
      ],
    },
    iconFolderPath: withPrefix(prefixPath, paths.iosLiquidGlassIconPath(iconName)),
    assetsFolderPath: withPrefix(prefixPath, paths.iosLiquidGlassAssetsPath(iconName)),
    configFilePath: withPrefix(prefixPath, paths.iosLiquidGlassConfigPath(iconName)),
    iconConfig: generateIconConfig(config),
    iconFolderDisplayPath: paths.iosLiquidGlassIconPath(iconName),
    logger: logger,
    prefixPath: prefixPath,
  );
}

/// Generate liquid glass .icon file for macOS (Tahoe 26+ renders live glass from it; the PNG catalog stays the fallback on older systems).
Future<void> generateMacOSLiquidGlassIcon(
  Config config,
  String iconName, {
  LILogger? logger,
  String prefixPath = '.',
}) async {
  // The bundle exists exactly when the macOS struct carries layers.
  final layers = config.macOSConfig?.liquidGlassLayers;
  if (layers == null || layers.isEmpty) {
    return;
  }

  printStatus('Creating macOS liquid glass .icon for $iconName', logger);

  // macOS has no dark/tinted PNG catalog variants to fall back to: only explicitly configured layer sources become appearances.

  await _writeLiquidGlassBundle(
    sources: {
      for (final layer in layers) ...[
        layer.imagePath,
        if (layer.imagePathDark != null) layer.imagePathDark!,
        if (layer.imagePathTinted != null) layer.imagePathTinted!,
      ],
    },
    iconFolderPath: withPrefix(prefixPath, paths.macOSLiquidGlassIconPath(iconName)),
    assetsFolderPath: withPrefix(prefixPath, paths.macOSLiquidGlassAssetsPath(iconName)),
    configFilePath: withPrefix(prefixPath, paths.macOSLiquidGlassConfigPath(iconName)),
    iconConfig: generateMacOSIconConfig(config),
    iconFolderDisplayPath: paths.macOSLiquidGlassIconPath(iconName),
    logger: logger,
    prefixPath: prefixPath,
  );
}

/// Copies layer [sources] into the `.icon` bundle folders, sweeps orphaned layers, and writes the `icon.json` document.
Future<void> _writeLiquidGlassBundle({
  required Set<String> sources,
  required String iconFolderPath,
  required String assetsFolderPath,
  required String configFilePath,
  required Map<String, dynamic> iconConfig,
  required String iconFolderDisplayPath,
  required LILogger? logger,
  required String prefixPath,
}) async {
  // Validate every source before creating any directories so error paths leave no empty `.icon`/`Assets` litter behind (e.g. unit tests asserting the missing-source throw at the repo root used to create `ios/Runner/AppIcon.icon/Assets` as a side effect).
  final wantedBasenames = <String>{};
  for (final source in sources) {
    if (!File(withPrefix(prefixPath, source)).existsSync()) {
      throw InvalidConfigException(
        'Liquid glass icon image not found at: $source',
      );
    }
    wantedBasenames.add(path.basename(source));
  }

  await createDirIfNotExist(iconFolderPath);
  await createDirIfNotExist(assetsFolderPath);

  // Copy image(s) to Assets folder. Sources pass through verbatim and are never decoded, so SVG layers work as-is.
  for (final source in sources) {
    final sourceImageFile = File(withPrefix(prefixPath, source));
    final basename = path.basename(source);
    await sourceImageFile.copy(path.join(assetsFolderPath, basename));
  }
  // Sweep layers orphaned by source switches (e.g. PNG replaced by SVG): the Assets folder is fully tool-owned.
  for (final entity in Directory(assetsFolderPath).listSync()) {
    if (entity is File && !wantedBasenames.contains(path.basename(entity.path))) {
      printStatus(
        'Removing orphaned liquid glass asset ${path.basename(entity.path)}',
        logger,
      );
      await entity.delete();
    }
  }

  // Generate icon.json
  final configFile = await createFileIfNotExist(configFilePath);
  await configFile.writeAsString(prettifyJsonEncode(iconConfig));

  printStatus('Generated liquid glass .icon at $iconFolderDisplayPath', logger);
}

/// Resolves a per-appearance layer basename: null when unset or identical to the base image (a present base key silently wins over the specializations array, so same-file variants must not be emitted).
String? _variantName(String? source, String imageFileName) {
  if (source == null || path.basename(source) == imageFileName) {
    return null;
  }
  return path.basename(source);
}

/// Generate the icon.json configuration
@visibleForTesting
Map<String, dynamic> generateIconConfig(Config config) {
  // Fall back to defaults so direct callers don't need an ios block.
  final iosConfig = config.iosConfig ?? const IOSConfig();
  return buildLiquidGlassDocument(
    platform: 'ios',
    backgroundColor: iosConfig.backgroundColor,
    layers: iosConfig.liquidGlassLayers ?? const <LiquidGlassLayer>[],
    darkFallback: iosConfig.imagePathDarkTransparent,
    tintedFallback: iosConfig.imagePathTintedGrayscale,
    removeGlass: iosConfig.removeLiquidGlass,
    translucency: iosConfig.liquidGlassTranslucency,
    specular: iosConfig.liquidGlassSpecular,
    shadowKind: iosConfig.liquidGlassShadowKind,
    shadowOpacity: iosConfig.liquidGlassShadowOpacity,
    blur: iosConfig.liquidGlassBlur,
    lighting: iosConfig.liquidGlassLighting,
    refractivityEnabled: iosConfig.liquidGlassRefractivityEnabled,
    refractivityDepth: iosConfig.liquidGlassRefractivityDepth,
    refractivityStrength: iosConfig.liquidGlassRefractivityStrength,
    specularPlacement: iosConfig.liquidGlassSpecularHighlightPlacement,
  );
}

/// Generate the macOS icon.json configuration.
///
/// macOS shares Icon Composer's document format with iOS (one shared square design covers both); only the option source differs.
@visibleForTesting
Map<String, dynamic> generateMacOSIconConfig(Config config) {
  // Fall back to defaults so direct callers don't need a macos block.
  final macOSConfig = config.macOSConfig ?? const MacOSConfig();
  return buildLiquidGlassDocument(
    platform: 'macos',
    backgroundColor: macOSConfig.backgroundColor,
    layers: macOSConfig.liquidGlassLayers ?? const <LiquidGlassLayer>[],
    removeGlass: macOSConfig.removeLiquidGlass,
    translucency: macOSConfig.liquidGlassTranslucency,
    specular: macOSConfig.liquidGlassSpecular,
    shadowKind: macOSConfig.liquidGlassShadowKind,
    shadowOpacity: macOSConfig.liquidGlassShadowOpacity,
    blur: macOSConfig.liquidGlassBlur,
    lighting: macOSConfig.liquidGlassLighting,
    refractivityEnabled: macOSConfig.liquidGlassRefractivityEnabled,
    refractivityDepth: macOSConfig.liquidGlassRefractivityDepth,
    refractivityStrength: macOSConfig.liquidGlassRefractivityStrength,
    specularPlacement: macOSConfig.liquidGlassSpecularHighlightPlacement,
  );
}

/// Blend modes Icon Composer accepts on a layer.
const _blendModes = <String>{
  'normal',
  'plus-lighter',
  'plus-darker',
  'overlay',
  'multiply',
  'soft-light',
  'hard-light',
  'darken',
  'lighten',
  'screen',
};

/// Converts [hex] to display P3, labelling failures with the config [key].
String _displayP3(String hex, String key) {
  try {
    return convertHexToDisplayP3(hex);
  } on InvalidConfigException catch (e) {
    throw InvalidConfigException('$key must be a hex color: ${e.message}');
  }
}

/// Builds the Icon Composer `icon.json` document from explicit values.
///
/// [platform] labels validation errors (`ios` or `macos`). [layers] stack bottom-to-top in list order inside one group sharing the group's glass pass. Optical pass-throughs are opt-in so unset keys stay out of the document and historical output is byte-identical.
@visibleForTesting
Map<String, dynamic> buildLiquidGlassDocument({
  required String platform,
  required String backgroundColor,
  required List<LiquidGlassLayer> layers,
  String? darkFallback,
  String? tintedFallback,
  required bool removeGlass,
  required double? translucency,
  required bool specular,
  required String shadowKind,
  required double? shadowOpacity,
  required double? blur,
  required String? lighting,
  required bool? refractivityEnabled,
  required double? refractivityDepth,
  required double? refractivityStrength,
  required String? specularPlacement,
}) {
  // Convert background color to display P3 format
  final displayP3Color = convertHexToDisplayP3(backgroundColor);

  // Validate shadow kind
  if (shadowKind.toLowerCase() != 'neutral' && shadowKind.toLowerCase() != 'chromatic') {
    throw InvalidConfigException(
      '$platform.liquid_glass_shadow_kind must be either "Neutral" or "Chromatic", got: $shadowKind',
    );
  }

  // Optical pass-throughs. All are opt-in so unset keys stay out of the document and historical output is byte-identical.
  if (lighting != null && lighting != 'individual' && lighting != 'combined') {
    throw InvalidConfigException(
      '$platform.liquid_glass_lighting must be either "individual" or "combined", got: $lighting',
    );
  }
  Map<String, dynamic>? refractivity;
  if (refractivityEnabled == true) {
    if (refractivityDepth == null || refractivityStrength == null) {
      throw InvalidConfigException(
        '$platform.liquid_glass_refractivity_enabled requires '
        '`liquid_glass_refractivity_depth` and '
        '`liquid_glass_refractivity_strength`.',
      );
    }
    refractivity = {
      'enabled': true,
      'depth': refractivityDepth,
      'strength': refractivityStrength,
    };
  }
  if (specularPlacement != null && specularPlacement != 'inside' && specularPlacement != 'outside') {
    throw InvalidConfigException(
      '$platform.liquid_glass_specular_highlight_placement must be either "inside" or "outside", got: $specularPlacement',
    );
  }

  // NOTE: no top-level `features` declaration is emitted. It is optional per the format (the keys below stand alone), and actool rejects the array with an internal error — verified against Xcode 26.6.

  final layersJson = <Map<String, dynamic>>[];
  for (var i = 0; i < layers.length; i++) {
    layersJson.add(
      _buildLayer(
        platform,
        i,
        layers[i],
        darkFallback: darkFallback,
        tintedFallback: tintedFallback,
        removeGlass: removeGlass,
      ),
    );
  }

  return {
    'fill': {
      'solid': displayP3Color,
    },
    'groups': [
      {
        'blur-material': blur,
        if (lighting != null) 'lighting': lighting,
        'layers': layersJson,
        if (refractivity != null) 'refractivity': refractivity,
        'shadow': {
          'kind': shadowKind.toLowerCase() == 'chromatic' ? 'layer-color' : shadowKind.toLowerCase(),
          'opacity': shadowOpacity,
        },
        'specular': specular,
        if (specularPlacement != null) 'specular-highlight-placement': specularPlacement,
        'translucency': {
          'enabled': !removeGlass,
          'value': translucency ?? 0.5,
        },
      },
    ],
    'supported-platforms': {
      'circles': ['watchOS'],
      'squares': 'shared',
    },
  };
}

/// Builds one Icon Composer layer document from [layer], validating the per-layer composition keys and resolving appearance variants against the [darkFallback]/[tintedFallback] catalog sources.
Map<String, dynamic> _buildLayer(
  String platform,
  int index,
  LiquidGlassLayer layer, {
  required String? darkFallback,
  required String? tintedFallback,
  required bool removeGlass,
}) {
  final label = '$platform.liquid_glass_layers[$index]';

  final opacity = layer.opacity;
  if (opacity != null && (opacity < 0.0 || opacity > 1.0)) {
    throw InvalidConfigException(
      '$label.opacity must be between 0.0 and 1.0, got: $opacity',
    );
  }

  final blendMode = layer.blendMode?.toLowerCase();
  if (blendMode != null && !_blendModes.contains(blendMode)) {
    throw InvalidConfigException(
      '$label.blend_mode must be one of ${_blendModes.join(', ')}, '
      'got: ${layer.blendMode}',
    );
  }

  // Extract image name without extension for the layer name
  final imageFileName = path.basename(layer.imagePath);
  final imageName = path.basenameWithoutExtension(imageFileName);

  final darkName = _variantName(
    layer.imagePathDark ?? darkFallback,
    imageFileName,
  );
  final tintedName = _variantName(
    layer.imagePathTinted ?? tintedFallback,
    imageFileName,
  );

  final doc = <String, dynamic>{
    'glass': !removeGlass && layer.glass,
    'hidden': false,
    'name': imageName,
    'position': {
      'scale': layer.scale,
      'translation-in-points': [
        layer.offsetX ?? 0.0,
        layer.offsetY ?? 0.0,
      ],
    },
  };
  if (opacity != null) {
    doc['opacity'] = opacity;
  }
  if (blendMode != null) {
    doc['blend-mode'] = blendMode;
  }
  if (darkName == null && tintedName == null) {
    doc['image-name'] = imageFileName;
  } else {
    doc['image-name-specializations'] = [
      {'value': imageFileName},
      if (darkName != null) {'appearance': 'dark', 'value': darkName},
      if (tintedName != null) {'appearance': 'tinted', 'value': tintedName},
    ];
  }

  // A recolor tint for the artwork. Like image-name, the plain key and the specializations array are mutually exclusive (the plain key silently wins), so a lone fill stays flat and variants become an array. The base value is the first set key, so a variant-only tint still emits.
  final fill = layer.fill;
  final fillDark = layer.fillDark;
  final fillTinted = layer.fillTinted;
  final fillBase = fill ?? fillDark ?? fillTinted;
  if (fillBase != null && fillDark == null && fillTinted == null) {
    doc['fill'] = {'solid': _displayP3(fillBase, '$label.fill')};
  } else if (fillBase != null) {
    doc['fill-specializations'] = [
      {
        'value': {'solid': _displayP3(fillBase, '$label.fill')},
      },
      if (fillDark != null)
        {
          'appearance': 'dark',
          'value': {'solid': _displayP3(fillDark, '$label.fill_dark')},
        },
      if (fillTinted != null)
        {
          'appearance': 'tinted',
          'value': {'solid': _displayP3(fillTinted, '$label.fill_tinted')},
        },
    ];
  }

  return doc;
}

/// Convert hex color to Display P3 format (as used by Apple Icon Composer)
@visibleForTesting
String convertHexToDisplayP3(String hexColor) {
  final (:r, :g, :b) = parseHexColor(hexColor);

  return 'display-p3:${(r / 255).toStringAsFixed(5)},'
      '${(g / 255).toStringAsFixed(5)},'
      '${(b / 255).toStringAsFixed(5)},1.00000';
}
