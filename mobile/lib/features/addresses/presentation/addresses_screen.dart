import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/address.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/app_ui.dart';
import '../../../shared/widgets/brand_widgets.dart';
import '../providers/addresses_provider.dart';

class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(addressesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const HelianthaAppBarTitle(subtitle: 'Mes adresses'),
      ),
      body: SafeArea(
        child: addresses.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => ResponsivePagePadding(
            child: AppStatusPanel(
              icon: Icons.cloud_off_rounded,
              title: 'Adresses indisponibles',
              message: 'Impossible de charger vos adresses pour le moment.',
              action: OutlinedButton.icon(
                onPressed: () => ref.invalidate(addressesProvider),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Réessayer'),
              ),
            ),
          ),
          data: (items) {
            if (items.isEmpty) {
              return ResponsivePagePadding(
                child: AppStatusPanel(
                  icon: Icons.location_on_outlined,
                  title: 'Aucune adresse enregistrée',
                  message:
                      'Vos informations de livraison apparaîtront ici.',
                  action: FilledButton.icon(
                    onPressed: () => _showWritePending(context),
                    icon: const Icon(Icons.add_location_alt_rounded),
                    label: const Text('Ajouter une adresse'),
                  ),
                ),
              );
            }

            return ListView(
              padding: EdgeInsets.zero,
              children: [
                ResponsivePagePadding(
                  bottom: 96,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: () => _showWritePending(context),
                          icon: const Icon(Icons.add_location_alt_rounded),
                          label: const Text('Ajouter une adresse'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (var index = 0; index < items.length; index++) ...[
                        _AddressCard(address: items[index]),
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

  static void _showWritePending(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Ajout et modification seront activés via le bridge PrestaShop.',
        ),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.address});

  final AddressModel address;

  @override
  Widget build(BuildContext context) {
    final title = address.alias?.isNotEmpty == true
        ? address.alias!
        : 'Adresse ${address.id}';
    final name = address.fullName;
    final cityLine = [
      address.postcode,
      address.city,
    ].where((value) => value != null && value!.trim().isNotEmpty).join(' ');
    final phone = address.phoneMobile?.isNotEmpty == true
        ? address.phoneMobile
        : address.phone;
    final location = [
      cityLine,
      address.country,
    ].whereType<String>().where((value) => value.trim().isNotEmpty).join(', ');

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => AddressesScreen._showWritePending(context),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.softBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  color: AppColors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    if (name.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (address.company?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        address.company!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      address.address1,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    if (address.address2?.isNotEmpty == true) ...[
                      const SizedBox(height: 3),
                      Text(
                        address.address2!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 5),
                    Text(
                      location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    if (phone?.isNotEmpty == true) ...[
                      const SizedBox(height: 7),
                      InfoPill(
                        icon: Icons.phone_rounded,
                        label: phone!,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.edit_location_alt_outlined,
                color: AppColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
