import 'package:launcher_icons/src/platforms/web/web_template.dart';
import 'package:test/test.dart';

void main() {
  group('WebTemplate', () {
    late WebIconTemplate icTemplate;
    late WebIconTemplate icMaskableTemplate;
    late WebIconTemplate icMonoMaskableTemplate;

    setUp(() {
      icTemplate = const WebIconTemplate(size: 512);
      icMaskableTemplate = const WebIconTemplate(size: 512, maskable: true);
      icMonoMaskableTemplate = const WebIconTemplate(size: 512, maskable: true, monochrome: true);
    });

    test('.iconFile should return valid file name', () {
      expect(icTemplate.iconFile, equals('Icon-512.png'));
      expect(icMaskableTemplate.iconFile, equals('Icon-maskable-512.png'));
      expect(icMonoMaskableTemplate.iconFile, equals('Icon-maskable-monochrome-512.png'));
    });

    test('.iconManifest should return valid manifest config', () {
      expect(
        icTemplate.iconManifest,
        equals({
          'src': 'icons/Icon-512.png',
          'sizes': '512x512',
          'type': 'image/png',
        }),
      );
      expect(
        icMaskableTemplate.iconManifest,
        equals({
          'src': 'icons/Icon-maskable-512.png',
          'sizes': '512x512',
          'type': 'image/png',
          'purpose': 'maskable',
        }),
      );
      expect(
        icMonoMaskableTemplate.iconManifest,
        equals({
          'src': 'icons/Icon-maskable-monochrome-512.png',
          'sizes': '512x512',
          'type': 'image/png',
          'purpose': 'maskable monochrome',
        }),
      );
    });
  });
}
