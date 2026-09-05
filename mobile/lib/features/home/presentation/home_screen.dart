import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/models/category.dart';
import '../../../shared/models/home_slide.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_tokens.dart';
import '../../../shared/utils/api_url.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_ui.dart';
import '../../../shared/widgets/brand_widgets.dart';
import '../../../shared/widgets/product_grid.dart';
import '../../auth/providers/auth_provider.dart';
import '../../catalog/providers/catalog_providers.dart';
import '../../notifications/presentation/notification_bell.dart';
import '../providers/home_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static bool _welcomeShownThisSession = false;

  bool _showWelcome = false;

  @override
  void initState() {
    super.initState();
    if (!_welcomeShownThisSession) {
      _welcomeShownThisSession = true;
      _showWelcome = true;
    }
  }

  void _dismissWelcome() {
    if (!_showWelcome || !mounted) {
      return;
    }
    setState(() => _showWelcome = false);
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    final products = ref.watch(productsProvider);
    final slides = ref.watch(homeSlidesProvider);
    final user = ref.watch(currentUserProvider).valueOrNull;
    final firstname = user?['firstname']?.toString().trim();

    return Scaffold(
      appBar: const AppTopBar(
        subtitle: "Leader de l'énergie solaire au Maroc",
        actions: [NotificationBell()],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
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
                        context.go('/catalog');
                        return;
                      }
                      context.push(
                        '/catalog?q=${Uri.encodeQueryComponent(query)}',
                      );
                    },
                    onFilter: () => context.go('/catalog'),
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
                    onAction: () => context.push('/catalog?categories=1'),
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
                    subtitle:
                        'Des équipements sélectionnés pour vos projets.',
                    actionLabel: 'Catalogue',
                    onAction: () => context.go('/catalog'),
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
                          message: 'Notre catalogue sera bientôt disponible.',
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
          if (_showWelcome)
            _WelcomeSplashOverlay(
              firstname: firstname?.isNotEmpty == true ? firstname : null,
              onDismissed: _dismissWelcome,
            ),
        ],
      ),
    );
  }
}

class _WelcomeSplashOverlay extends StatefulWidget {
  const _WelcomeSplashOverlay({
    required this.firstname,
    required this.onDismissed,
  });

  final String? firstname;
  final VoidCallback onDismissed;

  @override
  State<_WelcomeSplashOverlay> createState() => _WelcomeSplashOverlayState();
}

