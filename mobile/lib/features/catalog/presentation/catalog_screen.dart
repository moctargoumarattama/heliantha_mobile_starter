import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/product.dart';
import '../../../shared/models/store_context.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/app_ui.dart';
import '../../../shared/widgets/brand_widgets.dart';
import '../../../shared/widgets/product_grid.dart';
import '../providers/catalog_providers.dart';
import '../providers/store_context_provider.dart';

class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({
    super.key,
    this.initialCategory,
    this.initialQuery,
  });

  final int? initialCategory;
  final String? initialQuery;

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  static const _pageSize = 30;
  static const _loadMoreThreshold = 520.0;

  late final TextEditingController _search;
  late final ScrollController _scrollController;
  List<Product>? _products;
  int _page = 1;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;
  int _requestVersion = 0;
  Timer? _searchDebounce;

  bool get _hasSearch => _search.text.trim().isNotEmpty;
  int? get _categoryFilter => widget.initialCategory;
  String? get _queryFilter {
    final query = _search.text.trim();
    return query.isEmpty ? null : query;
  }

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: widget.initialQuery ?? '');
    _scrollController = ScrollController();
    _search.addListener(_onSearchChanged);
    _scrollController.addListener(_onCatalogScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadFirstPage();
      }
    });
  }

  @override
  void didUpdateWidget(covariant CatalogScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final routeChanged = oldWidget.initialCategory != widget.initialCategory ||
        oldWidget.initialQuery != widget.initialQuery;

    if (routeChanged) {
      _searchDebounce?.cancel();
      _search.text = widget.initialQuery ?? '';
      _loadFirstPage();
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.removeListener(_onCatalogScroll);
    _scrollController.dispose();
    _search.removeListener(_onSearchChanged);
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (mounted) {
      setState(() {});
    }
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      _loadFirstPage,
    );
  }

  void _onCatalogScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    if (_scrollController.position.extentAfter < _loadMoreThreshold) {
      _loadMore();
    }
  }

  void _loadMoreIfContentIsShort() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_hasMore ||
          _loading ||
          _loadingMore ||
          !_scrollController.hasClients) {
        return;
      }

      if (_scrollController.position.extentAfter < _loadMoreThreshold) {
        _loadMore();
      }
    });
  }

  Future<({int? languageId, int? currencyId})> _storeSelection() async {
    try {
      final context = await ref.read(storeContextProvider.future);
      return (
        languageId: context.effectiveLanguageId(
          ref.read(selectedLanguageIdProvider),
        ),
        currencyId: context.effectiveCurrencyId(
          ref.read(selectedCurrencyIdProvider),
        ),
      );
    } catch (_) {
      return (
        languageId: ref.read(selectedLanguageIdProvider),
        currencyId: ref.read(selectedCurrencyIdProvider),
      );
    }
  }

  Future<void> _loadFirstPage() async {
    _searchDebounce?.cancel();
    final requestVersion = ++_requestVersion;
    setState(() {
      _loading = true;
      _loadingMore = false;
      _error = null;
      _products = null;
      _page = 1;
      _hasMore = false;
    });

    try {
      final repo = ref.read(catalogRepositoryProvider);
      final selection = await _storeSelection();
      final rows = await repo.products(
        page: 1,
        pageSize: _pageSize,
        category: _categoryFilter,
        query: _queryFilter,
        languageId: selection.languageId,
        currencyId: selection.currencyId,
      );
      if (mounted) {
        if (requestVersion != _requestVersion) {
          return;
        }
        setState(() {
          _products = rows;
          _page = 1;
          _hasMore = rows.length == _pageSize;
        });
        _loadMoreIfContentIsShort();
        if (_hasMore) {
          repo.prefetchProducts(
            page: 2,
            pageSize: _pageSize,
            category: _categoryFilter,
            query: _queryFilter,
            languageId: selection.languageId,
            currencyId: selection.currencyId,
          );
        }
      }
    } catch (e) {
      if (mounted && requestVersion == _requestVersion) {
        setState(() => _error = e);
      }
    } finally {
      if (mounted && requestVersion == _requestVersion) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loading || !_hasMore) {
      return;
    }

    setState(() => _loadingMore = true);
    try {
      final repo = ref.read(catalogRepositoryProvider);
      final selection = await _storeSelection();
      final nextPage = _page + 1;
      final rows = await repo.products(
        page: nextPage,
        pageSize: _pageSize,
        category: _categoryFilter,
        query: _queryFilter,
        languageId: selection.languageId,
        currencyId: selection.currencyId,
      );
      if (mounted) {
        setState(() {
          _products = [...?_products, ...rows];
          _page = nextPage;
          _hasMore = rows.length == _pageSize;
        });
        _loadMoreIfContentIsShort();
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de charger plus de produits.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingMore = false);
      }
    }
  }

  void _clearSearch() {
    _search.clear();
    _loadFirstPage();
  }

  @override
  Widget build(BuildContext context) {
    final products = _products ?? const <Product>[];
    final storeContext = ref.watch(storeContextProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const HelianthaAppBarTitle(
          subtitle: 'Catalogue solaire',
        ),
        actions: _contextActions(storeContext),
      ),
      body: SafeArea(
        child: ResponsivePagePadding(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CatalogSearchBar(
                controller: _search,
                hasSearch: _hasSearch,
                onClear: _clearSearch,
                onSearch: _loadFirstPage,
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  const InfoPill(
                    icon: Icons.verified_rounded,
                    label: 'Produits Heliantha',
                    backgroundColor: AppColors.softLeaf,
                    foregroundColor: AppColors.leaf,
                  ),
                  if (widget.initialCategory != null)
                    InfoPill(
                      icon: Icons.category_rounded,
                      label: 'Catégorie sélectionnée',
                      backgroundColor: AppColors.softSun,
                      foregroundColor: AppColors.navy,
                    ),
                  if (!_loading && _error == null)
                    InfoPill(
                      icon: Icons.inventory_2_outlined,
                      label: _productCountLabel(products.length),
                      backgroundColor: AppColors.softBlue,
                      foregroundColor: AppColors.blue,
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(
                child: _CatalogContent(
                  loading: _loading,
                  error: _error,
                  products: products,
                  hasMore: _hasMore,
                  loadingMore: _loadingMore,
                  scrollController: _scrollController,
                  onRetry: _loadFirstPage,
                  onOpenProduct: (product) {
                    ref.read(catalogRepositoryProvider).rememberProduct(
                          product,
                        );
                    context.push(
                      '/product/${product.id}',
                      extra: product,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget>? _contextActions(StoreContext? context) {
    if (context == null) {
      return null;
    }

    final actions = <Widget>[];

    if (context.languages.length > 1) {
      actions.add(
        PopupMenuButton<int>(
          tooltip: 'Langue',
          icon: const Icon(Icons.language_rounded),
          onSelected: (id) async {
            await ref.read(selectedLanguageIdProvider.notifier).select(id);
            await _loadFirstPage();
          },
          itemBuilder: (_) => [
            for (final language in context.languages)
              PopupMenuItem<int>(
                value: language.id,
                child: Text(language.name),
              ),
          ],
        ),
      );
    }

    if (context.currencies.length > 1) {
      actions.add(
        PopupMenuButton<int>(
          tooltip: 'Devise',
          icon: const Icon(Icons.payments_rounded),
          onSelected: (id) async {
            await ref.read(selectedCurrencyIdProvider.notifier).select(id);
            await _loadFirstPage();
          },
          itemBuilder: (_) => [
            for (final currency in context.currencies)
              PopupMenuItem<int>(
                value: currency.id,
                child: Text(currency.isoCode),
              ),
          ],
        ),
      );
    }

    return actions.isEmpty ? null : actions;
  }
}

String _productCountLabel(int count) {
  return count == 1 ? '1 produit' : '$count produits';
}

class _CatalogSearchBar extends StatelessWidget {
  const _CatalogSearchBar({
    required this.controller,
    required this.hasSearch,
    required this.onClear,
    required this.onSearch,
  });

  final TextEditingController controller;
  final bool hasSearch;
  final VoidCallback onClear;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return SearchBar(
      controller: controller,
      hintText: 'Rechercher dans le catalogue...',
      leading: const Icon(Icons.search_rounded, color: AppColors.muted),
      trailing: [
        if (hasSearch)
          IconButton(
            tooltip: 'Effacer',
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded, color: AppColors.muted),
          ),
        IconButton(
          tooltip: 'Rechercher',
          onPressed: onSearch,
          icon: const Icon(Icons.arrow_forward_rounded, color: AppColors.blue),
        ),
      ],
      onSubmitted: (_) => onSearch(),
    );
  }
}

class _CatalogContent extends StatelessWidget {
  const _CatalogContent({
    required this.loading,
    required this.error,
    required this.products,
    required this.hasMore,
    required this.loadingMore,
    required this.scrollController,
    required this.onRetry,
    required this.onOpenProduct,
  });

  final bool loading;
  final Object? error;
  final List<Product> products;
  final bool hasMore;
  final bool loadingMore;
  final ScrollController scrollController;
  final VoidCallback onRetry;
  final ValueChanged<Product> onOpenProduct;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return SingleChildScrollView(
        child: AppStatusPanel(
          icon: Icons.cloud_off_rounded,
          title: 'Catalogue indisponible',
          message: 'Veuillez réessayer dans quelques instants.',
          action: OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
          ),
        ),
      );
    }

    if (products.isEmpty) {
      return SingleChildScrollView(
        child: AppStatusPanel(
          icon: Icons.manage_search_rounded,
          title: 'Aucun résultat',
          message: 'Essayez une autre recherche ou revenez plus tard.',
          action: OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Actualiser'),
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ResponsiveProductGrid(
            products: products,
            padding: const EdgeInsets.only(bottom: 12),
            controller: scrollController,
            onProductTap: onOpenProduct,
          ),
        ),
        if (loadingMore) ...[
          const SizedBox(height: 8),
          const _CatalogLoadingMoreIndicator(),
        ],
      ],
    );
  }
}

class _CatalogLoadingMoreIndicator extends StatelessWidget {
  const _CatalogLoadingMoreIndicator();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Row(
            key: const ValueKey('loading-more'),
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              Text(
                'Chargement...',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.blue,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
