import 'dart:io';

import 'package:image/image.dart';
import 'package:launcher_icons/src/config/config.dart';
import 'package:launcher_icons/src/core/constants.dart' as constants;
import 'package:launcher_icons/src/core/custom_exceptions.dart';
import 'package:launcher_icons/src/core/errors.dart' as errors;
import 'package:launcher_icons/src/core/logger.dart';
import 'package:launcher_icons/src/core/paths.dart' as paths;
import 'package:launcher_icons/src/core/utils.dart' as utils;
import 'package:launcher_icons/src/platforms/android/xml_templates.dart'
    as xml_template;

/// A legacy launcher icon density target: [directoryName] under the
/// flavor-aware res folder, rendered at [size] px square.
class AndroidIconTemplate {
  /// Creates an instance of [AndroidIconTemplate].
  AndroidIconTemplate({required this.size, required this.directoryName});

  /// Resource directory name (e.g. `mipmap-xxxhdpi`).
  final String directoryName;

  /// Icon edge length in pixels.
  final int size;
}

/// Adaptive foreground/background density targets (108dp layers).
final List<AndroidIconTemplate> adaptiveForegroundIcons = <AndroidIconTemplate>[
  AndroidIconTemplate(directoryName: 'drawable-mdpi', size: 108),
  AndroidIconTemplate(directoryName: 'drawable-hdpi', size: 162),
  AndroidIconTemplate(directoryName: 'drawable-xhdpi', size: 216),
  AndroidIconTemplate(directoryName: 'drawable-xxhdpi', size: 324),
  AndroidIconTemplate(directoryName: 'drawable-xxxhdpi', size: 432),
];

/// Legacy mipmap density targets (48dp across 1x–4x).
List<AndroidIconTemplate> androidIcons = <AndroidIconTemplate>[
  AndroidIconTemplate(directoryName: 'mipmap-mdpi', size: 48),
  AndroidIconTemplate(directoryName: 'mipmap-hdpi', size: 72),
  AndroidIconTemplate(directoryName: 'mipmap-xhdpi', size: 96),
  AndroidIconTemplate(directoryName: 'mipmap-xxhdpi', size: 144),
  AndroidIconTemplate(directoryName: 'mipmap-xxxhdpi', size: 192),
];

/// Creates the legacy mipmap icons (overwriting defaults, or adding a new icon when `android.icon_name` is set) and wires the manifest.
Future<void> createDefaultIcons(
  Config config,
  String? flavor, {
  LILogger? logger,
  String prefixPath = '.',
  utils.SvgRasterCache? cache,
}) async {
  utils.printStatus('Creating default icons Android', logger);
  final String? filePath = config.getImagePathAndroid();
  if (filePath == null) {
    throw const InvalidConfigException(errors.errorMissingImagePath);
  }
  final loadSize = await utils.sizeImageLoaderFor(
    utils.withPrefix(prefixPath, filePath),
    logger: logger,
    cache: cache,
  );
  final File androidManifestFile =
      File(utils.withPrefix(prefixPath, paths.androidManifestFile));
  final concurrentIconUpdates = <Future<void>>[];
  if (config.isCustomAndroidFile) {
    utils.printStatus('Adding a new Android launcher icon', logger);
    final String iconName = config.androidConfig!.iconName!;
    isAndroidIconNameCorrectFormat(iconName);
    final String iconPath = '$iconName.png';
    for (AndroidIconTemplate template in androidIcons) {
      concurrentIconUpdates.add(
        loadSize(template.size).then(
          (image) => writeResizedPng(
            template,
            image,
            iconPath,
            flavor,
            prefixPath: prefixPath,
          ),
        ),
      );
    }
    await removeStaleLegacyIconsForSwitch(
      androidManifestFile,
      iconName,
      flavor,
      logger: logger,
      prefixPath: prefixPath,
    );
    await overwriteAndroidManifestWithNewLauncherIcon(
      iconName,
      androidManifestFile,
      roundIconName: config.hasAndroidAdaptiveRoundConfig
          ? androidAdaptiveRoundXmlName(config)
          : null,
      logger: logger,
    );
  } else {
    utils.printStatus(
      'Overwriting the default Android launcher icon with a new icon',
      logger,
    );
    for (AndroidIconTemplate template in androidIcons) {
      concurrentIconUpdates.add(
        loadSize(template.size).then(
          (image) => writeResizedPng(
            template,
            image,
            constants.androidFileName,
            flavor,
            prefixPath: prefixPath,
          ),
        ),
      );
    }
    await removeStaleLegacyIconsForSwitch(
      androidManifestFile,
      constants.androidDefaultIconName,
      flavor,
      logger: logger,
      prefixPath: prefixPath,
    );
    await overwriteAndroidManifestWithNewLauncherIcon(
      constants.androidDefaultIconName,
      androidManifestFile,
      roundIconName: config.hasAndroidAdaptiveRoundConfig
          ? androidAdaptiveRoundXmlName(config)
          : null,
      logger: logger,
    );
  }
  await Future.wait(concurrentIconUpdates);
}

