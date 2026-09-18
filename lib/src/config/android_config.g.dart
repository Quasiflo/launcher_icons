// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'android_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AndroidConfig _$AndroidConfigFromJson(Map json) => $checkedCreate(
      'AndroidConfig',
      json,
      ($checkedConvert) {
        final val = AndroidConfig(
          generate: $checkedConvert('generate', (v) => v as bool? ?? false),
          imagePath: $checkedConvert('image_path', (v) => v as String?),
          iconName: $checkedConvert('icon_name', (v) => v as String?),
          adaptiveIconForeground:
              $checkedConvert('adaptive_icon_foreground', (v) => v as String?),
          adaptiveIconForegroundInset: $checkedConvert(
              'adaptive_icon_foreground_inset',
              (v) => (v as num?)?.toInt() ?? 16),
          adaptiveIconBackground:
              $checkedConvert('adaptive_icon_background', (v) => v as String?),
          adaptiveIconMonochrome:
              $checkedConvert('adaptive_icon_monochrome', (v) => v as String?),
          adaptiveIconRound:
              $checkedConvert('adaptive_icon_round', (v) => v as String?),
          playStoreIcon:
              $checkedConvert('play_store_icon', (v) => v as bool? ?? false),
        );
        return val;
      },
      fieldKeyMap: const {
        'imagePath': 'image_path',
        'iconName': 'icon_name',
        'adaptiveIconForeground': 'adaptive_icon_foreground',
        'adaptiveIconForegroundInset': 'adaptive_icon_foreground_inset',
        'adaptiveIconBackground': 'adaptive_icon_background',
        'adaptiveIconMonochrome': 'adaptive_icon_monochrome',
        'adaptiveIconRound': 'adaptive_icon_round',
        'playStoreIcon': 'play_store_icon'
      },
    );

Map<String, dynamic> _$AndroidConfigToJson(AndroidConfig instance) =>
    <String, dynamic>{
      'generate': instance.generate,
      'image_path': instance.imagePath,
      'icon_name': instance.iconName,
      'adaptive_icon_foreground': instance.adaptiveIconForeground,
      'adaptive_icon_foreground_inset': instance.adaptiveIconForegroundInset,
      'adaptive_icon_background': instance.adaptiveIconBackground,
      'adaptive_icon_monochrome': instance.adaptiveIconMonochrome,
      'adaptive_icon_round': instance.adaptiveIconRound,
      'play_store_icon': instance.playStoreIcon,
    };
