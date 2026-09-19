// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'web_shortcut_icon.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WebShortcutIcon _$WebShortcutIconFromJson(Map json) => $checkedCreate(
      'WebShortcutIcon',
      json,
      ($checkedConvert) {
        final val = WebShortcutIcon(
          imagePath: $checkedConvert('image_path', (v) => v as String),
          name: $checkedConvert('name', (v) => v as String?),
          shortName: $checkedConvert('short_name', (v) => v as String?),
          url: $checkedConvert('url', (v) => v as String?),
          description: $checkedConvert('description', (v) => v as String?),
        );
        return val;
      },
      fieldKeyMap: const {'imagePath': 'image_path', 'shortName': 'short_name'},
    );

Map<String, dynamic> _$WebShortcutIconToJson(WebShortcutIcon instance) =>
    <String, dynamic>{
      'image_path': instance.imagePath,
      'name': instance.name,
      'short_name': instance.shortName,
      'url': instance.url,
      'description': instance.description,
    };
