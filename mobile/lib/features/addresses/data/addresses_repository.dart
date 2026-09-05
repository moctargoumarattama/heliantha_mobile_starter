import '../../../core/api/api_client.dart';
import '../../../shared/models/address.dart';

class AddressesRepository {
  AddressesRepository(this._api);

  final ApiClient _api;

  Future<List<AddressModel>> list() async {
    final response = await _api.dio.get('/v1/addresses');
    final data = response.data['data'] as List<dynamic>? ?? [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(AddressModel.fromJson)
        .toList();
  }

  Future<AddressModel> create(Map<String, dynamic> payload) async {
    final response = await _api.dio.post('/v1/addresses', data: payload);
    return AddressModel.fromJson(
      Map<String, dynamic>.from(response.data['data'] as Map),
    );
  }

  Future<AddressModel> update(
      int addressId, Map<String, dynamic> payload) async {
    final response = await _api.dio.put(
      '/v1/addresses/$addressId',
      data: payload,
    );
    return AddressModel.fromJson(
      Map<String, dynamic>.from(response.data['data'] as Map),
    );
  }
}
