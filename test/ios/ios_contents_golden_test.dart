import 'dart:convert';

import 'package:launcher_icons/src/platforms/ios/ios.dart' as ios;
import 'package:test/test.dart';

// Golden tests for the Contents.json schema: the modern (Xcode 14+) universal set plus the single-size variant. These lock the entry counts, the shared-1024 dual reference, and the dark/tinted marketing exclusion so future edits cannot silently drift the schema.
void main() {
  group('createImageList goldens', () {
    test('base list has 21 entries ending in ios-marketing', () {
      final list = ios.createImageList('Icon-App', null, null);

      expect(list, hasLength(21));
      final base = list.sublist(0, 20);
      expect(
        base.every((final e) => e['idiom'] == 'universal' && e['platform'] == 'ios'),
        isTrue,
      );
      final marketing = list.last;
      expect(marketing['idiom'], equals('ios-marketing'));
      expect(marketing['size'], equals('1024x1024'));
      expect(marketing['scale'], equals('1x'));
      expect(marketing.containsKey('platform'), isFalse);
      expect(marketing.containsKey('appearances'), isFalse);
    });

    test('universal 1024 and marketing share one PNG file', () {
      final list = ios.createImageList('Icon-App', null, null);

      final hundreds = list.where((final e) => e['size'] == '1024x1024').toList();
      expect(hundreds, hasLength(2));
      expect(
        hundreds.map((final e) => e['filename']).toSet(),
        equals({'Icon-App-1024x1024@1x.png'}),
      );
    });

    test('dark and tinted add appearance entries, never marketing', () {
      final list = ios.createImageList(
        'Icon-App',
        'Icon-App-Dark',
        'Icon-App-Tinted',
      );

      expect(list, hasLength(21 + 20 + 20));
      final dark = list.where(
        (final e) =>
            (e['appearances'] as List?)?.any(
              (final a) => (a as Map)['value'] == 'dark',
            ) ??
            false,
      );
      expect(dark, hasLength(20));
      expect(
        dark.every((final e) => e['idiom'] == 'universal'),
        isTrue,
      );
      final tinted = list.where(
        (final e) =>
            (e['appearances'] as List?)?.any(
              (final a) => (a as Map)['value'] == 'tinted',
            ) ??
            false,
      );
      expect(tinted, hasLength(20));
      expect(
        tinted.every((final e) => e['idiom'] == 'universal'),
        isTrue,
      );
      // The marketing slot stays appearance-free.
      final marketing = list.where((final e) => e['idiom'] == 'ios-marketing').toList();
      expect(marketing, hasLength(1));
      expect(marketing.first.containsKey('appearances'), isFalse);
    });

    test('filenames follow the <prefix>-<size>@<scale>.png shape', () {
      final list = ios.createImageList('MyIcon', null, null);

      for (final entry in list) {
        expect(
          entry['filename'],
          equals('MyIcon-${entry['size']}@${entry['scale']}.png'),
        );
      }
    });
  });

  group('createSingleSizeImageList goldens', () {
    test('emits exactly one universal 1024 entry', () {
      final list = ios.createSingleSizeImageList('Icon-App');

      expect(list, hasLength(1));
      expect(
        list.single,
        equals({
          'size': '1024x1024',
          'idiom': 'universal',
          'filename': 'Icon-App-1024x1024@1x.png',
          'scale': '1x',
          'platform': 'ios',
        }),
      );
    });
  });

  group('Contents.json serialization', () {
    test('generateContentsFileAsString wraps the list with xcode info', () {
      final decoded = jsonDecode(
        ios.generateContentsFileAsString('Icon-App', null, null),
      ) as Map<String, dynamic>;

      expect(decoded['images'] as List, hasLength(21));
      expect(
        decoded['info'],
        equals({'version': 1, 'author': 'xcode'}),
      );
    });

    test('ContentsImageObject omits null platform and appearances', () {
      final withoutOptionals = ios.ContentsImageObject(
        size: '1024x1024',
        idiom: 'ios-marketing',
        filename: 'Icon-App-1024x1024@1x.png',
        scale: '1x',
      ).toJson();
      expect(withoutOptionals.containsKey('platform'), isFalse);
      expect(withoutOptionals.containsKey('appearances'), isFalse);

      final withAppearances = ios.ContentsImageObject(
        size: '20x20',
        idiom: 'universal',
        filename: 'Icon-App-Dark-20x20@2x.png',
        scale: '2x',
        platform: 'ios',
        appearances: [
          ios.ContentsImageAppearanceObject(
            appearance: 'luminosity',
            value: 'dark',
          ),
        ],
      ).toJson();
      expect(
        withAppearances['appearances'],
        equals([
          {'appearance': 'luminosity', 'value': 'dark'},
        ]),
      );
    });
  });
}
