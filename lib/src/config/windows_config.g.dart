// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'windows_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WindowsConfig _$WindowsConfigFromJson(Map json) => $checkedCreate(
      'WindowsConfig',
      json,
      ($checkedConvert) {
        final val = WindowsConfig(
          generate: $checkedConvert('generate', (v) => v as bool? ?? false),
          imagePath: $checkedConvert('image_path', (v) => v as String?),
          iconFilename: $checkedConvert('icon_filename', (v) => v as String? ?? 'app_icon.ico'),
          imagePathUnplated: $checkedConvert('image_path_unplated', (v) => v as String?),
          imagePathLightUnplated: $checkedConvert('image_path_light_unplated', (v) => v as String?),
          imagePathWide: $checkedConvert('image_path_wide', (v) => v as String?),
        );
        return val;
      },
      fieldKeyMap: const {'imagePath': 'image_path', 'iconFilename': 'icon_filename', 'imagePathUnplated': 'image_path_unplated', 'imagePathLightUnplated': 'image_path_light_unplated', 'imagePathWide': 'image_path_wide'},
    );

Map<String, dynamic> _$WindowsConfigToJson(WindowsConfig instance) => <String, dynamic>{
      'generate': instance.generate,
      'image_path': instance.imagePath,
      'icon_filename': instance.iconFilename,
      'image_path_unplated': instance.imagePathUnplated,
      'image_path_light_unplated': instance.imagePathLightUnplated,
      'image_path_wide': instance.imagePathWide,
    };
