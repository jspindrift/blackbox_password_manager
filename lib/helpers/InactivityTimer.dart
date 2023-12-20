import 'dart:async';

import '../managers/LogManager.dart';
import '../managers/SettingsManager.dart';


class InactivityTimer {
  static final InactivityTimer _shared = InactivityTimer._internal();

  factory InactivityTimer() {
    return _shared;
  }

  Timer? _timer;
  static const int _defaultInactiveTimeSeconds = 5*60;  // 5 minutes
  DateTime? _lastActivityTime;

  final _logManager = LogManager();
  final _settingsManager = SettingsManager();


  InactivityTimer._internal();


  void startInactivityTimer() async {
    /// ignore calls when app is locked
    if (_settingsManager.isOnLockScreen) {
      // print("hit");
      _lastActivityTime = null;
      return;
    }

    if (_timer != null) {
      stopInactivityTimer();
    }

    var inactivityTime = _settingsManager.inactivityTime;
    if (inactivityTime == null || inactivityTime == 0) {
      inactivityTime = _defaultInactiveTimeSeconds;
    }

    if (_lastActivityTime != null) {
      final timeDiff = DateTime.now().difference(_lastActivityTime!).inSeconds;
      if (timeDiff > inactivityTime) {
        /// logout if change inactivity time action occurs after
        _settingsManager.postLogoutMessage();
      }
    }

    _lastActivityTime = DateTime.now();

    final duration = Duration(seconds: inactivityTime);
    _timer = Timer.periodic(duration, (timer) {
      _logManager.logger.d("inactivity timer timed out: ${timer.tick}: ${DateTime.now().toIso8601String()}");
      _logManager.log("InactivityTimer", "startInactivityTimer", "inactivity");

      _lastActivityTime = null;
      /// post a logout message
      _settingsManager.postLogoutMessage();
    });
  }

  void stopInactivityTimer() async {
    if (_timer != null) {
      if ((_timer?.isActive)!) {
        // _logManager.logger.d("stop inactivity timer");
        // _logManager.log("InactivityTimer", "stopInactivityTimer", "stop heartbeat timer");
        _timer!.cancel();
        _timer = null;
      }
    }
  }


}