// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'macos_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MacOSConfig _$MacOSConfigFromJson(Map json) => $checkedCreate(
      'MacOSConfig',
      json,
      ($checkedConvert) {
        final val = MacOSConfig(
          generate: $checkedConvert('generate', (v) => v as bool? ?? false),
          imagePath: $checkedConvert('image_path', (v) => v as String?),
          iconName: $checkedConvert('icon_name', (v) => v as String?),
          xcodeprojPath: $checkedConvert('xcodeproj_path', (v) => v as String?),
          iconOnly: $checkedConvert('icon_only', (v) => v as bool? ?? false),
          padding: $checkedConvert('padding', (v) => (v as num?)?.toInt() ?? 0),
          roundedCorners:
              $checkedConvert('rounded_corners', (v) => v as bool? ?? false),
          liquidGlassLayers: $checkedConvert(
              'liquid_glass_layers',
              (v) => (v as List<dynamic>?)
                  ?.map((e) => LiquidGlassLayer.fromJson(e as Map))
                  .toList()),
          liquidGlassGroups: $checkedConvert(
              'liquid_glass_groups',
              (v) => (v as List<dynamic>?)
                  ?.map((e) => LiquidGlassGroup.fromJson(e as Map))
                  .toList()),
          removeLiquidGlass: $checkedConvert(
              'remove_liquid_glass', (v) => v as bool? ?? false),
          backgroundColor: $checkedConvert(
              'background_color', (v) => v as String? ?? '#ffffff'),
          liquidGlassGradientFrom: $checkedConvert(
              'liquid_glass_gradient_from', (v) => v as String?),
          liquidGlassGradientTo:
              $checkedConvert('liquid_glass_gradient_to', (v) => v as String?),
          liquidGlassTranslucency: $checkedConvert('liquid_glass_translucency',
              (v) => (v as num?)?.toDouble() ?? 0.5),
          liquidGlassSpecular: $checkedConvert(
              'liquid_glass_specular', (v) => v as bool? ?? true),
          liquidGlassShadowKind: $checkedConvert(
              'liquid_glass_shadow_kind', (v) => v as String? ?? 'Neutral'),
          liquidGlassShadowOpacity: $checkedConvert(
              'liquid_glass_shadow_opacity',
              (v) => (v as num?)?.toDouble() ?? 0.5),
          liquidGlassBlur: $checkedConvert(
              'liquid_glass_blur', (v) => (v as num?)?.toDouble() ?? 0.5),
          liquidGlassLighting:
              $checkedConvert('liquid_glass_lighting', (v) => v as String?),
          liquidGlassRefractivityEnabled: $checkedConvert(
              'liquid_glass_refractivity_enabled', (v) => v as bool?),
          liquidGlassRefractivityDepth: $checkedConvert(
              'liquid_glass_refractivity_depth',
              (v) => (v as num?)?.toDouble()),
          liquidGlassRefractivityStrength: $checkedConvert(
              'liquid_glass_refractivity_strength',
              (v) => (v as num?)?.toDouble()),
          liquidGlassSpecularHighlightPlacement: $checkedConvert(
              'liquid_glass_specular_highlight_placement', (v) => v as String?),
        );
        return val;
      },
      fieldKeyMap: const {
        'imagePath': 'image_path',
        'iconName': 'icon_name',
        'xcodeprojPath': 'xcodeproj_path',
        'iconOnly': 'icon_only',
        'roundedCorners': 'rounded_corners',
        'liquidGlassLayers': 'liquid_glass_layers',
        'liquidGlassGroups': 'liquid_glass_groups',
        'removeLiquidGlass': 'remove_liquid_glass',
        'backgroundColor': 'background_color',
        'liquidGlassGradientFrom': 'liquid_glass_gradient_from',
        'liquidGlassGradientTo': 'liquid_glass_gradient_to',
        'liquidGlassTranslucency': 'liquid_glass_translucency',
        'liquidGlassSpecular': 'liquid_glass_specular',
        'liquidGlassShadowKind': 'liquid_glass_shadow_kind',
        'liquidGlassShadowOpacity': 'liquid_glass_shadow_opacity',
        'liquidGlassBlur': 'liquid_glass_blur',
        'liquidGlassLighting': 'liquid_glass_lighting',
        'liquidGlassRefractivityEnabled': 'liquid_glass_refractivity_enabled',
        'liquidGlassRefractivityDepth': 'liquid_glass_refractivity_depth',
        'liquidGlassRefractivityStrength': 'liquid_glass_refractivity_strength',
        'liquidGlassSpecularHighlightPlacement':
            'liquid_glass_specular_highlight_placement'
      },
    );

Map<String, dynamic> _$MacOSConfigToJson(MacOSConfig instance) =>
    <String, dynamic>{
      'generate': instance.generate,
      'image_path': instance.imagePath,
      'icon_name': instance.iconName,
      'xcodeproj_path': instance.xcodeprojPath,
      'icon_only': instance.iconOnly,
      'padding': instance.padding,
      'rounded_corners': instance.roundedCorners,
      'liquid_glass_layers':
          instance.liquidGlassLayers?.map((e) => e.toJson()).toList(),
      'liquid_glass_groups':
          instance.liquidGlassGroups?.map((e) => e.toJson()).toList(),
      'remove_liquid_glass': instance.removeLiquidGlass,
      'background_color': instance.backgroundColor,
      'liquid_glass_gradient_from': instance.liquidGlassGradientFrom,
      'liquid_glass_gradient_to': instance.liquidGlassGradientTo,
      'liquid_glass_translucency': instance.liquidGlassTranslucency,
      'liquid_glass_specular': instance.liquidGlassSpecular,
      'liquid_glass_shadow_kind': instance.liquidGlassShadowKind,
      'liquid_glass_shadow_opacity': instance.liquidGlassShadowOpacity,
      'liquid_glass_blur': instance.liquidGlassBlur,
      'liquid_glass_lighting': instance.liquidGlassLighting,
      'liquid_glass_refractivity_enabled':
          instance.liquidGlassRefractivityEnabled,
      'liquid_glass_refractivity_depth': instance.liquidGlassRefractivityDepth,
      'liquid_glass_refractivity_strength':
          instance.liquidGlassRefractivityStrength,
      'liquid_glass_specular_highlight_placement':
          instance.liquidGlassSpecularHighlightPlacement,
    };
