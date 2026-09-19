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
          imagePathPwa: $checkedConvert('image_path_pwa', (v) => v as String?),
          imagePathMaskable: $checkedConvert('image_path_maskable', (v) => v as String?),
          imagePathMonochrome: $checkedConvert('image_path_monochrome', (v) => v as String?),
          imagePathMonochromeMaskable: $checkedConvert('image_path_monochrome_maskable', (v) => v as String?),
          imagePathFaviconSvg: $checkedConvert('image_path_favicon_svg', (v) => v as String?),
          imagePathOpengraph: $checkedConvert('image_path_opengraph', (v) => v as String?),
          imagePathTwitter: $checkedConvert('image_path_twitter', (v) => v as String?),
          shortcutIcons: $checkedConvert('shortcut_icons', (v) => (v as List<dynamic>?)?.map((e) => WebShortcutIcon.fromJson(e as Map)).toList()),
          faviconSize: $checkedConvert('favicon_size', (v) => (v as num?)?.toInt() ?? constants.faviconDefaultSize),
          faviconIco: $checkedConvert('favicon_ico', (v) => v as bool? ?? true),
          outputPath: $checkedConvert('output_path', (v) => v as String? ?? 'web'),
          backgroundColor: $checkedConvert('background_color', (v) => v as String?),
          themeColorLight: $checkedConvert('theme_color_light', (v) => v as String?),
          themeColorDark: $checkedConvert('theme_color_dark', (v) => v as String?),
        );
        return val;
      },
      fieldKeyMap: const {'imagePath': 'image_path', 'imagePathPwa': 'image_path_pwa', 'imagePathMaskable': 'image_path_maskable', 'imagePathMonochrome': 'image_path_monochrome', 'imagePathMonochromeMaskable': 'image_path_monochrome_maskable', 'imagePathFaviconSvg': 'image_path_favicon_svg', 'imagePathOpengraph': 'image_path_opengraph', 'imagePathTwitter': 'image_path_twitter', 'shortcutIcons': 'shortcut_icons', 'faviconSize': 'favicon_size', 'faviconIco': 'favicon_ico', 'outputPath': 'output_path', 'backgroundColor': 'background_color', 'themeColorLight': 'theme_color_light', 'themeColorDark': 'theme_color_dark'},
    );

Map<String, dynamic> _$WebConfigToJson(WebConfig instance) => <String, dynamic>{
      'generate': instance.generate,
      'image_path': instance.imagePath,
      'image_path_pwa': instance.imagePathPwa,
      'image_path_maskable': instance.imagePathMaskable,
      'image_path_monochrome': instance.imagePathMonochrome,
      'image_path_monochrome_maskable': instance.imagePathMonochromeMaskable,
      'image_path_favicon_svg': instance.imagePathFaviconSvg,
      'image_path_opengraph': instance.imagePathOpengraph,
      'image_path_twitter': instance.imagePathTwitter,
      'shortcut_icons': instance.shortcutIcons,
      'output_path': instance.outputPath,
      'favicon_size': instance.faviconSize,
      'favicon_ico': instance.faviconIco,
      'background_color': instance.backgroundColor,
      'theme_color_light': instance.themeColorLight,
      'theme_color_dark': instance.themeColorDark,
    };