class _WelcomeSplashOverlayState extends State<_WelcomeSplashOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<double> _textFade;
  late final Animation<double> _sheen;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2350),
    );
    _fade = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0).chain(
          CurveTween(curve: Curves.easeOutCubic),
        ),
        weight: 18,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 64),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0).chain(
          CurveTween(curve: Curves.easeInOutCubic),
        ),
        weight: 18,
      ),
    ]).animate(_controller);
    _scale = Tween<double>(begin: 0.96, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.32, curve: Curves.easeOutCubic),
      ),
    );
    _textFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.18, 0.46, curve: Curves.easeOutCubic),
    );
    _sheen = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.12, 0.48, curve: Curves.easeInOutCubic),
    );
    _controller
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onDismissed();
        }
      })
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    _controller.animateTo(
      1,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.firstname == null
        ? 'Marhaba 👋'
        : 'Marhaba ${widget.firstname} 👋';

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _dismiss,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _fade.value,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 2.2, sigmaY: 2.2),
                child: ColoredBox(
                  color: AppColors.ink.withValues(alpha: 0.08),
                  child: Center(
                    child: Transform.scale(
                      scale: _scale.value,
                      child: child,
                    ),
                  ),
                ),
              ),
            );
          },
          child: GestureDetector(
            onTap: () {},
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.surface.withValues(alpha: 0.96),
                      AppColors.surfaceGlow.withValues(alpha: 0.94),
                      const Color(0xFFF6FBFD).withValues(alpha: 0.94),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: AppColors.premiumLine.withValues(alpha: 0.8),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.navy.withValues(alpha: 0.12),
                      blurRadius: 28,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _WelcomeLogo(sheen: _sheen),
                    const SizedBox(height: 16),
                    FadeTransition(
                      opacity: _textFade,
                      child: Column(
                        children: [
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: AppColors.ink,
                                  fontWeight: FontWeight.w900,
                                  height: 1.1,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Bienvenue sur Heliantha',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: AppColors.navy,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Heureux de vous retrouver ✨',
                            textAlign: TextAlign.center,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.muted,
                                      fontWeight: FontWeight.w700,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeLogo extends StatelessWidget {
  const _WelcomeLogo({required this.sheen});

  final Animation<double> sheen;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 86,
      height: 86,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.sun.withValues(alpha: 0.18),
            blurRadius: 34,
            spreadRadius: 5,
          ),
          BoxShadow(
            color: AppColors.sky.withValues(alpha: 0.10),
            blurRadius: 26,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const HelianthaLogo(size: 72, padding: 5, showShadow: true),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.md),
            child: SizedBox(
              width: 72,
              height: 72,
              child: AnimatedBuilder(
                animation: sheen,
                builder: (context, _) {
                  final x = -1.2 + sheen.value * 2.4;
                  return IgnorePointer(
                    child: Align(
                      alignment: Alignment(x, 0),
                      child: Transform.rotate(
                        angle: -0.55,
                        child: Container(
                          width: 16,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0),
                                Colors.white.withValues(alpha: 0.34),
                                Colors.white.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
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
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.surface,
                AppColors.surfaceGlow,
                Color(0xFFF7FBFD),
              ],
            ),
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: AppColors.premiumLine),
            boxShadow: AppShadows.soft,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            child: Stack(
              fit: StackFit.expand,
              children: [
                slide.type == 'banner'
                    ? _SlideImage(
                        imageUrl: slide.imageUrl,
                        fit: BoxFit.contain,
                      )
                    : _ProductSlide(slide: slide),
                const _StaticSheen(),
              ],
            ),
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
              borderRadius: BorderRadius.circular(AppRadii.md),
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
                        borderRadius: BorderRadius.circular(AppRadii.sm),
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
              borderRadius: BorderRadius.circular(AppRadii.sm),
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
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surface,
            AppColors.surfaceGlow,
            Color(0xFFF7FBFD),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.premiumLine),
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
              borderRadius: BorderRadius.circular(AppRadii.lg),
              onTap: () => onTap(category.id),
              child: Container(
                width: 122,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.surface,
                      AppColors.surfaceGlow,
                      Color(0xFFF7FBFD),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  border: Border.all(color: AppColors.premiumLine),
                  boxShadow: AppShadows.soft,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: soft,
                        borderRadius: BorderRadius.circular(AppRadii.md),
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

class _SupportPanel extends StatefulWidget {
  const _SupportPanel();

  @override
  State<_SupportPanel> createState() => _SupportPanelState();
}

class _SupportPanelState extends State<_SupportPanel> {
  static final Uri _whatsappUrl = Uri.https(
    'wa.me',
    '/212661575128',
    {
      'text':
          'Bonjour Heliantha, je souhaite avoir des informations sur vos solutions énergétiques.',
    },
  );

  bool _hovered = false;

  Future<void> _openWhatsApp() async {
    final opened = await launchUrl(
      _whatsappUrl,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (!opened && mounted) {
      AppFeedback.error(context, 'Impossible d’ouvrir WhatsApp.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        scale: _hovered ? 1.005 : 1,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            onTap: _openWhatsApp,
            splashColor: Colors.white.withValues(alpha: 0.08),
            highlightColor: Colors.white.withValues(alpha: 0.05),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.navy, AppColors.slate],
                ),
                borderRadius: BorderRadius.circular(AppRadii.lg),
                border: Border.all(
                  color: _hovered ? AppColors.sun : AppColors.premiumLine,
                  width: _hovered ? 1.25 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.navy.withValues(
                      alpha: _hovered ? 0.18 : 0.12,
                    ),
                    blurRadius: _hovered ? 20 : 14,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 520;
                  final button = _WhatsAppCtaButton(
                    hovered: _hovered,
                    expand: compact,
                  );

                  if (compact) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SupportIcon(),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SupportPanelText(),
                              const SizedBox(height: 12),
                              button,
                            ],
                          ),
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      const _SupportIcon(),
                      const SizedBox(width: 14),
                      const Expanded(child: _SupportPanelText()),
                      const SizedBox(width: 16),
                      button,
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SupportIcon extends StatelessWidget {
  const _SupportIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: const Icon(
        Icons.support_agent_rounded,
        color: Colors.white,
        size: 24,
      ),
    );
  }
}

class _SupportPanelText extends StatelessWidget {
  const _SupportPanelText();

  @override
  Widget build(BuildContext context) {
    return Column(
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
    );
  }
}

class _WhatsAppCtaButton extends StatelessWidget {
  const _WhatsAppCtaButton({
    required this.hovered,
    required this.expand,
  });

  final bool hovered;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: expand ? double.infinity : null,
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: hovered ? AppColors.sun : Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: hovered ? AppColors.sun : Colors.white.withValues(alpha: 0.78),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: hovered ? 0.18 : 0.10),
            blurRadius: hovered ? 16 : 10,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_rounded,
            size: 18,
            color: hovered ? AppColors.navy : AppColors.leaf,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Nous contacter sur WhatsApp',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StaticSheen extends StatelessWidget {
  const _StaticSheen();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0x55FFFFFF),
              Color(0x0FFFFFFF),
              Color(0x00FFFFFF),
            ],
            stops: [0, 0.3, 0.62],
          ),
        ),
      ),
    );
  }
}
