import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppSpacing {
  const AppSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 28.0;
}

class AppRadii {
  const AppRadii._();

  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 18.0;
}

class AppShadows {
  const AppShadows._();

  static List<BoxShadow> get soft => [
        BoxShadow(
          color: AppColors.navy.withValues(alpha: 0.06),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ];
}
