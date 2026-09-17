/// Thrown when no usable `image_path` is configured
const String errorMissingImagePath = 'Missing "image_path" or "image_path_android" + "image_path_ios" within configuration';

/// Thrown when no platform section has `generate: true`
const String errorNoPlatformEnabled = 'No platform enabled within config to generate icons for. '
    'Set "generate: true" for at least one platform.';

/// Thrown when an Android `icon_name` breaks the naming contract
const String errorIncorrectIconName = 'The icon name must contain only lowercase a-z, 0-9, or underscore: '
    'E.g. "ic_my_new_icon"';
