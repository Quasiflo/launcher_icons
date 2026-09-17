import 'dart:io';

import 'package:args/args.dart';
import 'package:launcher_icons/src/config/config.dart';
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

/// CLI option name for the config file path (`-f`).
const String fileOption = 'file';

/// CLI flag name for usage help (`-h`).
const String helpFlag = 'help';

/// CLI flag name for verbose logging (`-v`).
const String verboseFlag = 'verbose';

/// CLI option name for the project-root prefix (`-p`).
const String prefixOption = 'prefix';

/// Default config file name.
const String defaultConfigFile = 'launcher_icons.yaml';

/// File-name pattern for per-flavor configs (`launcher_icons-<flavor>.yaml`).
const String flavorConfigFilePattern = r'^launcher_icons-(.*).yaml$';

/// Discovers flavor names by scanning [searchPath] for flavor config files.
Future<List<String>> getFlavors({String searchPath = '.'}) async {
  final List<String> flavors = [];

  // Recursively search through directories
  await for (var item in Directory(searchPath).list(recursive: true)) {
    if (item is File) {
      final name = path.basename(item.path);
      final match = RegExp(flavorConfigFilePattern).firstMatch(name);
      if (match != null) {
        flavors.add(match.group(1)!);
      }
    }
  }
  return flavors;
}

/// Returns the flavor named by an explicit `-f launcher_icons-<flavor>.yaml` argument, or `null` when `-f` does not point at a flavor config file.
String? explicitFlavorFromArgs(ArgResults argResults) {
  final String filePath = argResults[fileOption] as String;
  final match =
      RegExp(flavorConfigFilePattern).firstMatch(path.basename(filePath));
  return match?.group(1);
}

/// CLI entry point: parses [arguments], loads configs (including the
/// flavor loop), and generates icons, exiting 0/1/2 on success,
/// generation failure, or config/CLI failure.
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
      help: 'Verbose output',
      defaultsTo: false,
    )
    // Make default null to differentiate when it is explicitly set
    ..addOption(
      fileOption,
      abbr: 'f',
      help: 'Path to config file',
      defaultsTo: defaultConfigFile,
    )
    ..addOption(
      prefixOption,
      abbr: 'p',
      help: 'Generates icons in the given path (project root by default)',
      defaultsTo: '.',
    )
    ..addOption(
      'flavor-path',
      help: 'Path to search for flavor configuration files',
      defaultsTo: '.',
    )
    ..addOption(
      'flavor',
      help: 'Run a single flavor (from a launcher_icons-<flavor> section '
          'or a launcher_icons-<flavor>.yaml file)',
    );

  final argResults = parser.parse(arguments);
  // creating logger based on -v flag
  final logger = LILogger(argResults.flag(verboseFlag));

  logger.verbose('Received args ${argResults.arguments}');

  if (argResults.flag(helpFlag)) {
    logger.info('Generates icons for iOS and Android');
    logger.info(parser.usage);
    exit(0);
  }

  // Flavors management
  final String prefixPath = argResults[prefixOption] as String;

  // An explicit `-f launcher_icons-<flavor>.yaml` runs only that
  // flavor instead of looping over every discovered flavor (fluttercommunity/flutter_launcher_icons#215). The file is loaded from the given path directly, so flavor configs in subdirectories work too.
  final onlyFlavor = explicitFlavorFromArgs(argResults);
  if (onlyFlavor != null) {
    final requestedFlavor = argResults['flavor'] as String?;
    if (requestedFlavor != null && requestedFlavor != onlyFlavor) {
      throw InvalidConfigException(
        'Conflicting flavor selection: -f points at the "$onlyFlavor" '
        'flavor file while --flavor requests "$requestedFlavor". '
        'Pass only one of them.',
      );
    }
    final String filePath = argResults[fileOption] as String;
    final flutterLauncherIconsConfigs = Config.loadConfigFromPath(
      filePath,
      prefixPath,
    );
    if (flutterLauncherIconsConfigs == null) {
      throw NoConfigFoundException(
        'No configuration found for $onlyFlavor flavor at $filePath. '
        'To discover flavor files in subdirectories use --flavor-path.',
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

  final flavors =
      await getFlavors(searchPath: argResults['flavor-path'] as String);
  // An explicit `-f` for a non-flavor file is honored as-is instead of
  // looping over discovered flavor files (fluttercommunity/flutter_launcher_icons#426). (An explicit flavor file is already handled by the onlyFlavor branch above.) Suffixed
  // `launcher_icons-<flavor>:` sections inside the pinned file still count:
  // `-f` pins the file, not the absence of flavors.
  final hasFileFlavors = flavors.isNotEmpty && !isFileOptionExplicit(arguments);

  // Suffixed flavor sections live in the pinned file when `-f` names one,
  // otherwise in launcher_icons.yaml (when present) and pubspec.yaml, with the yaml winning a name conflict.
  final Map<String, Config> keyFlavors = {};
  if (isFileOptionExplicit(arguments)) {
    keyFlavors.addAll(
      Config.loadFlavorConfigsFromPath(
        argResults[fileOption] as String,
        prefixPath,
      ),
    );
  } else {
    for (final file in [defaultConfigFile, paths.pubspecFilePath]) {
      for (final entry
          in Config.loadFlavorConfigsFromPath(file, prefixPath).entries) {
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
    for (final flavor in flavors) {
      ordered[flavor] = const _FileFlavor();
    }
  }

  final requestedFlavor = argResults['flavor'] as String?;
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
      explicitFile: isFileOptionExplicit(arguments),
      logger: logger,
    );
    if (flutterLauncherIconsConfigs == null) {
      throw NoConfigFoundException(
        'No configuration found in $defaultConfigFile or in ${paths.pubspecFilePath}. '
        'In case file exists in different directory use --file option',
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

/// A `launcher_icons-<flavor>.yaml` file.
class _FileFlavor extends _FlavorSource {
  const _FileFlavor();
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
    _FileFlavor() => Config.loadConfigFromFlavor(flavor, prefixPath),
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

/// Loads the config named by `-f` (falling back to `pubspec.yaml`),
/// preferring pubspec when the default file is an unedited template.
Config? loadConfigFileFromArgResults(
  ArgResults argResults, {
  bool explicitFile = false,
  LILogger? logger,
}) {
  final String prefixPath = argResults[prefixOption] as String;
  final String filePath = argResults[fileOption] as String;
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
  if (filePath == defaultConfigFile) {
    final pubspecConfigs = Config.loadConfigFromPubSpec(prefixPath);
    if (pubspecConfigs != null &&
        !_hasExistingImage(flutterLauncherIconsConfigs, prefixPath) &&
        _hasExistingImage(pubspecConfigs, prefixPath)) {
      utils.printStatus(
        'Warning: $defaultConfigFile looks like an unedited generated template '
                '(its icon files were not found) while pubspec.yaml declares icons that exist. ' +
            (explicitFile
                ? 'Continuing with $defaultConfigFile as requested.'
                : 'Using pubspec.yaml instead. '
                    'Delete $defaultConfigFile or pass -f to be explicit.'),
        logger,
      );
      if (!explicitFile) {
        return pubspecConfigs;
      }
    }
  }
  return flutterLauncherIconsConfigs;
}

/// Whether `-f`/`--file` was explicitly passed on the command line.
bool isFileOptionExplicit(List<String> arguments) {
  return arguments.any(
    (arg) =>
        arg == '-f' ||
        arg == '--file' ||
        arg.startsWith('--file=') ||
        arg.startsWith('-f='),
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
  return candidates
      .whereType<String>()
      .any((image) => File(path.join(prefixPath, image)).existsSync());
}
