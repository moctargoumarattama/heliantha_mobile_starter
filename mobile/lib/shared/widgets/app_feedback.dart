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
        elevation: 0,
        backgroundColor: Colors.transparent,
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        content: _FeedbackToast(
          message: message,
          icon: icon,
          color: color,
          action: action,
        ),
      ),
    );
  }
}

class _FeedbackToast extends StatelessWidget {
  const _FeedbackToast({
    required this.message,
    required this.icon,
    required this.color,
    required this.action,
  });

  final String message;
  final IconData icon;
  final Color color;
  final SnackBarAction? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surface,
            AppColors.surfaceGlow,
            Color(0xFFF6FBFD),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.premiumLine),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadii.sm),
              border: Border.all(color: color.withValues(alpha: 0.18)),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                action!.onPressed();
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.navy,
                backgroundColor: AppColors.softSun,
                minimumSize: const Size(54, 36),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  side: const BorderSide(color: AppColors.premiumLine),
                ),
              ),
              child: Text(action!.label),
            ),
          ],
        ],
      ),
    );
  }
}
