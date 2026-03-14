import 'package:logger/logger.dart';

class AppLogger {
  AppLogger._();

  static bool enabled = true;

  static Level _level = Level.debug;

  static set level(Level value) => _level = value;

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
