import 'package:launcher_icons/src/config/config.dart';
import 'package:launcher_icons/src/core/icon_generator.dart';
import 'package:launcher_icons/src/core/logger.dart';
import 'package:test/test.dart';

// Unit tests for the IconGenerator base: context construction. (Platform
// orchestration used to live in generateIconsFor and is now inline in
// createIconsFromArguments, covered end to end by the cli_flavor suites.)
void main() {
  group('IconGeneratorContext', () {
    test('holds config, logger, prefix and flavor', () {
      const config = Config(imagePath: 'icon.png');
      final logger = LILogger(false);
      final context = IconGeneratorContext(
        config: config,
        logger: logger,
        prefixPath: 'prefix',
        flavor: 'staging',
      );

      expect(context.config, same(config));
      expect(context.logger, same(logger));
      expect(context.prefixPath, equals('prefix'));
      expect(context.flavor, equals('staging'));
    });

    test('flavor defaults to null', () {
      final context = IconGeneratorContext(
        config: const Config(),
        logger: LILogger(false),
        prefixPath: '.',
      );

      expect(context.flavor, isNull);
    });
  });
}
