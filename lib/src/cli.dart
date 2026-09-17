import 'dart:io';

import 'package:args/args.dart';
import 'package:launcher_icons/src/config/config.dart';
import 'package:launcher_icons/src/core/constants.dart' as constants;
import 'package:launcher_icons/src/core/custom_exceptions.dart';
import 'package:launcher_icons/src/core/errors.dart' as errors;
import 'package:launcher_icons/src/core/icon_generator.dart';
import 'package:launcher_icons/src/core/logger.dart';
import 'package:launcher_icons/src/core/paths.dart' as paths;
import 'package:launcher_icons/src/core/utils.dart' as utils;
import 'package:launcher_icons/src/platforms/android/android_icon_generator.dart';
import 'package:launcher_icons/src/platforms/ios/ios_icon_generator.dart';
import 'package:launcher_icons/src/platforms/linux/linux_icon_generator.dart';
import 'package:launcher_icons/src/platforms/macos/macos_icon_generator.dart';
import 'package:launcher_icons/src/platforms/web/web_icon_generator.dart';
import 'package:launcher_icons/src/platforms/windows/windows_icon_generator.dart';
import 'package:path/path.dart' as path;

/// CLI flag name for usage help (`-h`).
const String helpFlag = 'help';

/// CLI flag name for verbose logging (`-v`).
const String verboseFlag = 'verbose';

/// CLI option name for the config file or folder (`-c`).
const String configOption = 'config';

/// CLI option name for the flavor selection (`-f`).
const String flavorOption = 'flavor';

/// CLI option name for the project-root prefix (`-r`).
const String prefixOption = 'root';

/// File-name pattern for per-flavor configs (`launcher_icons-<flavor>.yaml`).
const String flavorConfigFilePattern = r'^launcher_icons-(.*).yaml$';

