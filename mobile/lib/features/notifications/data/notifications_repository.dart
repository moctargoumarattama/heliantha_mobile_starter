import '../../../core/api/api_client.dart';
import '../../../shared/models/notification_item.dart';

class NotificationsResult {
  const NotificationsResult({
    required this.items,
    required this.unread,
  });

  final List<NotificationItem> items;
  final int unread;
}

class NotificationsRepository {
  NotificationsRepository(this._api);

  final ApiClient _api;

  Future<NotificationsResult> list() async {
    final response = await _api.dio.get('/v1/notifications');
    final data = response.data['data'] as List<dynamic>? ?? [];
    final meta = Map<String, dynamic>.from(response.data['meta'] as Map? ?? {});
    return NotificationsResult(
      items: data
          .whereType<Map<String, dynamic>>()
          .map(NotificationItem.fromJson)
          .toList(),
      unread: (meta['unread'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> markRead(int id) async {
    await _api.dio.post('/v1/notifications/$id/read');
  }

  Future<void> registerDevice(String token) async {
    await _api.dio.post(
      '/v1/notifications/device',
      data: {
        'token': token,
        'platform': 'android',
      },
    );
  }

  Future<void> unregisterDevice(String token) async {
    await _api.dio.delete(
      '/v1/notifications/device',
      queryParameters: {'token': token},
    );
  }
}
