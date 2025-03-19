import 'package:logging/logging.dart';
import 'package:flutter/foundation.dart';

class AppLogger {
  static final Logger _logger = Logger('T4L');

  static void initialize() {
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      // In development, log to console using debugPrint
      // In production, you might want to send logs to a service
      debugPrint('${record.level.name}: ${record.time}: ${record.message}');
    });
  }

  static void info(String message) => _logger.info(message);
  static void warning(String message) => _logger.warning(message);
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.severe(message, error, stackTrace);
  }

  static void debug(String message) => _logger.fine(message);
}
