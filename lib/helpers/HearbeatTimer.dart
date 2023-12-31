import 'dart:async';

import '../managers/LogManager.dart';
import '../managers/SettingsManager.dart';


class HeartbeatTimer {
  static final HeartbeatTimer _shared = HeartbeatTimer._internal();

  factory HeartbeatTimer() {
    return _shared;
  }

  Timer? _timer;
  Duration _duration = Duration(seconds: 30);

  final _settingsManager = SettingsManager();
  final _logManager = LogManager();


  HeartbeatTimer._internal();


  Future<void> initialize() async {
    startHeartbeatTimer();
  }


  void startHeartbeatTimer() async {

    if (_timer != null) {
      _logManager.logger.d("heartbeat timer already set!");
      return;
    }

    _logManager.logger.d("start _heartbeatTimer");
    _logManager.log("HeartbeatTimer", "startHeartbeatTimer", "start heartbeat timer with duration: $_duration");

    _timer = Timer.periodic(_duration, (timer) async {
      // _logManager.logger.d("_heartbeatTimer: tick: $_ticks: ${DateTime.now().toIso8601String()}");

      final timestamp = DateTime.now();
      final timestampString = timestamp.toIso8601String();
      _logManager.log("HeartbeatTimer", "startHeartbeatTimer", "heartbeat: ${timer.tick} | $timestampString");

      _settingsManager.saveHeartbeatTick();
    });
  }

  void stopHeartbeatTimer() async {
    if (_timer != null) {
      if ((_timer?.isActive)!) {
        _logManager.logger.d("stop heartbeat timer");
        _logManager.log("HeartbeatTimer", "stopHeartbeatTimer", "stop heartbeat timer");
        _timer!.cancel();
        _timer = null;
      }
    }
  }


}