import 'dart:async';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import '../managers/LogManager.dart';

class BiometricManager {
  static final BiometricManager _shared = BiometricManager._internal();

  factory BiometricManager() {
    return _shared;
  }

  /// Local Authentication
  final LocalAuthentication auth = LocalAuthentication();
  bool _biometricsIsSupported = false;
  bool _canCheckBiometrics = false;
  List<BiometricType>? _availableBiometrics;
  String _biometricType = 'Biometrics';
  String _biometricIcon = 'assets/icons8-fingerprint-96.png';
  bool _isTouchID = true;

  final logManager = LogManager();

  bool get biometricsIsSupported {
    return _biometricsIsSupported;
  }

  bool get canCheckBiometrics {
    return _canCheckBiometrics;
  }

  List<BiometricType>? get availableBiometrics {
    return _availableBiometrics;
  }

  String get biometricType {
    return _biometricType;
  }

  String get biometricIcon {
    return _biometricIcon;
  }

  bool get isTouchID {
    return _isTouchID;
  }

  BiometricManager._internal();

  /// Check if device supports biometrics
  Future<bool> isDeviceSecured() async {
    try {
      /// local authentication check
      _biometricsIsSupported = await auth.isDeviceSupported();
      logManager.log("BiometricManager", "isDeviceSupported",
          "Device Biometrics Supported: $_biometricsIsSupported");

      return _biometricsIsSupported;
    } catch (e) {
      logManager.log("BiometricManager", "isDeviceSupported",
          "Device Biometrics Error: $e");
      return false;
    }
  }

  /// Check biometrics
  Future<bool> checkBiometrics() async {
    try {
      _canCheckBiometrics = await auth.canCheckBiometrics;
      // print('debug: canCheckBiometrics: $_canCheckBiometrics');
      logManager.log("BiometricManager", "checkBiometrics",
          "Check Biometrics: $_canCheckBiometrics");
      return _canCheckBiometrics;
    } on PlatformException catch (e) {
      _canCheckBiometrics = false;
      print('debug: canCheckBiometrics: $e');
      // print(e);
      logManager.log(
          "BiometricManager", "checkBiometrics", "Check Biometrics Error: $e");
      return false;
    }
  }

  /// Get available biometrics
  Future<void> getAvailableBiometrics() async {
    late List<BiometricType> availableBiometrics;
    try {
      availableBiometrics = await auth.getAvailableBiometrics();
    } on PlatformException catch (e) {
      availableBiometrics = <BiometricType>[];
      print(e);
    }

    _availableBiometrics = availableBiometrics;
    // print('debug: available biometrics: ${availableBiometrics[0]}');
    if (_availableBiometrics != null) {
      if (_availableBiometrics!.length > 0) {
        logManager.log("BiometricManager", "getAvailableBiometrics",
            "Available Biometrics: ${_availableBiometrics![0]}");
      }
    }

    if (_availableBiometrics != null) {
      if (_availableBiometrics!.isNotEmpty) {
        if (_availableBiometrics![0] == BiometricType.face) {
          _isTouchID = false;
          _biometricType = 'Face ID';
          _biometricIcon = 'assets/icons8-face-id-96.png';
        } else if (_availableBiometrics![0] == BiometricType.iris) {
          _isTouchID = false;
          _biometricType = 'Iris ID';
          _biometricIcon = 'assets/icons8-face-id-96.png';
        } else if (_availableBiometrics![0] == BiometricType.fingerprint) {
          _isTouchID = true;
          _biometricType = 'Touch ID';
          _biometricIcon = 'assets/icons8-fingerprint-96.png';
        }
      }
    }
  }

  Future<bool> doBiometricCheck() async {
    final status1 = await isDeviceSecured();
    if (status1) {
      final status2 = await checkBiometrics();
      if (status2) {
        await getAvailableBiometrics();
        return true;
      }
    }
    return false;
  }

  /// Authenticate using biometrics
  Future<bool> authenticateWithBiometrics() async {
    bool authenticated = false;

    // await getAvailableBiometrics();
    //
    // if (_availableBiometrics == null){
    //   print("no available biometrics");
    //   return false;
    // }

    try {
      authenticated = await auth.authenticate(
        localizedReason: 'Use biometrics to authenticate',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
          useErrorDialogs: true,
        ),
      );

      // print('authenticated: $authenticated');
      logManager.log("BiometricManager", "authenticateWithBiometrics",
          "Authenticated Biometrics: $authenticated");

      return authenticated;
    } on PlatformException catch (e) {
      print(e);
      logManager.log("BiometricManager", "authenticateWithBiometrics",
          "Authenticated Biometrics Error: $e");
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics2() async {
    bool authenticated = false;
    try {
      authenticated = await auth.authenticate(
        localizedReason: 'Use biometrics to authenticate',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
        ),
      );

      // print('authenticated: $authenticated');
      logManager.log("BiometricManager", "authenticateWithBiometrics2",
          "Authenticated Biometrics: $authenticated");

      return authenticated;
    } on PlatformException catch (e) {
      print(e);
      logManager.log("BiometricManager", "authenticateWithBiometrics2",
          "Authenticated Biometrics Error: $e");
      return false;
    }
  }
}