/// CLI entry point: parses [arguments], loads configs (including the flavor loop), and generates icons, exiting 0/1/2 on success, generation failure, or config/CLI failure.
Future<void> createIconsFromArguments(List<String> arguments) async {
  final ArgParser parser = ArgParser(allowTrailingOptions: true);
  parser
    ..addFlag(
      helpFlag,
      abbr: 'h',
      help: 'Usage Help',
      negatable: false,
    )
    ..addFlag(
      verboseFlag,
      abbr: 'v',
      help: 'Verbose Output',
      defaultsTo: false,
    )
    // Make default null to differentiate when it is explicitly set
    ..addOption(
      configOption,
      abbr: 'c',
      help: 'Path to a config file or a folder to search for '
          'configuration files',
      defaultsTo: constants.defaultConfigFileName,
    )
    ..addOption(
      flavorOption,
      abbr: 'f',
      help: 'Run a single flavor (from a launcher_icons-<flavor> section '
          'or a launcher_icons-<flavor>.yaml file)',
    )
    ..addOption(
      prefixOption,
      abbr: 'r',
      help: 'Set a different project root (cwd by default)',
      defaultsTo: '.',
    );

  final argResults = parser.parse(arguments);
  final logger = LILogger(argResults.flag(verboseFlag)); // creating logger based on -v flag

  logger.verbose('Received args ${argResults.arguments}');

  if (argResults.flag(helpFlag)) {
    logger.info('Generates launcher icons for Flutter projects');
    logger.info(parser.usage);
    exit(0);
  }

  // Flavors management
  final String prefixPath = argResults[prefixOption] as String;
  final String configValue = argResults[configOption] as String;
  // `-c` names either a config file (assumed flavorless unless its basename matches a flavor file) or a folder searched for default named configs and flavor configs.
  final bool configIsFolder = Directory(path.join(prefixPath, configValue)).existsSync();
  final bool configIsExplicitFile = isConfigOptionExplicit(arguments) && !configIsFolder;

  // An explicit `-f launcher_icons-<flavor>.yaml` runs only that
  // flavor instead of looping over every discovered flavor (fluttercommunity/flutter_launcher_icons#215). The file is loaded from the given path directly, so flavor configs in subdirectories work too.
  final onlyFlavor = configIsFolder ? null : explicitFlavorFromArgs(argResults);
  if (onlyFlavor != null) {
    final requestedFlavor = argResults[flavorOption] as String?;
    if (requestedFlavor != null && requestedFlavor != onlyFlavor) {
      throw InvalidConfigException(
        'Conflicting flavor selection: -c points at the "$onlyFlavor" '
        'flavor file while --flavor requests "$requestedFlavor". '
        'Pass only one of them.',
      );
    }
    final String filePath = argResults[configOption] as String;
    final flutterLauncherIconsConfigs = Config.loadConfigFromPath(
      filePath,
      prefixPath,
    );
    if (flutterLauncherIconsConfigs == null) {
      throw NoConfigFoundException(
        'No configuration found for $onlyFlavor flavor at $filePath. '
        'To discover flavor files in subdirectories pass a folder to -c.',
      );
    }
    try {
      logger.info('\nFlavor: $onlyFlavor');
      await createIconsFromConfig(
        flutterLauncherIconsConfigs,
        logger,
        prefixPath,
        onlyFlavor,
      );
      logger.info('\n✓ Successfully generated launcher icons');
    } on IconGenerationException catch (e) {
      logger.error('\n✕ Could not generate launcher icons');
      logger.error(e);
      exit(1);
    } catch (e) {
      logger.error('\n✕ Could not generate launcher icons');
      logger.error(e);
      exit(2);
    }
    return;
  }

  final flavors = await getFlavors(
    searchPath: configIsFolder ? path.join(prefixPath, configValue) : '.',
  );
  // An explicit `-c` file (not a flavor file) is honored as-is instead of
  // looping over discovered flavor files (fluttercommunity/flutter_launcher_icons#426). (An explicit flavor file is already handled by the onlyFlavor branch above.) Suffixed
  // `launcher_icons-<flavor>:` sections inside the pinned file still count:
  // `-c` pins the file, not the absence of flavors.
  final hasFileFlavors = flavors.isNotEmpty && !configIsExplicitFile;

  // Suffixed flavor sections live in the pinned file when `-c` names one,
  // otherwise in the searched folder's launcher_icons.yaml (when `-c`
  // names a folder) or the default one — plus pubspec.yaml, which always
  // comes from the project root (-r), never from the searched folder.
  // The yaml wins a name conflict.
  final Map<String, Config> keyFlavors = {};
  if (configIsExplicitFile) {
    keyFlavors.addAll(
      Config.loadFlavorConfigsFromPath(
        argResults[configOption] as String,
        prefixPath,
      ),
    );
  } else {
    final yamlFile = configIsFolder ? path.join(configValue, constants.defaultConfigFileName) : constants.defaultConfigFileName;
    for (final file in [yamlFile, paths.pubspecFilePath]) {
      for (final entry in Config.loadFlavorConfigsFromPath(file, prefixPath).entries) {
        keyFlavors.putIfAbsent(entry.key, () => entry.value);
      }
    }
  }

  // Union of file-discovered flavors and suffixed-key flavors. A
  // `launcher_icons-<flavor>.yaml` file wins over a section with the same
  // name (the file is the more specific declaration).
  final ordered = <String, _FlavorSource>{};
  ordered.addAll({
    for (final name in keyFlavors.keys) name: _KeyFlavor(keyFlavors[name]!),
  });
  if (hasFileFlavors) {
    for (final entry in flavors.entries) {
      ordered[entry.key] = _FileFlavor(entry.value);
    }
  }

  final requestedFlavor = argResults[flavorOption] as String?;
  // An unknown --flavor is a CLI usage error: throw before the generation
  // try/catch blocks so it propagates instead of exiting.
  if (requestedFlavor != null && !ordered.containsKey(requestedFlavor)) {
    final known = ordered.keys.join(', ');
    throw NoConfigFoundException(
      'No configuration found for "$requestedFlavor" flavor.'
      '${known.isEmpty ? '' : ' Available flavors: $known.'}',
    );
  }

  // Create icons
  if (ordered.isEmpty && requestedFlavor == null) {
    // Load configs from given file(defaults to ./launcher_icons.yaml) or from ./pubspec.yaml

    final flutterLauncherIconsConfigs = loadConfigFileFromArgResults(
      argResults,
      explicitFile: configIsExplicitFile,
      logger: logger,
    );
    if (flutterLauncherIconsConfigs == null) {
      throw NoConfigFoundException(
        'No configuration found in ${constants.defaultConfigFileName} or in ${paths.pubspecFilePath}. '
        'In case file exists in different directory use --config option',
      );
    }
    try {
      await createIconsFromConfig(
        flutterLauncherIconsConfigs,
        logger,
        prefixPath,
      );
      logger.info('\n✓ Successfully generated launcher icons');
    } on IconGenerationException catch (e) {
      logger.error('\n✕ Could not generate launcher icons');
      logger.error(e);
      exit(1);
    } catch (e) {
      logger.error('\n✕ Could not generate launcher icons');
      logger.error(e);
      exit(2);
    }
  } else {
    try {
      if (requestedFlavor != null) {
        final source = ordered[requestedFlavor]!;
        final config = _loadFlavorConfig(
          requestedFlavor,
          source,
          prefixPath,
        );
        if (config == null) {
          throw NoConfigFoundException(
            'No configuration found for "$requestedFlavor" flavor.',
          );
        }
        logger.info('\nFlavor: $requestedFlavor');
        await createIconsFromConfig(
          config,
          logger,
          prefixPath,
          requestedFlavor,
        );
        logger.info('\n✓ Successfully generated launcher icons');
        return;
      }
      await _runFlavorLoop(ordered, logger, prefixPath);
    } on IconGenerationException catch (e) {
      logger.error('\n✕ Could not generate launcher icons for flavors');
      logger.error(e);
      exit(1);
    } catch (e) {
      logger.error('\n✕ Could not generate launcher icons for flavors');
      logger.error(e);
      exit(2);
    }
  }
}

