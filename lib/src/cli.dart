import 'dart:io';

import 'package:args/args.dart';
import 'package:launcher_icons/src/config/config.dart';
import 'package:launcher_icons/src/core/constants.dart';
import 'package:launcher_icons/src/core/custom_exceptions.dart';
import 'package:launcher_icons/src/core/icon_generator.dart';
import 'package:launcher_icons/src/core/logger.dart';
import 'package:launcher_icons/src/core/paths.dart' as paths;
import 'package:launcher_icons/src/platforms/android/android_icon_generator.dart';
import 'package:launcher_icons/src/platforms/ios/ios_icon_generator.dart';
import 'package:launcher_icons/src/platforms/linux/linux_icon_generator.dart';
import 'package:launcher_icons/src/platforms/macos/macos_icon_generator.dart';
import 'package:launcher_icons/src/platforms/web/web_icon_generator.dart';
import 'package:launcher_icons/src/platforms/windows/windows_icon_generator.dart';
import 'package:launcher_icons/src/version.dart';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

/// CLI option name for the folder of config files (`-c`).
const String configOption = 'config';

/// CLI option name for the flavor selection (`-f`).
const String flavorOption = 'flavor';

/// CLI option name for the project-root dir prefix (`-d`).
const String prefixOption = 'dir';

/// File-name pattern for per-flavor configs (`launcher_icons-<flavor>.yaml`).
const String flavorConfigFilePattern = r'^launcher_icons-(.*).yaml$';

/// CLI entry point: parses [arguments], loads configs (including the flavor loop), and generates icons, exiting 0/1/2 on success, generation failure, or config/CLI failure.
Future<void> createIconsFromArguments(List<String> arguments) async {
  final ArgParser parser = ArgParser(allowTrailingOptions: true);
  parser
    ..addFlag(
      'help',
      abbr: 'h',
      help: 'Usage Help',
      negatable: false,
    )
    ..addFlag(
      'version',
      help: 'Tool Version',
      negatable: false,
    )
    ..addFlag(
      'verbose',
      abbr: 'v',
      help: 'Verbose Output',
      defaultsTo: false,
    )
    ..addOption(
      configOption,
      abbr: 'c',
      help: 'Path to search for configuration files in',
      defaultsTo: '.',
    )
    ..addOption(
      flavorOption,
      abbr: 'f',
      help: 'Run a single flavor (from a launcher_icons-<flavor> section or a launcher_icons-<flavor>.yaml file)',
    )
    ..addOption(
      prefixOption,
      abbr: 'd',
      help: 'Set a different project root directory (cwd by default)',
      defaultsTo: '.',
    );

  final argResults = parser.parse(arguments);
  final logger = LILogger(argResults.flag('verbose')); // creating logger based on -v flag

  logger.verbose('Received args ${argResults.arguments}');

  if (argResults.flag('version')) {
    print(packageVersion);
    exit(0);
  }

  print(introMessage());

  if (argResults.flag('help')) {
    logger.info('Generates launcher icons for Flutter projects');
    logger.info(parser.usage);
    exit(0);
  }

  final prefixPath = argResults[prefixOption] as String;
  final configValue = (argResults[configOption] as String) == '' ? '.' : argResults[configOption] as String; // Specified folder or CWD
  final requestedFlavor = (argResults[flavorOption] as String?) == '' ? null : argResults[flavorOption] as String?;

  if (!Directory(configValue).existsSync()) {
    throw InvalidCommandException('Config folder ${Directory(configValue).absolute} does not exist!');
  }

  final configs = <String, Config>{};

  // Folder's default-named yaml: default section plus any suffixed flavors.
  mergeConfigs(
    configs,
    configSections(path.join(configValue, paths.defaultConfigFileName)),
    paths.defaultConfigFileName,
  );

  // Collect all flavors from discovered flavor config files. Each file carries its own `launcher_icons-<flavor>:` section keyed by the file name.
  for (var flavor in (await getFlavors(configValue)).entries) {
    final sections = configSections(flavor.value);
    final section = sections[flavor.key];
    if (section != null) {
      mergeConfigs(
        configs,
        {flavor.key: section},
        path.basename(flavor.value),
      );
    }
  }

  // Parse all the pubspec configs (project root only, never the folder).
  mergeConfigs(
    configs,
    configSections(path.join(prefixPath, paths.pubspecFilePath)),
    'pubspec.yaml',
  );

  // An unknown --flavor is a CLI usage error: throw before running so it propagates instead of exiting.
  if (requestedFlavor != null && !configs.containsKey(requestedFlavor)) {
    final known = configs.keys.where((k) => k != 'launcher_icons').join(', ');
    throw NoConfigFoundException(
      'No configuration found for "$requestedFlavor" flavor.'
      '${known.isEmpty ? '' : ' Available flavors: $known.'}',
    );
  }

  // If a specific flavor was requested, purge all other flavors now
  if (requestedFlavor != null) {
    configs.removeWhere((k, _) => k != requestedFlavor);
  }

  if (configs.isEmpty) {
    throw const InvalidConfigException('Configuration or Flavor not found!');
  }

  // The default config runs nameless; every other entry runs as its bare flavor name so outputs land in the flavored locations.
  final bool loopFlavors = requestedFlavor == null && !(configs.length == 1 && configs.containsKey('launcher_icons'));
  for (final entry in configs.entries) {
    final flavor = entry.key == 'launcher_icons' ? null : entry.key;
    if (flavor != null) {
      logger.info('\nFlavor: $flavor');
    }
    if (!entry.value.hasEnabledPlatform) {
      throw const InvalidConfigException('No platform enabled within config to generate icons for. Set "generate: true" for at least one platform.');
    }
    try {
      final failedPlatforms = <String>[];
      final context = IconGeneratorContext(
        config: entry.value,
        logger: logger,
        prefixPath: prefixPath,
        flavor: flavor,
      );
      final platformList = <IconGenerator>[];
      if (entry.value.androidEnabled) {
        platformList.add(AndroidIconGenerator(context));
      }
      if (entry.value.iosEnabled) {
        platformList.add(IosIconGenerator(context));
      }
      if (entry.value.webEnabled) {
        platformList.add(WebIconGenerator(context));
      }
      if (entry.value.windowsEnabled) {
        platformList.add(WindowsIconGenerator(context));
      }
      if (entry.value.macOSEnabled) {
        platformList.add(MacOSIconGenerator(context));
      }
      if (entry.value.linuxEnabled) {
        platformList.add(LinuxIconGenerator(context));
      }

      for (final platform in platformList) {
        final progress = logger.progress('Creating Icons for ${platform.platformName}');
        logger.verbose('Validating platform requirements for ${platform.platformName}');
        // A failing platform must not stop the remaining ones, but the run as a whole still fails: failures are collected and reported together via [IconGenerationException] below.
        try {
          if (!platform.validateRequirements()) {
            logger.error('Requirements failed for platform ${platform.platformName}. Skipped');
            progress.cancel();
            continue;
          }
          await platform.createIcons();
          progress.finish(message: 'done', showTiming: true);
        } catch (e, st) {
          progress.cancel();
          logger
            ..error(e.toString())
            ..verbose(st);
          failedPlatforms.add(platform.platformName);
          continue;
        }
      }
      if (failedPlatforms.isNotEmpty) {
        throw IconGenerationException(failedPlatforms);
      }
    } on IconGenerationException catch (e) {
      logger.error('\n✕ Could not generate launcher icons');
      logger.error(e);
      exit(1);
    } catch (e) {
      logger.error('\n✕ Could not generate launcher icons');
      logger.error(e);
      exit(2);
    }
  }
  logger.info(
    loopFlavors ? '\n✓ Successfully generated launcher icons for flavors' : '\n✓ Successfully generated launcher icons',
  );
}