/// Deletes legacy `<old>.png` files after an icon-name switch.
///
/// The manifest's previous icon name proves tool ownership: only the tool writes custom names there. `ic_launcher` (possibly Flutter's originals) and the incoming name are never touched.
Future<void> removeStaleLegacyIconsForSwitch(
  File androidManifestFile,
  String newIconName,
  String? flavor, {
  LILogger? logger,
  String prefixPath = '.',
}) async {
  if (!androidManifestFile.existsSync()) {
    return;
  }
  final content = await androidManifestFile.readAsString();
  final match = RegExp(r'android:icon="@mipmap/([^"]+)"').firstMatch(content);
  final oldIconName = match?.group(1);
  if (oldIconName == null ||
      oldIconName == newIconName ||
      oldIconName == constants.androidDefaultIconName) {
    return;
  }
  for (final template in androidIcons) {
    final file = File(
      utils.withPrefix(
        prefixPath,
        paths.androidResFolder(flavor) +
            template.directoryName +
            '/' +
            '$oldIconName.png',
      ),
    );
    if (file.existsSync()) {
      utils.printStatus(
        'Removing stale legacy icon file $oldIconName.png after switch to $newIconName',
        logger,
      );
      await file.delete();
    }
  }
}

/// Ensures that the Android icon name is in the correct format
bool isAndroidIconNameCorrectFormat(String iconName) {
  // assure the icon only consists of lowercase letters, numbers and underscore
  if (!RegExp(r'^[a-z0-9_]+$').hasMatch(iconName)) {
    throw const InvalidAndroidIconNameException(
      errors.errorIncorrectIconName,
    );
  }
  return true;
}

/// Creates the adaptive foreground/background icons and `colors.xml`
/// entries.
Future<void> createAdaptiveIcons(
  Config config,
  String? flavor, {
  LILogger? logger,
  String prefixPath = '.',
  utils.SvgRasterCache? cache,
}) async {
  utils.printStatus('Creating adaptive icons Android', logger);

  // Retrieve the necessary Flutter Launcher Icons configuration from the pubspec.yaml file
  final androidConfig = config.androidConfig!;
  final String? backgroundConfig = androidConfig.adaptiveIconBackground;
  final String? foregroundImagePath = androidConfig.adaptiveIconForeground;
  if (backgroundConfig == null || foregroundImagePath == null) {
    throw const InvalidConfigException(errors.errorMissingImagePath);
  }
  final loadForegroundSize = await utils.sizeImageLoaderFor(
    utils.withPrefix(prefixPath, foregroundImagePath),
    logger: logger,
    cache: cache,
  );

  final concurrentImageUpdates = <Future<void>>[];
  // Create adaptive icon foreground images
  for (AndroidIconTemplate androidIcon in adaptiveForegroundIcons) {
    concurrentImageUpdates.add(
      loadForegroundSize(androidIcon.size).then(
        (foregroundImage) => writeResizedPng(
          androidIcon,
          foregroundImage,
          constants.androidAdaptiveForegroundFileName,
          flavor,
          prefixPath: prefixPath,
        ),
      ),
    );
  }

  // Create adaptive icon background
  if (isTransparentAdaptiveBackground(backgroundConfig)) {
    utils.printStatus(
      'Using transparent adaptive icon background (@android:color/transparent)',
      logger,
    );
  } else if (isAdaptiveIconConfigImageFile(backgroundConfig)) {
    concurrentImageUpdates.add(
      _createAdaptiveBackgrounds(
        config,
        backgroundConfig,
        flavor,
        prefixPath: prefixPath,
        cache: cache,
      ),
    );
  } else {
    // colors.xml has a single writer (this branch) and is awaited before the foreground/background fan-out below, so no locking is needed despite the concurrent PNG writes.
    await updateColorsXmlFile(
      backgroundConfig,
      flavor,
      logger: logger,
      prefixPath: prefixPath,
    );
  }
  await Future.wait(concurrentImageUpdates);
}

