import 'dart:async';
import 'dart:io';

import 'package:launcher_icons/src/cli.dart' as main_dart;
import 'package:launcher_icons/src/core/custom_exceptions.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

// End-to-end tests for suffixed `launcher_icons-<flavor>:` sections plus
// `--flavor` selection through createIconsFromArguments. Same sandbox
// discipline as cli_flavor_test.dart: CWD is process-global, execution is
// serialized via dart_test.yaml, print output is captured through a zone,
// and the sandbox path is absolute (a relative one would rebase after the
// chdir below).
void main() {
  group('createIconsFromArguments suffixed flavor sections', () {
    late String originalDir;
    late String sandboxDir;

    const keyedYaml = '''
launcher_icons:
  image_path: "icon.png"
  windows:
    generate: true
launcher_icons-staging:
  image_path: "icon.png"
  windows:
    generate: true
    icon_filename: "key_staging.ico"
launcher_icons-production:
  image_path: "icon.png"
  windows:
    generate: true
    icon_filename: "key_production.ico"
''';

    setUp(() async {
      originalDir = Directory.current.path;
      sandboxDir = path.join(
        originalDir,
        '.dart_tool',
        'launcher_icons',
        'test',
        'cli_flavor_keys',
      );
      final sandbox = Directory(sandboxDir);
      if (sandbox.existsSync()) {
        sandbox.deleteSync(recursive: true);
      }
      sandbox.createSync(recursive: true);
      await Directory(path.join(sandboxDir, 'windows', 'runner', 'resources')).create(recursive: true);
      File(path.join(originalDir, 'test', 'assets', 'master-light-1024.png')).copySync(path.join(sandboxDir, 'icon.png'));
      await File(path.join(sandboxDir, 'launcher_icons.yaml')).writeAsString(keyedYaml);
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

    bool icoExists(String name) => File(
          path.join(
            sandboxDir,
            'windows',
            'runner',
            'resources',
            name,
          ),
        ).existsSync();

    test('loops over suffixed sections without -c', () async {
      final printed = await runCli([]);

      expect(printed.any((line) => line.contains('Flavor: staging')), isTrue);
      expect(
        printed.any((line) => line.contains('Flavor: production')),
        isTrue,
      );
      expect(printed.any((line) => line.contains('for flavors')), isTrue);
      expect(icoExists('key_staging.ico'), isTrue);
      expect(icoExists('key_production.ico'), isTrue);
    });

    test('pubspec-only sections loop without launcher_icons.yaml', () async {
      await File(path.join(sandboxDir, 'launcher_icons.yaml')).delete();
      await File(path.join(sandboxDir, 'pubspec.yaml')).writeAsString(keyedYaml);

      final printed = await runCli([]);

      expect(printed.any((line) => line.contains('Flavor: staging')), isTrue);
      expect(
        printed.any((line) => line.contains('Flavor: production')),
        isTrue,
      );
      expect(icoExists('key_staging.ico'), isTrue);
    });

    test('--flavor runs a single section', () async {
      final printed = await runCli(['--flavor', 'staging']);

      expect(printed.any((line) => line.contains('Flavor: staging')), isTrue);
      expect(
        printed.any((line) => line.contains('Flavor: production')),
        isFalse,
      );
      expect(
        printed.any(
          (line) => line.contains('Successfully generated launcher icons') && !line.contains('flavors'),
        ),
        isTrue,
      );
      expect(icoExists('key_staging.ico'), isTrue);
      expect(icoExists('key_production.ico'), isFalse);
    });

    test('--flavor with an unknown name throws', () async {
      await expectLater(
        runCli(['--flavor', 'qa']),
        throwsA(isA<NoConfigFoundException>()),
      );
    });

    test('duplicate file and pubspec section throws', () async {
      const fileYaml = '''
launcher_icons-staging:
  image_path: "icon.png"
  windows:
    generate: true
    icon_filename: "file_staging.ico"
''';
      await File(path.join(sandboxDir, 'launcher_icons-staging.yaml')).writeAsString(fileYaml);
      await File(path.join(sandboxDir, 'pubspec.yaml')).writeAsString('''
launcher_icons-staging:
  image_path: "icon.png"
  windows:
    generate: true
    icon_filename: "key_staging.ico"
''');

      await expectLater(
        runCli([]),
        throwsA(isA<InvalidConfigException>()),
      );
    });

    test('-c folder with -f flavor uses the folder file, flavor-named outputs', () async {
      const subYaml = '''
launcher_icons-myflav:
  image_path: "icon.png"
  windows:
    generate: true
    icon_filename: "app_myflav.ico"
''';
      await Directory(path.join(sandboxDir, 'sub')).create();
      await File(path.join(sandboxDir, 'sub', 'launcher_icons-myflav.yaml')).writeAsString(subYaml);

      final printed = await runCli(['-c', 'sub', '-f', 'myflav']);

      expect(printed.any((line) => line.contains('Flavor: myflav')), isTrue);
      // The section ran from sub/launcher_icons-myflav.yaml ...
      expect(icoExists('app_myflav.ico'), isTrue);
      // ...not from the root launcher_icons.yaml sections.
      expect(icoExists('key_staging.ico'), isFalse);
      expect(icoExists('key_production.ico'), isFalse);
    });
  });
}
