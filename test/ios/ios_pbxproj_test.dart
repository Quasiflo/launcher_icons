import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:launcher_icons/src/platforms/ios/ios.dart';
import 'package:test/test.dart';

const String _pbxProjFixture = r'''
// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 56;
	objects = {

/* Begin PBXBuildFile section */
		00000000000000000000000A /* AppDelegate.swift in Sources */ = {isa = PBXBuildFile; fileRef = 000000000000000000000001 /* AppDelegate.swift */; };
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
		000000000000000000000001 /* AppDelegate.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = AppDelegate.swift; sourceTree = "<group>"; };
		000000000000000000000002 /* Assets.xcassets */ = {isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>"; };
/* End PBXFileReference section */

/* Begin PBXGroup section */
		000000000000000000000003 /* Runner */ = {
			isa = PBXGroup;
			children = (
				000000000000000000000002 /* Assets.xcassets */,
				000000000000000000000001 /* AppDelegate.swift */,
			);
			name = Runner;
			sourceTree = "<group>";
		};
/* End PBXGroup section */

/* Begin PBXResourcesBuildPhase section */
		000000000000000000000004 /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXResourcesBuildPhase section */
	};
	rootObject = 000000000000000000000005 /* Project object */;
}
''';

final RegExp _fileRefRegExp = RegExp(
  r'\s*([0-9A-F]{24}) /\* AppIcon\.icon \*/ = \{isa = PBXFileReference',
);
final RegExp _buildFileRegExp = RegExp(
  r'\s*([0-9A-F]{24}) /\* AppIcon\.icon in Resources \*/ = \{isa = PBXBuildFile',
);
final RegExp _xcodeIdRegExp = RegExp(r'^[0-9A-F]{24}$');

String _fileRefId(String content) => _fileRefRegExp.firstMatch(content)!.group(1)!;

String _buildFileId(String content) => _buildFileRegExp.firstMatch(content)!.group(1)!;

// Unit tests for the liquid glass project.pbxproj manipulation
void main() {
  group('addLiquidGlassIconReference', () {
    test('adds entries to the correct pbxproj sections', () {
      final result = addLiquidGlassIconReference(_pbxProjFixture, 'AppIcon');
      final refId = _fileRefId(result);
      final buildFileId = _buildFileId(result);

      final refLine = result.indexOf(
        '$refId /* AppIcon.icon */ = {isa = PBXFileReference',
      );
      expect(refLine, greaterThanOrEqualTo(0));
      expect(
        refLine,
        lessThan(result.indexOf('/* End PBXFileReference section */')),
      );

      final buildFileLine = result.indexOf(
        '$buildFileId /* AppIcon.icon in Resources */ = {isa = PBXBuildFile',
      );
      expect(buildFileLine, greaterThanOrEqualTo(0));
      expect(
        buildFileLine,
        lessThan(result.indexOf('/* End PBXBuildFile section */')),
      );

      final resourcesLine = result.indexOf(
        '\t\t\t\t$buildFileId /* AppIcon.icon in Resources */,',
      );
      final filesOpen = result.indexOf('files = (');
      final filesClose = result.indexOf(');', filesOpen);
      expect(resourcesLine, greaterThan(filesOpen));
      expect(resourcesLine, lessThan(filesClose));

      final groupLine = result.indexOf('\t\t\t\t$refId /* AppIcon.icon */,');
      final childrenOpen = result.indexOf('children = (');
      expect(groupLine, greaterThan(childrenOpen));
      expect(groupLine, lessThan(result.indexOf('/* End PBXGroup section */')));
    });

    test('uses unique 24 character hex identifiers', () {
      final result = addLiquidGlassIconReference(_pbxProjFixture, 'AppIcon');
      final refId = _fileRefId(result);
      final buildFileId = _buildFileId(result);
      expect(_xcodeIdRegExp.hasMatch(refId), isTrue);
      expect(_xcodeIdRegExp.hasMatch(buildFileId), isTrue);
      expect(refId, isNot(buildFileId));
    });

    test('is idempotent', () {
      final once = addLiquidGlassIconReference(_pbxProjFixture, 'AppIcon');
      final twice = addLiquidGlassIconReference(once, 'AppIcon');
      expect(twice, once);
    });

    test('returns the unchanged content when the reference already exists', () {
      final result = addLiquidGlassIconReference(_pbxProjFixture, 'AppIcon');
      expect(addLiquidGlassIconReference(result, 'AppIcon'), result);
    });

    test('returns unchanged content when no matching sections exist', () {
      const noSections = 'rootObject = 000000000000000000000000 /* P */;\n';
      expect(addLiquidGlassIconReference(noSections, 'AppIcon'), noSections);
    });

    test('regenerates the id when the initial hash already exists', () {
      final collidingId = sha256.convert(utf8.encode('fileRefAppIcon')).toString().substring(0, 24).toUpperCase();
      final collidingContent = _pbxProjFixture.replaceFirst(
        '000000000000000000000001 /* AppDelegate.swift */ = {isa = PBXFileReference',
        '$collidingId /* OldIcon.icon */ = {isa = PBXFileReference',
      );

      final result = addLiquidGlassIconReference(collidingContent, 'AppIcon');
      final refId = _fileRefId(result);
      expect(_xcodeIdRegExp.hasMatch(refId), isTrue);
      expect(refId, isNot(collidingId));
    });
  });
}