/// Creates the adaptive monochrome icons.
Future<void> createAdaptiveMonochromeIcons(
  Config config,
  String? flavor, {
  LILogger? logger,
  String prefixPath = '.',
  utils.SvgRasterCache? cache,
}) async {
  utils.printStatus('Creating adaptive monochrome icons Android', logger);

  // Retrieve the necessary Flutter Launcher Icons configuration from the pubspec.yaml file
  final String? monochromeImagePath =
      config.androidConfig!.adaptiveIconMonochrome;
  if (monochromeImagePath == null) {
    throw const InvalidConfigException(errors.errorMissingImagePath);
  }
  final loadMonochromeSize = await utils.sizeImageLoaderFor(
    utils.withPrefix(prefixPath, monochromeImagePath),
    logger: logger,
    cache: cache,
  );

  final concurrentIconUpdates = <Future<void>>[];
  // Create adaptive icon monochrome images
  for (AndroidIconTemplate androidIcon in adaptiveForegroundIcons) {
    concurrentIconUpdates.add(
      loadMonochromeSize(androidIcon.size).then(
        (monochromeImage) => writeResizedPng(
          androidIcon,
          monochromeImage,
          constants.androidAdaptiveMonochromeFileName,
          flavor,
          prefixPath: prefixPath,
        ),
      ),
    );
  }
  await Future.wait(concurrentIconUpdates);
}

/// Round-icon resource name: `<custom>_round` for custom icons,
/// `ic_launcher_round` otherwise.
String androidAdaptiveRoundXmlName(Config config) {
  final customName = config.androidConfig?.iconName;
  return customName != null
      ? '${customName}_round'
      : constants.androidAdaptiveRoundIconName;
}

/// Creates the opt-in adaptive round icons.
Future<void> createAdaptiveRoundIcons(
  Config config,
  String? flavor, {
  LILogger? logger,
  String prefixPath = '.',
  utils.SvgRasterCache? cache,
}) async {
  utils.printStatus('Creating adaptive round icons Android', logger);

  final String? roundImagePath = config.androidConfig?.adaptiveIconRound;
  if (roundImagePath == null) {
    throw const InvalidConfigException(errors.errorMissingImagePath);
  }
  if (!config.hasAndroidAdaptiveConfig) {
    throw const InvalidConfigException(
      'Invalid `adaptive_icon_round`: requires `adaptive_icon_background` '
      'and `adaptive_icon_foreground`.',
    );
  }
  final loadRoundSize = await utils.sizeImageLoaderFor(
    utils.withPrefix(prefixPath, roundImagePath),
    logger: logger,
    cache: cache,
  );

  final concurrentIconUpdates = <Future<void>>[];
  // Create adaptive icon round images
  for (AndroidIconTemplate androidIcon in adaptiveForegroundIcons) {
    concurrentIconUpdates.add(
      loadRoundSize(androidIcon.size).then(
        (roundImage) => writeResizedPng(
          androidIcon,
          roundImage,
          constants.androidAdaptiveRoundFileName,
          flavor,
          prefixPath: prefixPath,
        ),
      ),
    );
  }
  await Future.wait(concurrentIconUpdates);
}

