import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/category.dart';
import '../../../shared/models/home_slide.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/utils/api_url.dart';
import '../../../shared/widgets/app_ui.dart';
import '../../../shared/widgets/brand_widgets.dart';
import '../../../shared/widgets/product_grid.dart';
import '../../catalog/providers/catalog_providers.dart';
import '../providers/home_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    final products = ref.watch(productsProvider);
    final slides = ref.watch(homeSlidesProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const HelianthaAppBarTitle(
          subtitle: 'Leader de l’énergie solaire au Maroc',
        ),
        actions: [
          IconButton(
            tooltip: 'Panier',
            onPressed: () => context.go('/cart'),
            icon: const Icon(Icons.shopping_cart_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(categoriesProvider);
          ref.invalidate(productsProvider);
          ref.invalidate(homeSlidesProvider);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            ResponsivePagePadding(
              bottom: 96,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SearchSurface(
                    onSubmitted: (value) {
                      final query = value.trim();
                      if (query.isEmpty) {
                        context.push('/catalog');
                        return;
                      }
                      context.push(
                        '/catalog?q=${Uri.encodeQueryComponent(query)}',
                      );
                    },
                    onFilter: () => context.push('/catalog'),
                  ),
                  const SizedBox(height: 16),
                  slides.when(
                    loading: () => const _HomeSliderLoading(),
                    error: (_, __) => const _HomeSliderLoading(),
                    data: (items) => HomeSlider(
                      slides: items,
                      onOpenProduct: (productId) {
                        context.push('/product/$productId');
                      },
                    ),
                  ),
                  const SizedBox(height: 26),
                  AppSectionHeader(
                    title: 'Catégories',
                    subtitle: 'Retrouvez les familles produits du site.',
                    actionLabel: 'Voir tout',
                    onAction: () => context.push('/catalog'),
                  ),
                  const SizedBox(height: 12),
                  categories.when(
                    loading: () => const SizedBox(
                      height: 106,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, __) => AppStatusPanel(
                      icon: Icons.wifi_off_rounded,
                      title: 'Catégories indisponibles',
                      message: 'Veuillez réessayer dans quelques instants.',
                      action: OutlinedButton.icon(
                        onPressed: () => ref.invalidate(categoriesProvider),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Réessayer'),
                      ),
                    ),
                    data: (items) => _CategoryRail(
                      items: items,
                      onTap: (categoryId) {
                        context.push('/catalog?category=$categoryId');
                      },
                    ),
                  ),
                  const SizedBox(height: 28),
                  AppSectionHeader(
                    title: 'Nos solutions solaires',
                    subtitle: 'Des équipements sélectionnés pour vos projets.',
                    actionLabel: 'Catalogue',
                    onAction: () => context.push('/catalog'),
                  ),
                  const SizedBox(height: 12),
                  products.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 56),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, __) => AppStatusPanel(
                      icon: Icons.cloud_off_rounded,
                      title: 'Produits indisponibles',
                      message: 'Veuillez réessayer dans quelques instants.',
                      action: OutlinedButton.icon(
                        onPressed: () => ref.invalidate(productsProvider),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Réessayer'),
                      ),
                    ),
                    data: (items) {
                      if (items.isEmpty) {
                        return AppStatusPanel(
                          icon: Icons.inventory_2_outlined,
                          title: 'Aucun produit disponible',
                          message:
                              'Notre catalogue sera bientôt disponible.',
                          action: OutlinedButton.icon(
                            onPressed: () => ref.invalidate(productsProvider),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Actualiser'),
                          ),
                        );
                      }

                      return ResponsiveProductGrid(
                        products: items,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        onProductTap: (product) {
                          ref.read(catalogRepositoryProvider).rememberProduct(
                                product,
                              );
                          context.push(
                            '/product/${product.id}',
                            extra: product,
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  const _SupportPanel(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchSurface extends StatelessWidget {
  const _SearchSurface({
    required this.onSubmitted,
    required this.onFilter,
  });

  final ValueChanged<String> onSubmitted;
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) {
    return SearchBar(
      hintText: 'Rechercher un produit...',
      leading: const Icon(Icons.search_rounded, color: AppColors.muted),
      trailing: [
        IconButton(
          tooltip: 'Filtres',
          onPressed: onFilter,
          icon: const Icon(Icons.tune_rounded, color: AppColors.blue),
        ),
      ],
      onSubmitted: onSubmitted,
    );
  }
}

class HomeSlider extends StatefulWidget {
  const HomeSlider({
    super.key,
    required this.slides,
    required this.onOpenProduct,
  });

  final List<HomeSlide> slides;
  final ValueChanged<int> onOpenProduct;

  @override
  State<HomeSlider> createState() => _HomeSliderState();
}

class _HomeSliderState extends State<HomeSlider> {
  late final PageController _controller;
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant HomeSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slides.length != widget.slides.length) {
      _index = 0;
      _timer?.cancel();
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startTimer() {
    if (widget.slides.length < 2) {
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_controller.hasClients) {
        return;
      }
      final next = (_index + 1) % widget.slides.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.slides.isEmpty) {
      return const _HomeSliderLoading();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxWidth < 380 ? 218.0 : 244.0;
        return SizedBox(
          height: height,
          child: Stack(
            children: [
              PageView.builder(
                controller: _controller,
                itemCount: widget.slides.length,
                onPageChanged: (value) => setState(() => _index = value),
                itemBuilder: (context, index) {
                  final slide = widget.slides[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _HomeSlideCard(
                      slide: slide,
                      onTap: slide.isProduct
                          ? () => widget.onOpenProduct(slide.productId!)
                          : null,
                    ),
                  );
                },
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _SliderDots(
                  count: widget.slides.length,
                  index: _index,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HomeSlideCard extends StatelessWidget {
  const _HomeSlideCard({
    required this.slide,
    required this.onTap,
  });

  final HomeSlide slide;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: slide.type == 'banner'
                ? _SlideImage(
                    imageUrl: slide.imageUrl,
                    fit: BoxFit.contain,
                  )
                : _ProductSlide(slide: slide),
          ),
        ),
      ),
    );
  }
}

class _ProductSlide extends StatelessWidget {
  const _ProductSlide({required this.slide});

  final HomeSlide slide;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 6,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ColoredBox(
                color: AppColors.surface,
                child: _SlideImage(
                  imageUrl: slide.imageUrl,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  slide.title ?? '',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w900,
                        height: 1.18,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  slide.subtitle ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.blue,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Voir',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppColors.sun,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: AppColors.navy,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SlideImage extends StatelessWidget {
  const _SlideImage({
    required this.imageUrl,
    required this.fit,
    this.alignment = Alignment.center,
  });

  final String imageUrl;
  final BoxFit fit;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final url = absoluteApiUrl(imageUrl);
    if (url.isEmpty) {
      return const _SlideImageFallback();
    }

    if (kIsWeb) {
      return Image.network(
        url,
        fit: fit,
        alignment: alignment,
        width: double.infinity,
        height: double.infinity,
        headers: const {'Accept': 'image/*'},
        loadingBuilder: (context, child, progress) {
          if (progress == null) {
            return child;
          }
          return const _SlideImageLoading();
        },
        errorBuilder: (_, __, ___) => const _SlideImageFallback(),
      );
    }

    return CachedNetworkImage(
      imageUrl: url,
      httpHeaders: const {'Accept': 'image/*'},
      fit: fit,
      alignment: alignment,
      width: double.infinity,
      height: double.infinity,
      placeholder: (_, __) => const _SlideImageLoading(),
      errorWidget: (_, __, ___) => const _SlideImageFallback(),
    );
  }
}

class _SliderDots extends StatelessWidget {
  const _SliderDots({
    required this.count,
    required this.index,
  });

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: i == index ? 18 : 7,
            height: 7,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: i == index ? AppColors.blue : AppColors.border,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
      ],
    );
  }
}

class _HomeSliderLoading extends StatelessWidget {
  const _HomeSliderLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 244,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _SlideImageLoading extends StatelessWidget {
  const _SlideImageLoading();

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

class _SlideImageFallback extends StatelessWidget {
  const _SlideImageFallback();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.solar_power_rounded,
        color: AppColors.blue,
        size: 56,
      ),
    );
  }
}

class _CategoryRail extends StatelessWidget {
  const _CategoryRail({
    required this.items,
    required this.onTap,
  });

  final List<Category> items;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const AppStatusPanel(
        icon: Icons.category_outlined,
        title: 'Aucune catégorie',
        message: 'Nos familles de produits seront bientôt disponibles.',
      );
    }

    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final category = items[index];
          final accent = _accentFor(index);
          final soft = _softFor(index);
          final iconColor = accent == AppColors.sun ? AppColors.navy : accent;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onTap(category.id),
              child: Container(
                width: 122,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: soft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _categoryIcon(category.name),
                        color: iconColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      category.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _categoryIcon(String name) {
    final value = name.toLowerCase();

    if (value.contains('panneau')) {
      return Icons.solar_power_rounded;
    }
    if (value.contains('onduleur')) {
      return Icons.electric_bolt_rounded;
    }
    if (value.contains('batter')) {
      return Icons.battery_charging_full_rounded;
    }
    if (value.contains('pompe') || value.contains('pompage')) {
      return Icons.water_drop_rounded;
    }
    if (value.contains('groupe')) {
      return Icons.power_rounded;
    }
    if (value.contains('protection')) {
      return Icons.security_rounded;
    }
    if (value.contains('monitor')) {
      return Icons.monitor_heart_outlined;
    }
    if (value.contains('éclairage') || value.contains('eclairage')) {
      return Icons.lightbulb_outline_rounded;
    }

    return Icons.grid_view_rounded;
  }

  Color _accentFor(int index) {
    const colors = [
      AppColors.blue,
      AppColors.sun,
      AppColors.leaf,
      AppColors.sky,
    ];
    return colors[index % colors.length];
  }

  Color _softFor(int index) {
    const colors = [
      AppColors.softBlue,
      AppColors.softSun,
      AppColors.softLeaf,
      Color(0xFFE7F8FB),
    ];
    return colors[index % colors.length];
  }
}

class _SupportPanel extends StatelessWidget {
  const _SupportPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Besoin de conseils ?',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Nos équipes vous accompagnent dans votre projet énergétique.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFC9D7E2),
                        height: 1.35,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
