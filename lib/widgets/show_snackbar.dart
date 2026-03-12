import 'package:flutter/material.dart';
import 'package:get/get.dart';




void showSnackbar({
  required String title,
  required String message,
  Color backgroundColor = Colors.black,
  IconData icon = Icons.info,
}) 


{
  Get.snackbar(
    title,
    message,
    snackPosition: SnackPosition.BOTTOM,
    margin: EdgeInsets.all(30),
    backgroundColor: backgroundColor,
    colorText: Colors.black,
    duration: Duration(seconds: 3),
    icon: Icon(icon, color: Colors.white),
  );
}
