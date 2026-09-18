import 'package:launcher_icons/src/config/android_config.dart';
import 'package:launcher_icons/src/config/config.dart';
import 'package:launcher_icons/src/config/ios_config.dart';
import 'package:launcher_icons/src/config/linux_config.dart';
import 'package:launcher_icons/src/config/macos_config.dart';
import 'package:launcher_icons/src/config/web_config.dart';
import 'package:launcher_icons/src/config/windows_config.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import '../bin/generate.dart' as generate;

// The `:generate` template must cover every schema key the loader
// validates: new keys without template coverage silently drift
// (fluttercommunity/flutter_launcher_icons#628 class of bug — the phantom
// because template and schema already diverged once).
void main() {
  group('configFileTemplate', () {
    Map<String, Set<String>> schemaKeys() => {
          'android': const AndroidConfig().toJson().keys.toSet(),
          'ios': const IOSConfig().toJson().keys.toSet(),
          'web': const WebConfig().toJson().keys.toSet(),
          'windows': const WindowsConfig().toJson().keys.toSet(),
          'macos': const MacOSConfig().toJson().keys.toSet(),
          'linux': const LinuxConfig().toJson().keys.toSet(),
        };

    test('covers every schema key per platform section', () {
      const template = generate.configFileTemplate;
      final missing = <String>[];
      for (final section in schemaKeys().entries) {
        // Find the section block, then look for each key as an active or
        // commented `key:` line within it.
        final sectionStart = template.indexOf('\n  ${section.key}:');
        expect(sectionStart, isNot(-1), reason: section.key);
        final nextSection = RegExp(r'\n  \w+:').firstMatch(
          template.substring(sectionStart + 1),
        );
        final block = nextSection == null
            ? template.substring(sectionStart)
            : template.substring(
                sectionStart,
                sectionStart + 1 + nextSection.start,
              );
        for (final key in section.value) {
          final keyPattern = RegExp(
            '^\\s*#?\\s*${RegExp.escape(key)}\\s*:',
            multiLine: true,
          );
          if (!keyPattern.hasMatch(block)) {
            missing.add('${section.key}.$key');
          }
        }
      }
      expect(missing, isEmpty, reason: 'template is missing: $missing');
    });

    test('parses to a valid enabled config', () {
      final config = Config.fromJson(
        loadYaml(
          generate.configFileTemplate,
        )['launcher_icons'] as Map<dynamic, dynamic>,
      );
      expect(config.hasEnabledPlatform, isTrue);
    });
  });
}
