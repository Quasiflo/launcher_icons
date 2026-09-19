// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Config _$ConfigFromJson(Map json) => $checkedCreate(
      'Config',
      json,
      ($checkedConvert) {
        final val = Config(
          imagePath: $checkedConvert('image_path', (v) => v as String?),
          androidConfig: $checkedConvert('android',
              (v) => v == null ? null : AndroidConfig.fromJson(v as Map)),
          iosConfig: $checkedConvert(
              'ios', (v) => v == null ? null : IOSConfig.fromJson(v as Map)),
          webConfig: $checkedConvert(
              'web', (v) => v == null ? null : WebConfig.fromJson(v as Map)),
          windowsConfig: $checkedConvert('windows',
              (v) => v == null ? null : WindowsConfig.fromJson(v as Map)),
          macOSConfig: $checkedConvert('macos',
              (v) => v == null ? null : MacOSConfig.fromJson(v as Map)),
          linuxConfig: $checkedConvert('linux',
              (v) => v == null ? null : LinuxConfig.fromJson(v as Map)),
        );
        return val;
      },
      fieldKeyMap: const {
        'imagePath': 'image_path',
        'androidConfig': 'android',
        'iosConfig': 'ios',
        'webConfig': 'web',
        'windowsConfig': 'windows',
        'macOSConfig': 'macos',
        'linuxConfig': 'linux'
      },
    );

Map<String, dynamic> _$ConfigToJson(Config instance) => <String, dynamic>{
      'image_path': instance.imagePath,
      'android': instance.androidConfig,
      'ios': instance.iosConfig,
      'web': instance.webConfig,
      'windows': instance.windowsConfig,
      'macos': instance.macOSConfig,
      'linux': instance.linuxConfig,
    };
