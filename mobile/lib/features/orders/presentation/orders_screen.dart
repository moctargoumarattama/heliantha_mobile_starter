import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/models/order.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/app_ui.dart';
import '../../../shared/widgets/brand_widgets.dart';
import '../providers/orders_provider.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const HelianthaAppBarTitle(subtitle: 'Commandes client'),
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
                    children: [
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
    final total = NumberFormat.currency(
      locale: 'fr_FR',
      symbol: 'MAD ',
      decimalDigits: 0,
    ).format(order.totalPaid);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.softBlue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.local_shipping_outlined,
              color: AppColors.blue,
            ),
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
        ],
      ),
    );
  }
}
