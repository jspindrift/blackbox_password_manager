import 'dart:async';
import 'dart:math';
import 'dart:io';
import '../helpers/WidgetUtils.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:enum_to_string/enum_to_string.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/VaultItem.dart';
import '../helpers/AppConstants.dart';
import '../managers/DeviceManager.dart';


enum SharedPreferenceKey {
  hasLaunched, // tells if app has been launched before
  lockOnExit,
  darkMode,
  backup,
  lastTabIndex,
  itemTags,
  inactivityTime,
  pinCodeLength,
  numEncryptions,
  numBytesEncrypted,
  numBlocksEncrypted,
  numRolloverEncryptions,
  sessionNumber,
  heartbeats,
  numGestureInteractions,
  saveToSDCard,
  saveToSDCardOnly,
  recoveryMode,
}

class SettingsManager {
  static final SettingsManager _shared = SettingsManager._internal();

  factory SettingsManager() {
    return _shared;
  }

  var logger = Logger(
    printer: PrettyPrinter(),
  );

  var loggerNoStack = Logger(
    printer: PrettyPrinter(methodCount: 0),
  );

  PackageInfo _packageInfo = PackageInfo(
    appName: 'Unknown',
    packageName: 'Unknown',
    version: 'Unknown',
    buildNumber: 'Unknown',
    buildSignature: 'Unknown',
  );

  PackageInfo get packageInfo {
    return _packageInfo;
  }

  bool _launchSettingInitialized = false;
  int _initCount = 0;
  int _initCount2 = 0;

  bool _isDarkModeEnabled = false;
  bool _isLockOnExitEnabled = false;
  bool _isRecoveredSession = false;
  bool _saveToSDCard = false;
  bool _saveToSDCardOnly = false;

  int _inactivityTime = 5 * 60;

  int _pinCodeLength = 4;

  int _numEncryptions = 0;
  int _numBytesEncrypted = 0;
  int _numRolloverEncryptionCounts = 0;

  static final _maxBlocks = AppConstants.maxEncryptionBlocks; // pow(2, 10); // per counter 2^10*16 bytes 16 kb
  static final _maxRolloverBlocks = AppConstants.maxRolloverBlocks;


  bool _isScanningQRCode = false;
  bool _isOnLockScreen = true;
  bool _isCreatingNewAccount = false;
  bool _didCopyToClipboard = false;
  bool _isRecoveryModeEnabled = false;

  bool _hasLaunched = false;
  bool _shouldRekey = false;

  int _currentTabIndex = 0;

  int _sessionNumber = 0;
  int _numBlocksEncrypted = 0;

  int _heartbeatsTotal = 0;

  List<String> _itemTags = [];

  VaultItem? _androidBackup;

  bool get launchSettingInitialized {
    return _launchSettingInitialized;
  }

  bool get saveToSDCard {
    return _saveToSDCard;
  }

  bool get saveToSDCardOnly {
    return _saveToSDCardOnly;
  }

  bool get isRecoveryModeEnabled {
    return _isRecoveryModeEnabled;
  }

  bool get shouldRekey {
    return _shouldRekey;
  }

  bool get hasLaunched {
    return _hasLaunched;
  }

  bool get isRecoveredSession {
    return _isRecoveredSession;
  }

  int get sessionNumber {
    return _sessionNumber;
  }

  int get heartbeatsTotal {
    return _heartbeatsTotal;
  }

  int get numEncryptions {
    return _numEncryptions;
  }

  int get numBytesEncrypted {
    return _numBytesEncrypted;
  }

  int get numBlocksEncrypted {
    return _numBlocksEncrypted;
  }

  int get numRolloverEncryptionCounts {
    return _numRolloverEncryptionCounts;
  }

  num get maxBlocks {
    return _maxBlocks;
  }

  num get maxRolloverBlocks {
    return _maxRolloverBlocks;
  }


  int get currentTabIndex {
    return _currentTabIndex;
  }

  int get pinCodeLength {
    return _pinCodeLength;
  }

  bool get didCopyToClipboard {
    return _didCopyToClipboard;
  }

  bool get isCreatingNewAccount {
    return _isCreatingNewAccount;
  }

  List<String> get itemTags {
    return _itemTags;
  }

  bool get isLockOnExitEnabled {
    return _isLockOnExitEnabled;
  }

  int get inactivityTime {
    return _inactivityTime;
  }

  bool get isOnLockScreen {
    return _isOnLockScreen;
  }

  bool get isDarkModeEnabled {
    return _isDarkModeEnabled;
  }

