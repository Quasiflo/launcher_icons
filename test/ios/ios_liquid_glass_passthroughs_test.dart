import 'package:launcher_icons/src/config/config.dart';
import 'package:launcher_icons/src/core/custom_exceptions.dart';
import 'package:launcher_icons/src/platforms/ios/liquid_glass_icon_generator.dart';
import 'package:test/test.dart';

// Pass-throughs for Icon Composer engine features: group lighting,
// refractivity, and specular highlight placement, plus the top-level
// `features` declarations actool expects.
void main() {
  group('generateIconConfig optical pass-throughs', () {
    Map<String, dynamic> iconJsonFor(Map<String, dynamic> ios) {
      final config = Config.fromJson(<String, dynamic>{'ios': ios});
      return generateIconConfig(config);
    }

    Map<String, dynamic> groupFor(Map<String, dynamic> ios) {
      final groups = iconJsonFor(ios)['groups'] as List;
      return groups.first as Map<String, dynamic>;
    }

    Map<String, dynamic> withLayer(Map<String, dynamic> extra) =>
        <String, dynamic>{
          'generate': true,
          'liquid_glass_layers': [
            {'image_path': 'icon.png'},
          ],
          ...extra,
        };

    test('emits lighting when set', () {
      final group = groupFor(withLayer({'liquid_glass_lighting': 'combined'}));
      expect(group['lighting'], equals('combined'));
    });

    test('rejects unknown lighting values', () {
      expect(
        () => iconJsonFor(withLayer({'liquid_glass_lighting': 'dramatic'})),
        throwsA(isA<InvalidConfigException>()),
      );
    });

    test('emits refractivity object without a features array', () {
      final json = iconJsonFor(
        withLayer({
          'liquid_glass_refractivity_enabled': true,
          'liquid_glass_refractivity_depth': 0.6,
          'liquid_glass_refractivity_strength': 0.7,
        }),
      );
      final group = (json['groups'] as List).first as Map<String, dynamic>;
      expect(
        group['refractivity'],
        equals({'enabled': true, 'depth': 0.6, 'strength': 0.7}),
      );
      // actool rejects the `features` declaration (verified: Xcode 26.6
      // crashes compiling any `features` array), and the keys stand alone.
      expect(json.containsKey('features'), isFalse);
    });

    test('requires depth and strength when refractivity is enabled', () {
      expect(
        () => iconJsonFor(
          withLayer({'liquid_glass_refractivity_enabled': true}),
        ),
        throwsA(isA<InvalidConfigException>()),
      );
    });

    test('emits specular placement without a features array', () {
      final json = iconJsonFor(
        withLayer({'liquid_glass_specular_highlight_placement': 'inside'}),
      );
      final group = (json['groups'] as List).first as Map<String, dynamic>;
      expect(group['specular-highlight-placement'], equals('inside'));
      expect(json.containsKey('features'), isFalse);
    });

    test('rejects unknown specular placements', () {
      expect(
        () => iconJsonFor(
          withLayer({'liquid_glass_specular_highlight_placement': 'behind'}),
        ),
        throwsA(isA<InvalidConfigException>()),
      );
    });

    test('omits features and optical keys by default', () {
      final json = iconJsonFor(withLayer({}));
      final group = (json['groups'] as List).first as Map<String, dynamic>;
      expect(json.containsKey('features'), isFalse);
      expect(group.containsKey('lighting'), isFalse);
      expect(group.containsKey('refractivity'), isFalse);
      expect(
        group.containsKey('specular-highlight-placement'),
        isFalse,
      );
    });
  });
}
