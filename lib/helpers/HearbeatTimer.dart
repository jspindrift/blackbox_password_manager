import 'dart:async';
import 'package:convert/convert.dart';

import '../managers/Cryptor.dart';
import '../managers/LogManager.dart';
import '../managers/SettingsManager.dart';

class HeartbeatTimer {
  static final HeartbeatTimer _shared = HeartbeatTimer._internal();

  factory HeartbeatTimer() {
    return _shared;
  }


  Timer? _timer;
  Duration _duration = Duration(seconds: 30);

  final settingsManager = SettingsManager();
  final logManager = LogManager();
  final cryptor = Cryptor();


  HeartbeatTimer._internal();


  Future<void> initialize() async {
    startHeartbeatTimer();
  }


  void startHeartbeatTimer() async {

    if (_timer != null) {
      logManager.logger.d("heartbeat timer already set!");
      return;
    }

    logManager.logger.d("start _heartbeatTimer");
    logManager.log("HeartbeatTimer", "startHeartbeatTimer", "start heartbeat timer with duration: $_duration");

    _timer = Timer.periodic(_duration, (timer) async {
      // logManager.logger.d("_heartbeatTimer: tick: $_ticks: ${DateTime.now().toIso8601String()}");

      final timestamp = DateTime.now();
      final timestampString = timestamp.toIso8601String();
      logManager.log("HeartbeatTimer", "startHeartbeatTimer", "heartbeat: ${timer.tick} | $timestampString");

      settingsManager.saveHeartbeatTick();
    });
  }

  void stopHeartbeatTimer() async {
    if (_timer != null) {
      if ((_timer?.isActive)!) {
        logManager.logger.d("stop heartbeat timer");
        logManager.log("HeartbeatTimer", "stopHeartbeatTimer", "stop heartbeat timer");
        _timer!.cancel();
        _timer = null;
      }
    }
  }


}