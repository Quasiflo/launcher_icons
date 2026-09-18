import 'package:launcher_icons/src/core/utils.dart';

/// Base class for all launcher_icons exceptions.
///
/// Catching `LIException` handles every error thrown by this package while the specific subtypes stay available for fine-grained handling.
abstract class LIException implements Exception {
  /// Constructs instance
  const LIException([this.message]);

  /// Message for the exception
  final String? message;

  @override
  String toString() {
    return generateError(this, message);
  }
}

/// Exception to be thrown whenever we have invalid command line arguments
class InvalidCommandException extends LIException {
  /// Constructs instance
  const InvalidCommandException([super.message]);
}

/// Exception to be thrown whenever we have an invalid configuration
class InvalidConfigException extends LIException {
  /// Constructs instance
  const InvalidConfigException([super.message]);
}

/// Exception to be thrown whenever using an invalid Android icon name
class InvalidAndroidIconNameException extends LIException {
  /// Constructs instance of this exception
  const InvalidAndroidIconNameException([super.message]);
}

/// Exception to be thrown whenever no config is found
class NoConfigFoundException extends LIException {
  /// Constructs instance of this exception
  const NoConfigFoundException([super.message]);
}

/// Exception to be thrown whenever there is no decoder for the image format
class NoDecoderForImageFormatException extends LIException {
  /// Constructs instance of this exception
  const NoDecoderForImageFormatException([super.message]);
}

/// A exception to throw when given [fileName] is not found
class FileNotFoundException extends LIException {
  /// Creates a instance of [FileNotFoundException].
  const FileNotFoundException(this.fileName) : super('$fileName file not found');

  /// Name of the file
  final String fileName;
}

/// Exception to be thrown when one or more platforms fail during
/// [generateIconsFor]. Every enabled platform still runs; the names of the
/// failed platforms are collected here so the CLI can report them together and exit non-zero.
class IconGenerationException extends LIException {
  /// Constructs instance with the names of the failed platforms
  IconGenerationException(this.failedPlatforms) : super('Icon generation failed for: ${failedPlatforms.join(', ')}');

  /// Names of the platforms that failed
  final List<String> failedPlatforms;
}