  VaultItem? get androidBackup {
    return _androidBackup;
  }

  bool get isScanningQRCode {
    return _isScanningQRCode;
  }

  /// communicates to TabHomeScreen to refresh layout for dark mode
  final _onDarkModeEnabledChanged = StreamController<bool>.broadcast();
  Stream<bool> get onDarkModeEnabledChanged => _onDarkModeEnabledChanged.stream;

  final _onSelectedRouteChanged = StreamController<int>.broadcast();
  Stream<int> get onSelectedRouteChanged => _onSelectedRouteChanged.stream;

  final _onInactivityLogoutRecieved = StreamController<bool>.broadcast();
  Stream<bool> get onInactivityLogoutRecieved =>
      _onInactivityLogoutRecieved.stream;

  final _onResetAppRecieved = StreamController<bool>.broadcast();
  Stream<bool> get onResetAppRecieved => _onResetAppRecieved.stream;


  final deviceManager = DeviceManager();

  SettingsManager._internal();

  initializeLaunchSettings() async {
    // final startTime = DateTime.now();
    // logger.d("initializeLaunchSettings-begin: $_initCount2");
    await _readHasLaunched();

    // final endTime = DateTime.now();
    // final timeDiff = endTime.difference(startTime);
    // logger.d("initializeLaunchSettings time diff[$_initCount2]: ${timeDiff.inMilliseconds} ms");
    // logger.d("initializeLaunchSettings-done: $_initCount2");
    // _initCount2++;
  }

  Future<void> initialize() async {
    // final startTime = DateTime.now();
    // logger.d("initialize-begin: $_initCount");

    // await _readHasLaunched();

    await readRecoveryModeEnabled();

    await _readSaveToSDCard();

    await _readSaveToSDCardOnly();

    await _readLockOnExit();

    await _readInactivityTime();

    await _readDarkMode();

    await _readPinCodeLength();

    await _readLastTabIndex();

    await _readItemTags();

    await _readSessionNumber();

    await _readHeartbeatCount();

    await _readNumBytesEncrypted();

    await _readNumBlocksEncrypted();

    await _readRolloverEncryptionCount();

    await _initPackageInfo();

    await deviceManager.initialize();

    // final endTime = DateTime.now();
    // final timeDiff = endTime.difference(startTime);
    // logger.d("initialize time diff[$_initCount]: ${timeDiff.inMilliseconds} ms");
    // logger.d("initialize-done: $_initCount");
    // _initCount++;
  }

  Future<void> _initPackageInfo() async {
    _packageInfo = await PackageInfo.fromPlatform();
    // logger.d('_packageInfo: appName: ${_packageInfo.appName}');
    // logger.d('_packageInfo: version: ${_packageInfo.version}');
    // logger.d('_packageInfo: buildNumber: ${_packageInfo.buildNumber}');
    // logger.d('_packageInfo: buildSignature: ${_packageInfo.buildSignature}');
    // logger.d('_packageInfo: packageName: ${_packageInfo.packageName}');
    // logger.d('_packageInfo: installerStore: ${_packageInfo.installerStore}');
  }

  String versionAndBuildNumber() {
    return "v${_packageInfo.version}-${_packageInfo.buildNumber}";
  }

  void setIsRecoveredSession(bool value) {
    _isRecoveredSession = value;
  }

  void doEncryption(int nbytes) {
    _numEncryptions += 1;
    final ablocks = (_numBytesEncrypted / 16).ceil();
    final nblocks = (nbytes / 16).ceil();
    // logger.d("a[$ablocks]: n[${nblocks}]");

    // logger.d("a[$ablocks]: ${(ablocks/_maxBlocks)}: ${(ablocks/_maxBlocks)*100}");
    // logger.d("a+n[$nblocks, ${nblocks+ablocks}]: ${((ablocks+nblocks)/_maxBlocks)}: ${((ablocks+nblocks)/_maxBlocks)*100}");

    if (ablocks + nblocks >= _maxBlocks) {
      logger.d("reached limit!!!!!........:)");
      _numRolloverEncryptionCounts += 1;
      _numBytesEncrypted = nbytes;
      _numBlocksEncrypted = nblocks;
      if (_numRolloverEncryptionCounts + 1 > _maxRolloverBlocks) {
        logger.d("_maxRolloverBlocks reached:  Must RE-KEY!!!!!");
        _shouldRekey = true;
      }
      saveEncryptionRolloverCount(_numRolloverEncryptionCounts);
      saveNumBytesEncrypted(_numBytesEncrypted);
      saveNumBlocksEncrypted(_numBlocksEncrypted);
      WidgetUtils.showToastMessage("Rolled Over: ${_numRolloverEncryptionCounts}", 5);
    } else {
      _numBytesEncrypted += nbytes;
      _numBlocksEncrypted += nblocks;
    }
    // logger.d("_numBlocksEncrypted: n[${_numBlocksEncrypted}]");
  }

