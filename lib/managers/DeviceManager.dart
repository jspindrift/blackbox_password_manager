import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:logger/logger.dart';

/// creates stackOverflow
// import 'LogManager.dart';

class DeviceManager {
  var logger = Logger(
    printer: PrettyPrinter(),
  );

  static final DeviceManager _shared = DeviceManager._internal();

  factory DeviceManager() {
    return _shared;
  }

  static final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();

  Map<String, dynamic> _deviceData = <String, dynamic>{};

  Map<String, dynamic> get deviceData {
    return _deviceData;
  }

  DeviceManager._internal();

  Future<void> initialize() async {
    await initPlatformState();
  }

  Future<void> initPlatformState() async {
    var deviceData = <String, dynamic>{};

    try {
      if (Platform.isAndroid) {
        deviceData = _readAndroidBuildData(await deviceInfoPlugin.androidInfo);
      } else if (Platform.isIOS) {
        deviceData = _readIosDeviceInfo(await deviceInfoPlugin.iosInfo);
      }

      /// we don't need the systemFeatures data (its a lot and irrelevant)
      deviceData["systemFeatures"] = "";
      logger.d("device data: $deviceData");

      // else if (Platform.isLinux) {
      //   deviceData = _readLinuxDeviceInfo(await deviceInfoPlugin.linuxInfo);
      // } else if (Platform.isMacOS) {
      //   deviceData = _readMacOsDeviceInfo(await deviceInfoPlugin.macOsInfo);
      // } else if (Platform.isWindows) {
      //   deviceData =
      //       _readWindowsDeviceInfo(await deviceInfoPlugin.windowsInfo);
      // }
      // }
    } on PlatformException {
      deviceData = <String, dynamic>{
        'Error:': 'Failed to get platform version.'
      };
    }

    // if (!mounted) return;

    // setState(() {
    _deviceData = deviceData;
    // });
  }

  Map<String, dynamic> _readAndroidBuildData(AndroidDeviceInfo build) {
    return <String, dynamic>{
      'version.securityPatch': build.version.securityPatch,
      'version.sdkInt': build.version.sdkInt,
      'version.release': build.version.release,
      'version.previewSdkInt': build.version.previewSdkInt,
      'version.incremental': build.version.incremental,
      'version.codename': build.version.codename,
      'version.baseOS': build.version.baseOS,
      'board': build.board,
      'bootloader': build.bootloader,
      'brand': build.brand,
      'device': build.device,
      'display': build.display,
      'fingerprint': build.fingerprint,
      'hardware': build.hardware,
      'host': build.host,
      'id': build.id,
      'manufacturer': build.manufacturer,
      'model': build.model,
      'product': build.product,
      'supported32BitAbis': build.supported32BitAbis,
      'supported64BitAbis': build.supported64BitAbis,
      'supportedAbis': build.supportedAbis,
      'tags': build.tags,
      'type': build.type,
      'isPhysicalDevice': build.isPhysicalDevice,
      'systemFeatures': build.systemFeatures,
      // 'displaySizeInches':
      // ((build.displayMetrics.sizeInches * 10).roundToDouble() / 10),
      // 'displayWidthPixels': build.displayMetrics.widthPx,
      // 'displayWidthInches': build.displayMetrics.widthInches,
      // 'displayHeightPixels': build.displayMetrics.heightPx,
      // 'displayHeightInches': build.displayMetrics.heightInches,
      // 'displayXDpi': build.displayMetrics.xDpi,
      // 'displayYDpi': build.displayMetrics.yDpi,
    };
  }

  Map<String, dynamic> _readIosDeviceInfo(IosDeviceInfo data) {
    return <String, dynamic>{
      'name': data.name,
      'systemName': data.systemName,
      'systemVersion': data.systemVersion,
      'model': data.model,
      'localizedModel': data.localizedModel,
      'identifierForVendor': data.identifierForVendor,
      'isPhysicalDevice': data.isPhysicalDevice,
      'utsname.sysname:': data.utsname.sysname,
      'utsname.nodename:': data.utsname.nodename,
      'utsname.release:': data.utsname.release,
      'utsname.version:': data.utsname.version,
      'utsname.machine:': data.utsname.machine,
    };
  }

  Future<String?> getDeviceId() async {
    // var deviceInfo = DeviceInfoPlugin();
    if (Platform.isIOS) {
      var iosDeviceInfo = await deviceInfoPlugin.iosInfo;
      return iosDeviceInfo.identifierForVendor; // unique ID on iOS
    } else if (Platform.isAndroid) {
      var androidDeviceInfo = await deviceInfoPlugin.androidInfo;
      logger.d("android info:\n"
          "id: ${androidDeviceInfo.id}\n"
          "fingerprint: ${androidDeviceInfo.fingerprint}\n"
          "serialNumber: ${androidDeviceInfo.serialNumber}\n"
          "device: ${androidDeviceInfo.device}");
      return androidDeviceInfo.id; // unique ID on Android
    }
  }

  Future<String?> getDeviceModel() async {
    // var deviceInfo = DeviceInfoPlugin();
    // if (Platform.isIOS) {
      var model = _deviceData['model'];
      return model; // unique ID on iOS
    // } else if (Platform.isAndroid) {
    //   var androidDeviceInfo = await deviceInfoPlugin.androidInfo;
    //   return androidDeviceInfo.androidId; // unique ID on Android
    // }
  }

  String? getDeviceVersion() {
    if (Platform.isIOS) {
      var iosDeviceInfo = _deviceData['systemVersion'];
      return iosDeviceInfo; // unique ID on iOS
    } else if (Platform.isAndroid) {
      var iosDeviceInfo = _deviceData['version.sdkInt'];
      return iosDeviceInfo; // unique ID on Android
    }
  }
}
