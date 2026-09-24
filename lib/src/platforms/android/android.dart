import 'dart:io';

import 'package:image/image.dart';
import 'package:launcher_icons/src/config/config.dart';
import 'package:launcher_icons/src/core/constants.dart' as constants;
import 'package:launcher_icons/src/core/custom_exceptions.dart';
import 'package:launcher_icons/src/core/logger.dart';
import 'package:launcher_icons/src/core/paths.dart' as paths;
import 'package:launcher_icons/src/core/utils.dart' as utils;
import 'package:launcher_icons/src/platforms/android/xml_templates.dart' as xml_template;
import 'package:path/path.dart' as path;

/// A legacy launcher icon density target: [directoryName] under the flavor-aware res folder, rendered at [size] px square.
class AndroidIconTemplate {
  /// Creates an instance of [AndroidIconTemplate].
  AndroidIconTemplate({required this.size, required this.directoryName});

  /// Resource directory name (e.g. `mipmap-xxxhdpi`).
  final String directoryName;

  /// Icon edge length in pixels.
  final int size;
}

/// Adaptive foreground/background density targets (108dp layers, scaled per density).
List<AndroidIconTemplate> get adaptiveForegroundIcons => [
      for (final density in paths.androidDensities.entries) AndroidIconTemplate(directoryName: 'drawable-${density.key}', size: (108 * density.value).round()),
    ];

/// Legacy mipmap density targets (48dp across 1x–4x, scaled per density).
List<AndroidIconTemplate> get androidIcons => [
      for (final density in paths.androidDensities.entries) AndroidIconTemplate(directoryName: 'mipmap-${density.key}', size: (48 * density.value).round()),
    ];

/// Notification (status-bar) small-icon density targets (24dp, scaled per density).
List<AndroidIconTemplate> get notificationIcons => [
      for (final density in paths.androidDensities.entries) AndroidIconTemplate(directoryName: 'drawable-${density.key}', size: (constants.androidNotificationIconDp * density.value).round()),
    ];

/// Whether [config] requests the adaptive pair: enabled with both background and foreground layers. Only Android reads these keys, so the rule lives here rather than on Config.
bool hasAndroidAdaptiveConfig(final Config config) {
  final androidConfig = config.androidConfig;
  return config.androidEnabled && androidConfig?.adaptiveIconForeground != null && androidConfig?.adaptiveIconBackground != null;
}

/// Whether [config] requests Android 13+ monochrome icons: enabled with a monochrome layer.
bool hasAndroidAdaptiveMonochromeConfig(final Config config) {
  final androidConfig = config.androidConfig;
  return config.androidEnabled && androidConfig?.adaptiveIconMonochrome != null;
}

/// Whether [config] requests the opt-in round icon: enabled with a round layer (which itself requires the adaptive pair).
bool hasAndroidAdaptiveRoundConfig(final Config config) {
  final androidConfig = config.androidConfig;
  return config.androidEnabled && androidConfig?.adaptiveIconRound != null;
}

/// Whether [config] requests the notification (status-bar) icon: enabled with a notification layer.
bool hasAndroidNotificationConfig(final Config config) {
  final androidConfig = config.androidConfig;
  return config.androidEnabled && androidConfig?.notificationIcon != null;
}

/// Whether a custom Android `icon_name` was specified. When set, a new launcher icon is generated without removing the old default existing Flutter launcher icon.
bool isCustomAndroidFile(final Config config) => config.androidConfig?.iconName != null;

/// Whether [sourcePath] is an Android vector drawable source (`.xml`), copied verbatim into `drawable/` instead of rasterized into density PNGs.
bool isVectorDrawableSource(final String sourcePath) => sourcePath.toLowerCase().endsWith('.xml');

/// Vector drawable file name for a raster layer file (e.g. `ic_launcher_foreground.png` -> `ic_launcher_foreground.xml`).
String vectorDrawableFileName(final String rasterFileName) => '${path.basenameWithoutExtension(rasterFileName)}.xml';

