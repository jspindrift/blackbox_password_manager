import 'package:blackbox_password_manager/helpers/AppConstants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:dynamic_themes/dynamic_themes.dart';

import '../models/KeyItem.dart';
// import '../screens/peer_messages_screen.dart';
import '../screens/active_encryption_screen.dart';
import '../screens/add_key_item_screen.dart';
import '../screens/add_peer_public_key_screen.dart';
import '../screens/add_public_encryption_key_screen.dart';
import '../screens/edit_public_encryption_key_screen.dart';
import '../screens/peer_public_key_list_screen.dart';
import '../screens/rekey_auth_screen.dart';
import '../screens/show_log_detail2_screen.dart';
import '../screens/welcome_all_list_screen.dart';
import '../managers/LogManager.dart';
import './screens/change_password_screen.dart';
import './screens/add_password_screen.dart';
import './screens/edit_password_screen.dart';
import './screens/settings_screen.dart';
import './screens/login_screen.dart';
import './screens/welcome_screen.dart';
import './screens/lock_screen.dart';
import './screens/previous_passwords_screen.dart';
import './screens/backups_screen.dart';
import './screens/show_bip39_screen.dart';
import './screens/pin_code_screen.dart';
import './screens/settings_about_screen.dart';
import './screens/show_logs_screen.dart';
import './screens/show_log_detail_screen.dart';
import './screens/advanced_settings_screen.dart';
import './screens/diagnostics_screen.dart';
import './screens/recovery_mode_screen.dart';
import './screens/home_tab_screen.dart';
import './screens/items_by_tag_screen.dart';
import './screens/welcome_categories_screen.dart';
import './screens/add_note_screen.dart';
import './screens/note_list_screen.dart';
import './screens/favorites_list_screen.dart';
import './screens/inactivity_time_screen.dart';
import './screens/emergency_kit_screen.dart';
import './widgets/qr_code_view.dart';
import './helpers/InactivityTimer.dart';