/// Emits the 512x512 Play Store upload icon next to the project.
///
/// This is a store-upload artifact, never an `android/res` deliverable.
Future<void> createPlayStoreIcon(
  Config config,
  String prefixPath, [
  LILogger? logger,
  utils.SvgRasterCache? cache,
]) async {
  final String? filePath = config.getImagePathAndroid();
  if (filePath == null) {
    throw const InvalidConfigException(errors.errorMissingImagePath);
  }
  final loadSize = await utils.sizeImageLoaderFor(
    utils.withPrefix(prefixPath, filePath),
    logger: logger,
    cache: cache,
  );
  final bytes = encodePng(await loadSize(512));
  final outFile = await utils.createFileIfNotExist(
    utils.withPrefix(prefixPath, constants.androidPlayStoreIconFile),
  );
  await outFile.writeAsBytes(bytes);
  utils.printStatus(
    'Created Play Store icon ${constants.androidPlayStoreIconFile} '
    '(${bytes.length ~/ 1024}KB)',
    logger,
  );
  if (bytes.length > 1024 * 1024) {
    utils.printStatus(
      'WARNING: Play Store icon exceeds the 1024KB upload budget; '
      'use a simpler source image.',
      logger,
    );
  }
}

/// Creates the `mipmap-anydpi-v26` adaptive-icon xml (plus the round
/// variant when configured), clearing stale adaptive artifacts otherwise.
Future<void> createMipmapXmlFile(
  Config config,
  String? flavor, {
  LILogger? logger,
  String prefixPath = '.',
}) async {
  // Note: Adaptive Icons will only be used when both
  // `adaptive_icon_background` and `adaptive_icon_foreground` or
  // `adaptive_icon_monochrome` are specified (The `image_path` is not
  // automatically taken as foreground)
  if (!config.hasAndroidAdaptiveConfig &&
      !config.hasAndroidAdaptiveMonochromeConfig &&
      !config.hasAndroidAdaptiveRoundConfig) {
    // No adaptive icons requested: clear leftovers from a previous adaptive
    // configuration so they cannot shadow the fresh icons (fluttercommunity/flutter_launcher_icons#328).
    await _removeStaleAdaptiveIcons(
      config,
      flavor,
      logger: logger,
      prefixPath: prefixPath,
    );
    return;
  }

  utils.printStatus('Creating mipmap xml file Android', logger);

  String xmlContent = '';
  final androidConfig = config.androidConfig!;

  if (config.hasAndroidAdaptiveConfig) {
    final background = androidConfig.adaptiveIconBackground!;
    if (isTransparentAdaptiveBackground(background)) {
      xmlContent +=
          '  <background android:drawable="@android:color/transparent"/>\n';
    } else if (isAdaptiveIconConfigImageFile(background)) {
      xmlContent +=
          '  <background android:drawable="@drawable/ic_launcher_background"/>\n';
    } else {
      xmlContent +=
          '  <background android:drawable="@color/ic_launcher_background"/>\n';
    }

    xmlContent += '''
  <foreground>
      <inset
          android:drawable="@drawable/ic_launcher_foreground"
          android:inset="${androidConfig.adaptiveIconForegroundInset}%" />
  </foreground>
''';
  }

  if (config.hasAndroidAdaptiveMonochromeConfig) {
    final int monochromeInset = androidConfig.adaptiveIconForegroundInset;
    if (monochromeInset == 0) {
      // Canonical form per developer.android.com: a direct drawable
      // attribute with no <inset> wrapper.
      xmlContent +=
          '  <monochrome android:drawable="@drawable/ic_launcher_monochrome" />\n';
    } else {
      xmlContent += '''
  <monochrome>
      <inset
          android:drawable="@drawable/ic_launcher_monochrome"
          android:inset="$monochromeInset%" />
  </monochrome>
''';
    }
  }

  late File mipmapXmlFile;
  if (config.isCustomAndroidFile) {
    mipmapXmlFile = await utils.createFileIfNotExist(
      utils.withPrefix(
        prefixPath,
        paths.androidAdaptiveXmlFolder(flavor) +
            androidConfig.iconName! +
            '.xml',
      ),
    );
  } else {
    mipmapXmlFile = await utils.createFileIfNotExist(
      utils.withPrefix(
        prefixPath,
        paths.androidAdaptiveXmlFolder(flavor) +
            constants.androidDefaultIconName +
            '.xml',
      ),
    );
  }

  await mipmapXmlFile.writeAsString(
    xml_template.mipmapXmlFile.replaceAll('{{CONTENT}}', xmlContent),
  );

  if (config.hasAndroidAdaptiveRoundConfig) {
    // The round icon is a separate adaptive-icon resource with the same
    // layers, wired via android:roundIcon.
    final roundXmlFile = await utils.createFileIfNotExist(
      utils.withPrefix(
        prefixPath,
        paths.androidAdaptiveXmlFolder(flavor) +
            androidAdaptiveRoundXmlName(config) +
            '.xml',
      ),
    );
    await roundXmlFile.writeAsString(
      xml_template.mipmapXmlFile.replaceAll('{{CONTENT}}', xmlContent),
    );
  }
}

