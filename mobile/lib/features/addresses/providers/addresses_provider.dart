import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/providers.dart';
import '../../../shared/models/address.dart';
import '../data/addresses_repository.dart';

final addressesRepositoryProvider = Provider<AddressesRepository>(
  (ref) => AddressesRepository(ref.watch(apiClientProvider)),
);

final addressesProvider = FutureProvider<List<AddressModel>>(
  (ref) => ref.watch(addressesRepositoryProvider).list(),
);
