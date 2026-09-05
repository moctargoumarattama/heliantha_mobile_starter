import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/cart/providers/cart_provider.dart';
import '../../features/favorites/providers/favorites_provider.dart';
import '../models/product.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../utils/api_url.dart';
import '../utils/money.dart';
import 'app_feedback.dart';

class ProductCard extends ConsumerWidget {
  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
  });

  final Product product;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);
    final isFavorite = favorites.contains(product.id);
    final price = formatMoney(
      product.price,
      currency: product.currency,
      symbol: product.currencySymbol,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.soft,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Container(
                          clipBehavior: Clip.antiAlias,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(AppRadii.md),
                          ),
                          child: _ProductCardImage(imageUrl: product.imageUrl),
                        ),
                      ),
                      Positioned(
                        right: 7,
                        top: 7,
                        child: _RoundIconButton(
                          tooltip: isFavorite
                              ? 'Retirer des favoris'
                              : 'Ajouter aux favoris',
                          icon: isFavorite
                              ? Icons.favorite
                              : Icons.favorite_border_rounded,
                          color: isFavorite ? AppColors.danger : AppColors.navy,
                          onPressed: () {
                            ref
                                .read(favoritesProvider.notifier)
                                .toggle(product.id);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w800,
                        height: 1.22,
                      ),
                ),
                const SizedBox(height: 7),
                Text(
                  price,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.blue,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final canShowStatus = width >= 88;
                    final showStatusLabel = width >= 138;

                    if (!canShowStatus) {
                      return Align(
                        alignment: Alignment.centerRight,
                        child: _CartButton(
                          enabled: product.available,
                          onPressed: () => _addToCart(context, ref),
                        ),
                      );
                    }

                    return Row(
                      children: [
                        Expanded(
                          child: _AvailabilityPill(
                            available: product.available,
                            showLabel: showStatusLabel,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _CartButton(
                          enabled: product.available,
                          onPressed: () => _addToCart(context, ref),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _addToCart(BuildContext context, WidgetRef ref) {
    ref.read(cartProvider.notifier).add(product);
    AppFeedback.success(
      context,
      'Ajouté au panier',
      action: SnackBarAction(
        label: 'Voir',
        onPressed: () => context.go('/cart'),
      ),
    );
  }
}

class _AvailabilityPill extends StatelessWidget {
  const _AvailabilityPill({
    required this.available,
    required this.showLabel,
  });

  final bool available;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final color = available ? AppColors.leaf : AppColors.danger;
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: available ? AppColors.softLeaf : const Color(0xFFFFEFEF),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            available ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 14,
            color: color,
          ),
          if (showLabel) ...[
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                available ? 'En stock' : 'Rupture',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProductCardImage extends StatelessWidget {
  const _ProductCardImage({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = absoluteApiUrl(imageUrl);
    if (url.isEmpty) {
      return const _FallbackProductImage();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Transform.scale(
        scale: 1.00,
        child: kIsWeb
            ? Image.network(
                url,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                headers: const {'Accept': 'image/*'},
                loadingBuilder: (context, child, progress) {
                  if (progress == null) {
                    return child;
                  }
                  return const _ImageLoading();
                },
                errorBuilder: (_, __, ___) => const _FallbackProductImage(),
              )
            : CachedNetworkImage(
                imageUrl: url,
                httpHeaders: const {'Accept': 'image/*'},
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                placeholder: (_, __) => const _ImageLoading(),
                errorWidget: (_, __, ___) => const _FallbackProductImage(),
              ),
      ),
    );
  }
}

class _ImageLoading extends StatelessWidget {
  const _ImageLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox.square(
        dimension: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _CartButton extends StatelessWidget {
  const _CartButton({
    required this.enabled,
    required this.onPressed,
  });

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 38,
      child: IconButton.filled(
        tooltip: 'Ajouter au panier',
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          backgroundColor: enabled ? AppColors.blue : AppColors.border,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.border,
          disabledForegroundColor: AppColors.muted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
        ),
        onPressed: enabled ? onPressed : null,
        icon: const Icon(Icons.add_shopping_cart_rounded, size: 19),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 34,
      child: IconButton(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 19),
      ),
    );
  }
}

class _FallbackProductImage extends StatelessWidget {
  const _FallbackProductImage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.solar_power_rounded,
        size: 54,
        color: AppColors.blue,
      ),
    );
  }
}