/// Deletes adaptive icon artifacts left behind by a previous adaptive
/// configuration so they cannot shadow freshly generated icons (fluttercommunity/flutter_launcher_icons#328).
///
/// Only tool-owned file names are removed (`colors.xml` is shared and left untouched). Both the default and the custom icon xml names are covered so switching in either direction is cleaned up.
Future<void> _removeStaleAdaptiveIcons(
  Config config,
  String? flavor, {
  LILogger? logger,
  String prefixPath = '.',
}) async {
  final xmlNames = <String>{constants.androidDefaultIconName};
  final customName = config.androidConfig?.iconName;
  if (customName != null) {
    xmlNames.add(customName);
  }
  final stalePaths = <String>[
    for (final name in xmlNames)
      utils.withPrefix(
        prefixPath,
        paths.androidAdaptiveXmlFolder(flavor) + name + '.xml',
      ),
    for (final name in xmlNames)
      utils.withPrefix(
        prefixPath,
        paths.androidAdaptiveXmlFolder(flavor) + name + '_round.xml',
      ),
    for (final template in adaptiveForegroundIcons)
      for (final fileName in [
        constants.androidAdaptiveForegroundFileName,
        constants.androidAdaptiveBackgroundFileName,
        constants.androidAdaptiveMonochromeFileName,
        constants.androidAdaptiveRoundFileName,
      ])
        utils.withPrefix(
          prefixPath,
          paths.androidResFolder(flavor) +
              template.directoryName +
              '/' +
              fileName,
        ),
  ];
  for (final filePath in stalePaths) {
    final file = File(filePath);
    // Using the sync method here due to `avoid_slow_async_io` lint suggestion.
    if (file.existsSync()) {
      utils.printStatus('Removing stale adaptive icon file $filePath', logger);
      await file.delete();
    }
  }
}

/// Retrieves the colors.xml file for the project.
///
/// If the colors.xml file is found, it is updated with a new color item for the adaptive icon background.
///
/// If not, the colors.xml file is created and a color item for the adaptive icon background is included in the new colors.xml file.
Future<void> updateColorsXmlFile(
  String backgroundConfig,
  String? flavor, {
  LILogger? logger,
  String prefixPath = '.',
}) async {
  final File colorsXml =
      File(utils.withPrefix(prefixPath, paths.androidColorsFile(flavor)));
  // Using the sync method here due to `avoid_slow_async_io` lint suggestion.
  if (colorsXml.existsSync()) {
    utils.printStatus(
      'Updating colors.xml with color for adaptive icon background',
      logger,
    );
    await updateColorsFile(colorsXml, backgroundConfig);
  } else {
    utils.printStatus(
      'No colors.xml file found in your Android project',
      logger,
    );
    utils.printStatus(
      'Creating colors.xml file and adding it to your Android project',
      logger,
    );
    await createNewColorsFile(
      backgroundConfig,
      flavor,
      prefixPath: prefixPath,
    );
  }
}