void main() {
  /// TODO: added to try fix Android Studio android device run, vs flutter run issues
  // WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}


class MyApp extends StatelessWidget {
  MyApp({Key? key}) : super(key: key);

  final _inactivityTimer = InactivityTimer();
  // final _settingsManager = SettingsManager();


  @override
  Widget build(BuildContext context) {
    return DynamicTheme(builder: (context, themeData) {
      return Listener(
        onPointerDown: (_) {
          /// TODO: only do this while logged in
          /// check this
          _inactivityTimer.startInactivityTimer();
        },
        onPointerUp: (_) {
          /// TODO: only do this while logged in
          /// check this
          _inactivityTimer.startInactivityTimer();
        },
        child: MaterialApp(
          title: 'Blackbox Password Manager',
          theme: themeData,
          home: const LoginScreen(),
          routes: {
            LoginScreen.routeName: (ctx) => LoginScreen(),
            HomeTabScreen.routeName: (ctx) => HomeTabScreen(),
            EmergencyKitScreen.routeName: (ctx) => EmergencyKitScreen(),
            WelcomeScreen.routeName: (ctx) => WelcomeScreen(),
            FavoritesListScreen.routeName: (ctx) => FavoritesListScreen(),
            WelcomeCategoriesScreen.routeName: (ctx) =>
                WelcomeCategoriesScreen(),
            ItemsByTagScreen.routeName: (ctx) =>
                ItemsByTagScreen(
                  tag: "",
                ),
            AddPasswordScreen.routeName: (ctx) =>
                AddPasswordScreen(
                  passwordList: [],
                ),
            EditPasswordScreen.routeName: (ctx) =>
                EditPasswordScreen(
                  id: '',
                  passwordList: [],
                ),
            NoteListScreen.routeName: (ctx) => NoteListScreen(),
            AddNoteScreen.routeName: (ctx) =>
                AddNoteScreen(
                  id: null,
                ),
            SettingsScreen.routeName: (ctx) => SettingsScreen(),
            ChangePasswordScreen.routeName: (ctx) => ChangePasswordScreen(),
            LockScreen.routeName: (ctx) => LockScreen(),
            InactivityTimeScreen.routeName: (ctx) => InactivityTimeScreen(),
            PreviousPasswordsScreen.routeName: (ctx) =>
                PreviousPasswordsScreen(items: []),
            BackupsScreen.routeName: (ctx) => BackupsScreen(),
            ShowBIP39Screen.routeName: (ctx) =>
                ShowBIP39Screen(
                  mnemonic: '',
                ),
            PinCodeScreen.routeName: (ctx) =>
                PinCodeScreen(
                  flow: PinCodeFlow.create,
                ),
            SettingsAboutScreen.routeName: (ctx) => SettingsAboutScreen(),
            ShowLogsScreen.routeName: (ctx) => ShowLogsScreen(),
            ShowLogDetailScreen.routeName: (ctx) =>
                ShowLogDetailScreen(
                  block: Block(
                    time: '',
                    logList: BasicLogList(list: []),
                    blockNumber: 0,
                    hash: '',
                    mac: '',
                  ),
                ),
            ShowLogDetail2Screen.routeName: (ctx) => ShowLogDetail2Screen(),
            AdvancedSettingsScreen.routeName: (ctx) => AdvancedSettingsScreen(),
            DiagnosticsScreen.routeName: (ctx) => DiagnosticsScreen(),
            QRCodeView.routeName: (ctx) =>
                QRCodeView(
                  data: 'testing',
                  isDarkModeEnabled: true,
                  isEncrypted: false,
                ),
            RecoveryModeScreen.routeName: (ctx) => RecoveryModeScreen(),
            AddKeyItemScreen.routeName: (ctx) => AddKeyItemScreen(),
            WelcomeAllListScreen.routeName: (ctx) => WelcomeAllListScreen(),
            ActiveEncryptionScreen.routeName: (ctx) =>
                ActiveEncryptionScreen(
                  peerId: '',
                ),
            AddPublicEncryptionKeyScreen.routeName: (ctx) =>
                AddPublicEncryptionKeyScreen(),
            EditPublicEncryptionKeyScreen.routeName: (ctx) =>
                EditPublicEncryptionKeyScreen(
                  id: "",
                ),
            PeerPublicKeyListScreen.routeName: (ctx) =>
                PeerPublicKeyListScreen(
                  id: "",
                ),
            // PeerMessagesScreen.routeName: (ctx) =>
            //     PeerMessagesScreen(
            //       peerKeyItem: null,
            //       keyItem: null,
            //       myPrivateKey: [],
            //     ),
            AddPeerPublicKeyScreen.routeName: (ctx) =>
                AddPeerPublicKeyScreen(
                  keyItem: KeyItem(
                    id: "",
                    keyId: "",
                    version: 0,
                    name: "",
                    keys: Keys(privX: "", privS: "", privK: ""),
                    keyType: "",
                    purpose: "",
                    algo: "",
                    notes: "",
                    favorite: false,
                    isBip39: true,
                    peerPublicKeys: [],
                    tags: [],
                    mac: "",
                    cdate: "",
                    mdate: "",
                  ),
                ),
            ReKeyAuthScreen.routeName: (ctx) => ReKeyAuthScreen(),
          },
          builder: EasyLoading.init(),
        ),
      );
    },
      themeCollection: ThemeCollection(
          fallbackTheme: ThemeData(
            useMaterial3: AppConstants.useMaterial3,
            brightness: Brightness.dark,
          ),
          themes: {
            0: ThemeData(
              useMaterial3: AppConstants.useMaterial3,
              brightness: Brightness.light,
            ),
            1: ThemeData(
              useMaterial3: AppConstants.useMaterial3,
              brightness: Brightness.dark,
            ),
          }
      ),);


  // ThemeData themeData() {
  //   // bool isDarkMode = (_settingsManager?.isDarkModeEnabled)!;
  //   // var themeColor = isDarkMode ? Colors.black87 : Colors.blueAccent;
  //   return ThemeData(
  //     useMaterial3: false,
  //     brightness: _settingsManager.isDarkModeEnabled ? Brightness.dark : Brightness.light,
  //     inputDecorationTheme: InputDecorationTheme(
  //       border: OutlineInputBorder(
  //           borderSide: BorderSide(
  //               color: _settingsManager.isDarkModeEnabled ? Colors.black87 : Colors.blueAccent,
  //           ),
  //       ),
  //       focusedBorder: OutlineInputBorder(
  //           borderSide: BorderSide(
  //               color: _settingsManager.isDarkModeEnabled ? Colors.black87 : Colors.blueAccent,
  //           ),
  //       ),
  //       enabledBorder: OutlineInputBorder(
  //           borderSide: BorderSide(
  //               color: _settingsManager.isDarkModeEnabled ? Colors.black87 : Colors.blueAccent,
  //           ),
  //       ), // this one
  //       // errorBorder: const OutlineInputBorder(
  //       //     borderSide: BorderSide(color: Colors.green)),
  //       // focusedErrorBorder: const OutlineInputBorder(
  //       //     borderSide: BorderSide(color: Colors.green)),
  //       disabledBorder: OutlineInputBorder(
  //           borderSide: BorderSide(
  //               color: _settingsManager.isDarkModeEnabled ? Colors.black87 : Colors.blueAccent,
  //           ),
  //       ),
  //       fillColor: _settingsManager.isDarkModeEnabled ? Colors.black87 : Colors.blueAccent,
  //
  //       // scrollbarTheme: ScrollbarThemeData().copyWith(
  //       //   thumbColor: MaterialStateProperty.all(Colors.grey[500]),
  //       // ),
  //     ),
  //     highlightColor:
  //         _settingsManager.isDarkModeEnabled ? Colors.white : Colors.black,
  //   );
  // }
  }
}