/// Discovers flavor configs directly inside [searchPath], mapping flavor
/// name to file path. The search is flat: configs must live directly in
/// the folder, never nested. Paths are absolute so loading stays correct
/// regardless of the project-root prefix.
Future<Map<String, String>> getFlavors({String searchPath = '.'}) async {
  final flavors = <String, String>{};

  await for (final item in Directory(searchPath).list(recursive: false)) {
    if (item is File) {
      final name = path.basename(item.path);
      final match = RegExp(flavorConfigFilePattern).firstMatch(name);
      if (match != null) {
        flavors[match.group(1)!] = path.absolute(item.path);
      }
    }
  }
  return flavors;
}

/// Returns the flavor named by an explicit `-f launcher_icons-<flavor>.yaml` argument, or `null` when `-f` does not point at a flavor config file.
String? explicitFlavorFromArgs(ArgResults argResults) {
  final String filePath = argResults[configOption] as String;
  final match = RegExp(flavorConfigFilePattern).firstMatch(path.basename(filePath));
  return match?.group(1);
}

/// Where a flavor's config comes from: a suffixed
/// `launcher_icons-<flavor>:` section or a file.
sealed class _FlavorSource {
  const _FlavorSource();
}

/// A suffixed section already parsed from its file.
class _KeyFlavor extends _FlavorSource {
  const _KeyFlavor(this.config);
  final Config config;
}

/// A `launcher_icons-<flavor>.yaml` file at [filePath].
class _FileFlavor extends _FlavorSource {
  const _FileFlavor(this.filePath);
  final String filePath;
}

/// Loads the effective config for [flavor] from [source], or null when a
/// flavor file vanished between discovery and loading.
Config? _loadFlavorConfig(
  String flavor,
  _FlavorSource source,
  String prefixPath,
) {
  return switch (source) {
    _KeyFlavor(:final config) => config,
    _FileFlavor(:final filePath) => Config.loadConfigFromPath(filePath, prefixPath),
  };
}

/// Runs every flavor in [ordered], failing loudly on a vanished file.
Future<void> _runFlavorLoop(
  Map<String, _FlavorSource> ordered,
  LILogger logger,
  String prefixPath,
) async {
  for (final entry in ordered.entries) {
    final flavor = entry.key;
    logger.info('\nFlavor: $flavor');
    final flutterLauncherIconsConfigs = _loadFlavorConfig(
      flavor,
      entry.value,
      prefixPath,
    );
    if (flutterLauncherIconsConfigs == null) {
      throw NoConfigFoundException(
        'No configuration found for $flavor flavor.',
      );
    }
    await createIconsFromConfig(
      flutterLauncherIconsConfigs,
      logger,
      prefixPath,
      flavor,
    );
  }
  logger.info('\n✓ Successfully generated launcher icons for flavors');
}

