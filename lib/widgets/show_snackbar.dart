import 'package:flutter/material.dart';
import 'package:get/get.dart';

void showSnackbar({
  BuildContext? context,
  required String title,
  required String message,
  Color backgroundColor = Colors.black,
  IconData icon = Icons.info,
}) {
  if (context == null) {
    Get.snackbar(
      title,
      message,
      backgroundColor: backgroundColor,
      colorText: Colors.white,
      icon: Icon(icon, color: Colors.white),
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    );
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  message,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
      backgroundColor: backgroundColor,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    ),
  );
}
