import 'dart:io';

import 'package:launcher_icons/src/platforms/android/android.dart' as android;
import 'package:test/test.dart';

// Malformed-input coverage for the line-oriented parsers: XML comments, duplicate keys, CRLF, and missing trailing newlines.
void main() {
  group('manifest icon rewriting', () {
    Future<String> rewrite(final String input, final String iconName) async {
      final dir = await Directory.systemTemp.createTemp('manifest_fuzz');
      try {
        final file = File('${dir.path}/AndroidManifest.xml');
        await file.writeAsString(input);
        await android.overwriteAndroidManifestWithNewLauncherIcon(
          iconName,
          file,
        );
        return file.readAsStringSync();
      } finally {
        await dir.delete(recursive: true);
      }
    }

    const header = '''
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application''';

    const footer = '''
        android:label="@string/app_name">
    </application>
</manifest>
''';

    test('leaves commented icon lines untouched', () async {
      const input = '$header\n'
          '        <!-- android:icon="@mipmap/stale" -->\n'
          '        android:icon="@mipmap/ic_launcher"\n'
          '$footer';

      final output = await rewrite(input, 'ic_new');

      expect(output, contains('<!-- android:icon="@mipmap/stale" -->'));
      expect(output, contains('android:icon="@mipmap/ic_new"'));
    });

    test('rewrites duplicate icon lines', () async {
      const input = '$header\n'
          '        android:icon="@mipmap/ic_launcher"\n'
          '        android:icon="@mipmap/ic_launcher"\n'
          '$footer';

      final output = await rewrite(input, 'ic_new');

      expect(output, isNot(contains('android:icon="@mipmap/ic_launcher"')));
      expect(
        'android:icon="@mipmap/ic_new"'.allMatches(output),
        hasLength(2),
      );
    });

    test('preserves CRLF across a rewrite', () async {
      final input = '$header\n'
              '        android:icon="@mipmap/ic_launcher"\n'
              '$footer'
          .replaceAll('\n', '\r\n');

      final output = await rewrite(input, 'ic_new');

      expect(output, contains('android:icon="@mipmap/ic_new"'));
      expect(output.contains('\r\n'), isTrue);
      expect(output.replaceAll('\r\n', '\n').contains('\r'), isFalse);
    });

    test('preserves a missing trailing newline across a rewrite', () async {
      final input = '$header\n'
          '        android:icon="@mipmap/ic_launcher"\n'
          '${footer.trimRight()}';

      final output = await rewrite(input, 'ic_new');

      expect(output, contains('android:icon="@mipmap/ic_new"'));
      expect(output.endsWith('\n'), isFalse);
    });
  });

  group('colors.xml updating', () {
    Future<String> update(final String input, final String color) async {
      final dir = await Directory.systemTemp.createTemp('colors_fuzz');
      try {
        final file = File('${dir.path}/colors.xml');
        await file.writeAsString(input);
        await android.updateColorsFile(file, color);
        return file.readAsStringSync();
      } finally {
        await dir.delete(recursive: true);
      }
    }

    test('ignores commented background entries', () async {
      const input = '''
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- <color name="ic_launcher_background">#000000</color> -->
</resources>
''';

      final output = await update(input, '#ffffff');

      expect(
        output,
        contains(
          '<!-- <color name="ic_launcher_background">#000000</color> -->',
        ),
      );
      expect(
        output,
        contains('<color name="ic_launcher_background">#ffffff</color>'),
      );
    });

    test('first duplicate entry wins', () async {
      const input = '''
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#111111</color>
    <color name="ic_launcher_background">#222222</color>
</resources>
''';

      final output = await update(input, '#ffffff');

      expect(
        output.indexOf('#ffffff') < output.indexOf('#222222'),
        isTrue,
      );
      expect(output, contains('#222222'));
    });
  });
}