/// creates adaptive background using png image
Future<void> _createAdaptiveBackgrounds(
  Config config,
  String adaptiveIconBackgroundImagePath,
  String? flavor, {
  String prefixPath = '.',
  utils.SvgRasterCache? cache,
}) async {
  final String filePath = adaptiveIconBackgroundImagePath;
  final loadSize = await utils.sizeImageLoaderFor(
    utils.withPrefix(prefixPath, filePath),
    cache: cache,
  );

  final concurrentImageUpdates = <Future<void>>[];
  // creates a png image (ic_adaptive_background.png) for the adaptive icon background in each of the locations it is required
  for (AndroidIconTemplate androidIcon in adaptiveForegroundIcons) {
    concurrentImageUpdates.add(
      loadSize(androidIcon.size).then(
        (image) => writeResizedPng(
          androidIcon,
          image,
          constants.androidAdaptiveBackgroundFileName,
          flavor,
          prefixPath: prefixPath,
        ),
      ),
    );
  }
  await Future.wait(concurrentImageUpdates);
}

/// Creates a colors.xml file if it was missing from android/app/src/main/res/values/colors.xml
Future<void> createNewColorsFile(
  String backgroundColor,
  String? flavor, {
  String prefixPath = '.',
}) async {
  final colorsFile = await utils.createFileIfNotExist(
    utils.withPrefix(prefixPath, paths.androidColorsFile(flavor)),
  );
  await colorsFile.writeAsString(xml_template.colorsXml);
  await updateColorsFile(colorsFile, backgroundColor);
}

/// Updates the colors.xml with the new adaptive launcher icon color
Future<void> updateColorsFile(File colorsFile, String backgroundColor) async {
  // Normalize bare hex colors (`ffffff` -> `#ffffff`, #673). Image paths
  // never reach this function (see createAdaptiveIcons), so a plain 6/8-digit hex string here is always meant to be a color.
  if (RegExp(r'^[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$').hasMatch(backgroundColor)) {
    backgroundColor = '#$backgroundColor';
  }
  // Write foreground color
  final List<String> lines = await colorsFile.readAsLines();
  bool foundExisting = false;
  for (int x = 0; x < lines.length; x++) {
    String line = lines[x];
    // Never touch XML comments: a commented-out entry is documentation,
    // not configuration.
    if (line.trimLeft().startsWith('<!--')) {
      continue;
    }
    if (line.contains('name="ic_launcher_background"')) {
      foundExisting = true;
      // replace anything between tags which does not contain another tag
      line = line.replaceAll(RegExp(r'>([^><]*)<'), '>$backgroundColor<');
      lines[x] = line;
      break;
    }
  }

  // Add new line if we didn't find an existing value
  if (!foundExisting) {
    lines.insert(
      lines.length - 1,
      '\t<color name="ic_launcher_background">$backgroundColor</color>',
    );
  }

  await colorsFile.writeAsString(lines.join('\n'));
}

/// Writes [image] resized to [template.size] as a PNG file named [filename] inside [template.directoryName] (see [utils.createResizedImage] for the interpolation policy).
Future<void> writeResizedPng(
  AndroidIconTemplate template,
  Image image,
  String filename,
  String? flavor, {
  String prefixPath = '.',
}) async {
  final Image resizedImage = utils.createResizedImage(template.size, image);
  final pngFile = await utils.createFileIfNotExist(
    utils.withPrefix(
      prefixPath,
      paths.androidResFolder(flavor) + template.directoryName + '/' + filename,
    ),
  );
  await pngFile.writeAsBytes(encodePng(resizedImage));
}

