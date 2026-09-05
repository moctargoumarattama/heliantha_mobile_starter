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
import '../../cart/providers/cart_provider.dart';
import '../../catalog/providers/catalog_providers.dart';
import '../../favorites/providers/favorites_provider.dart';

class ProductScreen extends ConsumerWidget {
  const ProductScreen({
    super.key,
    required this.productId,
    this.initialProduct,
  });

  final int productId;
  final Product? initialProduct;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(productProvider(productId));

    return Scaffold(
      appBar: const AppTopBar(
        subtitle: 'Détail produit',
        showBack: true,
      ),
      body: productAsync.when(
        loading: () => initialProduct == null
            ? const Center(child: CircularProgressIndicator())
            : _ProductBody(product: initialProduct!),
        error: (_, __) => initialProduct == null
            ? ResponsivePagePadding(
                child: AppStatusPanel(
                  icon: Icons.cloud_off_rounded,
                  title: 'Produit indisponible',
                  message: 'Veuillez réessayer dans quelques instants.',
                  action: OutlinedButton.icon(
                    onPressed: () => ref.invalidate(productProvider(productId)),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Réessayer'),
                  ),
                ),
              )
            : _ProductBody(product: initialProduct!),
        data: (product) => _ProductBody(product: product),
      ),
    );
  }
}

class _ProductBody extends ConsumerWidget {
  const _ProductBody({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);
    final isFavorite = favorites.contains(product.id);
    final price = formatMoney(
      product.price,
      currency: product.currency,
      symbol: product.currencySymbol,
    );
    final description = _cleanText(
      product.descriptionShort?.isNotEmpty == true
          ? product.descriptionShort
          : product.description,
    );

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        ResponsivePagePadding(
          bottom: 96,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 760;
              final image = _ProductImage(
                imageUrl: product.imageUrl,
                height: wide ? 430 : 310,
              );
              final summary = _ProductSummary(
                name: product.name,
                reference: product.reference,
                price: price,
                available: product.available,
                isFavorite: isFavorite,
                onToggleFavorite: () {
                  ref.read(favoritesProvider.notifier).toggle(product.id);
                },
                onAddToCart: () {
                  ref.read(cartProvider.notifier).add(product);
                  AppFeedback.success(
                    context,
                    'Ajouté au panier',
                    action: SnackBarAction(
                      label: 'Voir',
                      onPressed: () => context.go('/cart'),
                    ),
                  );
                },
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: image),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              summary,
                              if (description.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                _TextPanel(
                                  title: 'Description',
                                  text: description,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    )
                  else ...[
                    image,
                    const SizedBox(height: 14),
                    summary,
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _TextPanel(
                        title: 'Description',
                        text: description,
                      ),
                    ],
                  ],
                  if (product.features.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _FeaturesPanel(features: product.features),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({
    required this.imageUrl,
    required this.height,
  });

  final String? imageUrl;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: AppSurface(
        padding: const EdgeInsets.all(14),
        radius: AppRadii.lg,
        child: imageUrl == null
            ? const _ProductImageFallback()
            : ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.sm),
                child: CachedNetworkImage(
                  imageUrl: absoluteApiUrl(imageUrl),
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  errorWidget: (_, __, ___) => const _ProductImageFallback(),
                ),
              ),
      ),
    );
  }
}

class _ProductImageFallback extends StatelessWidget {
  const _ProductImageFallback();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.solar_power_rounded,
        color: AppColors.blue,
        size: 72,
      ),
    );
  }
}

class _ProductSummary extends StatelessWidget {
  const _ProductSummary({
    required this.name,
    required this.reference,
    required this.price,
    required this.available,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onAddToCart,
  });

  final String name;
  final String? reference;
  final String price;
  final bool available;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onAddToCart;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      padding: const EdgeInsets.all(AppSpacing.xl),
      radius: AppRadii.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              InfoPill(
                icon: available
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                label: available ? 'En stock' : 'Indisponible',
                backgroundColor:
                    available ? AppColors.softLeaf : const Color(0xFFFFEFEF),
                foregroundColor: available ? AppColors.leaf : AppColors.danger,
              ),
              if (reference?.isNotEmpty == true)
                InfoPill(
                  icon: Icons.tag_rounded,
                  label: 'Réf. $reference',
                  backgroundColor: AppColors.softBlue,
                  foregroundColor: AppColors.blue,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w900,
                  height: 1.12,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            price,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.blue,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: available ? onAddToCart : null,
                icon: const Icon(Icons.shopping_cart_rounded),
                label: const Text('Ajouter au panier'),
              ),
              OutlinedButton.icon(
                onPressed: onToggleFavorite,
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border_rounded,
                ),
                label: Text(isFavorite ? 'Favori' : 'Ajouter aux favoris'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TextPanel extends StatelessWidget {
  const _TextPanel({
    required this.title,
    required this.text,
  });

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      padding: const EdgeInsets.all(AppSpacing.xl),
      radius: AppRadii.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.muted,
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }
}

class _FeaturesPanel extends StatelessWidget {
  const _FeaturesPanel({required this.features});

  final List<ProductFeature> features;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      padding: const EdgeInsets.all(AppSpacing.xl),
      radius: AppRadii.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Caractéristiques',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 10),
          ...features.map(
            (feature) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      feature.name,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.muted,
                          ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      feature.value,
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _cleanText(String? value) {
  if (value == null) {
    return '';
  }

  return value
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#039;', "'")
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
