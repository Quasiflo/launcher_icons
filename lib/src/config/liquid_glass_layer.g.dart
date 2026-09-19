// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'liquid_glass_layer.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LiquidGlassLayer _$LiquidGlassLayerFromJson(Map json) => $checkedCreate(
      'LiquidGlassLayer',
      json,
      ($checkedConvert) {
        final val = LiquidGlassLayer(
          imagePath: $checkedConvert('image_path', (v) => v as String),
          imagePathDark:
              $checkedConvert('image_path_dark', (v) => v as String?),
          imagePathTinted:
              $checkedConvert('image_path_tinted', (v) => v as String?),
          scale:
              $checkedConvert('scale', (v) => (v as num?)?.toDouble() ?? 1.0),
          offsetX: $checkedConvert(
              'offset_x', (v) => (v as num?)?.toDouble() ?? 0.0),
          offsetY: $checkedConvert(
              'offset_y', (v) => (v as num?)?.toDouble() ?? 0.0),
          glass: $checkedConvert('glass', (v) => v as bool? ?? true),
          opacity: $checkedConvert('opacity', (v) => (v as num?)?.toDouble()),
          blendMode: $checkedConvert('blend_mode', (v) => v as String?),
          fill: $checkedConvert('fill', (v) => v as String?),
          fillDark: $checkedConvert('fill_dark', (v) => v as String?),
          fillTinted: $checkedConvert('fill_tinted', (v) => v as String?),
        );
        return val;
      },
      fieldKeyMap: const {
        'imagePath': 'image_path',
        'imagePathDark': 'image_path_dark',
        'imagePathTinted': 'image_path_tinted',
        'offsetX': 'offset_x',
        'offsetY': 'offset_y',
        'blendMode': 'blend_mode',
        'fillDark': 'fill_dark',
        'fillTinted': 'fill_tinted'
      },
    );

Map<String, dynamic> _$LiquidGlassLayerToJson(LiquidGlassLayer instance) =>
    <String, dynamic>{
      'image_path': instance.imagePath,
      'image_path_dark': instance.imagePathDark,
      'image_path_tinted': instance.imagePathTinted,
      'scale': instance.scale,
      'offset_x': instance.offsetX,
      'offset_y': instance.offsetY,
      'glass': instance.glass,
      'opacity': instance.opacity,
      'blend_mode': instance.blendMode,
      'fill': instance.fill,
      'fill_dark': instance.fillDark,
      'fill_tinted': instance.fillTinted,
    };
