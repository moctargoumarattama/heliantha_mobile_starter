import '../../../core/api/api_client.dart';
import '../../../shared/models/order.dart';

class OrdersRepository {
  OrdersRepository(this._api);
  final ApiClient _api;

  Future<List<OrderModel>> list() async {
    final response = await _api.dio.get('/v1/orders');
    final data = response.data['data'] as List<dynamic>? ?? [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(OrderModel.fromJson)
        .toList();
  }
}
