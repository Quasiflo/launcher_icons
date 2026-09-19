import 'dart:io';

import 'package:launcher_icons/src/core/custom_exceptions.dart';
import 'package:launcher_icons/src/core/utils.dart' as utils;
import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

void main() {
  group('#areFSEntitesExist', () {
    late String prefixPath;
    setUp(() async {
      prefixPath = path.join(d.sandbox, 'fli_test');
      await d.dir('fli_test', [
        d.file('file1.txt', 'contents1'),
        d.dir('dir1'),
      ]).create();
    });

    test('should return null when entites exists', () async {
      expect(
        utils.areFSEntiesExist([
          path.join(prefixPath, 'file1.txt'),
          path.join(prefixPath, 'dir1'),
        ]),
        isNull,
      );
    });

    test('should return the file path that does not exist', () {
      final result = utils.areFSEntiesExist([
        path.join(prefixPath, 'dir1'),
        path.join(prefixPath, 'file_that_does_not_exist.txt'),
      ]);
      expect(result, isNotNull);
      expect(
        result,
        equals(path.join(prefixPath, 'file_that_does_not_exist.txt')),
      );
    });

    test('should return the dir path that does not exist', () {
      final result = utils.areFSEntiesExist([
        path.join(prefixPath, 'dir_that_does_not_exist'),
        path.join(prefixPath, 'file.txt'),
      ]);
      expect(result, isNotNull);
      expect(result, equals(path.join(prefixPath, 'dir_that_does_not_exist')));
    });

    test('should return the first entity path that does not exist', () {
      final result = utils.areFSEntiesExist([
        path.join(prefixPath, 'dir_that_does_not_exist'),
        path.join(prefixPath, 'file_that_dodes_not_exist.txt'),
      ]);
      expect(result, isNotNull);
      expect(result, equals(path.join(prefixPath, 'dir_that_does_not_exist')));
    });
  });

  group('#createDirIfNotExist', () {
    setUpAll(() async {
      await d.dir('fli_test', [
        d.dir('dir_exists'),
      ]).create();
    });
    test('should create directory if it does not exist', () async {
      await expectLater(
        d.dir('fli_test', [d.dir('dir_that_does_not_exist')]).validate(),
        throwsException,
      );
      final result = await utils.createDirIfNotExist(
        path.join(d.sandbox, 'fli_test', 'dir_that_does_not_exist'),
      );
      expect(result.existsSync(), isTrue);
      await expectLater(
        d.dir('fli_test', [d.dir('dir_that_does_not_exist')]).validate(),
        completes,
      );
    });
    test('should return dir if it exist', () async {
      await expectLater(
        d.dir('fli_test', [d.dir('dir_exists')]).validate(),
        completes,
      );
      final result = await utils.createDirIfNotExist(path.join(d.sandbox, 'fli_test', 'dir_exists'));
      expect(result.existsSync(), isTrue);
      await expectLater(
        d.dir('fli_test', [d.dir('dir_exists')]).validate(),
        completes,
      );
    });
  });

  group('#createFileIfNotExist', () {
    setUpAll(() async {
      await d.dir('fli_test', [
        d.file('file_exists.txt'),
      ]).create();
    });
    test('should create file if it does not exist', () async {
      await expectLater(
        d.dir('fli_test', [d.file('file_that_does_not_exist.txt')]).validate(),
        throwsException,
      );
      final result = await utils.createFileIfNotExist(
        path.join(d.sandbox, 'fli_test', 'file_that_does_not_exist.txt'),
      );
      expect(result.existsSync(), isTrue);
      await expectLater(
        d.dir('fli_test', [d.file('file_that_does_not_exist.txt')]).validate(),
        completes,
      );
    });
    test('should return file if it exist', () async {
      await expectLater(
        d.dir('fli_test', [d.file('file_exists.txt')]).validate(),
        completes,
      );
      final result = await utils.createFileIfNotExist(
        path.join(d.sandbox, 'fli_test', 'file_exists.txt'),
      );
      expect(result.existsSync(), isTrue);
      await expectLater(
        d.dir('fli_test', [d.file('file_exists.txt')]).validate(),
        completes,
      );
    });
  });

  group('#prettifyJsonEncode', () {
    test('should return prettiffed json string 4 indents', () {
      const expectedValue = r'''
{
    "key1": "value1",
    "key2": "value2"
}''';
      final result = utils.prettifyJsonEncode({
        'key1': 'value1',
        'key2': 'value2',
      });
      expect(result, equals(expectedValue));
    });
  });

  // Regression tests: indexed-color (palette) PNGs used to throw RangeError in downstream pixel operations on older `image` versions.
  group('#decodeImageFile exotic PNG variants', () {
    test('decodes indexed-color PNG and survives icon ops', () async {
      final image = await utils.decodeImageFile('test/assets/paletted-opaque-2x2.png');
      expect(image, isNotNull);
      final pixel = image.getPixel(0, 0);
      expect(pixel.r, equals(255));
      expect(utils.createResizedImage(48, image).width, equals(48));
    });

    test('decodes indexed PNG with tRNS transparency', () async {
      final image = await utils.decodeImageFile('test/assets/paletted-alpha-2x2.png');
      expect(image, isNotNull);
      expect(image.getPixel(0, 0).a, equals(255));
      expect(utils.createResizedImage(48, image).width, equals(48));
    });
  });

  // The loader contract: it never returns null — missing files raise FileSystemException, undecodable files raise NoDecoderForImageFormatException.
  group('#decodeImageFile error contract', () {
    test('throws FileSystemException for a missing file', () async {
      await expectLater(
        utils.decodeImageFile(path.join(d.sandbox, 'missing.png')),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('throws NoDecoderForImageFormatException for garbage bytes', () async {
      final garbage = File(path.join(d.sandbox, 'garbage.png'))..createSync(recursive: true);
      // Plain text: every decoder probe rejects it and decodeImage returns null (short binary blobs can throw inside a probe instead).
      await garbage.writeAsString(
        'this is definitely not an image file, just plain text....',
      );
      await expectLater(
        utils.decodeImageFile(garbage.path),
        throwsA(isA<NoDecoderForImageFormatException>()),
      );
    });
  });
}
