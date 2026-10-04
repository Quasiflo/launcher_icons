import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:launcher_icons/src/cli.dart' as cli;
import 'package:launcher_icons/src/config/config.dart';
import 'package:launcher_icons/src/core/custom_exceptions.dart';
import 'package:launcher_icons/src/core/icon_generator.dart';
import 'package:launcher_icons/src/core/logger.dart';
import 'package:launcher_icons/src/core/utils.dart' as utils;
import 'package:launcher_icons/src/platforms/web/web_icon_generator.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import '../templates.dart' as templates;

void main() {
  group('normalizeWebQueryString', () {
    test('off when absent, empty, or bare ?', () {
      expect(utils.normalizeWebQueryString(null), isNull);
      expect(utils.normalizeWebQueryString(''), isNull);
      expect(utils.normalizeWebQueryString('?'), isNull);
    });

    test('dynamic matches exactly, other casings are static tokens', () {
      expect(utils.normalizeWebQueryString('dynamic'), equals('dynamic'));
      expect(utils.normalizeWebQueryString('?dynamic'), equals('dynamic'));
      // Exact lowercase only triggers dynamic mode; other casings are
      // ordinary (valid) static tokens.
      expect(utils.normalizeWebQueryString('Dynamic'), equals('Dynamic'));
      expect(utils.normalizeWebQueryString('DYNAMIC'), equals('DYNAMIC'));
    });

    test('allows letters, digits, dots, underscores, dashes', () {
      expect(utils.normalizeWebQueryString('abcXYZ019'), equals('abcXYZ019'));
      expect(utils.normalizeWebQueryString('v1.2_3-4'), equals('v1.2_3-4'));
      expect(utils.normalizeWebQueryString('?stripme'), equals('stripme'));
    });

    test('rejects anything else', () {
      for (final bad in ['a b', 'a#b', 'a=b', 'a/b', 'a&b', 'a?b', 'v=abc', 'a:b', 'ä']) {
        expect(
          () => utils.normalizeWebQueryString(bad),
          throwsA(isA<InvalidConfigException>()),
          reason: bad,
        );
      }
      expect(
        () => utils.normalizeWebQueryString('a' * 129),
        throwsA(isA<InvalidConfigException>()),
      );
    });
  });

  group('shortOutputHash', () {
    test('is 7 lowercase hex chars, deterministic, content-sensitive', () {
      final a = utils.shortOutputHash([1, 2, 3]);
      final b = utils.shortOutputHash([1, 2, 3]);
      final c = utils.shortOutputHash([1, 2, 4]);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a, matches(RegExp(r'^[0-9a-f]{7}$')));
      expect(c, matches(RegExp(r'^[0-9a-f]{7}$')));
    });
  });

  group('WebIconGenerator query_string', () {
    late String prefixPath;
    final assetPath = path.join(Directory.current.path, 'test', 'assets');

    setUp(() async {
      final imageFile = File(path.join(assetPath, 'master-light-1024.png'));
      final svgFile = File(path.join(assetPath, 'master-light-1024.svg'));
      expect(imageFile.existsSync(), isTrue);
      expect(svgFile.existsSync(), isTrue);
      await d.dir('fli_test', [
        d.dir('web', [
          d.dir('icons'),
          d.file('index.html', templates.webIndexTemplate),
          d.file('manifest.json', templates.webManifestTemplate),
        ]),
        d.file('master-light-1024.png', imageFile.readAsBytesSync()),
        d.file('icon-favicon.svg', svgFile.readAsBytesSync()),
        d.file('og.png', imageFile.readAsBytesSync()),
        d.file('twitter.png', imageFile.readAsBytesSync()),
        d.file('shortcut.png', imageFile.readAsBytesSync()),
      ]).create();
      prefixPath = path.join(d.sandbox, 'fli_test');
    });

    WebIconGenerator generatorFor(
      final Map<String, dynamic> web, {
      final String? queryStringOverride,
    }) =>
        WebIconGenerator(
          IconGeneratorContext(
            config: Config.fromJson(<String, dynamic>{'web': web}),
            prefixPath: prefixPath,
            logger: LILogger(isVerbose: false),
            queryStringOverride: queryStringOverride,
          ),
        );

    Future<String> readIndex() => File(path.join(prefixPath, 'web', 'index.html')).readAsString();

    Future<Map<String, dynamic>> readManifest() async => jsonDecode(
          await File(path.join(prefixPath, 'web', 'manifest.json')).readAsString(),
        ) as Map<String, dynamic>;

    test('off by default emits bare URLs', () async {
      final generator = generatorFor(<String, dynamic>{
        'generate': true,
        'image_path': 'master-light-1024.png',
      });
      expect(generator.validateRequirements(), isTrue);
      await generator.createIcons();

      final index = await readIndex();
      expect(index, contains('href="favicon.png"'));
      expect(index, contains('href="manifest.json"'));
      expect(index, isNot(contains('favicon.png?')));
      expect(index, isNot(contains('manifest.json?')));

      final manifest = await readManifest();
      for (final icon in (manifest['icons'] as List).cast<Map<String, dynamic>>()) {
        expect(icon['src'] as String, isNot(contains('?')));
      }
    });

    test('static yaml token suffixes every emitted URL', () async {
      final generator = generatorFor(<String, dynamic>{
        'generate': true,
        'image_path': 'master-light-1024.png',
        'image_path_favicon_svg': 'icon-favicon.svg',
        'image_path_opengraph': 'og.png',
        'image_path_twitter': 'twitter.png',
        'query_string': 'build.42',
        'shortcut_icons': [
          {'image_path': 'shortcut.png', 'name': 'Search', 'url': '/search'},
        ],
      });
      expect(generator.validateRequirements(), isTrue);
      await generator.createIcons();

      final index = await readIndex();
      expect(index, contains('href="favicon.ico?build.42"'));
      expect(index, contains('href="favicon.png?build.42"'));
      expect(index, contains('href="favicon.svg?build.42"'));
      expect(index, contains('href="icons/apple-touch-icon.png?build.42"'));
      expect(index, contains('href="manifest.json?build.42"'));
      expect(index, contains('content="opengraph.png?build.42"'));
      expect(index, contains('content="twitter.png?build.42"'));
      // No v= prefix anywhere.
      expect(index, isNot(contains('?v=')));

      final manifest = await readManifest();
      for (final icon in (manifest['icons'] as List).cast<Map<String, dynamic>>()) {
        expect(icon['src'] as String, endsWith('?build.42'));
      }
      final shortcuts = (manifest['shortcuts'] as List).cast<Map<String, dynamic>>();
      expect(shortcuts, hasLength(1));
      // Navigation url untouched; only the icon src is suffixed.
      expect(shortcuts.first['url'], equals('/search'));
      final shortcutSrcs = (shortcuts.first['icons'] as List).cast<Map<String, dynamic>>();
      expect(shortcutSrcs.single['src'] as String, endsWith('?build.42'));
    });

    test('leading ? in yaml is tolerated', () async {
      final generator = generatorFor(<String, dynamic>{
        'generate': true,
        'image_path': 'master-light-1024.png',
        'query_string': '?stripme',
      });
      expect(generator.validateRequirements(), isTrue);
      await generator.createIcons();
      expect(await readIndex(), contains('href="favicon.png?stripme"'));
    });

    test('CLI override wins over yaml; CLI "" strips', () async {
      final yamlWeb = <String, dynamic>{
        'generate': true,
        'image_path': 'master-light-1024.png',
        'query_string': 'yaml-token',
      };
      final overridden = generatorFor(yamlWeb, queryStringOverride: 'cli-token');
      expect(overridden.validateRequirements(), isTrue);
      await overridden.createIcons();
      expect(await readIndex(), contains('href="favicon.png?cli-token"'));

      // Fresh sandbox state for the strip case is covered by setUp; rerun
      // with an explicit empty CLI override over a yaml token.
      final stripped = generatorFor(yamlWeb, queryStringOverride: '');
      expect(stripped.validateRequirements(), isTrue);
      await stripped.createIcons();
      final index = await readIndex();
      expect(index, contains('href="favicon.png"'));
      expect(index, isNot(contains('favicon.png?')));
    });

    test('CLI "dynamic" enables dynamic mode over a static yaml', () async {
      final generator = generatorFor(
        <String, dynamic>{
          'generate': true,
          'image_path': 'master-light-1024.png',
          'query_string': 'static-token',
        },
        queryStringOverride: 'dynamic',
      );
      expect(generator.validateRequirements(), isTrue);
      await generator.createIcons();
      final index = await readIndex();
      expect(index, isNot(contains('static-token')));
      expect(
        RegExp(r'favicon\.png\?[0-9a-f]{7}').hasMatch(index),
        isTrue,
      );
    });

    test('dynamic mode hashes each output file', () async {
      final generator = generatorFor(<String, dynamic>{
        'generate': true,
        'image_path': 'master-light-1024.png',
        'query_string': 'dynamic',
      });
      expect(generator.validateRequirements(), isTrue);
      await generator.createIcons();

      Future<String> hashOf(final String webRelative) async => utils.shortOutputHash(
            await File(path.join(prefixPath, 'web', webRelative)).readAsBytes(),
          );

      final index = await readIndex();
      expect(index, contains('href="favicon.png?${await hashOf('favicon.png')}"'));
      expect(index, contains('href="favicon.ico?${await hashOf('favicon.ico')}"'));
      expect(
        index,
        contains('href="icons/apple-touch-icon.png?${await hashOf('icons/apple-touch-icon.png')}"'),
      );
      expect(index, contains('href="manifest.json?${await hashOf('manifest.json')}"'));
      expect(index, isNot(contains('?v=')));

      final manifest = await readManifest();
      for (final icon in (manifest['icons'] as List).cast<Map<String, dynamic>>()) {
        final src = icon['src'] as String;
        final match = RegExp(r'^(.+)\?([0-9a-f]{7})$').firstMatch(src);
        expect(match, isNotNull, reason: src);
        expect(match!.group(2), equals(await hashOf(match.group(1)!)));
      }
    });

    test('rerun without a value strips previously written suffixes', () async {
      final versioned = generatorFor(<String, dynamic>{
        'generate': true,
        'image_path': 'master-light-1024.png',
        'query_string': 'build.42',
      });
      await versioned.createIcons();
      expect(await readIndex(), contains('favicon.png?build.42'));

      final bare = generatorFor(<String, dynamic>{
        'generate': true,
        'image_path': 'master-light-1024.png',
      });
      await bare.createIcons();
      final index = await readIndex();
      expect(index, contains('href="favicon.png"'));
      expect(index, isNot(contains('?build.42')));
      final manifest = await readManifest();
      for (final icon in (manifest['icons'] as List).cast<Map<String, dynamic>>()) {
        expect(icon['src'] as String, isNot(contains('?')));
      }
    });

    test('static reruns are idempotent', () async {
      final generator = generatorFor(<String, dynamic>{
        'generate': true,
        'image_path': 'master-light-1024.png',
        'query_string': 'build.42',
      });
      await generator.createIcons();
      final firstIndex = await readIndex();
      final firstManifest = await File(
        path.join(prefixPath, 'web', 'manifest.json'),
      ).readAsString();
      await generator.createIcons();
      expect(await readIndex(), equals(firstIndex));
      expect(
        await File(path.join(prefixPath, 'web', 'manifest.json')).readAsString(),
        equals(firstManifest),
      );
    });

    test('dynamic reruns are deterministic', () async {
      final generator = generatorFor(<String, dynamic>{
        'generate': true,
        'image_path': 'master-light-1024.png',
        'query_string': 'dynamic',
      });
      await generator.createIcons();
      final firstIndex = await readIndex();
      await generator.createIcons();
      expect(await readIndex(), equals(firstIndex));
    });

    test('invalid values fail validation and throw on create', () {
      for (final bad in ['has space', 'a=b', 'a/b', 'a#b', 'a&b']) {
        final generator = generatorFor(<String, dynamic>{
          'generate': true,
          'image_path': 'master-light-1024.png',
          'query_string': bad,
        });
        expect(generator.validateRequirements(), isFalse, reason: bad);
        expect(
          generator.createIcons(),
          throwsA(isA<InvalidConfigException>()),
          reason: bad,
        );
      }
      final cliBad = generatorFor(
        <String, dynamic>{
          'generate': true,
          'image_path': 'master-light-1024.png',
        },
        queryStringOverride: 'nope!',
      );
      expect(cliBad.validateRequirements(), isFalse);
    });
  });

  // End-to-end coverage for the --query-string/-q CLI flag through
  // createIconsFromArguments. Mutates process CWD like cli_flavor_test.dart;
  // serialized via dart_test.yaml.
  group('createIconsFromArguments --query-string', () {
    late String originalDir;
    late String sandboxAbs;

    setUp(() async {
      originalDir = Directory.current.path;
      final sandboxDir = path.join(
        '.dart_tool',
        'launcher_icons',
        'test',
        'cli_query_string',
      );
      final sandbox = Directory(sandboxDir);
      if (sandbox.existsSync()) {
        sandbox.deleteSync(recursive: true);
      }
      sandbox.createSync(recursive: true);
      sandboxAbs = sandbox.absolute.path;
      await Directory(path.join(sandboxAbs, 'web', 'icons')).create(recursive: true);
      await File(
        path.join(sandboxAbs, 'web', 'index.html'),
      ).writeAsString(templates.webIndexTemplate);
      await File(
        path.join(sandboxAbs, 'web', 'manifest.json'),
      ).writeAsString(templates.webManifestTemplate);
      File(
        path.join(originalDir, 'test', 'assets', 'master-light-1024.png'),
      ).copySync(path.join(sandboxAbs, 'icon.png'));
      await File(
        path.join(sandboxAbs, 'launcher_icons.yaml'),
      ).writeAsString('''
launcher_icons:
  web:
    generate: true
    image_path: "icon.png"
    query_string: "yaml-token"
''');
      Directory.current = sandboxAbs;
    });

    tearDown(() {
      Directory.current = originalDir;
    });

    Future<void> runCli(final List<String> args) => runZoned(
          () => cli.createIconsFromArguments(args),
          zoneSpecification: ZoneSpecification(
            print: (final self, final parent, final zone, final line) {},
          ),
        );

    Future<String> cliIndex() => File(path.join(sandboxAbs, 'web', 'index.html')).readAsString();

    test('yaml token applies without the flag', () async {
      await runCli([]);
      expect(await cliIndex(), contains('favicon.png?yaml-token'));
    });

    test('--query-string overrides yaml', () async {
      await runCli(['--query-string', 'cli-token']);
      final index = await cliIndex();
      expect(index, contains('favicon.png?cli-token'));
      expect(index, isNot(contains('yaml-token')));
    });

    test('-q abbr works and empty strips the yaml token', () async {
      await runCli(['-q', '']);
      final index = await cliIndex();
      expect(index, contains('href="favicon.png"'));
      expect(index, isNot(contains('?')));
    });

    test('--query-string=dynamic enables dynamic mode', () async {
      await runCli(['--query-string=dynamic']);
      expect(
        RegExp(r'favicon\.png\?[0-9a-f]{7}').hasMatch(await cliIndex()),
        isTrue,
      );
    });
  });
}
