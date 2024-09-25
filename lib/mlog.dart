import 'dart:developer' as log;

import 'package:flutter/foundation.dart';

class TgLog {
  static const appName = 'TG Hero Log';

  void message(String message,{int level = 0}) {
    if (!kDebugMode) return;
    log.log(message, name: appName,level: level);
  }

  void error({Object? error, StackTrace? t}) {
    if (!kDebugMode) return;
    log.log('', name: appName, error: error, stackTrace: t);
  }
}

final mLog = TgLog();
