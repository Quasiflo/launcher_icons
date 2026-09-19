# Launcher_icons

A new example Flutter project to quickly test launcher_icons.

## Quickstart

Before being able to run this example you need to navigate to this directory and run the following commands

```bash
flutter create --org com.example.launcher_icons_minimal .
dart run launcher_icons
```

Then you can run the app for whichever target platform, and you should see some variation of the following icon:

![Minimal Example Icon](./assets/icon/icon-master-1024.png)

## Exploring Further

Try changing `image_path` in `pubspec.yaml` to point to a different file (square svg or 1024x1024 png). Run `dart run launcher_icons`. See what changes! If the icon doesn't refresh on next launch, try running `flutter clean && flutter pub install` and deleting the app from the device (if using mobile device).

If you're still having trouble, check whether the image files in:

- [android/app/src/main/res/](android/app/src/main/res/)
- [ios/Runner/Assets.xcassets/AppIcon.appiconset/](ios/Runner/Assets.xcassets/AppIcon.appiconset/)
- [macos/Runner/Assets.xcassets/AppIcon.appiconset/](macos/Runner/Assets.xcassets/AppIcon.appiconset/)
- [share/icons/hicolor/](share/icons/hicolor/)
- [snap/gui/](snap/gui/)
- [web/icons/](web/icons/)
- [windows/runner/resources/](windows/runner/resources/)

Are what you're expecting. If they aren't, please submit an issue at [github.com/Quasiflo/launcher_icons/issues/new](https://github.com/Quasiflo/launcher_icons/issues/new), we'll be happy to help diagnose & resolve the problem!
