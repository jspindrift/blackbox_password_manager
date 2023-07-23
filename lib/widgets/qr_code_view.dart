/*
 * QR.Flutter
 * Copyright (c) 2019 the QR.Flutter authors.
 * See LICENSE for distribution and usage details.
 */

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../managers/LogManager.dart';

/// This is the screen that you'll see when the app starts
class QRCodeView extends StatefulWidget {
  const QRCodeView({
    Key? key,
    required this.data,
    required this.isDarkModeEnabled,
    required this.isEncrypted,
  }) : super(key: key);
  static const routeName = '/qr_code_view';

  final String data;
  final bool isDarkModeEnabled;
  final bool isEncrypted;

  @override
  _QRCodeViewState createState() => _QRCodeViewState();
}

class _QRCodeViewState extends State<QRCodeView> {
  // ignore: lines_longer_than_80_chars ??
  // final message = 'Hey this is a QR code. Change this value in the main_screen.dart file. Hey this is a QR code. Change this value in the main_screen.dart file. Hey this is a QR code. Change this value in the main_screen.dart file.';

  final logManager = LogManager();

  @override
  void initState() {
    super.initState();

    logManager.log("QRCodeView", "initState", "initState");
  }

  @override
  Widget build(BuildContext context) {
    var headerText =
        "Open the Blackbox app and scan this code.\n\nThis QR Code is not secure (unencrypted).";
    if (widget.isEncrypted) {
      headerText =
          "Open the Blackbox app and scan this code.\n\nThis QR Code is secure (encrypted).";
    }
    final qrFutureBuilder = FutureBuilder<ui.Image>(
      future: _loadOverlayImage(),
      builder: (ctx, snapshot) {
        final size = 280.0;
        if (!snapshot.hasData) {
          return Container(width: size, height: size);
        }
        return CustomPaint(
          size: Size.square(size),
          painter: QrPainter(
            data: widget.data,
            version: QrVersions.auto,
            eyeStyle: QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color:
                  widget.isDarkModeEnabled ? Colors.greenAccent : Colors.black,
            ),
            dataModuleStyle: QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.circle,
              color:
                  widget.isDarkModeEnabled ? Colors.greenAccent : Colors.black,
            ),
            // size: 320.0,
            embeddedImage: snapshot.data,
            embeddedImageStyle: QrEmbeddedImageStyle(
              size: Size.square(1),
            ),
          ),
        );
      },
    );

    return Material(
      color: widget.isDarkModeEnabled ? Colors.black : Colors.white,
      child: SafeArea(
        top: true,
        bottom: true,
        child: Container(
          color: widget.isDarkModeEnabled ? Colors.black : Colors.white,
          child: Column(
            children: <Widget>[
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  headerText,
                  style: TextStyle(
                    color: widget.isDarkModeEnabled
                        ? Colors.greenAccent
                        : Colors.black,
                    fontSize: 16,
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Container(
                    width: 280,
                    child: qrFutureBuilder,
                  ),
                ),
              ),
              // Padding(
              //   padding: EdgeInsets.symmetric(vertical: 10, horizontal: 40)
              //       .copyWith(bottom: 40),
              //   child: Text(
              //       widget.data,
              //     style: TextStyle(
              //       color: Colors.greenAccent,
              //       fontSize: 14,
              //     ),
              //   ),
              // ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: widget.isDarkModeEnabled
                      ? BorderSide(color: Colors.greenAccent)
                      : null,
                ),
                child: Text(
                  "Close",
                  style: TextStyle(
                    color: widget.isDarkModeEnabled
                        ? Colors.greenAccent
                        : Colors.blue,
                    fontSize: 20,
                  ),
                ),
                onPressed: () {
                  logManager.log(
                      "QRCodeView", "CloseButton:onPressed", "close");

                  Navigator.of(context).pop();
                },
              ),
              SizedBox(
                height: 44,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<ui.Image> _loadOverlayImage() async {
    final completer = Completer<ui.Image>();
    final byteData = await rootBundle.load('assets/icons8-face-id-grey-64.png');
    ui.decodeImageFromList(byteData.buffer.asUint8List(), completer.complete);
    return completer.future;
  }
}
