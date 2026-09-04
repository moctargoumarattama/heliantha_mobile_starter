import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/providers.dart';
import '../../../shared/models/home_slide.dart';
import '../data/home_repository.dart';

final homeRepositoryProvider = Provider<HomeRepository>(
  (ref) => HomeRepository(ref.watch(apiClientProvider)),
);

final homeSlidesProvider = FutureProvider<List<HomeSlide>>(
  (ref) => ref.watch(homeRepositoryProvider).slides(),
);
