import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

class AppFeedback {
  const AppFeedback._();

  static void success(
    BuildContext context,
    String message, {
    SnackBarAction? action,
  }) {
    _show(context, message, Icons.check_circle_rounded, AppColors.leaf, action);
  }

  static void info(
    BuildContext context,
    String message, {
    SnackBarAction? action,
  }) {
    _show(context, message, Icons.info_outline_rounded, AppColors.blue, action);
  }

  static void warning(BuildContext context, String message) {
    _show(context, message, Icons.warning_amber_rounded, AppColors.sun, null);
  }

  static void error(BuildContext context, String message) {
    _show(
        context, message, Icons.error_outline_rounded, AppColors.danger, null);
  }

  static void _show(
    BuildContext context,
    String message,
    IconData icon,
    Color color,
    SnackBarAction? action,
  ) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.all(14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        action: action,
        content: Row(
          children: [
            Icon(icon, color: color, size: 19),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}
