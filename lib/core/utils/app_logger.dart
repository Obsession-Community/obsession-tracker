import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Application-wide logger utility
///
/// Provides structured logging with different levels and proper formatting.
/// In production, only warnings and errors are logged to avoid performance impact.
class AppLogger {
  static final Logger _logger = Logger(
    filter: kDebugMode ? DevelopmentFilter() : ProductionFilter(),
    printer: PrettyPrinter(
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
    output: ConsoleOutput(),
  );

  /// Log debug information (only in debug mode)
  static void debug(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  /// Log informational messages
  static void info(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  /// Log warnings
  static void warning(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  /// Log errors
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  /// Log fatal errors
  static void fatal(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.f(message, error: error, stackTrace: stackTrace);
  }

  /// Log verbose information (only in debug mode)
  static void verbose(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.t(message, error: error, stackTrace: stackTrace);
  }

  /// Log performance metrics and test results
  /// This is specifically for test output that should be visible
  static void performance(String message,
      [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      _logger.i('🔋 PERFORMANCE: $message',
          error: error, stackTrace: stackTrace);
    }
  }

  /// Log test results and metrics
  /// This is specifically for test output that should be visible
  static void testResult(String message,
      [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      _logger.i('🧪 TEST: $message', error: error, stackTrace: stackTrace);
    }
  }
}

/// Custom filter for production builds
class ProductionFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) => event.level.index >= Level.warning.index;
}
