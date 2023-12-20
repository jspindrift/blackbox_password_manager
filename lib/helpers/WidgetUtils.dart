import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';


class WidgetUtils {

  /// custom snack bar
  static showSnackBarCustom(BuildContext context, SnackBar snackBar) {
    /// clear remaining snack bars if we need to show another right after
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  /// default snack bar - shows at bottom of page for 3 seconds
  static showSnackBar(BuildContext context, String messageText) {
    final snackBar = SnackBar(content: Text(messageText), duration: Duration(seconds: 3),);

    /// clear remaining snack bars if we need to show another right after
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  /// shows up at bottom of screen for custom duration
  static showSnackBarDuration(BuildContext context, String messageText, Duration duration) {
    final snackBar = SnackBar(
      content: Text(messageText),
      duration: duration,
    );

    /// clear remaining snack bars if we need to show another right after
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  /// default toast - shows up on center of screen
  static showToastMessage(String message, int seconds) {
    /// dismiss the last toast message if we have multiple
    EasyLoading.dismiss();
    EasyLoading.showToast(message, duration: Duration(seconds: seconds));
  }

}