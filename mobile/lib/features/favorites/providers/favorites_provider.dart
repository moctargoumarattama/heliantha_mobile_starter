import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesNotifier extends StateNotifier<Set<int>> {
  FavoritesNotifier() : super(<int>{}) {
    _load();
  }

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
  }
}

final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, Set<int>>(
  (ref) => FavoritesNotifier(),
);
