import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../shared/models/notification_item.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_tokens.dart';
import '../../../shared/widgets/app_ui.dart';
import '../../../shared/widgets/brand_widgets.dart';
import '../providers/notifications_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: const AppTopBar(
        subtitle: 'Notifications',
        showBack: true,
        backFallbackLocation: '/account',
      ),
      body: notifications.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => ResponsivePagePadding(
          child: AppStatusPanel(
            icon: Icons.notifications_off_outlined,
            title: 'Notifications indisponibles',
            message: 'Veuillez réessayer dans quelques instants.',
            action: OutlinedButton.icon(
              onPressed: () => ref.invalidate(notificationsProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ),
        ),
        data: (result) {
          if (result.items.isEmpty) {
            return const ResponsivePagePadding(
              child: AppStatusPanel(
                icon: Icons.notifications_none_rounded,
                title: 'Aucune notification',
                message:
                    'Vos alertes de commande et de stock apparaîtront ici.',
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 96),
            itemCount: result.items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = result.items[index];
              return _NotificationTile(
                item: item,
                onTap: () async {
                  await ref
                      .read(notificationsRepositoryProvider)
                      .markRead(item.id);
                  ref.invalidate(notificationsProvider);
                  if (!context.mounted) return;
                  _openNotification(context, item);
                },
              );
            },
          );
        },
      ),
    );
  }

  void _openNotification(BuildContext context, NotificationItem item) {
    if (item.orderId != null &&
        (item.type == 'ORDER_STATUS' || item.type == 'PAYMENT_STATUS')) {
      context.push('/orders/${item.orderId}');
      return;
    }
    if (item.productId != null && item.type == 'FAVORITE_BACK_IN_STOCK') {
      context.push('/product/${item.productId}');
    }
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.onTap,
  });

  final NotificationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(item.type);
    return AppSurface(
      radius: AppRadii.lg,
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIconBadge(
            icon: _iconFor(item.type),
            color: color,
            backgroundColor: color.withValues(alpha: 0.12),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                    if (!item.isRead)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.sun,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm')
                      .format(item.createdAt.toLocal()),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ],
      ),
    );
  }

  IconData _iconFor(String type) {
    return switch (type) {
      'PAYMENT_STATUS' => Icons.payments_outlined,
      'FAVORITE_BACK_IN_STOCK' => Icons.favorite_border_rounded,
      _ => Icons.local_shipping_outlined,
    };
  }

  Color _colorFor(String type) {
    return switch (type) {
      'PAYMENT_STATUS' => AppColors.leaf,
      'FAVORITE_BACK_IN_STOCK' => AppColors.danger,
      _ => AppColors.blue,
    };
  }
}