  void setIsScanningQRCode(bool value) {
    _isScanningQRCode = value;
  }

  void setDidCopyToClipboard(bool value) {
    _didCopyToClipboard = value;
  }

  void setIsCreatingNewAccount(bool value) {
    _isCreatingNewAccount = value;
  }

  void setCurrentTabIndex(int index) async {
    _currentTabIndex = index;
    // logger.d("setCurrentTabIndex: $index");

    try {
      final prefs = await SharedPreferences.getInstance();
      prefs.setInt(
          EnumToString.convertToString(SharedPreferenceKey.lastTabIndex),
          index);
    } catch (e) {
      logger.e(e);
    }
  }

  Future<void> _readLastTabIndex() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      var intData = prefs.getInt(
          EnumToString.convertToString(SharedPreferenceKey.lastTabIndex));
      if (intData == null) {
        return;
      }

      _currentTabIndex = intData;
    } catch (e) {
      logger.e(e);
    }
  }

  Future<void> _readInactivityTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      var intData = prefs.getInt(
          EnumToString.convertToString(SharedPreferenceKey.inactivityTime));
      if (intData == null) {
        return;
      }

      _inactivityTime = intData;
    } catch (e) {
      logger.e(e);
    }
  }

  /// Lock On Exit
  Future<void> saveInactivityTime(int time) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      prefs.setInt(
          EnumToString.convertToString(SharedPreferenceKey.inactivityTime),
          time);

      _inactivityTime = time;
    } catch (e) {
      logger.e(e);
    }
  }

  Future<void> _readHasLaunched() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      var boolData = prefs.getBool(
          EnumToString.convertToString(SharedPreferenceKey.hasLaunched));
      if (boolData == null) {
        return;
      }

      _hasLaunched = boolData;
      _launchSettingInitialized = true;
    } catch (e) {
      logger.e(e);
    }
  }

  /// Lock On Exit
  Future<void> saveHasLaunched() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      prefs.setBool(
          EnumToString.convertToString(SharedPreferenceKey.hasLaunched), true);

      _hasLaunched = true;
    } catch (e) {
      logger.e(e);
    }
  }

  Future<void> _readSessionNumber() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      var intData = prefs.getInt(
          EnumToString.convertToString(SharedPreferenceKey.sessionNumber));
      if (intData == null) {
        return;
      }

      if (intData == 0) {
        _sessionNumber = 1;
      } else {
        _sessionNumber = intData;
      }
    } catch (e) {
      logger.e(e);
      _sessionNumber = 1;
    }
  }

  incrementSessionNumber() async {
    _sessionNumber += 1;

    await saveSessionNumber(_sessionNumber);
  }

  /// Lock On Exit
  Future<void> saveSessionNumber(int count) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      prefs.setInt(
          EnumToString.convertToString(SharedPreferenceKey.sessionNumber),
          count);

      _sessionNumber = count;
    } catch (e) {
      logger.e(e);
    }
  }

  Future<void> _readHeartbeatCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      var intData = prefs
          .getInt(EnumToString.convertToString(SharedPreferenceKey.heartbeats));
      if (intData == null) {
        return;
      }

      // logger.d("_readHeartbeatCount: $intData");

      _heartbeatsTotal = intData;
    } catch (e) {
      logger.e(e);
    }
  }

  /// Lock On Exit
  Future<void> saveHeartbeatTick() async {
    try {
      _heartbeatsTotal += 1;
      // logger.d("saveHeartbeatTick: $_heartbeatsTotal");

      final prefs = await SharedPreferences.getInstance();
      prefs.setInt(EnumToString.convertToString(SharedPreferenceKey.heartbeats),
          _heartbeatsTotal);

      // _heartbeatsTotal = count;
    } catch (e) {
      logger.e(e);
    }
  }

  /// Bytes Encrypted
  Future<void> _readNumBytesEncrypted() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      var intData = prefs.getInt(
          EnumToString.convertToString(SharedPreferenceKey.numBytesEncrypted));
      if (intData == null) {
        return;
      }

      // logger.d("_readNumBytesEncrypted: [$intData]\nblocks: ${(intData/16)}, floor: ${(intData/16).floor()}\npercentage used: floor: ${(intData/16).floor()/pow(2,31)}");
      _numBytesEncrypted = intData;
    } catch (e) {
      logger.e(e);
    }
  }

  Future<void> saveNumBytesEncrypted(int count) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      prefs.setInt(
          EnumToString.convertToString(SharedPreferenceKey.numBytesEncrypted),
          count);

      _numBytesEncrypted = count;
      // logger.d("save _numBytesEncrypted: [$count]");
    } catch (e) {
      logger.e(e);
    }
  }

  /// Blocks Encrypted
  Future<void> _readNumBlocksEncrypted() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      var intData = prefs.getInt(
          EnumToString.convertToString(SharedPreferenceKey.numBlocksEncrypted));
      if (intData == null) {
        return;
      }

      // logger.d("_readNumBlocksEncrypted: [$intData]");
      _numBlocksEncrypted = intData;
    } catch (e) {
      logger.e(e);
    }
  }

  Future<void> saveNumBlocksEncrypted(int count) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      prefs.setInt(
          EnumToString.convertToString(SharedPreferenceKey.numBlocksEncrypted),
          count);

      _numBlocksEncrypted = count;
      logger.d("save _numBlocksEncrypted: [$count]");
    } catch (e) {
      logger.e(e);
    }
  }

  /// Rollover Blocks
  Future<void> _readRolloverEncryptionCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      var intData = prefs.getInt(EnumToString.convertToString(
          SharedPreferenceKey.numRolloverEncryptions));
      if (intData == null) {
        return;
      }

      // logger.d("_readRolloverEncryptionCount: [$intData]");
      _numRolloverEncryptionCounts = intData;

      if (_numRolloverEncryptionCounts + 1 > _maxRolloverBlocks) {
        logger.d("_maxRolloverBlocks reached:  Should RE-KEY!!!!!");
        _shouldRekey = true;
      }
    } catch (e) {
      logger.e(e);
    }
  }

  Future<void> saveEncryptionRolloverCount(int count) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      prefs.setInt(
          EnumToString.convertToString(
              SharedPreferenceKey.numRolloverEncryptions),
          count);

      _numRolloverEncryptionCounts = count;
    } catch (e) {
      logger.e(e);
    }
  }

  Future<void> _readPinCodeLength() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      var intData = prefs.getInt(
          EnumToString.convertToString(SharedPreferenceKey.pinCodeLength));
      if (intData == null) {
        return;
      }

      _pinCodeLength = intData;
    } catch (e) {
      logger.e(e);
    }
  }

  Future<void> savePinCodeLength(int length) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      prefs.setInt(
          EnumToString.convertToString(SharedPreferenceKey.pinCodeLength),
          length);

      _pinCodeLength = length;
    } catch (e) {
      logger.e(e);
    }
  }

  void setIsOnLockScreen(bool isLocked) {
    _isOnLockScreen = isLocked;
  }

  /// Lock On Exit
  void saveLockOnExit(bool isEnabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      prefs.setBool(
          EnumToString.convertToString(SharedPreferenceKey.lockOnExit),
          isEnabled);

      _isLockOnExitEnabled = isEnabled;
    } catch (e) {
      logger.e(e);
    }
  }

  /// Read Lock On Exit
  Future<void> _readLockOnExit() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      var boolData = prefs.getBool(
          EnumToString.convertToString(SharedPreferenceKey.lockOnExit));
      if (boolData == null) {
        return;
      }

      // logger.d("read lock on exit: $boolData");
      _isLockOnExitEnabled = boolData;
    } catch (e) {
      logger.e(e);
    }
  }

  /// Dark Mode
  Future<void> saveDarkMode(bool isEnabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      prefs.setBool(EnumToString.convertToString(SharedPreferenceKey.darkMode),
          isEnabled);

      // logger.d('saveDarkMode: $isEnabled');
      _isDarkModeEnabled = isEnabled;
    } catch (e) {
      logger.e(e);
    }
  }

  Future<void> _readDarkMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      var boolData = prefs
          .getBool(EnumToString.convertToString(SharedPreferenceKey.darkMode));
      if (boolData == null) {
        return;
      }

      // logger.d('readDarkMode: $boolData');
      _isDarkModeEnabled = boolData;
    } catch (e) {
      logger.e(e);
    }
  }

  /// Lock On Exit
  void saveRecoveryModeEnabled(bool isEnabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      prefs.setBool(
          EnumToString.convertToString(SharedPreferenceKey.recoveryMode),
          isEnabled);

      _isRecoveryModeEnabled = isEnabled;
    } catch (e) {
      logger.e(e);
    }
  }

  /// Read Lock On Exit
  Future<void> readRecoveryModeEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      var boolData = prefs.getBool(
          EnumToString.convertToString(SharedPreferenceKey.recoveryMode));
      if (boolData == null) {
        return;
      }

      // logger.d("read lock on exit: $boolData");
      _isRecoveryModeEnabled = boolData;
    } catch (e) {
      logger.e(e);
    }
  }


  Future<void> _readSaveToSDCard() async {
    if (Platform.isAndroid) {
      try {
        final prefs = await SharedPreferences.getInstance();

        var boolData = prefs.getBool(
            EnumToString.convertToString(SharedPreferenceKey.saveToSDCard));
        if (boolData == null) {
          return;
        }

        // logger.d("_saveToSDCard: [boolData]");
        _saveToSDCard = boolData;
      } catch (e) {
        logger.e(e);
      }
    }
  }

  Future<void> saveSaveToSDCard(bool saveToSD) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      prefs.setBool(
          EnumToString.convertToString(SharedPreferenceKey.saveToSDCard),
          saveToSD);

      // logger.d("save _saveToSDCard: [$saveToSD]");
      _saveToSDCard = saveToSD;
    } catch (e) {
      logger.e(e);
    }
  }

  /// Blocks Encrypted
  Future<void> _readSaveToSDCardOnly() async {
    if (Platform.isAndroid) {
      try {
        final prefs = await SharedPreferences.getInstance();

        var boolData = prefs.getBool(
            EnumToString.convertToString(SharedPreferenceKey.saveToSDCardOnly));
        if (boolData == null) {
          return;
        }

        _saveToSDCardOnly = boolData;
      } catch (e) {
        logger.e(e);
      }
    }
  }

  Future<void> saveSaveToSDCardOnly(bool saveToSDOnly) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      prefs.setBool(
          EnumToString.convertToString(SharedPreferenceKey.saveToSDCardOnly),
          saveToSDOnly);

      _saveToSDCardOnly = saveToSDOnly;
    } catch (e) {
      logger.e(e);
    }
  }


  /// Tags
  void saveItemTags(List<String> tags) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      prefs.setStringList(
          EnumToString.convertToString(SharedPreferenceKey.itemTags), tags);

      _itemTags = tags;
    } catch (e) {
      logger.e(e);
    }
  }

  Future<void> _readItemTags() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      var strData = prefs.getStringList(
          EnumToString.convertToString(SharedPreferenceKey.itemTags));
      if (strData == null) {
        return;
      }

      _itemTags = strData;
    } catch (e) {
      logger.e(e);
    }
  }

  _removeSharedPreference(SharedPreferenceKey sharedPreferenceKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(EnumToString.convertToString(sharedPreferenceKey));
  }

  void removeAllPreferences() async {
    // logger.d("removeAllPreferences");
    var allKeys = SharedPreferenceKey.values;

    for (var element in allKeys) {
      // do not remove backup items for android
      // if (EnumToString.convertToString(element) != "backup") {
      if (element != SharedPreferenceKey.backup &&
          element != SharedPreferenceKey.lockOnExit) {
        await _removeSharedPreference(element);
      }
    }

    _resetAllVariables();

    /// set back to secure defaults
    saveLockOnExit(true);
    saveDarkMode(true);
  }

  void _resetAllVariables() {
    _isDarkModeEnabled = true;
    _isLockOnExitEnabled = true;
    _isRecoveredSession = false;
    _inactivityTime = 5 * 60;
    _pinCodeLength = 6;
    _numEncryptions = 0;
    _numBytesEncrypted = 0;
    _numRolloverEncryptionCounts = 0;

    _isScanningQRCode = false;
    _isOnLockScreen = true;
    _isCreatingNewAccount = false;
    _didCopyToClipboard = false;

    _hasLaunched = false;
    _shouldRekey = false;

    _currentTabIndex = 0;

    _sessionNumber = 0;
    _numBlocksEncrypted = 0;

    _heartbeatsTotal = 0;

    _itemTags = [];

    _androidBackup = null;
  }


  /// async function to communicate dark mode change
  processDarkModeChange(bool isEnabled) {
    _onDarkModeEnabledChanged.sink.add(isEnabled);
  }

  changeRoute(int index) {
    _onSelectedRouteChanged.sink.add(index);
  }

  postLogoutMessage() {
    _onInactivityLogoutRecieved.sink.add(true);
  }

  postResetAppNotification() {
    _onResetAppRecieved.sink.add(true);
  }


}
