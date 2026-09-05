import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/navigation_helpers.dart';
import '../../features/cart/providers/cart_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

const helianthaLogoAsset = 'assets/brand/helin.jpeg';

class HelianthaLogo extends StatelessWidget {
  const HelianthaLogo({
    super.key,
    this.size = 44,
    this.padding = 4,
    this.showShadow = false,
  });

  final double size;
  final double padding;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surface, AppColors.surfaceGlow],
        ),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.premiumLine),
        boxShadow: showShadow ? AppShadows.soft : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: Image.asset(
          helianthaLogoAsset,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.solar_power_rounded,
            color: AppColors.blue,
          ),
        ),
      ),
    );
  }
}

class AppTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const AppTopBar({
    super.key,
    required this.subtitle,
    this.showBack = false,
    this.showCart = true,
    this.actions = const [],
    this.backFallbackLocation,
  });

  final String subtitle;
  final bool showBack;
  final bool showCart;
  final List<Widget> actions;
  final String? backFallbackLocation;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBar(
      automaticallyImplyLeading: false,
      flexibleSpace: const _TopBarFinish(),
      shape: const Border(
        bottom: BorderSide(color: AppColors.premiumLine),
      ),
      leading: showBack
          ? IconButton(
              tooltip: 'Retour',
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  final fallback = backFallbackLocation;
                  if (fallback != null) {
                    context.go(fallback);
                  }
                }
              },
              icon: const Icon(Icons.arrow_back_rounded),
            )
          : null,
      title: HelianthaAppBarTitle(subtitle: subtitle),
      actions: [
        ...actions,
        if (showCart) const AppCartButton(),
        const SizedBox(width: 8),
      ],
    );
  }
}

class _TopBarFinish extends StatelessWidget {
  const _TopBarFinish();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surface,
            AppColors.surfaceGlow,
            Color(0xFFF5FBFD),
          ],
        ),
      ),
    );
  }
}

class AppCartButton extends ConsumerWidget {
  const AppCartButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(
      cartProvider.select(
        (items) => items.fold<int>(0, (sum, item) => sum + item.quantity),
      ),
    );

    return IconButton(
      tooltip: 'Panier',
      onPressed: () {
        if (currentLocation(context) == '/cart') {
          return;
        }
        context.push('/cart');
      },
      icon: Badge(
        isLabelVisible: count > 0,
        backgroundColor: AppColors.danger,
        label: Text(count > 9 ? '9+' : '$count'),
        child: const Icon(Icons.shopping_cart_outlined),
      ),
    );
  }
}

class HelianthaAppBarTitle extends StatelessWidget {
  const HelianthaAppBarTitle({
    super.key,
    this.subtitle = "Leader de l'énergie solaire au Maroc",
  });

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: 'Accueil',
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.md),
            onTap: () => context.go('/'),
            child: const HelianthaLogo(size: 38, padding: 3),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'HELIANTHA',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
