// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'liquid_glass_group.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LiquidGlassGroup _$LiquidGlassGroupFromJson(Map json) => $checkedCreate(
      'LiquidGlassGroup',
      json,
      ($checkedConvert) {
        final val = LiquidGlassGroup(
          name: $checkedConvert('name', (v) => v as String?),
          layers: $checkedConvert(
              'layers',
              (v) => (v as List<dynamic>?)
                  ?.map((e) => LiquidGlassLayer.fromJson(e as Map))
                  .toList()),
          translucency: $checkedConvert(
              'liquid_glass_translucency', (v) => (v as num?)?.toDouble()),
          specular: $checkedConvert('liquid_glass_specular', (v) => v as bool?),
          shadowKind:
              $checkedConvert('liquid_glass_shadow_kind', (v) => v as String?),
          shadowOpacity: $checkedConvert(
              'liquid_glass_shadow_opacity', (v) => (v as num?)?.toDouble()),
          blur: $checkedConvert(
              'liquid_glass_blur', (v) => (v as num?)?.toDouble()),
          lighting:
              $checkedConvert('liquid_glass_lighting', (v) => v as String?),
          refractivityEnabled: $checkedConvert(
              'liquid_glass_refractivity_enabled', (v) => v as bool?),
          refractivityDepth: $checkedConvert('liquid_glass_refractivity_depth',
              (v) => (v as num?)?.toDouble()),
          refractivityStrength: $checkedConvert(
              'liquid_glass_refractivity_strength',
              (v) => (v as num?)?.toDouble()),
          specularHighlightPlacement: $checkedConvert(
              'liquid_glass_specular_highlight_placement', (v) => v as String?),
          removeLiquidGlass:
              $checkedConvert('remove_liquid_glass', (v) => v as bool?),
        );
        return val;
      },
      fieldKeyMap: const {
        'translucency': 'liquid_glass_translucency',
        'specular': 'liquid_glass_specular',
        'shadowKind': 'liquid_glass_shadow_kind',
        'shadowOpacity': 'liquid_glass_shadow_opacity',
        'blur': 'liquid_glass_blur',
        'lighting': 'liquid_glass_lighting',
        'refractivityEnabled': 'liquid_glass_refractivity_enabled',
        'refractivityDepth': 'liquid_glass_refractivity_depth',
        'refractivityStrength': 'liquid_glass_refractivity_strength',
        'specularHighlightPlacement':
            'liquid_glass_specular_highlight_placement',
        'removeLiquidGlass': 'remove_liquid_glass'
      },
    );

Map<String, dynamic> _$LiquidGlassGroupToJson(LiquidGlassGroup instance) =>
    <String, dynamic>{
      'name': instance.name,
      'layers': instance.layers?.map((e) => e.toJson()).toList(),
      'liquid_glass_translucency': instance.translucency,
      'liquid_glass_specular': instance.specular,
      'liquid_glass_shadow_kind': instance.shadowKind,
      'liquid_glass_shadow_opacity': instance.shadowOpacity,
      'liquid_glass_blur': instance.blur,
      'liquid_glass_lighting': instance.lighting,
      'liquid_glass_refractivity_enabled': instance.refractivityEnabled,
      'liquid_glass_refractivity_depth': instance.refractivityDepth,
      'liquid_glass_refractivity_strength': instance.refractivityStrength,
      'liquid_glass_specular_highlight_placement':
          instance.specularHighlightPlacement,
      'remove_liquid_glass': instance.removeLiquidGlass,
    };
