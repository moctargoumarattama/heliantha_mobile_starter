import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/utils/api_url.dart';
import '../../../shared/widgets/app_ui.dart';
import '../../../shared/widgets/brand_widgets.dart';
import '../domain/cart_item.dart';
import '../providers/cart_provider.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(cartProvider);
    final total = ref.watch(cartTotalProvider);
    final currency = items.isEmpty ? 'MAD' : items.first.product.currency;

    return Scaffold(
      appBar: AppBar(
        title: const HelianthaAppBarTitle(subtitle: 'Votre panier'),
      ),
      body: SafeArea(
        child: items.isEmpty
            ? ResponsivePagePadding(
                child: AppStatusPanel(
                  icon: Icons.shopping_bag_outlined,
                  title: 'Votre panier est vide',
                  message: 'Ajoutez des produits depuis le catalogue Heliantha.',
                  action: FilledButton.icon(
                    onPressed: () => context.go('/catalog'),
                    icon: const Icon(Icons.storefront_rounded),
                    label: const Text('Ouvrir le catalogue'),
                  ),
                ),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 820;
                  if (wide) {
                    return ResponsivePagePadding(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _CartList(items: items),
                          ),
                          const SizedBox(width: 18),
                          SizedBox(
                            width: 330,
                            child: _OrderSummary(
                              itemCount: items.length,
                              total: total,
                              currency: currency,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      ResponsivePagePadding(
                        bottom: 96,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _CartItemsColumn(items: items),
                            const SizedBox(height: 14),
                            _OrderSummary(
                              itemCount: items.length,
                              total: total,
                              currency: currency,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

class _CartList extends StatelessWidget {
  const _CartList({required this.items});

  final List<CartItem> items;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _CartItemCard(item: items[index]),
    );
  }
}

class _CartItemsColumn extends StatelessWidget {
  const _CartItemsColumn({required this.items});

  final List<CartItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < items.length; index++) ...[
          _CartItemCard(item: items[index]),
          if (index != items.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _CartItemCard extends ConsumerWidget {
  const _CartItemCard({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = item.product;
    final price = _money(product.price, product.currency);
    final total = _money(item.total, product.currency);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 380;
        final productInfo = Expanded(
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
                      height: 1.25,
                    ),
              ),
              const SizedBox(height: 5),
              Text(
                price,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                total,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.blue,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ],
          ),
        );

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: compact
              ? Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CartProductImage(imageUrl: product.imageUrl),
                        const SizedBox(width: 12),
                        productInfo,
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _QuantityStepper(item: item),
                        const Spacer(),
                        _RemoveButton(productId: product.id),
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    _CartProductImage(imageUrl: product.imageUrl),
                    const SizedBox(width: 12),
                    productInfo,
                    const SizedBox(width: 10),
                    _QuantityStepper(item: item),
                    _RemoveButton(productId: product.id),
                  ],
                ),
        );
      },
    );
  }
}

class _CartProductImage extends StatelessWidget {
  const _CartProductImage({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 74,
      height: 74,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
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

class _QuantityStepper extends ConsumerWidget {
  const _QuantityStepper({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            tooltip: 'Retirer',
            icon: Icons.remove_rounded,
            onPressed: () {
              ref.read(cartProvider.notifier).decrement(item.product.id);
            },
          ),
          SizedBox(
            width: 34,
            child: Text(
              '${item.quantity}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
          _StepButton(
            tooltip: 'Ajouter',
            icon: Icons.add_rounded,
            onPressed: () {
              ref.read(cartProvider.notifier).add(item.product);
            },
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 36,
      child: IconButton(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        icon: Icon(icon, color: AppColors.blue, size: 19),
      ),
    );
  }
}

class _RemoveButton extends ConsumerWidget {
  const _RemoveButton({required this.productId});

  final int productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: 'Supprimer',
      onPressed: () {
        ref.read(cartProvider.notifier).remove(productId);
      },
      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
    );
  }
}

class _OrderSummary extends StatelessWidget {
  const _OrderSummary({
    required this.itemCount,
    required this.total,
    required this.currency,
  });

  final int itemCount;
  final double total;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final totalText = _money(total, currency);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Résumé',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 14),
          _SummaryRow(label: 'Produits', value: '$itemCount'),
          const SizedBox(height: 8),
          const _SummaryRow(
            label: 'Livraison',
            value: 'Calculée au checkout',
          ),
          const Divider(height: 26),
          _SummaryRow(label: 'Total', value: totalText, strong: true),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.push('/checkout'),
              icon: const Icon(Icons.lock_open_rounded),
              label: const Text('Commander'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: strong ? AppColors.ink : AppColors.muted,
                  fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
                ),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: strong ? AppColors.blue : AppColors.ink,
                fontWeight: FontWeight.w900,
              ),
        ),
      ],
    );
  }
}

String _money(double value, String currency) {
  return NumberFormat.currency(
    locale: 'fr_FR',
    symbol: '$currency ',
    decimalDigits: 0,
  ).format(value);
}
