import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_client.dart';
import '../../../shared/models/store_context.dart';

class StoreContextRepository {
  StoreContextRepository(this._api);

  static const _languageKey = 'heliantha_language_id';
  static const _currencyKey = 'heliantha_currency_id';

  final ApiClient _api;

  Future<StoreContext> context() async {
    final response = await _api.dio.get('/v1/store-context');
    return StoreContext.fromJson(
      Map<String, dynamic>.from(response.data['data'] as Map),
    );
  }

  Future<int?> readLanguageId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_languageKey);
  }

  Future<void> saveLanguageId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_languageKey, id);
  }

  Future<int?> readCurrencyId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_currencyKey);
  }

  Future<void> saveCurrencyId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_currencyKey, id);
  }
}
