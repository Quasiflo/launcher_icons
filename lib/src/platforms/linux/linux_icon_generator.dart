import 'dart:io';

import 'package:image/image.dart';
import 'package:launcher_icons/src/core/constants.dart' as constants;
import 'package:launcher_icons/src/core/custom_exceptions.dart';
import 'package:launcher_icons/src/core/icon_generator.dart';
import 'package:launcher_icons/src/core/paths.dart' as paths;
import 'package:launcher_icons/src/core/utils.dart' as utils;
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

/// An implementation of [LinuxIconGenerator] for Linux
class LinuxIconGenerator extends IconGenerator {
  /// Creates an instance of [LinuxIconGenerator]
  LinuxIconGenerator(IconGeneratorContext context) : super(context, 'Linux');

  /// Runtime icon path: SVG sources derive a sibling raster (see constants.linuxRuntimeSize) because the runner can only load rasters; raster sources pass through untouched.
  static String runtimeIconPath(String iconPath) => utils.isSvgPath(iconPath)
      ? path.join(
          path.dirname(iconPath),
          '${path.basenameWithoutExtension(iconPath)}${paths.linuxDerivedIconSuffix}',
        )
      : iconPath;

  @override
  Future<void> createIcons() async {
    final sourcePath = context.config.resolveImageFile(context.config.linuxConfig!.imagePath, context.prefixPath);
    final iconPath = runtimeIconPath(sourcePath);
    context.logger.verbose('Using Linux icon at $iconPath...');

    // SVG sources can't be loaded by the runner: derive the runtime raster first. The file is tool-owned and always rewritten so the wired window icon can never go stale.
    if (iconPath != sourcePath) {
      await _writeDerivedRuntimeIcon(sourcePath, iconPath);
    }

    // The icon must be a bundled flutter asset: the runner resolves it at runtime via data/flutter_assets (a filesystem path, not an asset handle), so an absolute host path would not be portable. Bundling is enforced by validateRequirements() via _hasPubspecAsset.

    // Update my_application.cc file with the icon path (X11 window icon). On Wayland there is no window-icon protocol: the compositor matches the window to the installed .desktop file instead, which the packaging files below provide.
    await _updateMyApplicationFile(iconPath);

    // Real launcher deliverables for Wayland/desktop/snap. Everything is strictly only-if-absent: existing files are never overwritten.
    await _generatePackagingFiles(sourcePath);
  }

  /// Rasterizes the SVG at [sourcePath] to the [iconPath] runtime raster.
  Future<void> _writeDerivedRuntimeIcon(
    String sourcePath,
    String iconPath,
  ) async {
    final image = await utils.cachedSvgRaster(
      context.svgRasterCache,
      path.join(context.prefixPath, sourcePath),
      constants.linuxRuntimeSize,
      constants.linuxRuntimeSize,
      logger: context.logger,
      message: 'Rasterizing SVG source $sourcePath for the Linux runtime icon',
    );
    final file = File(path.join(context.prefixPath, iconPath));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(encodePng(image));
  }

  /// Generates the real launcher deliverables: the hicolor PNG tree and the freedesktop `.desktop` entry under `sharePrefix`, plus (when `generate_snap` is true) the snap icon, the snap `.desktop` entry and `snap/snapcraft.yaml` — all keyed off the pubspec name/version. Also ensures `linux/CMakeLists.txt` installs the `share/` tree.
  ///
  /// Every file is strictly only-if-absent: pre-existing files are left untouched (with a warning) so user edits are never clobbered. The CMake block is canonical and updated in place when the prefix changes.
  Future<void> _generatePackagingFiles(String iconPath) async {
    final linuxConfig = context.config.linuxConfig!;
    final sharePrefix = linuxConfig.sharePrefix;
    final generateSnap = linuxConfig.generateSnap;
    final loadSize = await utils.sizeImageLoaderFor(
      path.join(context.prefixPath, iconPath),
      logger: context.logger,
      cache: context.svgRasterCache,
    );
    final appName = _readAppName();
    final appVersion = _readAppVersion();

    for (final size in constants.linuxHicolorSizes) {
      await _writeBytesIfAbsent(
        paths.linuxHicolorIconPath(appName, size, sharePrefix),
        encodePng(await loadSize(size)),
      );
    }
    final applicationId = _readApplicationId();
    await _writeStringIfAbsent(
      paths.linuxDesktopFilePath(appName, sharePrefix),
      _desktopFile(appName, 'Icon=$appName', applicationId),
    );
    if (generateSnap) {
      await _writeBytesIfAbsent(
        paths.linuxSnapIconPath(appName),
        encodePng(await loadSize(256)),
      );
      await _writeStringIfAbsent(
        paths.linuxSnapDesktopFilePath(appName),
        _desktopFile(
          appName,
          'Icon=\${SNAP}/meta/gui/$appName.png',
          applicationId,
        ),
      );
      await _writeStringIfAbsent(
        paths.linuxSnapcraftFilePath,
        _snapcraftFile(appName, appVersion),
      );
    }
    await _ensureCmakeInstallRules(sharePrefix);
  }

