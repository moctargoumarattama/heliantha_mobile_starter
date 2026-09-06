import '../../../core/api/api_client.dart';
import '../../../core/storage/token_storage.dart';

class AuthRepository {
  AuthRepository(this._api, this._storage);

  final ApiClient _api;
  final TokenStorage _storage;

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await _api.dio.post(
      '/v1/auth/login',
      data: {
        'email': email,
        'password': password,
      },
    );
    final data = Map<String, dynamic>.from(response.data['data'] as Map);
    await _storage.save(data['access_token'].toString());
    return data;
  }

  Future<Map<String, dynamic>> register({
    required String firstname,
    required String lastname,
    required String email,
    required String password,
  }) async {
    final response = await _api.dio.post(
      '/v1/auth/register',
      data: {
        'firstname': firstname,
        'lastname': lastname,
        'email': email,
        'password': password,
      },
    );
    final data = Map<String, dynamic>.from(response.data['data'] as Map);
    await _storage.save(data['access_token'].toString());
    return data;
  }

  Future<Map<String, dynamic>?> me() async {
    try {
      final response = await _api.dio.get('/v1/me');
      return Map<String, dynamic>.from(response.data['data'] as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() => _storage.clear();
}
