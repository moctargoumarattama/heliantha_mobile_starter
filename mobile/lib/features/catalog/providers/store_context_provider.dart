import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/providers.dart';
import '../../../shared/models/store_context.dart';
import '../data/store_context_repository.dart';

final storeContextRepositoryProvider = Provider<StoreContextRepository>(
  (ref) => StoreContextRepository(ref.watch(apiClientProvider)),
);

final storeContextProvider = FutureProvider<StoreContext>(
  (ref) => ref.watch(storeContextRepositoryProvider).context(),
);

final selectedLanguageIdProvider =
    StateNotifierProvider<SelectedLanguageIdNotifier, int?>(
  (ref) =>
      SelectedLanguageIdNotifier(ref.watch(storeContextRepositoryProvider)),
);

final selectedCurrencyIdProvider =
    StateNotifierProvider<SelectedCurrencyIdNotifier, int?>(
  (ref) =>
      SelectedCurrencyIdNotifier(ref.watch(storeContextRepositoryProvider)),
);

class SelectedLanguageIdNotifier extends StateNotifier<int?> {
  SelectedLanguageIdNotifier(this._repository) : super(null) {
    _load();
  }

  final StoreContextRepository _repository;

  Future<void> _load() async {
    state = await _repository.readLanguageId();
  }

  Future<void> select(int id) async {
    state = id;
    await _repository.saveLanguageId(id);
  }
}

class SelectedCurrencyIdNotifier extends StateNotifier<int?> {
  SelectedCurrencyIdNotifier(this._repository) : super(null) {
    _load();
  }

  final StoreContextRepository _repository;

  Future<void> _load() async {
    state = await _repository.readCurrencyId();
  }

  Future<void> select(int id) async {
    state = id;
    await _repository.saveCurrencyId(id);
  }
}
