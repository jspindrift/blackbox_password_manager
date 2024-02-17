// import 'dart:convert';
// import 'dart:io';
//
// import 'package:blackbox_password_manager/managers/Cryptor.dart';
// import 'package:blackbox_password_manager/managers/KeychainManager.dart';
// import 'package:blackbox_password_manager/models/WOTSSignatureItem.dart';
// import 'package:convert/convert.dart';
// import 'package:cryptography/cryptography.dart';
// import 'package:enum_to_string/enum_to_string.dart';
// import 'package:flutter_easyloading/flutter_easyloading.dart';
// import 'package:intl/intl.dart';
// import 'package:flutter/material.dart';
//
// import '../helpers/AppConstants.dart';
// import '../models/EncryptedPeerMessage.dart';
// import '../models/GenericItem.dart';
// import '../screens/show_log_detail_screen.dart';
// import '../models/KeyItem.dart';
// import '../managers/LogManager.dart';
// // import '../managers/FileManager.dart';
// import '../managers/SettingsManager.dart';
//
//
// class PeerMessagesScreen extends StatefulWidget {
//   const PeerMessagesScreen({
//     Key? key,
//     PeerPublicKey? this.peerKeyItem,
//     KeyItem? this.keyItem,
//     List<int>? this.myPrivateKey,
//   }) : super(key: key);
//   static const routeName = '/peer_messages_screen';
//
//   final PeerPublicKey? peerKeyItem;
//   final KeyItem? keyItem;
//   final List<int>? myPrivateKey;
//
//   @override
//   State<PeerMessagesScreen> createState() => _PeerMessagesScreenState();
// }
//
// class _PeerMessagesScreenState extends State<PeerMessagesScreen> {
//
//   List<dynamic> _sentMessageList = [];
//   List<dynamic> _receivedMessageList = [];
//   List<dynamic> _sentMessageHashList = [];
//
//   List<int> _peerPublicKey = [];
//   List<int> _myPublicKey = [];
//
//   GenericMessageList? _receivedMessages;
//   GenericMessageList? _sentMessages;
//
//   List<dynamic> _receivedMessageHashList = [];
//   List<dynamic> _messageList = [];
//
//
//   bool _isDarkModeEnabled = false;
//   String _peerKeyName = "";
//   String _decryptedMainKeyName = "";
//   List<int> _peerPublicKeyX = [];
//   List<int> _myPublicKeyX = [];
//
//   String _myPublicKeyXAddress = "";
//   String _peerPublicKeyXAddress = "";
//
//   String _fromAddr = "";
//   String _toAddr = "";
//
//   List<int> _Kenc = [];
//   List<int> _Kauth = [];
//
//   /// sender (this user)
//   List<int> _Kenc_send = [];
//   List<int> _Kauth_send = [];
//
//   /// reciever (peer)
//   List<int> _Kenc_rec = [];
//   List<int> _Kauth_rec = [];
//
//   List<int> _Kwots = [];
//   List<int> _Kwots_send = [];
//
//   late ScrollController _controller = ScrollController();
//
//   final algorithm_exchange = X25519();
//
//
//   final _logManager = LogManager();
//   final _settingsManager = SettingsManager();
//   final _cryptor = Cryptor();
//   final _keyManager = KeychainManager();
//
//
//   @override
//   void initState() {
//     super.initState();
//
//     _logManager.log("PeerMessagesScreen", "initState", "initState");
//
//     _isDarkModeEnabled = _settingsManager.isDarkModeEnabled;
//
//     _generateKey();
//
//     // _buildMessageList();
//   }
//
//   _generateKey() async {
//
//     try {
//       // _logManager.logger.d("privX: ${widget.keyItem!.keys.privX!}");
//       final decryptedPrivX = await _cryptor.decrypt(widget.keyItem!.keys.privX!);
//       // _logManager.logger.d("decryptedPrivX: ${decryptedPrivX}");
//
//       final ownerKeyPair = await algorithm_exchange.newKeyPairFromSeed(base64.decode(decryptedPrivX));
//       final mainPublicKey = await ownerKeyPair.extractPublicKey();
//       // _myPublicKey = mainPublicKey.bytes;
//
//       final decryptedName = await _cryptor.decrypt(widget.peerKeyItem!.name);
//
//       setState(() {
//         _myPublicKey = mainPublicKey.bytes;
//         _peerKeyName = decryptedName;
//       });
//
//       var peerPublicKeyXEncoded = await _cryptor.decrypt(
//           widget.peerKeyItem!.pubKeyX,
//       );
//
//       _peerPublicKeyX = base64.decode(peerPublicKeyXEncoded);
//       final peerPubHash = _cryptor.sha256(hex.encode(_peerPublicKeyX));
//
//       // setState(() {
//         _peerPublicKeyXAddress =  peerPubHash.substring(0,40);
//       // });
//
//       final name = await _cryptor.decrypt(widget.keyItem!.name);//.then((value) {
//       _logManager.logger.d("name: ${name}");
//
//       setState(() {
//         _decryptedMainKeyName = name;
//       });
//
//       if (_peerPublicKeyX == null) {
//         _logManager.logger.wtf("keydata.privX == null");
//         return;
//       }
//
//       await _generatePeerKeyPair();
//
//     } catch (e) {
//       _logManager.logger.e("exception: ${e}");
//     }
//   }
//
//   Future<void> _generatePeerKeyPair() async {
//     if (widget.keyItem == null
//         && widget.myPrivateKey != null
//         && widget.peerKeyItem == null) {
//       return;
//     }
//
//     final ownerKeyPair = await algorithm_exchange.newKeyPairFromSeed(widget.myPrivateKey!);
//
//     // final privKey = await ownerKeyPair.extractPrivateKeyBytes();
//     // print("privKeyBytes: ${privKey.length}: ${privKey}");
//
//     final mainPublicKey = await ownerKeyPair.extractPublicKey();
//     _myPublicKeyX = mainPublicKey.bytes;
//
//     final pubhash = _cryptor.sha256(hex.encode(_myPublicKeyX));
//     _myPublicKeyXAddress = pubhash.substring(0,40);
//
//     // print("_mainPublicKey: ${_mainPublicKey.length}: ${_mainPublicKey}");
//     // print("_mainPublicKeyHex: ${_mainPublicKey.length}: ${hex.encode(_mainPublicKey)}");
//
//     final peerSimplePublicKey = SimplePublicKey(_peerPublicKeyX, type: KeyPairType.x25519);
//     final peerPubKeyBytes = peerSimplePublicKey.bytes;
//
//     final sharedSecret = await algorithm_exchange.sharedSecretKey(
//       keyPair: ownerKeyPair,
//       remotePublicKey: peerSimplePublicKey,
//     );
//
//     final sharedSecretBytes = await sharedSecret.extractBytes();
//     // print('Shared secret: $sharedSecretBytes');
//     // print('Shared secret hex: ${hex.encode(sharedSecretBytes)}');
//
//     // final sharedSecretKeyHash = await _cryptor.sha256(hex.encode(sharedSecretBytes));
//     // print("shared secret key hash: ${sharedSecretKeyHash}");
//
//     final expanded = await _cryptor.expandKey(sharedSecretBytes);
//     // print('Shared secret expanded: $expanded');
//     _Kenc = expanded.sublist(0, 32);
//     _Kauth = expanded.sublist(32, 64);
//     // print('secret _Kenc: ${hex.encode(_Kenc)}');
//     // print('secret _Kauth: ${hex.encode(_Kauth)}');
//
//     /// set public key values
//     final mainPubSecretKey = SecretKey(_myPublicKeyX);
//     final bobPubSecretKey = SecretKey(peerPubKeyBytes);
//
//     final hmac = Hmac.sha256();
//     final mac_e_receive = await hmac.calculateMac(
//       _Kenc,
//       secretKey: mainPubSecretKey!,
//     );
//
//     final mac_e_send = await hmac.calculateMac(
//       _Kenc,
//       secretKey: bobPubSecretKey!,
//     );
//
//     final Kwots_send = await hmac.calculateMac(
//       _Kwots,
//       secretKey: bobPubSecretKey!,
//     );
//
//     _Kenc_rec = mac_e_receive.bytes;
//     _Kenc_send = mac_e_send.bytes;
//
//     /// now do auth send/recieve keys
//     final mac_auth_receive = await hmac.calculateMac(
//       _Kauth,
//       secretKey: mainPubSecretKey!,
//     );
//
//     final mac_auth_send = await hmac.calculateMac(
//       _Kauth,
//       secretKey: bobPubSecretKey!,
//     );
//
//     _Kauth_rec = mac_auth_receive.bytes;
//     _Kauth_send = mac_auth_send.bytes;
//     _Kwots_send = Kwots_send.bytes;
//     // _logManager.logger.d("_Kwots_send: ${hex.encode(_Kwots_send)}");
//
//     final toAddr = _cryptor.sha256(hex.encode(_peerPublicKeyX)).substring(0, 40);
//     final fromAddr = _cryptor.sha256(hex.encode(_myPublicKeyX)).substring(0,40);
//
//     // setState(() {
//       _fromAddr = fromAddr;
//       _toAddr = toAddr;
//     // });
//
//     /// Generate WOTS private and pub keys
//     ///
//     // if (_debugTestWots) {
//     //   // await _wotsManager.createSimpleOverlapTopPubKey(_Kwots_send, 1);
//     // }
//
//     if (AppConstants.debugKeyData) {
//       _logManager.logger.d('secret _Kenc_recec: ${hex.encode(_Kenc_rec)}');
//       _logManager.logger.d('secret _Kenc_sendend: ${hex.encode(_Kenc_send)}');
//       _logManager.logger.d('secret _Kauth_recec: ${hex.encode(_Kauth_rec)}');
//       _logManager.logger.d('secret _Kauth_sendend: ${hex.encode(_Kauth_send)}');
//     }
//
//     _buildMessageList();
//
//     setState(() {
//
//     });
//
//   }
//
//   _buildMessageList() async {
//     final item = widget.peerKeyItem;
//     final receivedMessages = item?.receivedMessages!.list;
//     final sentMessages = item?.sentMessages!.list;
//
//     _receivedMessages = item!.receivedMessages!;
//     _sentMessages = item!.sentMessages!;
//
//     /// check against the from and to address
//     // final toAddr = _cryptor.sha256(base64.encode(_peerPublicKey)).substring(0, 40);
//     // final fromAddr = _cryptor.sha256(base64.encode(_mainPublicKey)).substring(0,40);
//     final peerAddr = _cryptor.sha256(hex.encode(_peerPublicKeyX)).substring(0, 40);
//     final myAddr = _cryptor.sha256(hex.encode(_myPublicKeyX)).substring(0, 40);
//
//     var isWots = false;
//
//     var baseMessageData;
//     /// decode received messages
//     for (var message in receivedMessages!) {
//       _logManager.logger.d("wotsSignature: ${message.data}");
//
//       var thisMessage;
//       var isWots = false;
//       var wotsSignature;
//       try {
//         switch (message.type) {
//           case "plain":
//             thisMessage = PlaintextPeerMessage.fromRawJson(message.data);
//             break;
//           case "encrypted"://MessageType.encrypted:
//             thisMessage = EncryptedPeerMessage.fromRawJson(message.data);
//             break;
//           case "encryptedMesh"://MessageType.encryptedMesh:
//             thisMessage = EncryptedMeshPeerMessage.fromRawJson(message.data);
//             break;
//           case "wotsPlain"://MessageType.wotsPlain:
//             isWots = true;
//             thisMessage = PlaintextPeerMessage.fromRawJson(message.data);
//             isWots = true;
//             break;
//           case "wotsEncrypted"://MessageType.wotsEncrypted:
//             isWots = true;
//             thisMessage = EncryptedPeerMessage.fromRawJson(message.data);
//             isWots = true;
//             break;
//           case "wotsEncryptedMesh"://MessageType.wotsEncryptedMesh:
//             wotsSignature = GigaWOTSSignatureItem.fromRawJson(message.data);
//             final Hm = _cryptor.sha256(wotsSignature.toRawJson());
//             _logManager.logger.d("R: wotsSignature Hm:${Hm}");
//             isWots = true;
//             _logManager.logger.d("R: wotsSignature: ${wotsSignature.message.toRawJson()}");
//             // var data = WOTSMessageData.fromRawJson(wotsSignature.message.data);
//             thisMessage =  EncryptedWotsMeshPeerMessage.fromRawJson(wotsSignature.message.data);
//             // thisMessage =  EncryptedWotsMeshPeerMessage.fromRawJson(wotsSignature.message.data);
//             // _logManager.logger.d("wotsSignature: ${wotsSignature.toRawJson()}");
//             _logManager.logger.d("R: baseMessageData: ${thisMessage.toRawJson()}");
//             break;
//           case "unknown"://MessageType.unknown:
//             thisMessage = EncryptedPeerMessage.fromRawJson(message.data);
//             break;
//         }
//       } catch (e) {
//         _logManager.logger.e("Exception: $e");
//         continue;
//       }
//
//       if (wotsSignature != null) {
//         _receivedMessageList.add(wotsSignature);
//       } else {
//         _receivedMessageList.add(thisMessage);
//       }
//
//       var messageToAddr; // = thisMessage.to;
//       var messageFromAddr; // = thisMessage.from;
//
//       // if (isWots) {
//       //   messageToAddr = baseMessageData.to;
//       //   messageFromAddr = baseMessageData.from;
//       // } else {
//         messageToAddr = thisMessage.to;
//         messageFromAddr = thisMessage.from;
//       // }
//
//       var Kuse_e = _Kenc_rec;
//       var Kuse_a = _Kauth_rec;
//
//       var isOwnMessage = false;
//       if (messageToAddr == myAddr) {
//         Kuse_e = _Kenc_rec;
//         Kuse_a = _Kauth_rec;
//       }
//       else if (messageToAddr == peerAddr) {
//         isOwnMessage = true;
//         Kuse_e = _Kenc_send;
//         Kuse_a = _Kauth_send;
//       }
//       // _logManager.logger.d("Kuse_e: ${Kuse_e}, Kuse_a: ${Kuse_a}");
//
//       _logManager.logger.d("myAddr: ${myAddr}, peerAddr: ${peerAddr}");
//       _logManager.logger.d("received[$isOwnMessage]:\nmessageFromAddr: ${messageFromAddr}\nmessageToAddr: ${messageToAddr}");
//
//       _logManager.logger.d("thisMessage: ${thisMessage.toJson()}");
//
//       // final macToCheck = isWots ? baseMessageData.mac : thisMessage.mac;
//       final macToCheck = thisMessage.mac;
//
//       //   baseMessageData.mac = "";
//       // } else {
//         thisMessage.mac = "";
//       // }
//
//       // var newWotsMsgObj;
//       // GigaWOTSSignatureItem? wotsSignatureUpgraded;
//       // if (isWots) {
//       //   newWotsMsgObj = WOTSMessageData(
//       //     messageIndex: wotsSignature.message.messageIndex,
//       //     previousHash: wotsSignature.message.previousHash,
//       //     publicKey: wotsSignature.message.publicKey,
//       //     nextPublicKey: wotsSignature.message.nextPublicKey,
//       //     data: thisMessage.toRawJson(),
//       //   );
//       //
//       //   wotsSignatureUpgraded = GigaWOTSSignatureItem(
//       //     id: wotsSignature.id,
//       //     signature: wotsSignature.signature,
//       //     checksum: wotsSignature.checksum,
//       //     message: newWotsMsgObj,
//       //   );
//       //
//       // }
//
//       GenericPeerMessage? genericMessage;
//       if (isWots) {
//        genericMessage = GenericPeerMessage(
//           type: MessageType.wotsEncryptedMesh.name,
//           data: thisMessage.toRawJson(),
//         );
//       } else {
//         genericMessage = GenericPeerMessage(
//           type: MessageType.encryptedMesh.name,
//           data: thisMessage.toRawJson(),
//         );
//       }
//
//
//
//       final msg_hash = _cryptor.sha256(genericMessage.toRawJson());
//       print("msg_rec_hash: ${msg_hash}");
//       _receivedMessageHashList.add(msg_hash);
//
//       final msgRecHashKey = SecretKey(hex.decode(msg_hash));
//
//       final hmac = Hmac.sha256();
//       final computedMac = await hmac.calculateMac(
//         Kuse_a,
//         secretKey: msgRecHashKey!,
//       );
//
//       _logManager.logger.w("$macToCheck == ${base64.encode(computedMac.bytes)}");
//
//       if (macToCheck != base64.encode(computedMac.bytes)) {
//         _logManager.logger.w("MACs DO NOT Equal!!");
//         return;
//       }
//
//       thisMessage.mac = macToCheck;
//
//       /// need to decrypt with shared secret key
//       final decryptedMessage = await _cryptor.decryptWithKey(Kuse_e, Kuse_a, thisMessage.message);
//
//       if (decryptedMessage == null) {
//         // setState(() {
//         //   _didEncrypt = false;
//         //   _hasEmbeddedMessageObject = false;
//         //   _didDecryptSuccessfully = false;
//         // });
//         return;
//       }
//
//       thisMessage.message = decryptedMessage;
//
//       _messageList.add(thisMessage);
//     }
//
//
//     var wotsSignature;
//     /// decode sent messages
//     for (var message in sentMessages!) {
//       // _logManager.logger.d("message: ${message.data}");
//
//       var thisMessage;
//       try {
//         // _logManager.logger.d("message.type:${message.type}");
//         switch (message.type) {
//           case "plain":
//             thisMessage = PlaintextPeerMessage.fromRawJson(message.data);
//             break;
//           case "encrypted"://MessageType.encrypted:
//             thisMessage = EncryptedPeerMessage.fromRawJson(message.data);
//             break;
//           case "encryptedMesh"://MessageType.encryptedMesh:
//             thisMessage = EncryptedMeshPeerMessage.fromRawJson(message.data);
//             break;
//           case "wotsPlain"://MessageType.wotsPlain:
//             isWots = true;
//             thisMessage = PlaintextPeerMessage.fromRawJson(message.data);
//             break;
//           case "wotsEncrypted"://MessageType.wotsEncrypted:
//             isWots = true;
//             thisMessage = EncryptedPeerMessage.fromRawJson(message.data);
//             break;
//           case "wotsEncryptedMesh"://MessageType.wotsEncryptedMesh:
//             isWots = true;
//             wotsSignature = GigaWOTSSignatureItem.fromRawJson(message.data);
//             final Hm = _cryptor.sha256(wotsSignature.toRawJson());
//             // var encoder = new JsonEncoder.withIndent("     ");
//             // final prettySig = encoder.convert(wotsSignature);
//
//             // getPrettyJSONString();
//             _logManager.logger.d("S: wotsSignature Hm:${Hm}");
//             // var data = WOTSMessageData.fromRawJson(wotsSignature.message.data);
//             // thisMessage = wotsSignature.message;
//             thisMessage =  EncryptedWotsMeshPeerMessage.fromRawJson(wotsSignature.message.data);
//             // _logManager.logger.d("wotsSignature: ${wotsSignature.toRawJson()}");
//             // _logManager.logger.d("thisMessage: ${thisMessage.toRawJson()}");
//
//             break;
//           case "unknown"://MessageType.unknown:
//           thisMessage = EncryptedPeerMessage.fromRawJson(message.data);
//           break;
//         }
//       } catch (e) {
//         _logManager.logger.e("Exception: $e");
//         continue;
//       }
//
//       _sentMessageList.add(thisMessage);
//
//       // _logManager.logger.d("thisMessage: ${thisMessage.toJson()}");
//
//       // final messageToAddr = thisMessage.to;
//       // final messageFromAddr = thisMessage.from;
//
//       // final mac_msg_bytes = base64.decode(messageItem.mac);
//       final messageToAddr = thisMessage.to;
//       final messageFromAddr = thisMessage.from;
//       _logManager.logger.d("sent:\nmessageFromAddr: ${messageFromAddr}\nmessageToAddr: ${messageToAddr}");
//
//       var Kuse_e = _Kenc_send;
//       var Kuse_a = _Kauth_send;
//
//       // var isOwnMessage = false;
//       // if (messageToAddr == myAddr) {
//       //   Kuse_e = _Kenc_rec;
//       //   Kuse_a = _Kauth_rec;
//       // } else if (messageFromAddr == peerAddr) {
//       //   isOwnMessage = true;
//       //   Kuse_e = _Kenc_send;
//       //   Kuse_a = _Kauth_send;
//       // }
//
//
//       // _logManager.logger.d("fromAddr: ${fromAddr}, toAddr: ${toAddr}");
//       // _logManager.logger.d("messageFromAddr: ${messageFromAddr}, messageToAddr: ${messageToAddr}");
//
//       // _logManager.logger.d("thisMessage: ${thisMessage.toJson()}");
//
//       final macToCheck = thisMessage.mac;
//       thisMessage.mac = "";
//       GenericPeerMessage genericMessage = GenericPeerMessage(
//         type: message.type,
//         data: thisMessage.toRawJson(),
//       );
//       // print("msg_rec_hash: ${genericMessage}");
//
//       final msg_hash = _cryptor.sha256(genericMessage.toRawJson());
//       // print("msg_rec_hash: ${msg_hash}");
//       _sentMessageHashList.add(msg_hash);
//
//       final msgRecHashKey = SecretKey(hex.decode(msg_hash));
//
//       final hmac = Hmac.sha256();
//       final computedMac = await hmac.calculateMac(
//         Kuse_a,
//         secretKey: msgRecHashKey!,
//       );
//
//       // _logManager.logger.w("$macToCheck == ${base64.encode(computedMac.bytes)}");
//
//       if (macToCheck != base64.encode(computedMac.bytes)) {
//         _logManager.logger.w("MACs DO NOT Equal!!");
//         return;
//       }
//
//       thisMessage.mac = macToCheck;
//
//       /// need to decrypt with shared secret key
//       final decryptedMessage = await _cryptor.decryptWithKey(Kuse_e, Kuse_a, thisMessage.message);
//
//       if (decryptedMessage == null) {
//         // setState(() {
//         //   _didEncrypt = false;
//         //   _hasEmbeddedMessageObject = false;
//         //   _didDecryptSuccessfully = false;
//         // });
//         return;
//       }
//
//       thisMessage.message = decryptedMessage;
//
//       if (isWots) {
//         // wotsSignature
//         // _messageList.add(wotsSignature!);
//         _messageList.add(thisMessage);
//
//       } else {
//         _messageList.add(thisMessage);
//       }
//     }
//
//     /// iterate through messages and build chronological time-based list
//     ///
//     _messageList.sort((a, b) {
//       return isWots ? a.time.compareTo(b.time) : a.message.time.compareTo(b.message.time);
//     });
//
//     final decryptedPeerPublicKey = await _cryptor.decrypt(
//         widget.peerKeyItem!.pubKeyX);
//     // _peerPublicKey = base64.decode(decryptedPeerPublicKey);
//
//     // final decryptedPeerName = await _cryptor.decrypt(widget.peerKeyItem!.name);
//     // _peerKeyName = decryptedPeerName;
//     setState(() {
//       _peerPublicKey = base64.decode(decryptedPeerPublicKey);
//       // _peerKeyName = decryptedPeerName;
//     });
//
//     // final peerAddr = _cryptor.sha256(base64.encode(_peerPublicKey)).substring(0, 40);
//     // final myAddr = _cryptor.sha256(base64.encode(_mainPublicKey)).substring(0,40);
//
//     var rhashList = [];
//     for (var msg in _messageList) {
//       _logManager.logger.d("msg: ${msg.toRawJson().length}: ${msg.toRawJson()}");
//
//       final Hm = _cryptor.sha256(msg.toRawJson());
//       // _logManager.logger.d("hash: ${Hm}");
//
//       final rstate = msg.rstate;
//       final from = msg.from;
//       final to = msg.from;
//
//       _logManager.logger.d("hash: ${Hm}\nrstate: $rstate");
//
//     }
//
//     // for (var m in _messageList) {
//     //   _logManager.logger.d("message: ${m.toJson()}");
//     // }
//
//
//     _doMessageStateSort();
//
//     setState(() {
//
//     });
//
//   }
//
//   _doMessageStateSort() {
//     // _sentMessageList.firstWhere((element) => element.rstate == "");
//
//     // final index = _sentMessageList.indexWhere((element) => element.rstate == _receivedMessageHashList[0]);
//   }
//
//   @override
//   void dispose() {
//     super.dispose();
//   }
//
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: _isDarkModeEnabled ? (Platform.isAndroid ? (AppConstants.useMaterial3 ? Colors.black12 : Colors.black54) : (AppConstants.useMaterial3 ? Colors.black26 : Colors.black54)) : Colors.blue[50],//Colors.grey[100],
//       appBar: AppBar(
//         title: Text("Messages"),
//         automaticallyImplyLeading: false,
//         backgroundColor: _isDarkModeEnabled ? Colors.black54 : null,
//         leading: BackButton(
//           color: _isDarkModeEnabled ? Colors.greenAccent : null,
//           onPressed: () {
//             Navigator.of(context).pop();
//           },
//         ),
//         actions: [
//           Visibility(
//             visible: true,
//             child:
//             IconButton(
//               icon: Icon(
//                   Icons.delete,
//                 color: _isDarkModeEnabled ? Colors.redAccent : Colors.redAccent,
//               ),
//               onPressed: () async {
//                 await _deletePeerMessages();
//               },
//             ),),
//         ],
//       ),
//       body: ListView.separated(
//         separatorBuilder: (context, index) => Divider(
//           color: _isDarkModeEnabled ? Colors.greenAccent : Colors.grey,
//         ),
//         itemCount: _messageList.length,
//         controller: _controller,
//         itemBuilder: (context, index) {
//
//           var source = "Me (${_decryptedMainKeyName})";
//           var isOwnMessage = false;
//           try {
//             if (_messageList[index].to == _myPublicKeyXAddress) {
//               isOwnMessage = true;
//               // if (_messageList[index].from == _peerPublicKeyXAddress) {
//               source = _peerPublicKeyXAddress;
//               source = _peerKeyName;
//             }
//           } catch (e) {
//             if (_messageList[index].message.to == _myPublicKeyXAddress) {
//               isOwnMessage = true;
//               // if (_messageList[index].from == _peerPublicKeyXAddress) {
//               source = _peerPublicKeyXAddress;
//               source = _peerKeyName;
//             }
//           }
//           // _logManager.logger.d("from: ${_messageList[index].from}");
//           // _logManager.logger.d("to: ${_messageList[index].to}");
//           //
//           // _logManager.logger.d("me: ${_myPublicKeyXAddress}");
//           // _logManager.logger.d("peer: ${_peerPublicKeyXAddress}");
//           return ListTile(
//             title: Text(
//               "from: $source\ntime:${DateFormat('yyyy-MM-dd  hh:mm a').format(DateTime.parse(_messageList[index].time))}",
//               // "from: ${_messageList[index].from}\nTo: ${_messageList[index].to}",
//               style: TextStyle(
//                 color: _isDarkModeEnabled ? Colors.white : null,
//               ),
//             ),
//             subtitle: Text(
//               "message: ${_messageList[index].message}",
//               style: TextStyle(
//                 color: _isDarkModeEnabled ? Colors.white : null,
//               ),
//             ),
//             leading: Icon(
//                 Icons.person,
//               color: isOwnMessage ? Colors.redAccent : Colors.greenAccent,
//             ),
//             onTap: () {
//               // nothing
//             },
//           );
//         },
//       ),
//     );
//   }
//
//   String getPrettyJSONString(jsonObject){
//     var encoder = new JsonEncoder.withIndent("     ");
//     return encoder.convert(jsonObject);
//   }
//
//   Future<void> _deletePeerMessages() async {
//     if (widget.keyItem != null && widget.peerKeyItem != null) {
//
//       final timestamp = DateTime.now().toIso8601String();
//
//       PeerPublicKey newPeerPublicKey = PeerPublicKey(
//         id: widget.peerKeyItem!.id,
//         version: AppConstants.peerPublicKeyItemVersion,
//         name: (widget.peerKeyItem!.name)!,
//         pubKeyX: (widget.peerKeyItem!.pubKeyX)!,
//         pubKeyS: (widget.peerKeyItem!.pubKeyS)!,
//         notes: (widget.peerKeyItem!.notes)!,
//         sentMessages: GenericMessageList(list: []),
//         // TODO: add back in
//         receivedMessages: GenericMessageList(list: []),
//         // TODO: add back in
//         cdate: (widget.peerKeyItem!.cdate)!,
//         mdate: timestamp,
//       );
//
//       var peerIndex = 0;
//       var peerPubKeys = widget.keyItem!.peerPublicKeys;
//       for (var peerKey in widget.keyItem!.peerPublicKeys) {
//         if (peerKey.id == widget.peerKeyItem!.id) {
//           break;
//         }
//         peerIndex++;
//       }
//
//       peerPubKeys.removeAt(peerIndex);
//       peerPubKeys.insert(peerIndex, newPeerPublicKey);
//
//
//       var keyItem = KeyItem(
//         id: widget.keyItem!.id,
//         keyId: widget.keyItem!.keyId,
//         version: AppConstants.keyItemVersion,
//         name: widget.keyItem!.name,
//         keys: widget.keyItem!.keys,
//         keyType: widget.keyItem!.keyType,
//         purpose: widget.keyItem!.purpose,
//         algo: widget.keyItem!.algo,
//         notes: widget.keyItem!.notes,
//         favorite: widget.keyItem!.favorite,
//         isBip39: widget.keyItem!.isBip39,
//         peerPublicKeys: peerPubKeys,
//         tags: widget.keyItem!.tags,
//         mac: "",
//         cdate: widget.keyItem!.cdate,
//         mdate: timestamp,
//       );
//
//       final itemMac = await _cryptor.hmac256(keyItem.toRawJson());
//       keyItem.mac = itemMac;
//
//       final keyItemJson = keyItem.toRawJson();
//       _logManager.logLongMessage("save add peer key keyItem.toRawJson: $keyItemJson");
//
//       final genericItem = GenericItem(type: "key", data: keyItemJson);
//       final genericItemString = genericItem.toRawJson();
//       // _logManager.logger.d("genericItemString: ${genericItemString}");
//
//       /// save key item in keychain
//       ///
//       final status = await _keyManager.saveItem(widget.keyItem!.id, genericItemString);
//
//       if (status) {
//         // await _getItem();
//         EasyLoading.showToast('Saved Peer Message', duration: Duration(seconds: 1));
//         Navigator.of(context).pop("delete");
//       } else {
//         _showErrorDialog('Could not save the item.');
//       }
//
//     }
//   }
//
//   void _showErrorDialog(String message) {
//     showDialog(
//       context: context,
//       builder: (ctx) => AlertDialog(
//         title: Text('An error occured'),
//         content: Text(message),
//         actions: <Widget>[
//           ElevatedButton(
//               onPressed: () {
//                 Navigator.of(ctx).pop();
//               },
//               child: Text('Okay'))
//         ],
//       ),
//     );
//   }
//
// }
