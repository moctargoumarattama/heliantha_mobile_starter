import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/order.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_tokens.dart';
import '../../../shared/utils/money.dart';
import '../../../shared/widgets/app_ui.dart';
import '../../../shared/widgets/brand_widgets.dart';
import '../providers/orders_provider.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider);

    return Scaffold(
      appBar: const AppTopBar(
        subtitle: 'Commandes client',
        showBack: true,
        backFallbackLocation: '/account',
      ),
      body: SafeArea(
        child: orders.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => ResponsivePagePadding(
            child: AppStatusPanel(
              icon: Icons.cloud_off_rounded,
              title: 'Commandes indisponibles',
              message: 'Veuillez réessayer dans quelques instants.',
              action: OutlinedButton.icon(
                onPressed: () => ref.invalidate(ordersProvider),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Réessayer'),
              ),
            ),
          ),
          data: (items) {
            if (items.isEmpty) {
              return const ResponsivePagePadding(
                child: AppStatusPanel(
                  icon: Icons.receipt_long_outlined,
                  title: 'Aucune commande',
                  message: 'Vos prochaines commandes apparaîtront ici.',
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
                      _OrdersHero(orders: items),
                      const SizedBox(height: 16),
                      for (var index = 0; index < items.length; index++) ...[
                        _OrderCard(order: items[index]),
                        if (index != items.length - 1)
                          const SizedBox(height: 12),
                      ],
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

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final total = formatMoney(order.totalPaid, currency: 'MAD');

    return AppSurface(
      padding: const EdgeInsets.all(AppSpacing.lg),
      radius: AppRadii.lg,
      shadow: true,
      onTap: () => context.push('/orders/${order.id}', extra: order),
      child: Row(
        children: [
          const AppIconBadge(
            icon: Icons.receipt_long_rounded,
            color: AppColors.blue,
            backgroundColor: AppColors.softBlue,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Commande ${order.reference}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                if (order.dateAdd?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    order.dateAdd!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                        ),
                  ),
                ],
                if (order.stateName?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  InfoPill(
                    icon: Icons.circle_rounded,
                    label: order.stateName!,
                    backgroundColor: AppColors.softLeaf,
                    foregroundColor: AppColors.leaf,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            total,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.blue,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ],
      ),
    );
  }
}

class _OrdersHero extends StatelessWidget {
  const _OrdersHero({required this.orders});

  final List<OrderModel> orders;

  @override
  Widget build(BuildContext context) {
    final total = orders.fold<double>(
      0,
      (sum, order) => sum + order.totalPaid,
    );
    final totalText = formatMoney(total, currency: 'MAD');

    return AppSurface(
      padding: const EdgeInsets.all(AppSpacing.xl),
      backgroundColor: AppColors.navy,
      borderColor: AppColors.navy,
      radius: AppRadii.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppIconBadge(
                icon: Icons.receipt_long_rounded,
                color: AppColors.navy,
                backgroundColor: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Mes commandes',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _HeroMetric(
                  label: 'Commandes',
                  value: '${orders.length}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroMetric(
                  label: 'Total',
                  value: totalText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xFFC9D7E2),
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({
    super.key,
    required this.orderId,
    this.initialOrder,
  });

  final int orderId;
  final OrderModel? initialOrder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider);

    return Scaffold(
      appBar: const AppTopBar(
        subtitle: 'Détail commande',
        showBack: true,
        backFallbackLocation: '/orders',
      ),
      body: SafeArea(
        child: orders.when(
          loading: () => initialOrder == null
              ? const Center(child: CircularProgressIndicator())
              : _OrderDetailBody(order: initialOrder!),
          error: (_, __) => initialOrder == null
              ? ResponsivePagePadding(
                  child: AppStatusPanel(
                    icon: Icons.cloud_off_rounded,
                    title: 'Commande indisponible',
                    message: 'Veuillez réessayer dans quelques instants.',
                    action: OutlinedButton.icon(
                      onPressed: () => ref.invalidate(ordersProvider),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Réessayer'),
                    ),
                  ),
                )
              : _OrderDetailBody(order: initialOrder!),
          data: (items) {
            OrderModel? order;
            for (final item in items) {
              if (item.id == orderId) {
                order = item;
                break;
              }
            }
            if (order == null) {
              return const ResponsivePagePadding(
                child: AppStatusPanel(
                  icon: Icons.receipt_long_outlined,
                  title: 'Commande introuvable',
                  message: 'Cette commande n’est pas disponible ici.',
                ),
              );
            }
            return _OrderDetailBody(order: order);
          },
        ),
      ),
    );
  }
}

class _OrderDetailBody extends StatelessWidget {
  const _OrderDetailBody({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final total = formatMoney(order.totalPaid, currency: 'MAD');

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        ResponsivePagePadding(
          bottom: 96,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSurface(
                padding: const EdgeInsets.all(AppSpacing.xl),
                backgroundColor: AppColors.navy,
                borderColor: AppColors.navy,
                radius: AppRadii.lg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppIconBadge(
                      icon: Icons.verified_rounded,
                      color: AppColors.leaf,
                      backgroundColor: Colors.white,
                      size: 52,
                      iconSize: 28,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Commande ${order.reference}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    if (order.stateName?.isNotEmpty == true) ...[
                      const SizedBox(height: 10),
                      InfoPill(
                        icon: Icons.circle_rounded,
                        label: order.stateName!,
                        backgroundColor: AppColors.softLeaf,
                        foregroundColor: AppColors.leaf,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppSurface(
                padding: const EdgeInsets.all(AppSpacing.xl),
                radius: AppRadii.lg,
                child: Column(
                  children: [
                    _DetailRow(label: 'Référence', value: order.reference),
                    const Divider(height: 22),
                    _DetailRow(label: 'Date', value: order.dateAdd ?? '-'),
                    const Divider(height: 22),
                    _DetailRow(
                      label: 'Statut',
                      value: order.stateName ?? 'En traitement',
                    ),
                    const Divider(height: 22),
                    _DetailRow(label: 'Total TTC', value: total, strong: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
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
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: strong ? AppColors.blue : AppColors.ink,
                  fontWeight: strong ? FontWeight.w900 : FontWeight.w800,
                ),
          ),
        ),
      ],
    );
  }
}
