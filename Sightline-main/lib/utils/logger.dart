import 'package:logging/logging.dart';

class AppLogger {
  static final Logger _logger = Logger('SightlineApp');
  static bool _initialized = false;

  static void init() {
    if (_initialized) return;
    
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      // Format: LEVEL: TIME: MESSAGE
      print('${record.level.name}: ${record.time}: ${record.message}');
      
      if (record.error != null) {
        print('Error: ${record.error}');
        if (record.stackTrace != null) {
          print('Stack trace:\n${record.stackTrace}');
        }
      }
    });
    
    _initialized = true;
  }

  static void info(String message) {
    _ensureInitialized();
    _logger.info(message);
  }

  static void warning(String message) {
    _ensureInitialized();
    _logger.warning(message);
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    _ensureInitialized();
    _logger.severe(message, error, stackTrace);
  }

  static void debug(String message) {
    _ensureInitialized();
    _logger.fine(message);
  }

  static void _ensureInitialized() {
    if (!_initialized) {
      init();
    }
  }
}
