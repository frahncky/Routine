import 'package:flutter/material.dart';

import 'package:routine/theme/app_semantic_colors.dart';

enum SnackbarVariant { success, error, warning, info, neutral }

void showSnackbar({
  required BuildContext context,
  required String title,
  required String message,
  SnackbarVariant variant = SnackbarVariant.info,
  IconData? icon,
}) {
  final semantic = Theme.of(context).extension<AppSemanticColors>()!;

  final Color background;
  final Color foreground;
  final IconData defaultIcon;
  switch (variant) {
    case SnackbarVariant.success:
      background = semantic.success;
      foreground = semantic.onSuccess;
      defaultIcon = Icons.check_circle_outline;
      break;
    case SnackbarVariant.error:
      background = semantic.danger;
      foreground = semantic.onDanger;
      defaultIcon = Icons.error_outline;
      break;
    case SnackbarVariant.warning:
      background = semantic.warning;
      foreground = semantic.onWarning;
      defaultIcon = Icons.warning_amber_outlined;
      break;
    case SnackbarVariant.info:
      background = semantic.info;
      foreground = semantic.onInfo;
      defaultIcon = Icons.info_outline;
      break;
    case SnackbarVariant.neutral:
      background = semantic.neutral;
      foreground = semantic.onNeutral;
      defaultIcon = Icons.info_outline;
      break;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(icon ?? defaultIcon, color: foreground, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(message, style: TextStyle(color: foreground, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
      backgroundColor: background,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    ),
  );
}
