// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'linux_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LinuxConfig _$LinuxConfigFromJson(Map json) => $checkedCreate(
      'LinuxConfig',
      json,
      ($checkedConvert) {
        final val = LinuxConfig(
          generate: $checkedConvert('generate', (v) => v as bool? ?? false),
          imagePath: $checkedConvert('image_path', (v) => v as String?),
          sharePrefix: $checkedConvert('share_prefix', (v) => v as String? ?? 'linux'),
          generateSnap: $checkedConvert('generate_snap', (v) => v as bool? ?? false),
        );
        return val;
      },
      fieldKeyMap: const {'imagePath': 'image_path', 'sharePrefix': 'share_prefix', 'generateSnap': 'generate_snap'},
    );

Map<String, dynamic> _$LinuxConfigToJson(LinuxConfig instance) => <String, dynamic>{
      'generate': instance.generate,
      'image_path': instance.imagePath,
      'share_prefix': instance.sharePrefix,
      'generate_snap': instance.generateSnap,
    };
