import 'dart:async';
import 'dart:io';

import 'package:launcher_icons/src/cli.dart' as main_dart;
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

// End-to-end tests for flavor selection through createIconsFromArguments.
// These change the process working directory (the CLI resolves everything
// against CWD); test execution is serialized via dart_test.yaml.
//
// LILogger routes info output through top-level print (via cli_util's
// StandardLogger), so a print zone captures the CLI banners below.

// End-to-end tests for flavor selection through createIconsFromArguments.
// These change the process working directory (the CLI resolves everything
// against CWD); test execution is serialized via dart_test.yaml.
void main() {
  group('createIconsFromArguments flavor selection', () {
    late String originalDir;
    late String sandboxDir;

    const windowsYaml = '''
launcher_icons:
  image_path: "icon.png"
  windows:
    generate: true
''';

    String flavorYaml(String flavor) => '''
launcher_icons-$flavor:
  image_path: "icon.png"
  windows:
    generate: true
''';

    setUp(() async {
      originalDir = Directory.current.path;
      sandboxDir = path.join(
        '.dart_tool',
        'launcher_icons',
        'test',
        'cli_flavor',
      );
      final sandbox = Directory(sandboxDir);
      if (sandbox.existsSync()) {
        sandbox.deleteSync(recursive: true);
      }
      sandbox.createSync(recursive: true);
      await Directory(path.join(sandboxDir, 'windows')).create();
      File(path.join(originalDir, 'test', 'assets', 'master-light-1024.png')).copySync(path.join(sandboxDir, 'icon.png'));
      await File(
        path.join(sandboxDir, 'launcher_icons-staging.yaml'),
      ).writeAsString(flavorYaml('staging'));
      await File(
        path.join(sandboxDir, 'launcher_icons-production.yaml'),
      ).writeAsString(flavorYaml('production'));
      Directory.current = sandboxDir;
    });

    tearDown(() {
      Directory.current = originalDir;
    });

    Future<List<String>> runCli(List<String> args) async {
      final printed = <String>[];
      await runZoned(
        () => main_dart.createIconsFromArguments(args),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => printed.add(line),
        ),
      );
      return printed;
    }

    test('loops over all flavors without -c', () async {
      final printed = await runCli([]);
      expect(printed.any((line) => line.contains('Flavor: staging')), isTrue);
      expect(
        printed.any((line) => line.contains('Flavor: production')),
        isTrue,
      );
      expect(
        printed.any((line) => line.contains('for flavors')),
        isTrue,
      );
    });

    test('explicit --flavor runs only that flavor (fluttercommunity/flutter_launcher_icons#215)', () async {
      final printed = await runCli(['--flavor', 'staging']);
      expect(printed.any((line) => line.contains('Flavor: staging')), isTrue);
      expect(
        printed.any((line) => line.contains('Flavor: production')),
        isFalse,
      );
    });

    test('explicit -c folder with a default file bypasses the flavor loop (fluttercommunity/flutter_launcher_icons#426)', () async {
      final custom = path.join(Directory.current.path, 'customdir');
      await Directory(custom).create();
      await File(
        path.join(custom, 'launcher_icons.yaml'),
      ).writeAsString(windowsYaml);

      final printed = await runCli(['-c', 'customdir']);
      expect(
        printed.any((line) => line.contains('Flavor:')),
        isFalse,
      );
      expect(
        printed.any(
          (line) => line.contains('Successfully generated launcher icons') && !line.contains('flavors'),
        ),
        isTrue,
      );
    });

    test('explicit -c folder discovers flavors inside it', () async {
      // NOTE: Directory.current is already the sandbox here (see setUp),
      // so folder paths must be absolute.
      final sub = path.join(Directory.current.path, 'sub');
      await Directory(sub).create();
      await File(
        path.join(sub, 'launcher_icons-qa.yaml'),
      ).writeAsString(flavorYaml('qa'));

      final printed = await runCli(['-c', 'sub']);

      expect(printed.any((line) => line.contains('Flavor: qa')), isTrue);
      expect(
        printed.any((line) => line.contains('Flavor: staging')),
        isFalse,
      );
    });

    test('explicit -c folder ignores nested flavor files', () async {
      final sub = path.join(Directory.current.path, 'sub');
      await Directory(sub).create();
      await File(
        path.join(sub, 'launcher_icons-qa.yaml'),
      ).writeAsString(flavorYaml('qa'));
      final nested = path.join(sub, 'nested');
      await Directory(nested).create();
      await File(
        path.join(nested, 'launcher_icons-deep.yaml'),
      ).writeAsString(flavorYaml('deep'));

      final printed = await runCli(['-c', 'sub']);

      expect(printed.any((line) => line.contains('Flavor: qa')), isTrue);
      expect(printed.any((line) => line.contains('Flavor: deep')), isFalse);
    });

    test('explicit -c folder loads the default config inside it', () async {
      final plain = path.join(Directory.current.path, 'plain');
      await Directory(plain).create();
      await File(
        path.join(plain, 'launcher_icons.yaml'),
      ).writeAsString(windowsYaml);

      final printed = await runCli(['-c', 'plain']);

      expect(
        printed.any((line) => line.contains('Flavor:')),
        isFalse,
      );
      expect(
        printed.any(
          (line) => line.contains('Successfully generated launcher icons') && !line.contains('flavors'),
        ),
        isTrue,
      );
    });
  });
}
