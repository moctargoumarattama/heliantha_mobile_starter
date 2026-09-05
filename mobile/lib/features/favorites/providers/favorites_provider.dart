import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/providers.dart';

class FavoritesNotifier extends StateNotifier<Set<int>> {
  FavoritesNotifier(this.ref) : super(<int>{}) {
    _load();
  }

  final Ref ref;
  static const _key = 'favorite_product_ids';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_key) ?? const [];
    state = ids.map(int.tryParse).whereType<int>().toSet();
  }

  Future<void> toggle(int productId) async {
    final next = {...state};
    if (!next.add(productId)) {
      next.remove(productId);
    }
    state = next;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      next.map((e) => e.toString()).toList(),
    );

    final api = ref.read(apiClientProvider);
    try {
      if (next.contains(productId)) {
        await api.dio.post('/v1/favorites/$productId');
      } else {
        await api.dio.delete('/v1/favorites/$productId');
      }
    } catch (_) {
      // Favoris local immédiat; la surveillance stock sera synchronisée au login.
    }
  }
}

final favoritesProvider = StateNotifierProvider<FavoritesNotifier, Set<int>>(
  (ref) => FavoritesNotifier(ref),
);
