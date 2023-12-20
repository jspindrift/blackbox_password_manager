import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';

import '../managers/LogManager.dart';


class JailbreakChecker {
  static final JailbreakChecker _shared = JailbreakChecker._internal();

  factory JailbreakChecker() {
    return _shared;
  }

  bool _isJailbroken = false;
  bool _isDeveloperMode = false;

  final logManager = LogManager();

  bool get isJailbroken {
    return _isJailbroken;
  }

  bool get isDeveloperMode {
    return _isDeveloperMode;
  }

  JailbreakChecker._internal();

  /// Check if device supports biometrics
  Future<bool> isDeviceJailbroken() async {
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      _isJailbroken = await FlutterJailbreakDetection.jailbroken;
      _isDeveloperMode = await FlutterJailbreakDetection.developerMode;


    } on PlatformException {
      _isJailbroken = true;
      _isDeveloperMode = true;
    }

    logManager.log("JailbreakChecker", "isDeviceJailbroken",
        "isJailbroken: $_isJailbroken");

    logManager.log("JailbreakChecker", "isDeviceJailbroken",
        "isDeveloperMode: $_isDeveloperMode");

    logManager.logger.d("JailbreakChecker: isJailbroken: $_isJailbroken");
    logManager.logger.d("JailbreakChecker: isDeveloperMode: $_isDeveloperMode");


    return _isJailbroken;
  }

}