/// Copies a user-supplied vector drawable [sourcePath] verbatim to `drawable/[fileName]` (density-independent, flavor-aware res). The file must be a valid Android drawable XML; build-time `aapt` errors point at the source when it is not. PNG fallbacks are skipped for vector layers: the vector itself scales, while legacy mipmaps from `image_path` keep covering pre-26 devices.
Future<void> writeVectorDrawable(
  final String sourcePath,
  final String fileName,
  final String? flavor, {
  final String prefixPath = '.',
  final LILogger? logger,
}) async {
  final source = File(utils.withPrefix(prefixPath, sourcePath));
  if (!source.existsSync()) {
    throw InvalidConfigException('Vector drawable source not found: "$sourcePath"');
  }
  final out = await utils.createFileIfNotExist(
    utils.withPrefix(
      prefixPath,
      path.join(paths.androidResFolder(flavor), 'drawable', fileName),
    ),
  );
  await out.writeAsBytes(await source.readAsBytes());
  utils.printStatus('Copied vector drawable $sourcePath to drawable/$fileName', logger);
}

/// Deletes [relativePath] (under [prefixPath]) when present, e.g. a superseded vector/PNG twin that would otherwise collide as a duplicate resource.
Future<void> _deleteIfExists(
  final String relativePath, {
  final String prefixPath = '.',
  final LILogger? logger,
}) async {
  final file = File(utils.withPrefix(prefixPath, relativePath));
  // Using the sync method here due to `avoid_slow_async_io` lint suggestion.
  if (file.existsSync()) {
    utils.printStatus('Removing superseded icon file $relativePath', logger);
    await file.delete();
  }
}

