import '../../../core/api/api_client.dart';
import '../../../shared/models/home_slide.dart';

class HomeRepository {
  HomeRepository(this._api);

  final ApiClient _api;
  _CacheEntry<List<HomeSlide>>? _slidesCache;

  static const _slidesCacheTtl = Duration(minutes: 5);

  Future<List<HomeSlide>> slides() async {
    final cached = _slidesCache;
    if (cached != null && cached.isFresh) {
      return cached.value;
    }

    final response = await _api.dio.get('/v1/home/slides');
    final data = response.data['data'] as List<dynamic>? ?? [];
    final slides = data
        .whereType<Map<String, dynamic>>()
        .map(HomeSlide.fromJson)
        .where((slide) => slide.imageUrl.isNotEmpty)
        .toList();
    _slidesCache = _CacheEntry(
      slides,
      DateTime.now().add(_slidesCacheTtl),
    );
    return slides;
  }
}

class _CacheEntry<T> {
  const _CacheEntry(this.value, this.expiresAt);

  final T value;
  final DateTime expiresAt;

  bool get isFresh => DateTime.now().isBefore(expiresAt);
}
