import 'dart:math';

class AppConstants {

  /// TODO: DEBUG change this to true to show sensitive key data
  /// for testing/debug purposes only!!!
  static const bool debugKeyData = false;

  /// app-specific constants --------------------------------------------------
  static const String appName = "Blackbox Password Manager";

  /// TOTP values ---------------------------------------
  static const String appTOTPStartTime = "2023-07-22T15:08:36.310505";

  static const int appTOTPDefaultTimeInterval = 30;
  static const int appTOTPDefaultMaxNumberDigits = 12;
  static const int appTOTPDefaultMaxNumberWords = 12;
  static const int appTOTPDefaultMinNumberDigits = 3;
  static const int appTOTPDefaultMinNumberWords = 1;


  /// Vault specific values ---------------------------------------
  /// TODO: right side - increase to represent 64 bit iv (possibly < 64 bit && > 32 bit)
  /// 32 bit for now
  static final int maxEncryptionBlocks = (pow(2,32)-1).toInt();
  static final int maxEncryptionBytes = maxEncryptionBlocks*16;

  /// TODO: left side - increase to represent 64 bit iv (possibly < 64 bit && > 32 bit)
  /// 32 bit for now
  static final int maxRolloverBlocks = (pow(2,32)-1).toInt();


  /// Data model object versions
  /// used for possible future proofing implementations
  static const int keyItemVersion = 1;
  static const int passwordItemVersion = 1;
  static const int noteItemVersion = 1;
  static const int peerPublicKeyItemVersion = 1;
  static const int myDigitalIdentityItemVersion = 1;
  static const int pinCodeItemVersion = 1;
  static const int digitalIdentityVersion = 1;
  static const int encryptedGeoLockItemVersion = 1;


}