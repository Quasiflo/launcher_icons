/// Adaptive-icon xml template; `{{CONTENT}}` is replaced with the background/foreground/monochrome layers.
const String mipmapXmlFile = '''
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
{{CONTENT}}</adaptive-icon>
''';

/// Starter `colors.xml` template for a missing adaptive background file.
const String colorsXml = '''
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#FF000000</color>
</resources>
''';
