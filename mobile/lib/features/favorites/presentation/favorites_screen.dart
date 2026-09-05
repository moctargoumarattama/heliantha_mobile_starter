import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/product.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_tokens.dart';
import '../../../shared/utils/api_url.dart';
import '../../../shared/utils/money.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_ui.dart';
import '../../../shared/widgets/brand_widgets.dart';
import '../../catalog/providers/catalog_providers.dart';
import '../providers/favorites_provider.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(favoritesProvider).toList()..sort();

    return Scaffold(
      appBar: const AppTopBar(
        subtitle: 'Vos favoris',
      ),
      body: SafeArea(
        child: ids.isEmpty
            ? ResponsivePagePadding(
                child: AppStatusPanel(
                  icon: Icons.favorite_border_rounded,
                  title: 'Aucun favori',
                  message: 'Ajoutez vos produits solaires préférés ici.',
                  action: FilledButton.icon(
                    onPressed: () => context.go('/catalog'),
                    icon: const Icon(Icons.storefront_rounded),
                    label: const Text('Ouvrir le catalogue'),
                  ),
                ),
              )
            : ListView(
                padding: EdgeInsets.zero,
                children: [
                  ResponsivePagePadding(
                    bottom: 96,
                    child: Column(
                      children: [
                        for (var index = 0; index < ids.length; index++) ...[
                          _FavoriteProductCard(productId: ids[index]),
                          if (index != ids.length - 1)
                            const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _FavoriteProductCard extends ConsumerWidget {
  const _FavoriteProductCard({required this.productId});

  final int productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(productProvider(productId));

    return product.when(
      loading: () => const _FavoriteShell(
        child: SizedBox(
          height: 74,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (_, __) => _FavoriteShell(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.cloud_off_rounded, color: AppColors.danger),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Produit #$productId indisponible',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              IconButton(
                tooltip: 'Retirer',
                onPressed: () {
                  ref.read(favoritesProvider.notifier).toggle(productId);
                },
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
      ),
      data: (item) => _FavoriteProductTile(product: item),
    );
  }
}

class _FavoriteProductTile extends ConsumerWidget {
  const _FavoriteProductTile({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final price = formatMoney(
      product.price,
      currency: product.currency,
      symbol: product.currencySymbol,
    );

    return _FavoriteShell(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: () => context.push('/product/${product.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _FavoriteImage(imageUrl: product.imageUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w900,
                            height: 1.22,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      price,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.blue,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Retirer des favoris',
                onPressed: () {
                  ref.read(favoritesProvider.notifier).toggle(product.id);
                  AppFeedback.info(
                    context,
                    'Retiré des favoris',
                    action: SnackBarAction(
                      label: 'Annuler',
                      onPressed: () {
                        ref.read(favoritesProvider.notifier).toggle(product.id);
                      },
                    ),
                  );
                },
                icon: const Icon(Icons.favorite, color: AppColors.danger),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FavoriteShell extends StatelessWidget {
  const _FavoriteShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      padding: EdgeInsets.zero,
      radius: AppRadii.lg,
      child: child,
    );
  }
}

class _FavoriteImage extends StatelessWidget {
  const _FavoriteImage({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: imageUrl == null
          ? const Icon(Icons.solar_power_rounded, color: AppColors.blue)
          : ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CachedNetworkImage(
                imageUrl: absoluteApiUrl(imageUrl),
                fit: BoxFit.contain,
                errorWidget: (_, __, ___) => const Icon(
                  Icons.solar_power_rounded,
                  color: AppColors.blue,
                ),
              ),
            ),
    );
  }
}
