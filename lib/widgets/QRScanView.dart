import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

import '../managers/SettingsManager.dart';
import '../managers/LogManager.dart';


class QRScanView extends StatefulWidget {
  const QRScanView({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _QRScanViewState();
}

class _QRScanViewState extends State<QRScanView> {

  bool _isDarkModeEnabled = false;
  bool _hasShownErrorDialog = false;
  bool _scannedCodeAlready = false;

  Barcode? result;
  QRViewController? controller;
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');

  final _settingsManager = SettingsManager();
  final _logManager = LogManager();

  @override
  void initState() {
    super.initState();

    controller?.resumeCamera();

    setState(() {
      _isDarkModeEnabled = _settingsManager.isDarkModeEnabled;
    });
  }

  // In order to get hot reload to work we need to pause the camera if the platform
  // is android, or resume the camera if the platform is iOS.
  @override
  void reassemble() {
    super.reassemble();
    // if (Platform.isAndroid) {
    //   controller!.pauseCamera();
    // }
    controller!.resumeCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Card(
        color: _isDarkModeEnabled ? Colors.black54 : Colors.white,
        child: Column(
        children: <Widget>[
          Expanded(flex: 4, child: _buildQrView(context)),
          Expanded(

            flex: 1,
            child: FittedBox(
              fit: BoxFit.contain,
              child: Column(

                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  // if (result != null)
                  //   Text(
                  //       'Barcode Type: ${describeEnum(result!.format)}   Data: ${result!.code}')
                  // else
                  SizedBox(
                    height: 8,
                  ),
                  Text(
                      'Scan a code',
                    style: TextStyle(
                      color: _isDarkModeEnabled ? Colors.greenAccent : null,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Container(
                        margin: const EdgeInsets.all(8),
                        child: ElevatedButton(
                          style: ButtonStyle(
                              backgroundColor: _isDarkModeEnabled
                                  ? MaterialStateProperty.all<Color>(
                                  Colors.black)
                                  : null,
                          ),
                            onPressed: () async {
                              await controller?.toggleFlash();
                              setState(() {});
                            },
                            child: FutureBuilder(
                              future: controller?.getFlashStatus(),
                              builder: (context, snapshot) {
                                return Text(
                                    'Flash: ${snapshot.data}',
                                  style: TextStyle(
                                    color: _isDarkModeEnabled ? Colors.greenAccent : null,
                                  ),
                                );
                              },
                            ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.all(8),
                        child: ElevatedButton(
                            style: ButtonStyle(
                              backgroundColor: _isDarkModeEnabled
                                  ? MaterialStateProperty.all<Color>(
                                  Colors.black)
                                  : null,
                            ),
                            onPressed: () async {
                              await controller?.flipCamera();
                              setState(() {});
                            },
                            child: FutureBuilder(
                              future: controller?.getCameraInfo(),
                              builder: (context, snapshot) {
                                if (snapshot.data != null) {
                                  return Text(
                                      'Camera facing ${describeEnum(snapshot.data!)}',
                                    style: TextStyle(
                                      color: _isDarkModeEnabled ? Colors.greenAccent : null,
                                    ),
                                  );
                                } else {
                                  return Text(
                                      'loading',
                                    style: TextStyle(
                                      color: _isDarkModeEnabled ? Colors.greenAccent : null,
                                    ),
                                  );
                                }
                              },
                            )),
                      )
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Container(
                        margin: const EdgeInsets.all(8),
                        child: ElevatedButton(
                          style: ButtonStyle(
                            backgroundColor: _isDarkModeEnabled
                                ? MaterialStateProperty.all<Color>(
                                Colors.black)
                                : null,
                          ),
                          onPressed: () async {
                            Navigator.of(context).pop();
                          },
                          child: Text('Close',
                            style: TextStyle(
                              fontSize: 18,
                              color: _isDarkModeEnabled ? Colors.greenAccent : null,
                            ),
                          ),
                        ),
                      ),
                      // Container(
                      //   margin: const EdgeInsets.all(8),
                      //   child: ElevatedButton(
                      //     style: ButtonStyle(
                      //       backgroundColor: _isDarkModeEnabled
                      //           ? MaterialStateProperty.all<Color>(
                      //           Colors.black)
                      //           : null,
                      //     ),
                      //     onPressed: () async {
                      //       await controller?.pauseCamera();
                      //     },
                      //     child: Text('pause',
                      //       style: TextStyle(
                      //         fontSize: 18,
                      //         color: _isDarkModeEnabled ? Colors.greenAccent : null,
                      //       ),
                      //     ),
                      //   ),
                      // ),
                      // Container(
                      //   margin: const EdgeInsets.all(8),
                      //   child: ElevatedButton(
                      //     style: ButtonStyle(
                      //       backgroundColor: _isDarkModeEnabled
                      //           ? MaterialStateProperty.all<Color>(
                      //           Colors.black)
                      //           : null,
                      //     ),
                      //     onPressed: () async {
                      //       await controller?.resumeCamera();
                      //     },
                      //     child: Text('resume',
                      //       style: TextStyle(
                      //         fontSize: 18,
                      //         color: _isDarkModeEnabled ? Colors.greenAccent : null,
                      //       ),
                      //     ),
                      //   ),
                      // ),
                    ],
                  ),
                ],
              ),
            ),
          )
        ],
      ),),
    );
  }

  Widget _buildQrView(BuildContext context) {
    // For this example we check how width or tall the device is and change the scanArea and overlay accordingly.
    var scanArea = (MediaQuery.of(context).size.width < 400 ||
            MediaQuery.of(context).size.height < 400)
        ? 150.0
        : 300.0;
    // To ensure the Scanner view is properly sizes after rotation
    // we need to listen for Flutter SizeChanged notification and update controller
    return QRView(
      key: qrKey,
      onQRViewCreated: _onQRViewCreated,
      overlay: QrScannerOverlayShape(
          borderColor: Colors.red,
          borderRadius: 10,
          borderLength: 30,
          borderWidth: 10,
          cutOutSize: scanArea),
      onPermissionSet: (ctrl, p) => _onPermissionSet(context, ctrl, p),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    setState(() {
      this.controller = controller;
    });

    controller.scannedDataStream.listen((scanData) {
      setState(() {
        result = scanData;
        // _logManager.logger.d("got scanned data: ${scanData.code}");
        // _logManager.logger.d("got scanned data bytes: ${scanData.rawBytes}");
      });

      if (_scannedCodeAlready) {
        return;
      }

      try {
        final qrString = scanData.code!;

        if (qrString.isNotEmpty) {
          _scannedCodeAlready = true;
          Navigator.of(context).pop(qrString);
        } else {
          _showErrorDialog("Invalid code format");
        }
      } catch (e) {
        _logManager.logger.e("Exception: $e");
        _showErrorDialog("Invalid code format");
      }
    });
  }

  void _onPermissionSet(BuildContext context, QRViewController ctrl, bool p) {
    log('${DateTime.now().toIso8601String()}_onPermissionSet $p');
    if (!p) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('no Permission')),
      );
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  void _showErrorDialog(String message) {
    if (_hasShownErrorDialog) {
      return;
    }
    _hasShownErrorDialog = true;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Error"),
        content: Text(message),
        actions: <Widget>[
          ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
              },
              child: Text("Okay"))
        ],
      ),
    );
  }
}
