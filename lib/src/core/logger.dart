import 'package:cli_util/cli_logging.dart';

export 'package:cli_util/cli_logging.dart' show Progress;

/// Launcher Icons Logger
class LILogger {
  /// Creates a instance of [LILogger]. In case [isVerbose] is `true`, it logs all the [verbose] logs to console
  LILogger({required this.isVerbose}) {
    final ansi = Ansi(Ansi.terminalSupportsAnsi);
    _logger = isVerbose ? Logger.verbose(ansi: ansi) : Logger.standard(ansi: ansi);
  }
  late Logger _logger;

  /// Returns true if this is a verbose logger
  final bool isVerbose;

  /// Gives access to internal logger
  Logger get rawLogger => _logger;

  /// Logs error messages
  void error(final Object? message) => _logger.stderr('⚠️$message');

  /// Prints to console if [isVerbose] is true
  void verbose(final Object? message) => _logger.trace(message.toString());

  /// Prints to console
  void info(final Object? message) => _logger.stdout(message.toString());

  /// Shows progress in console
  Progress progress(final String message) => _logger.progress(message);
}
