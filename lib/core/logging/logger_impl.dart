import 'package:logger/logger.dart' as log_pkg;
import 'app_logger.dart';

/// Implementation of [AppLogger] wrapping the `logger` package with automatic redaction.
class AppLoggerImpl implements AppLogger {
  final log_pkg.Logger _logger;
  final bool enabled;

  AppLoggerImpl({this.enabled = true})
      : _logger = log_pkg.Logger(
          printer: log_pkg.PrettyPrinter(
            methodCount: 1,
            errorMethodCount: 5,
            lineLength: 80,
            colors: true,
            printEmojis: true,
            dateTimeFormat: log_pkg.DateTimeFormat.onlyTimeAndSinceStart,
          ),
        );

  @override
  void debug(String message, [Object? error, StackTrace? stackTrace]) {
    if (!enabled) return;
    _logger.d(AppLogger.redact(message), error: error, stackTrace: stackTrace);
  }

  @override
  void info(String message, [Object? error, StackTrace? stackTrace]) {
    if (!enabled) return;
    _logger.i(AppLogger.redact(message), error: error, stackTrace: stackTrace);
  }

  @override
  void warning(String message, [Object? error, StackTrace? stackTrace]) {
    if (!enabled) return;
    _logger.w(AppLogger.redact(message), error: error, stackTrace: stackTrace);
  }

  @override
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (!enabled) return;
    _logger.e(AppLogger.redact(message), error: error, stackTrace: stackTrace);
  }
}
