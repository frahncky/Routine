import 'package:flutter/material.dart';

import 'package:routine/theme/app_semantic_colors.dart';

enum SnackbarVariant { success, error, warning, info, neutral }

double _contrastRatio(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  final lighter =
      firstLuminance > secondLuminance ? firstLuminance : secondLuminance;
  final darker =
      firstLuminance > secondLuminance ? secondLuminance : firstLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}

Color _accessibleForeground(Color background, Color preferred) {
  if (_contrastRatio(background, preferred) >= 4.5) return preferred;

  final blackContrast = _contrastRatio(background, Colors.black);
  final whiteContrast = _contrastRatio(background, Colors.white);
  return blackContrast >= whiteContrast ? Colors.black : Colors.white;
}

void showSnackbar({
  required BuildContext context,
  required String title,
  required String message,
  SnackbarVariant variant = SnackbarVariant.info,
  IconData? icon,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final semantic = Theme.of(context).extension<AppSemanticColors>()!;

  final Color background;
  final Color preferredForeground;
  final IconData defaultIcon;
  switch (variant) {
    case SnackbarVariant.success:
      background = semantic.success;
      preferredForeground = semantic.onSuccess;
      defaultIcon = Icons.check_circle_outline;
      break;
    case SnackbarVariant.error:
      background = semantic.danger;
      preferredForeground = semantic.onDanger;
      defaultIcon = Icons.error_outline;
      break;
    case SnackbarVariant.warning:
      background = semantic.warning;
      preferredForeground = semantic.onWarning;
      defaultIcon = Icons.warning_amber_outlined;
      break;
    case SnackbarVariant.info:
      background = semantic.info;
      preferredForeground = semantic.onInfo;
      defaultIcon = Icons.info_outline;
      break;
    case SnackbarVariant.neutral:
      background = semantic.neutral;
      preferredForeground = semantic.onNeutral;
      defaultIcon = Icons.info_outline;
      break;
  }
  final foreground = _accessibleForeground(background, preferredForeground);

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
                Text(message,
                    style: TextStyle(color: foreground, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
      backgroundColor: background,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
      action: actionLabel != null && onAction != null
          ? SnackBarAction(
              label: actionLabel,
              textColor: foreground,
              onPressed: onAction,
            )
          : null,
    ),
  );
}
