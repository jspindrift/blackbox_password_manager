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

  final logManager = LogManager();
  final settingsManager = SettingsManager();


  InactivityTimer._internal();


  void startInactivityTimer() async {
    /// ignore calls when app is locked
    if (settingsManager.isOnLockScreen) {
      // print("hit");
      _lastActivityTime = null;
      return;
    }

    if (_timer != null) {
      // logManager.logger.d("resetting inactivity timer.");
      stopInactivityTimer();
      // return;
    }

    // logManager.logger.d("set inactivity timer");
    // logManager.log("InactivityTimer", "startInactivityTimer", "start heartbeat timer");

    var inactivityTime = settingsManager.inactivityTime;
    if (inactivityTime == null || inactivityTime == 0) {
      inactivityTime = _defaultInactiveTimeSeconds;
    }
    // logManager.logger.d("set inactivity timer: $inactivityTime");


    if (_lastActivityTime != null) {
      final timeDiff = DateTime.now().difference(_lastActivityTime!).inSeconds;
      // logManager.logger.d("inactivity time diff: $timeDiff");
      if (timeDiff > inactivityTime) {
        // logManager.logger.d("inactivity time diff: $timeDiff");
        settingsManager.postLogoutMessage();
      }
    }


    _lastActivityTime = DateTime.now();

    final duration = Duration(seconds: inactivityTime);
    _timer = Timer.periodic(duration, (timer) {
      logManager.logger.d("inactivity timer timed out: ${timer.tick}: ${DateTime.now().toIso8601String()}");
      logManager.log("InactivityTimer", "startInactivityTimer", "inactivity");

      _lastActivityTime = null;
      // final timeDiff = DateTime.now().difference(_lastActivityTime!).inSeconds;
      // logManager.logger.d("inactivity TIMER: time diff: $timeDiff");
      /// post a logout message
      settingsManager.postLogoutMessage();
    });
  }

  void stopInactivityTimer() async {
    if (_timer != null) {
      if ((_timer?.isActive)!) {
        // logManager.logger.d("stop inactivity timer");
        // logManager.log("InactivityTimer", "stopInactivityTimer", "stop heartbeat timer");
        _timer!.cancel();
        _timer = null;
      }
    }
  }


}