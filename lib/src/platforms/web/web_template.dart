/// A Icon Template for Web
class WebIconTemplate {
  /// Creates an instance of [WebIconTemplate].
  const WebIconTemplate({required this.size, this.maskable = false, this.monochrome = false});

  /// Size of the web icon
  final int size;

  /// Support for maskable icon
  ///
  /// Refer to https://web.dev/maskable-icon/
  final bool maskable;

  /// Monochrome icon for themed PWA icons (`purpose: monochrome`). Combines with [maskable] as `purpose: "maskable monochrome"`.
  final bool monochrome;

  /// Icon file name
  String get iconFile {
    final qualifiers = '${maskable ? '-maskable' : ''}${monochrome ? '-monochrome' : ''}';
    return 'Icon$qualifiers-$size.png';
  }

  /// Icon config for manifest.json
  ///
  /// ```json
  ///  {
  ///         "src": "icons/Icon-maskable-192.png",
  ///         "sizes": "192x192",
  ///         "type": "image/png",
  ///         "purpose": "maskable"
  ///  },
  /// ```
  Map<String, dynamic> get iconManifest {
    final purposes = <String>[if (maskable) 'maskable', if (monochrome) 'monochrome'];
    return <String, dynamic>{
      'src': 'icons/$iconFile',
      'sizes': '${size}x$size',
      'type': 'image/png',
      if (purposes.isNotEmpty) 'purpose': purposes.join(' '),
    };
  }
}
