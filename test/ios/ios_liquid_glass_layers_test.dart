import 'package:launcher_icons/src/config/config.dart';
import 'package:launcher_icons/src/core/custom_exceptions.dart';
import 'package:launcher_icons/src/platforms/ios/liquid_glass_icon_generator.dart';
import 'package:test/test.dart';

// Multi-layer composition: layers stack bottom-to-top in list order, each with its own artwork variants, position, and composition keys.
void main() {
  group('generateIconConfig layers', () {
    List<dynamic> layersFor(Map<String, dynamic> ios) {
      final config = Config.fromJson(<String, dynamic>{'ios': ios});
      final groups = generateIconConfig(config)['groups'] as List;
      return (groups.first as Map<String, dynamic>)['layers'] as List;
    }

    test('stacks layers bottom-to-top in list order', () {
      final layers = layersFor(<String, dynamic>{
        'generate': true,
        'liquid_glass_layers': [
          {'image_path': 'background.png'},
          {'image_path': 'glyph.png'},
        ],
      });

      expect(layers.length, equals(2));
      expect(
        (layers[0] as Map<String, dynamic>)['image-name'],
        equals('background.png'),
      );
      expect(
        (layers[1] as Map<String, dynamic>)['image-name'],
        equals('glyph.png'),
      );
    });

    test('emits per-layer position, glass, opacity, and blend mode', () {
      final layers = layersFor(<String, dynamic>{
        'generate': true,
        'liquid_glass_layers': [
          {'image_path': 'background.png'},
          {
            'image_path': 'glyph.png',
            'scale': 0.7,
            'offset_x': 4.0,
            'offset_y': -4.0,
            'glass': false,
            'opacity': 0.9,
            'blend_mode': 'Multiply',
          },
        ],
      });

      final glyph = layers[1] as Map<String, dynamic>;
      expect(
        glyph['position'],
        equals({
          'scale': 0.7,
          'translation-in-points': [4.0, -4.0],
        }),
      );
      expect(glyph['glass'], isFalse);
      expect(glyph['opacity'], equals(0.9));
      // Blend modes normalize to lowercase.
      expect(glyph['blend-mode'], equals('multiply'));
      // Untouched layers stay flat: no opt-in keys.
      final background = layers[0] as Map<String, dynamic>;
      expect(background.containsKey('opacity'), isFalse);
      expect(background.containsKey('blend-mode'), isFalse);
    });

    test('remove_liquid_glass overrides per-layer glass', () {
      final layers = layersFor(<String, dynamic>{
        'generate': true,
        'liquid_glass_layers': [
          {'image_path': 'background.png'},
          {'image_path': 'glyph.png'},
        ],
        'remove_liquid_glass': true,
      });

      for (final layer in layers) {
        expect((layer as Map<String, dynamic>)['glass'], isFalse);
      }
    });

    test('emits a lone fill flat', () {
      final layers = layersFor(<String, dynamic>{
        'generate': true,
        'liquid_glass_layers': [
          {
            'image_path': 'glyph.png',
            'fill': '#FF0000',
          },
        ],
      });

      final glyph = layers.single as Map<String, dynamic>;
      expect(
        glyph['fill'],
        equals({'solid': 'display-p3:1.00000,0.00000,0.00000,1.00000'}),
      );
      expect(glyph.containsKey('fill-specializations'), isFalse);
    });

    test('emits fill variants as fill-specializations', () {
      final layers = layersFor(<String, dynamic>{
        'generate': true,
        'liquid_glass_layers': [
          {
            'image_path': 'glyph.png',
            'fill': '#FF0000',
            'fill_dark': '#00FF00',
            'fill_tinted': '#0000FF',
          },
        ],
      });

      final glyph = layers.single as Map<String, dynamic>;
      expect(glyph.containsKey('fill'), isFalse);
      expect(
        glyph['fill-specializations'],
        equals([
          {
            'value': {'solid': 'display-p3:1.00000,0.00000,0.00000,1.00000'},
          },
          {
            'appearance': 'dark',
            'value': {'solid': 'display-p3:0.00000,1.00000,0.00000,1.00000'},
          },
          {
            'appearance': 'tinted',
            'value': {'solid': 'display-p3:0.00000,0.00000,1.00000,1.00000'},
          },
        ]),
      );
    });

    test('resolves per-layer appearance variants independently', () {
      final layers = layersFor(<String, dynamic>{
        'generate': true,
        'liquid_glass_layers': [
          {
            'image_path': 'background.png',
            'image_path_dark': 'background-dark.png',
          },
          {
            'image_path': 'glyph.png',
            'image_path_tinted': 'glyph-tinted.png',
          },
        ],
      });

      final background = layers[0] as Map<String, dynamic>;
      expect(
        background['image-name-specializations'],
        equals([
          {'value': 'background.png'},
          {'appearance': 'dark', 'value': 'background-dark.png'},
        ]),
      );
      final glyph = layers[1] as Map<String, dynamic>;
      expect(
        glyph['image-name-specializations'],
        equals([
          {'value': 'glyph.png'},
          {'appearance': 'tinted', 'value': 'glyph-tinted.png'},
        ]),
      );
    });

    test('rejects out-of-range opacity with a layer-labelled error', () {
      expect(
        () => layersFor(<String, dynamic>{
          'generate': true,
          'liquid_glass_layers': [
            {'image_path': 'background.png'},
            {'image_path': 'glyph.png', 'opacity': 1.5},
          ],
        }),
        throwsA(
          isA<InvalidConfigException>().having(
            (e) => e.message,
            'message',
            contains('ios.liquid_glass_layers[1].opacity'),
          ),
        ),
      );
    });

    test('rejects unknown blend modes with a layer-labelled error', () {
      expect(
        () => layersFor(<String, dynamic>{
          'generate': true,
          'liquid_glass_layers': [
            {'image_path': 'glyph.png', 'blend_mode': 'dissolve'},
          ],
        }),
        throwsA(
          isA<InvalidConfigException>().having(
            (e) => e.message,
            'message',
            contains('ios.liquid_glass_layers[0].blend_mode'),
          ),
        ),
      );
    });

    test('rejects non-hex fills with a layer-labelled error', () {
      expect(
        () => layersFor(<String, dynamic>{
          'generate': true,
          'liquid_glass_layers': [
            {'image_path': 'glyph.png', 'fill': 'red'},
          ],
        }),
        throwsA(
          isA<InvalidConfigException>().having(
            (e) => e.message,
            'message',
            contains('ios.liquid_glass_layers[0].fill'),
          ),
        ),
      );
    });
  });
}
