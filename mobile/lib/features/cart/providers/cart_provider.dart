import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/product.dart';
import '../domain/cart_item.dart';

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super(const []);

  void add(Product product) {
    final index = state.indexWhere((x) => x.product.id == product.id);
    if (index == -1) {
      state = [...state, CartItem(product: product, quantity: 1)];
      return;
    }
    final copy = [...state];
    copy[index] = copy[index].copyWith(quantity: copy[index].quantity + 1);
    state = copy;
  }

  void decrement(int productId) {
    final index = state.indexWhere((x) => x.product.id == productId);
    if (index == -1) {
      return;
    }
    final copy = [...state];
    final current = copy[index];
    if (current.quantity <= 1) {
      copy.removeAt(index);
    } else {
      copy[index] = current.copyWith(quantity: current.quantity - 1);
    }
    state = copy;
  }

  void remove(int productId) {
    state = state.where((x) => x.product.id != productId).toList();
  }

  void clear() => state = const [];
}

final cartProvider =
    StateNotifierProvider<CartNotifier, List<CartItem>>(
  (ref) => CartNotifier(),
);

final cartTotalProvider = Provider<double>(
  (ref) => ref.watch(cartProvider).fold(0, (sum, item) => sum + item.total),
);
