import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/navigation_helpers.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_tokens.dart';
import '../../../shared/widgets/app_ui.dart';
import '../../../shared/widgets/brand_widgets.dart';

class CheckoutStartScreen extends StatelessWidget {
  const CheckoutStartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(
        subtitle: 'Commander',
        showBack: true,
        backFallbackLocation: '/cart',
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            ResponsivePagePadding(
              maxWidth: 720,
              bottom: 96,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: Alignment.center,
                    child: HelianthaLogo(
                      size: 82,
                      padding: 6,
                      showShadow: true,
                    ),
                  ),
                  const SizedBox(height: 18),
                  AppSurface(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    radius: AppRadii.lg,
                    shadow: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Comment souhaitez-vous continuer ?',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: AppColors.ink,
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Choisissez le mode qui vous convient. Votre panier reste conservé.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.muted,
                                    height: 1.4,
                                  ),
                        ),
                        const SizedBox(height: 18),
                        _CheckoutChoiceTile(
                          icon: Icons.flash_on_rounded,
                          title: 'Continuer en invité',
                          subtitle: 'Commandez rapidement sans créer de compte.',
                          primary: true,
                          onTap: () => context.replace('/checkout'),
                        ),
                        const SizedBox(height: 12),
                        _CheckoutChoiceTile(
                          icon: Icons.person_add_alt_1_rounded,
                          title: 'Créer un compte',
                          subtitle:
                              'Retrouvez plus facilement vos commandes et informations.',
                          onTap: () => context.replace(
                            '/register?redirect=${Uri.encodeComponent('/checkout')}',
                          ),
                        ),
                        const SizedBox(height: 18),
                        Center(
                          child: Text(
                            'Déjà client ?',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.muted,
                                      fontWeight: FontWeight.w700,
                                    ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => context.replace(
                              loginLocationFor('/checkout'),
                            ),
                            icon: const Icon(Icons.login_rounded),
                            label: const Text('Se connecter'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckoutChoiceTile extends StatelessWidget {
  const _CheckoutChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final background = primary ? AppColors.navy : AppColors.surface;
    final foreground = primary ? Colors.white : AppColors.ink;
    final subtitleColor =
        primary ? const Color(0xFFC9D7E2) : AppColors.muted;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(
              color: primary ? AppColors.navy : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: primary
                      ? Colors.white.withValues(alpha: 0.12)
                      : AppColors.softBlue,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Icon(
                  icon,
                  color: primary ? Colors.white : AppColors.blue,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: foreground,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: subtitleColor,
                            height: 1.35,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: primary ? Colors.white : AppColors.blue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