/// Creates the legacy mipmap icons (overwriting defaults, or adding a new icon when `android.icon_name` is set) and wires the manifest.
Future<void> createDefaultIcons(
  final Config config,
  final String? flavor, {
  final LILogger? logger,
  final String prefixPath = '.',
  final utils.SvgRasterCache? cache,
}) async {
  utils.printStatus('Creating default icons Android', logger);
  final filePath = config.resolveImageFile(config.androidConfig?.imagePath, prefixPath);
  final loadSize = await utils.sizeImageLoaderFor(
    utils.withPrefix(prefixPath, filePath),
    logger: logger,
    cache: cache,
  );
  final androidManifestFile = File(utils.withPrefix(prefixPath, paths.androidManifestFile));
  final concurrentIconUpdates = <Future<void>>[];
  if (isCustomAndroidFile(config)) {
    utils.printStatus('Adding a new Android launcher icon', logger);
    final iconName = config.androidConfig!.iconName!;
    isAndroidIconNameCorrectFormat(iconName);
    final iconPath = '$iconName.png';
    for (final template in androidIcons) {
      concurrentIconUpdates.add(
        loadSize(template.size).then(
          (final image) => writeResizedPng(
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
      roundIconName: hasAndroidAdaptiveRoundConfig(config) ? androidAdaptiveRoundXmlName(config) : null,
      logger: logger,
    );
  } else {
    utils.printStatus(
      'Overwriting the default Android launcher icon with a new icon',
      logger,
    );
    for (final template in androidIcons) {
      concurrentIconUpdates.add(
        loadSize(template.size).then(
          (final image) => writeResizedPng(
            template,
            image,
            paths.androidFileName,
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
      roundIconName: hasAndroidAdaptiveRoundConfig(config) ? androidAdaptiveRoundXmlName(config) : null,
      logger: logger,
    );
  }
  await Future.wait(concurrentIconUpdates);
}

/// Deletes legacy `<old>.png` files after an icon-name switch.
///
/// The manifest's previous icon name proves tool ownership: only the tool writes custom names there. `ic_launcher` (possibly Flutter's originals) and the incoming name are never touched.
Future<void> removeStaleLegacyIconsForSwitch(
  final File androidManifestFile,
  final String newIconName,
  final String? flavor, {
  final LILogger? logger,
  final String prefixPath = '.',
}) async {
  if (!androidManifestFile.existsSync()) {
    return;
  }
  final content = await androidManifestFile.readAsString();
  final match = RegExp('android:icon="@mipmap/([^"]+)"').firstMatch(content);
  final oldIconName = match?.group(1);
  if (oldIconName == null || oldIconName == newIconName || oldIconName == constants.androidDefaultIconName) {
    return;
  }
  for (final template in androidIcons) {
    final file = File(
      utils.withPrefix(
        prefixPath,
        path.join(paths.androidResFolder(flavor), template.directoryName, '$oldIconName.png'),
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
bool isAndroidIconNameCorrectFormat(final String iconName) {
  // assure the icon only consists of lowercase letters, numbers and underscore
  if (!RegExp(r'^[a-z0-9_]+$').hasMatch(iconName)) {
    throw const InvalidAndroidIconNameException(
      'The icon name must contain only lowercase a-z, 0-9, or underscore: E.g. "ic_my_new_icon"',
    );
  }
  return true;
}

/// Creates the adaptive foreground/background icons and `colors.xml` entries.
Future<void> createAdaptiveIcons(
  final Config config,
  final String? flavor, {
  final LILogger? logger,
  final String prefixPath = '.',
  final utils.SvgRasterCache? cache,
}) async {
  utils.printStatus('Creating adaptive icons Android', logger);

  // Retrieve the necessary Flutter Launcher Icons configuration from the pubspec.yaml file
  final androidConfig = config.androidConfig!;
  final backgroundConfig = androidConfig.adaptiveIconBackground;
  final foregroundImagePath = androidConfig.adaptiveIconForeground;
  if (backgroundConfig == null || foregroundImagePath == null) {
    throw const InvalidConfigException('Missing "adaptive_icon_background" and "adaptive_icon_foreground" within android configuration.');
  }

  final concurrentImageUpdates = <Future<void>>[];
  // Create adaptive icon foreground images (or pass a vector drawable through verbatim, awaited inline so failures surface on this future instead of an unlistened batch entry).
  if (isVectorDrawableSource(foregroundImagePath)) {
    await writeVectorDrawable(
      foregroundImagePath,
      vectorDrawableFileName(paths.androidAdaptiveForegroundFileName),
      flavor,
      prefixPath: prefixPath,
      logger: logger,
    );
    for (final template in adaptiveForegroundIcons) {
      concurrentImageUpdates.add(
        _deleteIfExists(
          path.join(paths.androidResFolder(flavor), template.directoryName, paths.androidAdaptiveForegroundFileName),
          prefixPath: prefixPath,
          logger: logger,
        ),
      );
    }
  } else {
    final loadForegroundSize = await utils.sizeImageLoaderFor(
      utils.withPrefix(prefixPath, foregroundImagePath),
      logger: logger,
      cache: cache,
    );
    for (final androidIcon in adaptiveForegroundIcons) {
      concurrentImageUpdates.add(
        loadForegroundSize(androidIcon.size).then(
          (final foregroundImage) => writeResizedPng(
            androidIcon,
            foregroundImage,
            paths.androidAdaptiveForegroundFileName,
            flavor,
            prefixPath: prefixPath,
          ),
        ),
      );
    }
    concurrentImageUpdates.add(
      _deleteIfExists(
        path.join(paths.androidResFolder(flavor), 'drawable', vectorDrawableFileName(paths.androidAdaptiveForegroundFileName)),
        prefixPath: prefixPath,
        logger: logger,
      ),
    );
  }

  // Create adaptive icon background
  if (isTransparentAdaptiveBackground(backgroundConfig)) {
    utils.printStatus(
      'Using transparent adaptive icon background (@android:color/transparent)',
      logger,
    );
  } else if (isVectorDrawableSource(backgroundConfig)) {
    await writeVectorDrawable(
      backgroundConfig,
      vectorDrawableFileName(paths.androidAdaptiveBackgroundFileName),
      flavor,
      prefixPath: prefixPath,
      logger: logger,
    );
    for (final template in adaptiveForegroundIcons) {
      concurrentImageUpdates.add(
        _deleteIfExists(
          path.join(paths.androidResFolder(flavor), template.directoryName, paths.androidAdaptiveBackgroundFileName),
          prefixPath: prefixPath,
          logger: logger,
        ),
      );
    }
  } else if (isAdaptiveIconConfigImageFile(backgroundConfig)) {
    concurrentImageUpdates
      ..add(
        _createAdaptiveBackgrounds(
          config,
          backgroundConfig,
          flavor,
          prefixPath: prefixPath,
          cache: cache,
        ),
      )
      ..add(
        _deleteIfExists(
          path.join(paths.androidResFolder(flavor), 'drawable', vectorDrawableFileName(paths.androidAdaptiveBackgroundFileName)),
          prefixPath: prefixPath,
          logger: logger,
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
  final Config config,
  final String? flavor, {
  final LILogger? logger,
  final String prefixPath = '.',
  final utils.SvgRasterCache? cache,
}) async {
  utils.printStatus('Creating adaptive monochrome icons Android', logger);

  // Retrieve the necessary Flutter Launcher Icons configuration from the pubspec.yaml file
  final monochromeImagePath = config.androidConfig!.adaptiveIconMonochrome;
  if (monochromeImagePath == null) {
    throw const InvalidConfigException('Missing "adaptive_icon_monochrome" within android configuration.');
  }
  if (!hasAndroidAdaptiveConfig(config)) {
    throw const InvalidConfigException('Invalid `adaptive_icon_monochrome`: requires `adaptive_icon_background` and `adaptive_icon_foreground`.');
  }

  final concurrentIconUpdates = <Future<void>>[];
  if (isVectorDrawableSource(monochromeImagePath)) {
    await writeVectorDrawable(
      monochromeImagePath,
      vectorDrawableFileName(paths.androidAdaptiveMonochromeFileName),
      flavor,
      prefixPath: prefixPath,
      logger: logger,
    );
    for (final template in adaptiveForegroundIcons) {
      concurrentIconUpdates.add(
        _deleteIfExists(
          path.join(paths.androidResFolder(flavor), template.directoryName, paths.androidAdaptiveMonochromeFileName),
          prefixPath: prefixPath,
          logger: logger,
        ),
      );
    }
  } else {
    final loadMonochromeSize = await utils.sizeImageLoaderFor(
      utils.withPrefix(prefixPath, monochromeImagePath),
      logger: logger,
      cache: cache,
    );
    // Create adaptive icon monochrome images
    for (final androidIcon in adaptiveForegroundIcons) {
      concurrentIconUpdates.add(
        loadMonochromeSize(androidIcon.size).then(
          (final monochromeImage) => writeResizedPng(
            androidIcon,
            monochromeImage,
            paths.androidAdaptiveMonochromeFileName,
            flavor,
            prefixPath: prefixPath,
          ),
        ),
      );
    }
    concurrentIconUpdates.add(
      _deleteIfExists(
        path.join(paths.androidResFolder(flavor), 'drawable', vectorDrawableFileName(paths.androidAdaptiveMonochromeFileName)),
        prefixPath: prefixPath,
        logger: logger,
      ),
    );
  }
  await Future.wait(concurrentIconUpdates);
}

/// Round-icon drawable file name: `<custom>_round.png` for custom icons, `ic_launcher_round.png` otherwise.
String androidAdaptiveRoundFileName(final Config config) {
  final customName = config.androidConfig?.iconName;
  return customName != null ? '${customName}_round.png' : paths.androidAdaptiveRoundFileName;
}

/// Round-icon resource name: `<custom>_round` for custom icons, `ic_launcher_round` otherwise.
String androidAdaptiveRoundXmlName(final Config config) {
  final customName = config.androidConfig?.iconName;
  return customName != null ? '${customName}_round' : paths.androidAdaptiveRoundIconName;
}

/// Creates the opt-in adaptive round icons.
Future<void> createAdaptiveRoundIcons(
  final Config config,
  final String? flavor, {
  final LILogger? logger,
  final String prefixPath = '.',
  final utils.SvgRasterCache? cache,
}) async {
  utils.printStatus('Creating adaptive round icons Android', logger);

  final roundImagePath = config.androidConfig?.adaptiveIconRound;
  if (roundImagePath == null) {
    throw const InvalidConfigException('Missing "adaptive_icon_round" within android configuration.');
  }
  if (!hasAndroidAdaptiveConfig(config)) {
    throw const InvalidConfigException('Invalid `adaptive_icon_round`: requires `adaptive_icon_background` and `adaptive_icon_foreground`.');
  }

  final concurrentIconUpdates = <Future<void>>[];
  final roundFileName = androidAdaptiveRoundFileName(config);
  if (isVectorDrawableSource(roundImagePath)) {
    await writeVectorDrawable(
      roundImagePath,
      vectorDrawableFileName(roundFileName),
      flavor,
      prefixPath: prefixPath,
      logger: logger,
    );
    for (final template in adaptiveForegroundIcons) {
      concurrentIconUpdates.add(
        _deleteIfExists(
          path.join(paths.androidResFolder(flavor), template.directoryName, roundFileName),
          prefixPath: prefixPath,
          logger: logger,
        ),
      );
    }
  } else {
    final loadRoundSize = await utils.sizeImageLoaderFor(
      utils.withPrefix(prefixPath, roundImagePath),
      logger: logger,
      cache: cache,
    );
    // Create adaptive icon round images
    for (final androidIcon in adaptiveForegroundIcons) {
      concurrentIconUpdates.add(
        loadRoundSize(androidIcon.size).then(
          (final roundImage) => writeResizedPng(
            androidIcon,
            roundImage,
            roundFileName,
            flavor,
            prefixPath: prefixPath,
          ),
        ),
      );
    }
    concurrentIconUpdates.add(
      _deleteIfExists(
        path.join(paths.androidResFolder(flavor), 'drawable', vectorDrawableFileName(roundFileName)),
        prefixPath: prefixPath,
        logger: logger,
      ),
    );
  }
  await Future.wait(concurrentIconUpdates);
}

/// FCM manifest key for the default notification (status-bar) small icon.
const String fcmNotificationIconMetaDataName = 'com.google.firebase.messaging.default_notification_icon';

/// Creates the notification (status-bar) small icons and wires the FCM `default_notification_icon` meta-data in the manifest.
Future<void> createNotificationIcons(
  final Config config,
  final String? flavor, {
  final LILogger? logger,
  final String prefixPath = '.',
  final utils.SvgRasterCache? cache,
}) async {
  utils.printStatus('Creating notification icons Android', logger);

  final androidConfig = config.androidConfig!;
  final sourcePath = androidConfig.notificationIcon;
  if (sourcePath == null) {
    throw const InvalidConfigException('Missing "notification_icon" within android configuration.');
  }
  final resourceName = androidConfig.notificationIconName;
  isAndroidIconNameCorrectFormat(resourceName);

  if (isVectorDrawableSource(sourcePath)) {
    await writeVectorDrawable(
      sourcePath,
      '$resourceName.xml',
      flavor,
      prefixPath: prefixPath,
      logger: logger,
    );
    for (final template in notificationIcons) {
      await _deleteIfExists(
        path.join(paths.androidResFolder(flavor), template.directoryName, '$resourceName.png'),
        prefixPath: prefixPath,
        logger: logger,
      );
    }
  } else {
    final loadSize = await utils.sizeImageLoaderFor(
      utils.withPrefix(prefixPath, sourcePath),
      logger: logger,
      cache: cache,
    );
    final concurrentIconUpdates = <Future<void>>[];
    for (final template in notificationIcons) {
      concurrentIconUpdates.add(
        loadSize(template.size).then(
          (final image) => writeResizedPng(
            template,
            image,
            '$resourceName.png',
            flavor,
            prefixPath: prefixPath,
          ),
        ),
      );
    }
    concurrentIconUpdates.add(
      _deleteIfExists(
        path.join(paths.androidResFolder(flavor), 'drawable', '$resourceName.xml'),
        prefixPath: prefixPath,
        logger: logger,
      ),
    );
    await Future.wait(concurrentIconUpdates);
  }
  await ensureFcmNotificationIconMetaData(
    resourceName,
    logger: logger,
    prefixPath: prefixPath,
  );
}

/// Ensures `<meta-data android:name="com.google.firebase.messaging.default_notification_icon" android:resource="@drawable/<resourceName>" />` inside `<application>`: inserted before `</application>` when absent, updated in place when present with a different value. Missing manifests are skipped with a warning.
Future<void> ensureFcmNotificationIconMetaData(
  final String resourceName, {
  final LILogger? logger,
  final String prefixPath = '.',
}) async {
  final manifestFile = File(utils.withPrefix(prefixPath, paths.androidManifestFile));
  if (!manifestFile.existsSync()) {
    utils.printStatus('WARNING: AndroidManifest.xml not found, skipping FCM notification icon meta-data.', logger);
    return;
  }
  final lines = (await manifestFile.readAsString()).split('\n');
  final reference = '@drawable/$resourceName';
  var found = false;
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].contains(fcmNotificationIconMetaDataName)) {
      found = true;
      lines[i] = lines[i].replaceAll(RegExp('@drawable/[^"]*'), reference);
    }
  }
  if (!found) {
    final closeIndex = lines.indexWhere((final line) => line.contains('</application>'));
    if (closeIndex == -1) {
      utils.printStatus('WARNING: no <application> block in AndroidManifest.xml, skipping FCM notification icon meta-data.', logger);
      return;
    }
    final indent = RegExp(r'^(\s*)').firstMatch(lines[closeIndex])?.group(1) ?? '    ';
    lines.insert(closeIndex, '$indent<meta-data android:name="$fcmNotificationIconMetaDataName" android:resource="$reference" />');
  }
  await manifestFile.writeAsString(lines.join('\n'));
  utils.printStatus('Wired FCM default notification icon to $reference', logger);
}

/// Creates the `mipmap-anydpi-v26` adaptive-icon xml (plus the round variant when configured), clearing stale adaptive artifacts otherwise.
Future<void> createMipmapXmlFile(
  final Config config,
  final String? flavor, {
  final LILogger? logger,
  final String prefixPath = '.',
}) async {
  // Note: adaptive icons are only used when the adaptive pair (`adaptive_icon_background` + `adaptive_icon_foreground`) is specified. Monochrome and round layers require the pair (`image_path` is never taken as a layer).
  if (!hasAndroidAdaptiveConfig(config) && !hasAndroidAdaptiveMonochromeConfig(config) && !hasAndroidAdaptiveRoundConfig(config)) {
    // No adaptive icons requested: clear leftovers from a previous adaptive configuration so they cannot shadow the fresh icons.
    await _removeStaleAdaptiveIcons(
      config,
      flavor,
      logger: logger,
      prefixPath: prefixPath,
    );
    return;
  }
  if (hasAndroidAdaptiveMonochromeConfig(config) && !hasAndroidAdaptiveConfig(config)) {
    throw const InvalidConfigException('Invalid `adaptive_icon_monochrome`: requires `adaptive_icon_background` and `adaptive_icon_foreground`.');
  }
  if (hasAndroidAdaptiveRoundConfig(config) && !hasAndroidAdaptiveConfig(config)) {
    throw const InvalidConfigException('Invalid `adaptive_icon_round`: requires `adaptive_icon_background` and `adaptive_icon_foreground`.');
  }

  utils.printStatus('Creating mipmap xml file Android', logger);

  var xmlContent = '';
  final androidConfig = config.androidConfig!;

  if (hasAndroidAdaptiveConfig(config)) {
    final background = androidConfig.adaptiveIconBackground!;
    if (isTransparentAdaptiveBackground(background)) {
      xmlContent += '  <background android:drawable="@android:color/transparent"/>\n';
    } else if (isAdaptiveIconConfigImageFile(background) || isVectorDrawableSource(background)) {
      xmlContent += '  <background android:drawable="@drawable/ic_launcher_background"/>\n';
    } else {
      xmlContent += '  <background android:drawable="@color/ic_launcher_background"/>\n';
    }

    final foregroundInset = androidConfig.adaptiveIconForegroundInset;
    if (foregroundInset == 0) {
      // Canonical form per developer.android.com: a direct drawable attribute with no <inset> wrapper.
      xmlContent += '  <foreground android:drawable="@drawable/ic_launcher_foreground" />\n';
    } else {
      xmlContent += '''
  <foreground>
      <inset
          android:drawable="@drawable/ic_launcher_foreground"
          android:inset="$foregroundInset%" />
  </foreground>
''';
    }
  }

  if (hasAndroidAdaptiveMonochromeConfig(config)) {
    final monochromeInset = androidConfig.adaptiveIconMonochromeInset;
    if (monochromeInset == 0) {
      // Canonical form per developer.android.com: a direct drawable attribute with no <inset> wrapper.
      xmlContent += '  <monochrome android:drawable="@drawable/ic_launcher_monochrome" />\n';
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
  if (isCustomAndroidFile(config)) {
    mipmapXmlFile = await utils.createFileIfNotExist(
      utils.withPrefix(
        prefixPath,
        path.join(paths.androidAdaptiveXmlFolder(flavor), '${androidConfig.iconName!}.xml'),
      ),
    );
  } else {
    mipmapXmlFile = await utils.createFileIfNotExist(
      utils.withPrefix(
        prefixPath,
        path.join(paths.androidAdaptiveXmlFolder(flavor), '${constants.androidDefaultIconName}.xml'),
      ),
    );
  }

  await mipmapXmlFile.writeAsString(
    xml_template.mipmapXmlFile.replaceAll('{{CONTENT}}', xmlContent),
  );

  if (hasAndroidAdaptiveRoundConfig(config)) {
    // The round icon is a separate adaptive-icon resource with the same layers, wired via android:roundIcon.
    final roundXmlFile = await utils.createFileIfNotExist(
      utils.withPrefix(
        prefixPath,
        path.join(paths.androidAdaptiveXmlFolder(flavor), '${androidAdaptiveRoundXmlName(config)}.xml'),
      ),
    );
    await roundXmlFile.writeAsString(
      xml_template.mipmapXmlFile.replaceAll('{{CONTENT}}', xmlContent),
    );
  }
}

/// Deletes adaptive icon artifacts left behind by a previous adaptive configuration so they cannot shadow freshly generated icons.
///
/// Only tool-owned file names are removed (`colors.xml` is shared and left untouched). Both the default and the custom icon xml names are covered so switching in either direction is cleaned up.
Future<void> _removeStaleAdaptiveIcons(
  final Config config,
  final String? flavor, {
  final LILogger? logger,
  final String prefixPath = '.',
}) async {
  final xmlNames = <String>{constants.androidDefaultIconName};
  final customName = config.androidConfig?.iconName;
  if (customName != null) {
    xmlNames.add(customName);
  }
  // Round drawables honor `icon_name` since their introduction, but older runs always wrote the default name: cover both so neither direction orphans a file.
  final roundFileNames = <String>{androidAdaptiveRoundFileName(config), paths.androidAdaptiveRoundFileName};
  final stalePaths = <String>[
    for (final name in xmlNames)
      utils.withPrefix(
        prefixPath,
        path.join(paths.androidAdaptiveXmlFolder(flavor), '$name.xml'),
      ),
    for (final name in xmlNames)
      utils.withPrefix(
        prefixPath,
        path.join(paths.androidAdaptiveXmlFolder(flavor), '${name}_round.xml'),
      ),
    for (final template in adaptiveForegroundIcons)
      for (final fileName in [
        paths.androidAdaptiveForegroundFileName,
        paths.androidAdaptiveBackgroundFileName,
        paths.androidAdaptiveMonochromeFileName,
        ...roundFileNames,
      ])
        utils.withPrefix(
          prefixPath,
          path.join(paths.androidResFolder(flavor), template.directoryName, fileName),
        ),
    // Superseded vector twins: a PNG-named layer and its `.xml` twin are duplicate resources, so a layer-type switch must clear the other side.
    for (final fileName in [
      vectorDrawableFileName(paths.androidAdaptiveForegroundFileName),
      vectorDrawableFileName(paths.androidAdaptiveBackgroundFileName),
      vectorDrawableFileName(paths.androidAdaptiveMonochromeFileName),
      for (final roundFileName in roundFileNames) vectorDrawableFileName(roundFileName),
    ])
      utils.withPrefix(
        prefixPath,
        path.join(paths.androidResFolder(flavor), 'drawable', fileName),
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
  final String backgroundConfig,
  final String? flavor, {
  final LILogger? logger,
  final String prefixPath = '.',
}) async {
  final colorsXml = File(utils.withPrefix(prefixPath, paths.androidColorsFile(flavor)));
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
  final Config config,
  final String adaptiveIconBackgroundImagePath,
  final String? flavor, {
  final String prefixPath = '.',
  final utils.SvgRasterCache? cache,
}) async {
  final filePath = adaptiveIconBackgroundImagePath;
  final loadSize = await utils.sizeImageLoaderFor(
    utils.withPrefix(prefixPath, filePath),
    cache: cache,
  );

  final concurrentImageUpdates = <Future<void>>[];
  // creates a png image (ic_adaptive_background.png) for the adaptive icon background in each of the locations it is required
  for (final androidIcon in adaptiveForegroundIcons) {
    concurrentImageUpdates.add(
      loadSize(androidIcon.size).then(
        (final image) => writeResizedPng(
          androidIcon,
          image,
          paths.androidAdaptiveBackgroundFileName,
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
  final String backgroundColor,
  final String? flavor, {
  final String prefixPath = '.',
}) async {
  final colorsFile = await utils.createFileIfNotExist(
    utils.withPrefix(prefixPath, paths.androidColorsFile(flavor)),
  );
  await colorsFile.writeAsString(xml_template.colorsXml);
  await updateColorsFile(colorsFile, backgroundColor);
}

/// Updates the colors.xml with the new adaptive launcher icon color
Future<void> updateColorsFile(final File colorsFile, final String backgroundColor) async {
  // Normalize bare hex colors (`ffffff` -> `#ffffff`, #673). Image paths never reach this function (see createAdaptiveIcons), so a plain 6/8-digit hex string here is always meant to be a color.
  var normalizedColor = backgroundColor;
  if (RegExp(r'^[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$').hasMatch(normalizedColor)) {
    normalizedColor = '#$normalizedColor';
  }
  // Write foreground color
  final lines = await colorsFile.readAsLines();
  var foundExisting = false;
  for (var x = 0; x < lines.length; x++) {
    var line = lines[x];
    // Never touch XML comments: a commented-out entry is documentation, not configuration.
    if (line.trimLeft().startsWith('<!--')) {
      continue;
    }
    if (line.contains('name="ic_launcher_background"')) {
      foundExisting = true;
      // replace anything between tags which does not contain another tag
      line = line.replaceAll(RegExp('>([^><]*)<'), '>$normalizedColor<');
      lines[x] = line;
      break;
    }
  }

  // Add new line if we didn't find an existing value
  if (!foundExisting) {
    lines.insert(
      lines.length - 1,
      '\t<color name="ic_launcher_background">$normalizedColor</color>',
    );
  }

  await colorsFile.writeAsString(lines.join('\n'));
}

/// Writes `image` resized to the template size as a PNG file named `filename` inside the template directory (see `createResizedImage` for the interpolation policy).
Future<void> writeResizedPng(
  final AndroidIconTemplate template,
  final Image image,
  final String filename,
  final String? flavor, {
  final String prefixPath = '.',
}) async {
  final resizedImage = utils.createResizedImage(template.size, image);
  final pngFile = await utils.createFileIfNotExist(
    utils.withPrefix(
      prefixPath,
      path.join(paths.androidResFolder(flavor), template.directoryName, filename),
    ),
  );
  await pngFile.writeAsBytes(encodePng(resizedImage));
}

/// Updates the line which specifies the launcher icon within the AndroidManifest.xml with the new icon name (only if it has changed)
///
/// Note: default iconName = "ic_launcher"
Future<void> overwriteAndroidManifestWithNewLauncherIcon(
  final String iconName,
  final File androidManifestFile, {
  final String? roundIconName,
  final LILogger? logger,
}) async {
  // we do not use `file.readAsLines()` here because that always gets rid of the last empty newline
  final oldManifestLines = (await androidManifestFile.readAsString()).split('\n');
  final transformedLines = _transformAndroidManifestWithNewLauncherIcon(
    oldManifestLines,
    iconName,
    roundIconName,
  );
  await androidManifestFile.writeAsString(transformedLines.join('\n'));
  if (roundIconName == null && oldManifestLines.any((final line) => line.contains('android:roundIcon'))) {
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
  final List<String> oldManifestLines,
  final String iconName, [
  final String? roundIconName,
]) =>
    oldManifestLines.map((final line) {
      var result = line;
      // Never touch XML comments: a commented-out attribute is documentation, not configuration.
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
            result = '${result.substring(0, idx)}$roundAttr${result.substring(idx)}';
          } else {
            result = '$result$roundAttr';
          }
        }
      }
      return result;
    }).toList();

/// Returns true if the adaptive icon configuration is an image file.
bool isAdaptiveIconConfigImageFile(final String backgroundFile) {
  final normalizedPath = backgroundFile.toLowerCase();
  return normalizedPath.endsWith('.png') || normalizedPath.endsWith('.jpg') || normalizedPath.endsWith('.jpeg') || normalizedPath.endsWith('.webp') || normalizedPath.endsWith('.svg');
}

/// Returns true when the adaptive background is the `transparent` keyword (case-insensitive), meaning `@android:color/transparent` with no colors.xml entry.
bool isTransparentAdaptiveBackground(final String? backgroundConfig) => backgroundConfig?.toLowerCase() == 'transparent';

/// (NOTE THIS IS JUST USED FOR UNIT TEST) Ensures the correct path is used for generating adaptive icons "Next you must create alternative drawable resources in your app for use with Android 8.0 (API level 26) in res/mipmap-anydpi/ic_launcher.xml" Source: https://developer.android.com/develop/ui/compose/system/icon_design_adaptive
bool isCorrectMipmapDirectoryForAdaptiveIcon(final String dirPath) => dirPath == paths.androidAdaptiveXmlFolder(null);
