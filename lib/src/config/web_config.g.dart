// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'web_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WebConfig _$WebConfigFromJson(Map json) => $checkedCreate(
      'WebConfig',
      json,
      ($checkedConvert) {
        final val = WebConfig(
          generate: $checkedConvert('generate', (v) => v as bool? ?? false),
          imagePath: $checkedConvert('image_path', (v) => v as String?),
          imagePathFavicon:
              $checkedConvert('image_path_favicon', (v) => v as String?),
          imagePathMaskable:
              $checkedConvert('image_path_maskable', (v) => v as String?),
          faviconSize: $checkedConvert('favicon_size',
              (v) => (v as num?)?.toInt() ?? constants.kFaviconSize),
          faviconIco: $checkedConvert('favicon_ico', (v) => v as bool? ?? true),
          outputPath:
              $checkedConvert('output_path', (v) => v as String? ?? 'web'),
          backgroundColor:
              $checkedConvert('background_color', (v) => v as String?),
          themeColor: $checkedConvert('theme_color', (v) => v as String?),
        );
        return val;
      },
      fieldKeyMap: const {
        'imagePath': 'image_path',
        'imagePathFavicon': 'image_path_favicon',
        'imagePathMaskable': 'image_path_maskable',
        'faviconSize': 'favicon_size',
        'faviconIco': 'favicon_ico',
        'outputPath': 'output_path',
        'backgroundColor': 'background_color',
        'themeColor': 'theme_color'
      },
    );

Map<String, dynamic> _$WebConfigToJson(WebConfig instance) => <String, dynamic>{
      'generate': instance.generate,
      'image_path': instance.imagePath,
      'image_path_favicon': instance.imagePathFavicon,
      'image_path_maskable': instance.imagePathMaskable,
      'output_path': instance.outputPath,
      'favicon_size': instance.faviconSize,
      'favicon_ico': instance.faviconIco,
      'background_color': instance.backgroundColor,
      'theme_color': instance.themeColor,
    };
