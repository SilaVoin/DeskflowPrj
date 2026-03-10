import 'package:logger/logger.dart';

/// Application-wide logger instance.
///
/// Usage:
/// ```dart
/// import 'package:deskflow/core/utils/app_logger.dart';
///
/// final _log = AppLogger.getLogger('MyClass');
/// _log.d('Debug message');
/// _log.i('Info message');
/// _log.w('Warning message');
/// _log.e('Error message', error: e, stackTrace: st);
/// ```
class AppLogger {
  AppLogger._();

  /// Set to false to disable all verbose logging.
  static bool enabled = true;

  /// Global log level. Change via environment or runtime config.
  static Level _level = Level.debug;

  static set level(Level value) => _level = value;

  /// Get a logger instance tagged with [tag].
  static Logger getLogger(String tag) {
    return Logger(
      filter: _AppLogFilter(),
      printer: PrefixPrinter(
        PrettyPrinter(
          methodCount: 0,
          errorMethodCount: 5,
          lineLength: 80,
          noBoxingByDefault: true,
        ),
        debug: '[$tag]',
        info: '[$tag]',
        warning: '[$tag]',
        error: '[$tag]',
        fatal: '[$tag]',
      ),
      level: _level,
    );
  }
}

class _AppLogFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    return AppLogger.enabled && event.level.index >= AppLogger._level.index;
  }
}