/// Updates the line which specifies the launcher icon within the AndroidManifest.xml with the new icon name (only if it has changed)
///
/// Note: default iconName = "ic_launcher"
Future<void> overwriteAndroidManifestWithNewLauncherIcon(
  String iconName,
  File androidManifestFile, {
  String? roundIconName,
  LILogger? logger,
}) async {
  // we do not use `file.readAsLines()` here because that always gets rid of the last empty newline
  final List<String> oldManifestLines =
      (await androidManifestFile.readAsString()).split('\n');
  final List<String> transformedLines =
      _transformAndroidManifestWithNewLauncherIcon(
    oldManifestLines,
    iconName,
    roundIconName,
  );
  await androidManifestFile.writeAsString(transformedLines.join('\n'));
  if (roundIconName == null &&
      oldManifestLines.any((line) => line.contains('android:roundIcon'))) {
    utils.printStatus(
      'WARNING: AndroidManifest.xml has a pre-existing android:roundIcon '
      'that may shadow themed icons. Configure `android.adaptive_icon_round` '
      'to regenerate it, or remove the attribute.',
      logger,
    );
  }
}

/// Updates only the line containing android:icon with the specified iconName, wiring android:roundIcon alongside it when [roundIconName] is given
List<String> _transformAndroidManifestWithNewLauncherIcon(
  List<String> oldManifestLines,
  String iconName, [
  String? roundIconName,
]) {
  return oldManifestLines.map((String line) {
    var result = line;
    // Never touch XML comments: a commented-out attribute is documentation,
    // not configuration.
    final isComment = result.trimLeft().startsWith('<!--');
    if (result.contains('android:icon') && !isComment) {
      // Using RegExp replace the value of android:icon to point to the new icon
      // anything but a quote of any length: [^"]*
      // an escaped quote: \\" (escape slash, because it exists regex)
      // quote, no quote / quote with things behind : \"[^"]*
      // repeat as often as wanted with no quote at start: [^"]*(\"[^"]*)*
      // escaping the slash to place in string: [^"]*(\\"[^"]*)*"
      // result: any string which does only include escaped quotes
      result = result.replaceAll(
        RegExp(r'android:icon="[^"]*(\\"[^"]*)*"'),
        'android:icon="@mipmap/$iconName"',
      );
    }
    if (roundIconName != null) {
      if (result.contains('android:roundIcon')) {
        result = result.replaceAll(
          RegExp(r'android:roundIcon="[^"]*(\\"[^"]*)*"'),
          'android:roundIcon="@mipmap/$roundIconName"',
        );
      } else if (result.contains('android:icon')) {
        final roundAttr = ' android:roundIcon="@mipmap/$roundIconName"';
        if (result.trimRight().endsWith('>')) {
          final idx = result.lastIndexOf('>');
          result =
              '${result.substring(0, idx)}$roundAttr${result.substring(idx)}';
        } else {
          result = '$result$roundAttr';
        }
      }
    }
    return result;
  }).toList();
}

/// Returns true if the adaptive icon configuration is an image file.
bool isAdaptiveIconConfigImageFile(String backgroundFile) {
  final normalizedPath = backgroundFile.toLowerCase();
  return normalizedPath.endsWith('.png') ||
      normalizedPath.endsWith('.jpg') ||
      normalizedPath.endsWith('.jpeg') ||
      normalizedPath.endsWith('.webp') ||
      normalizedPath.endsWith('.svg');
}

/// Returns true when the adaptive background is the `transparent` keyword (case-insensitive), meaning `@android:color/transparent` with no colors.xml entry (fluttercommunity/flutter_launcher_icons#535).
bool isTransparentAdaptiveBackground(String? backgroundConfig) {
  return backgroundConfig?.toLowerCase() == 'transparent';
}

/// (NOTE THIS IS JUST USED FOR UNIT TEST)
/// Ensures the correct path is used for generating adaptive icons
/// "Next you must create alternative drawable resources in your app for use with Android 8.0 (API level 26) in res/mipmap-anydpi/ic_launcher.xml" Source: https://developer.android.com/develop/ui/compose/system/icon_design_adaptive
bool isCorrectMipmapDirectoryForAdaptiveIcon(String path) {
  return path == 'android/app/src/main/res/mipmap-anydpi-v26/';
}
