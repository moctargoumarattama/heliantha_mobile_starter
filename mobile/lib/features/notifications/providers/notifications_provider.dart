import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/providers.dart';
import '../data/notifications_repository.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => NotificationsRepository(ref.watch(apiClientProvider)),
);

final notificationsProvider = FutureProvider<NotificationsResult>(
  (ref) => ref.watch(notificationsRepositoryProvider).list(),
);
