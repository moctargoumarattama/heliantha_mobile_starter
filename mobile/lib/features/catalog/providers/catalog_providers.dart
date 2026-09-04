import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/providers.dart';
import '../../../shared/models/category.dart';
import '../../../shared/models/product.dart';
import '../data/catalog_repository.dart';
import 'store_context_provider.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => CatalogRepository(ref.watch(apiClientProvider)),
);

final categoriesProvider = FutureProvider<List<Category>>(
  (ref) async {
    final context = await ref.watch(storeContextProvider.future);
    final selectedLanguageId = ref.watch(selectedLanguageIdProvider);
    final languageId = context.effectiveLanguageId(selectedLanguageId);
    final categories = await ref.watch(catalogRepositoryProvider).categories(
          languageId: languageId,
        );
    return categories.where((category) => category.id > 2).toList();
  },
);

final productsProvider = FutureProvider<List<Product>>(
  (ref) async {
    final context = await ref.watch(storeContextProvider.future);
    final selectedLanguageId = ref.watch(selectedLanguageIdProvider);
    final selectedCurrencyId = ref.watch(selectedCurrencyIdProvider);
    return ref.watch(catalogRepositoryProvider).products(
          pageSize: 12,
          languageId: context.effectiveLanguageId(selectedLanguageId),
          currencyId: context.effectiveCurrencyId(selectedCurrencyId),
        );
  },
);

final productProvider = FutureProvider.family<Product, int>(
  (ref, id) async {
    final context = await ref.watch(storeContextProvider.future);
    final selectedLanguageId = ref.watch(selectedLanguageIdProvider);
    final selectedCurrencyId = ref.watch(selectedCurrencyIdProvider);
    return ref.watch(catalogRepositoryProvider).product(
          id,
          languageId: context.effectiveLanguageId(selectedLanguageId),
          currencyId: context.effectiveCurrencyId(selectedCurrencyId),
        );
  },
);