/// Discovers flavor configs directly inside [searchPath], mapping flavor name to file path. The search is flat: configs must live directly in the folder, never nested. Paths are absolute so loading stays correct regardless of the project-root prefix.
Future<Map<String, String>> getFlavors(String searchPath) async {
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

/// Reads the `launcher_icons` and `launcher_icons-<flavor>` sections out of the yaml file at [filePath], keyed by bare flavor name (`launcher_icons` itself keeps its full key as the default config). Missing, empty, or section-less files yield no sections.
Map<String, Map<dynamic, dynamic>> configSections(String filePath) {
  final file = File(filePath);
  if (!file.existsSync()) {
    return {};
  }
  final yaml = loadYaml(file.readAsStringSync());
  if (yaml is! Map<dynamic, dynamic>) {
    return {};
  }
  final sections = <String, Map<dynamic, dynamic>>{};
  for (final entry in yaml.entries) {
    final key = entry.key.toString();
    if (key != 'launcher_icons' && !key.startsWith('launcher_icons-')) {
      continue;
    }
    final value = entry.value;
    if (value is! Map<dynamic, dynamic>) {
      throw InvalidConfigException('Invalid `$key` value `$value`: each flavor section must be a map with the same shape as the `launcher_icons:` config.');
    }
    final name = key == 'launcher_icons' ? key : key.substring('launcher_icons-'.length);
    sections[name] = value;
  }
  return sections;
}

/// Merges decoded [sections] into [configs], throwing when a flavor is declared in more than one place. [source] names the file for the error.
void mergeConfigs(Map<String, Config> configs, Map<String, Map<dynamic, dynamic>> sections, String source) {
  for (final entry in sections.entries) {
    if (configs.containsKey(entry.key)) {
      final key = entry.key == 'launcher_icons' ? entry.key : 'launcher_icons-${entry.key}';
      throw InvalidConfigException('Configuration found both as $key in $source and as a dedicated config file! Choose one!');
    }
    configs[entry.key] = Config.fromJson(entry.value);
  }
}
