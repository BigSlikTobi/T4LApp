import 'package:logging/logging.dart';
import 'package:flutter/foundation.dart';

class AppLogger {
  static final Logger _logger = Logger('T4L');
  static bool _isInitialized = false;

  static void initialize() {
    if (_isInitialized) return;

    Logger.root.level = kDebugMode ? Level.ALL : Level.INFO;
    Logger.root.onRecord.listen((record) {
      // In development, log to console using debugPrint
      // In production, only log INFO and above
      if (kDebugMode || record.level.value >= Level.INFO.value) {
        debugPrint('${record.level.name}: ${record.time}: ${record.message}');
      }
    });

    _isInitialized = true;
    info('Logging initialized. Debug mode: $kDebugMode');
  }

  static void info(String message) => _logger.info(message);
  static void warning(String message) => _logger.warning(message);
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.severe(message, error, stackTrace);
  }

  // Debug logs only appear in debug mode
  static void debug(String message) {
    if (kDebugMode) {
      _logger.fine(message);
    }
  }
}
