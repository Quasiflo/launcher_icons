/// A macOS icon template
class MacOSIconTemplate {
  /// Creates an instance of [MacOSIconTemplate]
  ///
  const MacOSIconTemplate(this.size, this.scale);

  /// Icon size
  final int size;

  /// Icon scale
  final int scale;

  /// Icon content for contents.json' s images
  ///
  /// ```json
  /// {
  ///   "size" : "16x16",
  ///   "idiom" : "mac",
  ///   "filename" : "app_icon_16.png",
  ///   "scale" : "1x"
  /// }
  /// ```
  Map<String, dynamic> get iconContent => <String, dynamic>{
        'size': '${size}x$size',
        'idiom': 'mac',
        'filename': iconFile,
        'scale': '${scale}x',
      };

  /// Icon file name with extension
  ///
  /// `app_icon_16.png`
  String get iconFile => 'app_icon_$scaledSize.png';

  /// Image size after computing scale
  int get scaledSize => size * scale;
}
