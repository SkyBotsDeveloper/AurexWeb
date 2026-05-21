import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

class AppLogger {
  AppLogger._();

  static final Logger instance = Logger(
    filter: _AurexLogFilter(),
    printer: PrettyPrinter(methodCount: 0, errorMethodCount: 5),
  );
}

class _AurexLogFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) => kDebugMode;
}
