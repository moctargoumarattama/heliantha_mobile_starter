import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

const helianthaBackgroundAsset = 'assets/brand/fond_arriere_plan.png';

class HelianthaBackground extends StatelessWidget {
  const HelianthaBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: ColoredBox(color: AppColors.background),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: Image.asset(
              helianthaBackgroundAsset,
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.88),
              ),
            ),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}
