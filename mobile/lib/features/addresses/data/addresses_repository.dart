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
}