/// Generates icons for every enabled platform in [flutterConfigs],
/// throwing when no platform is enabled or a platform run fails.
Future<void> createIconsFromConfig(
  Config flutterConfigs,
  LILogger logger,
  String prefixPath, [
  String? flavor,
]) async {
  if (!flutterConfigs.hasEnabledPlatform) {
    throw const InvalidConfigException(errors.errorNoPlatformEnabled);
  }

  // Generates Icons for given platform
  await generateIconsFor(
    config: flutterConfigs,
    logger: logger,
    prefixPath: prefixPath,
    flavor: flavor,
    platforms: (context) {
      final platforms = <IconGenerator>[];
      if (flutterConfigs.hasAndroidConfig) {
        platforms.add(AndroidIconGenerator(context));
      }
      if (flutterConfigs.hasIOSConfig) {
        platforms.add(IosIconGenerator(context));
      }
      if (flutterConfigs.hasWebConfig) {
        platforms.add(WebIconGenerator(context));
      }
      if (flutterConfigs.hasWindowsConfig) {
        platforms.add(WindowsIconGenerator(context));
      }
      if (flutterConfigs.hasMacOSConfig) {
        platforms.add(MacOSIconGenerator(context));
      }
      if (flutterConfigs.hasLinuxConfig) {
        platforms.add(LinuxIconGenerator(context));
      }
      return platforms;
    },
  );
}

/// Loads the config named by `-c` (falling back to `pubspec.yaml`),
/// preferring pubspec when the default file is an unedited template.
///
/// When `-c` names a folder, only that folder's launcher_icons.yaml is
/// tried; the fallback is always the project-root pubspec.yaml (-r),
/// never a pubspec inside the folder.
Config? loadConfigFileFromArgResults(
  ArgResults argResults, {
  bool explicitFile = false,
  LILogger? logger,
}) {
  final String prefixPath = argResults[prefixOption] as String;
  final String configValue = argResults[configOption] as String;
  if (Directory(path.join(prefixPath, configValue)).existsSync()) {
    return Config.loadConfigFromPath(
          path.join(configValue, constants.defaultConfigFileName),
          prefixPath,
        ) ??
        Config.loadConfigFromPubSpec(prefixPath);
  }
  final String filePath = configValue;
  final flutterLauncherIconsConfigs = Config.loadConfigFromPath(
        filePath,
        prefixPath,
      ) ??
      Config.loadConfigFromPubSpec(prefixPath);
  if (flutterLauncherIconsConfigs == null) {
    return null;
  }
  // fluttercommunity/flutter_launcher_icons#628: an unedited `:generate` template still points at the phantom
  // `assets/icon/icon.png`. When the default config file is in play (not an
  // explicit `-f`) and none of its images exist while pubspec's do, the stale template is shadowing the real config — warn and prefer pubspec. An explicitly requested file is always honored, with a warning.
  if (filePath == constants.defaultConfigFileName) {
    final pubspecConfigs = Config.loadConfigFromPubSpec(prefixPath);
    if (pubspecConfigs != null && !_hasExistingImage(flutterLauncherIconsConfigs, prefixPath) && _hasExistingImage(pubspecConfigs, prefixPath)) {
      utils.printStatus(
        'Warning: ${constants.defaultConfigFileName} looks like an unedited generated template '
                '(its icon files were not found) while pubspec.yaml declares icons that exist. ' +
            (explicitFile
                ? 'Continuing with ${constants.defaultConfigFileName} as requested.'
                : 'Using pubspec.yaml instead. '
                    'Delete ${constants.defaultConfigFileName} or pass -f to be explicit.'),
        logger,
      );
      if (!explicitFile) {
        return pubspecConfigs;
      }
    }
  }
  return flutterLauncherIconsConfigs;
}

/// Whether `-c`/`--config` was explicitly passed on the command line.
bool isConfigOptionExplicit(List<String> arguments) {
  return arguments.any(
    (arg) => arg == '-c' || arg == '--config' || arg.startsWith('--config=') || arg.startsWith('-c='),
  );
}

/// Whether any image referenced by [config] exists under [prefixPath].
bool _hasExistingImage(Config config, String prefixPath) {
  final candidates = <String?>[
    config.imagePath,
    config.androidConfig?.imagePath,
    config.iosConfig?.imagePath,
    config.webConfig?.imagePath,
    config.windowsConfig?.imagePath,
    config.macOSConfig?.imagePath,
    config.linuxConfig?.imagePath,
  ];
  return candidates.whereType<String>().any((image) => File(path.join(prefixPath, image)).existsSync());
}