  /// Writes [bytes] to [relativePath] (under [prefixPath]) unless the file already exists, in which case it warns and leaves it untouched.
  Future<void> _writeBytesIfAbsent(String relativePath, List<int> bytes) async {
    final file = File(path.join(context.prefixPath, relativePath));
    if (file.existsSync()) {
      context.logger.verbose('$relativePath already exists, skipping.');
      return;
    }
    await file.create(recursive: true);
    await file.writeAsBytes(bytes);
    context.logger.verbose('Created $relativePath.');
  }

  /// String variant of [_writeBytesIfAbsent].
  Future<void> _writeStringIfAbsent(
    String relativePath,
    String content,
  ) async {
    final file = File(path.join(context.prefixPath, relativePath));
    if (file.existsSync()) {
      context.logger.verbose('$relativePath already exists, skipping.');
      return;
    }
    await file.create(recursive: true);
    await file.writeAsString(content);
    context.logger.verbose('Created $relativePath.');
  }

  /// Marker anchoring the tool-owned CMake install block in `linux/CMakeLists.txt`.
  static const _cmakeMarker = '# Installed by launcher_icons';

  /// Ensures `linux/CMakeLists.txt` installs the freedesktop `share/` tree (icons + desktop entry) into the bundle/system `share/`.
  ///
  /// The source directory is derived from [sharePrefix] relative to `linux/` (default `linux` -> `${CMAKE_CURRENT_SOURCE_DIR}/share/...`), so custom prefixes keep working. Idempotent: the canonical 2-line block is added once and rewritten in place when the prefix changes; user edits outside the block are preserved.
  Future<void> _ensureCmakeInstallRules(String sharePrefix) async {
    final file = File(path.join(context.prefixPath, paths.linuxTopCMakeListsFile));
    if (!file.existsSync()) {
      context.logger.verbose('${paths.linuxTopCMakeListsFile} not found, skipping CMake install rules.');
      return;
    }
    final content = await file.readAsString();
    final shareRoot = paths.linuxShareRoot(sharePrefix);
    final rawRel = path.relative(shareRoot, from: paths.linuxDirPath).replaceAll(r'\', '/');
    // `path.relative` yields `.` when both coincide; CMake wants `share`.
    final cmakeRel = (rawRel == '.' || rawRel.isEmpty) ? 'share' : rawRel;
    final block = '$_cmakeMarker: freedesktop icons + desktop entry from $shareRoot/.\n'
        'install(DIRECTORY "\${CMAKE_CURRENT_SOURCE_DIR}/$cmakeRel/icons" DESTINATION "share" COMPONENT Runtime)\n'
        'install(DIRECTORY "\${CMAKE_CURRENT_SOURCE_DIR}/$cmakeRel/applications" DESTINATION "share" COMPONENT Runtime)';

    if (content.contains(_cmakeMarker)) {
      final pattern = RegExp(
        RegExp.escape(_cmakeMarker) + r'[^\n]*\ninstall\(DIRECTORY "\$\{CMAKE_CURRENT_SOURCE_DIR\}/[^"]+/icons" DESTINATION "share" COMPONENT Runtime\)\ninstall\(DIRECTORY "\$\{CMAKE_CURRENT_SOURCE_DIR\}/[^"]+/applications" DESTINATION "share" COMPONENT Runtime\)',
      );
      if (pattern.hasMatch(content)) {
        final updated = content.replaceFirst(pattern, block);
        if (updated != content) {
          await file.writeAsString(updated);
          context.logger.verbose('Updated CMake install rules for $shareRoot.');
        } else {
          context.logger.verbose('CMake install rules already up to date for $shareRoot.');
        }
      } else {
        // Marker present but block shape diverged (hand-edited): leave it.
        context.logger.verbose('CMake install block already present, skipping.');
      }
      return;
    }
    final eol = content.contains('\r\n') ? '\r\n' : '\n';
    final normalizedEol = content.replaceAll('\r\n', '\n');
    final withTrailing = normalizedEol.endsWith('\n') ? normalizedEol : '$normalizedEol\n';
    final updated = (withTrailing + '\n$block\n').replaceAll('\n', eol);
    await file.writeAsString(updated);
    context.logger.verbose('Added CMake install rules for $shareRoot.');
  }

  /// Reads the pubspec `name` (fallback `app`).
  String _readAppName() {
    final yamlDoc = _readPubspec();
    final name = yamlDoc?['name'];
    if (name is String && name.isNotEmpty) {
      return name;
    }
    return 'app';
  }

  /// Reads the pubspec `version` with any build number stripped (fallback `0.0.1`).
  String _readAppVersion() {
    final yamlDoc = _readPubspec();
    final version = yamlDoc?['version'];
    if (version is String && version.isNotEmpty) {
      return version.split('+').first;
    }
    return '0.0.1';
  }

  /// Parses prefix `pubspec.yaml`, or returns null when missing/unparseable.
  Map<dynamic, dynamic>? _readPubspec() {
    final pubspecFile = File(path.join(context.prefixPath, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) {
      return null;
    }
    try {
      return loadYaml(pubspecFile.readAsStringSync()) as Map<dynamic, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  /// freedesktop desktop entry with the given `Icon=` line. [applicationId] becomes `StartupWMClass=` so docks/taskbars group the window under this entry; it is omitted when unknown (a wrong value is worse than none — it would override the signals that already work).
  String _desktopFile(
    String appName,
    String iconLine,
    String? applicationId,
  ) {
    final buffer = StringBuffer('''
[Desktop Entry]
Name=$appName
Comment=$appName
Exec=$appName
$iconLine
Terminal=false
Type=Application
Categories=Utility;
''');
    if (applicationId != null) {
      buffer.writeln('StartupWMClass=$applicationId');
    }
    return buffer.toString();
  }

  /// Reads the GTK application id from `linux/CMakeLists.txt` (`set(APPLICATION_ID "...")`). This id is the window identity on both session types (Wayland `app_id`, X11 `WM_CLASS` instance part), so it is the only correct `StartupWMClass` value. A flavor-conditional override (`if(FLUTTER_APP_FLAVOR STREQUAL "<flavor>")`) wins on flavor runs. Null when absent — the caller omits the line rather than guessing.
  String? _readApplicationId() {
    final file = File(path.join(context.prefixPath, paths.linuxTopCMakeListsFile));
    if (!file.existsSync()) {
      return null;
    }
    try {
      final content = file.readAsStringSync();
      final matches = RegExp(r'set\s*\(\s*APPLICATION_ID\s+"([^"]+)"\s*\)').allMatches(content).toList();
      if (matches.isEmpty) {
        return null;
      }
      final flavor = context.flavor;
      if (flavor != null) {
        for (final match in matches) {
          final contextStart = (match.start - 300).clamp(0, match.start);
          final before = content.substring(contextStart, match.start);
          if (before.contains('STREQUAL') && before.contains('"$flavor"')) {
            return match.group(1);
          }
        }
      }
      return matches.first.group(1);
    } catch (_) {
      return null;
    }
  }

  /// Minimal snap packaging template off the pubspec name/version.
  String _snapcraftFile(String appName, String appVersion) => '''
name: $appName
version: $appVersion
summary: $appName
description: $appName

confinement: strict
base: core22
grade: stable

slots:
  dbus-$appName: # adjust accordingly to your app name
    interface: dbus
    bus: session
    name: org.example.$appName # adjust accordingly to your app name

apps:
  $appName:
    command: $appName
    extensions: [gnome] # gnome includes the libraries required by flutter
    plugs:
    - network
    slots:
      - dbus-$appName
parts:
  $appName:
    source: .
    plugin: flutter
    flutter-target: lib/main.dart # The main entry-point file of the application
''';

  @override
  bool validateRequirements() {
    // The generate flag is enforced by the caller via the config enabled flag; only filesystem and config preconditions are checked here.
    context.logger.verbose('Validating Linux config...');
    final linuxConfig = context.config.linuxConfig!;

    final String sourcePath;
    try {
      sourcePath = context.config.resolveImageFile(linuxConfig.imagePath, context.prefixPath);
    } on InvalidConfigException catch (e) {
      context.logger.error(e.message);
      return false;
    }

    // SVG sources derive a sibling raster at generation time (see constants.linuxRuntimeSize): the pubspec must bundle the derived file.
    final iconPath = runtimeIconPath(sourcePath);

    final entitesToCheck = [
      path.join(context.prefixPath, paths.linuxDirPath),
      path.join(context.prefixPath, paths.linuxMyApplicationFile),
    ];

    final failedEntityPath = utils.areFSEntiesExist(entitesToCheck);
    if (failedEntityPath != null) {
      context.logger.error(
        '$failedEntityPath this file or folder is required to generate Linux icons',
      );
      return false;
    }

    if (!_hasPubspecAsset(
      iconPath,
      sourcePath: iconPath == sourcePath ? null : sourcePath,
    )) {
      return false;
    }

    return true;
  }

  /// Returns `true` when [iconPath] (or its directory) is declared in the `assets:` list under `flutter:` in `pubspec.yaml`. [sourcePath] names the SVG the runtime raster derives from, so the error can explain which file to declare.
  bool _hasPubspecAsset(String iconPath, {String? sourcePath}) {
    final pubspecFile = File(path.join(context.prefixPath, 'pubspec.yaml'));

    if (!pubspecFile.existsSync()) {
      context.logger.error(
        'pubspec.yaml not found. Please add "$iconPath" to the `assets:` list under `flutter:` in pubspec.yaml.',
      );
      return false;
    }

    final Map<dynamic, dynamic>? yamlDoc;
    try {
      yamlDoc = loadYaml(pubspecFile.readAsStringSync()) as Map<dynamic, dynamic>?;
    } catch (_) {
      context.logger.error('Could not parse pubspec.yaml');
      return false;
    }

    if (yamlDoc == null) {
      context.logger.error('Could not parse pubspec.yaml');
      return false;
    }

    final flutter = yamlDoc['flutter'] as Map<dynamic, dynamic>?;
    if (flutter == null) {
      context.logger.error(
        'No `flutter:` section found in pubspec.yaml. Please add $iconPath to the `assets:` list under `flutter:`.',
      );
      return false;
    }

    final assets = flutter['assets'] as List<dynamic>?;
    if (assets == null) {
      context.logger.error(
        'No `assets:` list found under `flutter:` in pubspec.yaml. Please add "$iconPath" to it.',
      );
      return false;
    }

    // Check if the icon path or its directory is included in assets. Normalize separators so a directory entry also matches on Windows.
    final iconDir = '${path.dirname(iconPath).replaceAll(r'\', '/')}/';
    for (final asset in assets) {
      final assetStr = asset.toString();
      if (assetStr == iconPath || assetStr == iconDir) {
        context.logger.verbose(
          'Icon path $iconPath is properly configured in pubspec.yaml',
        );
        return true;
      }
    }

    context.logger.error(
      sourcePath == null ? 'Icon path $iconPath not found in the `assets:` list under `flutter:` in pubspec.yaml. Please add "$iconPath" or "$iconDir" to it.' : 'Icon path $iconPath (rasterized from "$sourcePath" at generation time) not found in the `assets:` list under `flutter:` in pubspec.yaml. Please add "$iconPath" or "$iconDir" to it.',
    );
    return false;
  }

  static const _assetHelperName = 'get_flutter_asset_path';
  static const _iconVarName = 'linux_icon_path';
  static const _gioInclude = '#include <gio/gio.h>';

  /// Matches the helper definition/call, but not a longer identifier that merely ends with the helper name (e.g. `my_get_flutter_asset_path(`).
  static final _helperRefRegex = RegExp(
    '(^|[^A-Za-z0-9_])' + _assetHelperName + r'\s*\(',
    multiLine: true,
  );

  static const _assetHelperTemplate = r'''
static gchar* get_flutter_asset_path(const gchar* asset_path) {
  g_autofree gchar* executable = g_file_read_link("/proc/self/exe", NULL);
  if (executable == NULL) {
    return g_strdup(asset_path);
  }
  g_autofree gchar* executable_dir = g_path_get_dirname(executable);
  return g_build_filename(executable_dir, "data", "flutter_assets", asset_path, NULL);
}
''';

  /// Builds the canonical 2-line call block for [iconPath] with [indent].
  static List<String> _canonicalBlock(String iconPath, String indent) {
    return [
      '${indent}g_autofree gchar* $_iconVarName = $_assetHelperName("$iconPath");',
      '${indent}gtk_window_set_icon_from_file(window, $_iconVarName, NULL);',
    ];
  }

  Future<void> _updateMyApplicationFile(String iconPath) async {
    final myAppFile = File(path.join(context.prefixPath, paths.linuxMyApplicationFile));

    if (!myAppFile.existsSync()) {
      context.logger.error(
        'my_application.cc file not found at ${paths.linuxMyApplicationFile}',
      );
      throw FileNotFoundException(paths.linuxMyApplicationFile);
    }

    var content = await myAppFile.readAsString();

    // Canonical block already present -> check path, update or no-op.
    if (_helperRefRegex.hasMatch(content)) {
      final canonicalPathRegex = RegExp(
        // ignore: prefer_single_quotes
        RegExp.escape(_assetHelperName) + r'\s*\(\s*"([^"]+)"\s*\)',
      );
      final canonicalMatch = canonicalPathRegex.firstMatch(content);
      if (canonicalMatch != null) {
        final currentPath = canonicalMatch.group(1)!;
        if (currentPath == iconPath) {
          context.logger.verbose(
            'Icon configuration already exists with correct path: $iconPath',
          );
          // Still ensure helper + include are present (e.g. hand-edited file).
          final updated = _ensureHelperAndInclude(content);
          if (updated != content) {
            await myAppFile.writeAsString(updated);
          }
          return;
        } else {
          context.logger.verbose(
            'Updating icon configuration from "$currentPath" to "$iconPath"',
          );
          var updated = content.replaceAll(
            canonicalPathRegex,
            '$_assetHelperName("$iconPath")',
          );
          updated = _ensureHelperAndInclude(updated);
          await myAppFile.writeAsString(updated);
          context.logger.verbose(
            'Updated my_application.cc with new icon configuration: $iconPath',
          );
          return;
        }
      }
    }

    // Legacy single/multi-line call present -> upgrade to canonical block, taking the path from the manual call only for logging; we always rewrite to the configured iconPath.
    final existingIconRegex = RegExp(
      r'gtk_window_set_icon_from_file\s*\(\s*[^;]*;',
      multiLine: true,
      dotAll: true,
    );
    final existingIconMatch = existingIconRegex.firstMatch(content);
    if (existingIconMatch != null) {
      final existingIconStatement = existingIconMatch.group(0)!;
      // Skip if this is already the canonical second line (uses variable).
      if (!existingIconStatement.contains(_iconVarName)) {
        final iconPathRegex = RegExp(r'"([^"]+)"');
        final iconPathMatch = iconPathRegex.firstMatch(existingIconStatement);
        final currentIconPath = iconPathMatch?.group(1);
        context.logger.verbose(
          currentIconPath == null ? 'Upgrading icon configuration to exe-relative block: $iconPath' : 'Upgrading icon configuration from "$currentIconPath" to "$iconPath"',
        );
        var updated = _ensureHelperAndInclude(content);
        updated = _replaceLegacyCall(updated, existingIconRegex, iconPath);
        await myAppFile.writeAsString(updated);
        context.logger.verbose(
          'Updated my_application.cc with new icon configuration: $iconPath',
        );
        return;
      } else {
        // Canonical call line exists but helper-call regex missed (should be rare) -> just ensure helper + include.
        final updated = _ensureHelperAndInclude(content);
        if (updated != content) {
          await myAppFile.writeAsString(updated);
        }
        return;
      }
    }

    // No existing icon configuration found - need to add it
    context.logger.verbose('Adding new icon configuration: $iconPath');

    content = _ensureHelperAndInclude(content);
    final lines = content.split('\n');
    var modified = false;

    void insertAt(int index, String indent) {
      final block = _canonicalBlock(iconPath, indent);
      lines.insertAll(index, block);
    }

    // Strategy 1: Find gtk_window_set_default_size and insert before it
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].contains('gtk_window_set_default_size')) {
        final currentLine = lines[i];
        final leadingWhitespace = RegExp(r'^(\s*)').firstMatch(currentLine)?.group(1) ?? '  ';
        insertAt(i, leadingWhitespace);
        modified = true;
        break;
      }
    }

    // Strategy 2: Find window variable declaration and insert after it
    if (!modified) {
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].contains('GtkWindow* window =') || lines[i].contains('GtkWindow *window =')) {
          // Find the end of the window declaration (look for semicolon)
          int declarationEndIndex = i;
          while (declarationEndIndex < lines.length && !lines[declarationEndIndex].contains(';')) {
            declarationEndIndex++;
          }

          // Insert after the window declaration
          final int insertIndex = declarationEndIndex + 1;

          // Find proper indentation
          final currentLine = lines[i];
          final leadingWhitespace = RegExp(r'^(\s*)').firstMatch(currentLine)?.group(1) ?? '  ';

          insertAt(insertIndex, leadingWhitespace);
          modified = true;
          break;
        }
      }
    }

    // Strategy 3: Find gtk_window_show and insert before it
    if (!modified) {
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].contains('gtk_window_show') || lines[i].contains('gtk_widget_show')) {
          // Find proper indentation
          final currentLine = lines[i];
          final leadingWhitespace = RegExp(r'^(\s*)').firstMatch(currentLine)?.group(1) ?? '  ';

          insertAt(i, leadingWhitespace);
          modified = true;
          break;
        }
      }
    }

    // Strategy 4: Find any gtk_window function call and insert nearby
    if (!modified) {
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].contains('gtk_window_') && !lines[i].contains('gtk_window_set_icon_from_file')) {
          // Find proper indentation
          final currentLine = lines[i];
          final leadingWhitespace = RegExp(r'^(\s*)').firstMatch(currentLine)?.group(1) ?? '  ';

          insertAt(i + 1, leadingWhitespace);
          modified = true;
          break;
        }
      }
    }

    if (modified) {
      await myAppFile.writeAsString(lines.join('\n'));
      context.logger.verbose(
        'Updated my_application.cc with icon configuration: $iconPath',
      );
    } else {
      // The 2-line call depends on the asset-path helper and the gio include, so spell out all three pieces for a manual fix.
      final errorMessage = 'Could not find appropriate location to add icon configuration in my_application.cc. '
          'Please manually update it as follows:\n'
          '1. Add $_gioInclude alongside the other includes (if missing).\n'
          '2. Add this helper before my_application_activate:\n'
          '${_assetHelperTemplate.trim()}\n'
          '3. Add these lines after the window creation:\n'
          '  g_autofree gchar* linux_icon_path = get_flutter_asset_path("$iconPath");\n'
          '  gtk_window_set_icon_from_file(window, linux_icon_path, NULL);';
      context.logger.error(errorMessage);
      throw Exception('Failed to update my_application.cc. $errorMessage');
    }
  }

  /// Ensures `#include <gio/gio.h>` and the asset-path helper are present.
  String _ensureHelperAndInclude(String content) {
    var updated = content;
    if (!updated.contains(_gioInclude)) {
      final lines = updated.split('\n');
      final lastInclude = lines.lastIndexWhere((l) => l.trimLeft().startsWith('#include'));
      if (lastInclude != -1) {
        lines.insert(lastInclude + 1, _gioInclude);
      } else {
        lines.insert(0, _gioInclude);
      }
      updated = lines.join('\n');
    }
    if (!_helperRefRegex.hasMatch(updated) || !updated.contains('g_file_read_link("/proc/self/exe"')) {
      // Insert helper before my_application_activate when possible.
      const anchor = 'static void my_application_activate';
      final anchorIndex = updated.indexOf(anchor);
      if (anchorIndex != -1) {
        updated = updated.replaceFirst(
          anchor,
          '${_assetHelperTemplate.trim()}\n\n$anchor',
        );
      } else {
        updated = '${_assetHelperTemplate.trim()}\n\n$updated';
      }
    }
    return updated;
  }

  /// Replaces a legacy `gtk_window_set_icon_from_file(...)` statement with the canonical 2-line exe-relative block, preserving indentation.
  String _replaceLegacyCall(
    String content,
    RegExp legacyRegex,
    String iconPath,
  ) {
    final match = legacyRegex.firstMatch(content);
    if (match == null) {
      return content;
    }
    final statement = match.group(0)!;
    // Derive indentation from the start of the matched statement.
    final before = content.substring(0, match.start);
    final lineStart = before.lastIndexOf('\n') + 1;
    final linePrefix = content.substring(lineStart, match.start);
    final indentMatch = RegExp(r'^(\s*)').firstMatch(linePrefix + statement);
    final indent = indentMatch?.group(1) ?? '  ';
    final block = _canonicalBlock(iconPath, indent).join('\n');
    return content.replaceFirst(legacyRegex, block);
  }
}
