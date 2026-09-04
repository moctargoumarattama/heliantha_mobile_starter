class StoreLanguage {
  const StoreLanguage({
    required this.id,
    required this.name,
    required this.active,
    required this.isRtl,
    this.isoCode,
    this.locale,
    this.languageCode,
  });

  final int id;
  final String name;
  final bool active;
  final bool isRtl;
  final String? isoCode;
  final String? locale;
  final String? languageCode;

  factory StoreLanguage.fromJson(Map<String, dynamic> json) {
    return StoreLanguage(
      id: (json['id'] as num).toInt(),
      name: (json['name'] ?? '').toString(),
      active: json['active'] == true,
      isRtl: json['is_rtl'] == true,
      isoCode: json['iso_code']?.toString(),
      locale: json['locale']?.toString(),
      languageCode: json['language_code']?.toString(),
    );
  }
}

class StoreCurrency {
  const StoreCurrency({
    required this.id,
    required this.name,
    required this.isoCode,
    required this.symbol,
    required this.precision,
    required this.conversionRate,
    required this.active,
  });

  final int id;
  final String name;
  final String isoCode;
  final String symbol;
  final int precision;
  final double conversionRate;
  final bool active;

  factory StoreCurrency.fromJson(Map<String, dynamic> json) {
    return StoreCurrency(
      id: (json['id'] as num).toInt(),
      name: (json['name'] ?? '').toString(),
      isoCode: (json['iso_code'] ?? '').toString(),
      symbol: (json['symbol'] ?? json['iso_code'] ?? '').toString(),
      precision: (json['precision'] as num? ?? 2).toInt(),
      conversionRate: (json['conversion_rate'] as num? ?? 1).toDouble(),
      active: json['active'] == true,
    );
  }
}

class StoreContext {
  const StoreContext({
    required this.defaultLanguageId,
    required this.languages,
    required this.defaultCurrencyId,
    required this.currencies,
  });

  final int? defaultLanguageId;
  final List<StoreLanguage> languages;
  final int? defaultCurrencyId;
  final List<StoreCurrency> currencies;

  factory StoreContext.fromJson(Map<String, dynamic> json) {
    final language = Map<String, dynamic>.from(json['language'] as Map? ?? {});
    final currency = Map<String, dynamic>.from(json['currency'] as Map? ?? {});
    final languages = language['available'] as List<dynamic>? ?? [];
    final currencies = currency['available'] as List<dynamic>? ?? [];

    return StoreContext(
      defaultLanguageId: (language['default_id'] as num?)?.toInt(),
      languages: languages
          .whereType<Map<String, dynamic>>()
          .map(StoreLanguage.fromJson)
          .toList(),
      defaultCurrencyId: (currency['default_id'] as num?)?.toInt(),
      currencies: currencies
          .whereType<Map<String, dynamic>>()
          .map(StoreCurrency.fromJson)
          .toList(),
    );
  }

  StoreLanguage? languageById(int? id) {
    for (final language in languages) {
      if (language.id == id) {
        return language;
      }
    }
    return null;
  }

  int? effectiveLanguageId(int? selectedId) {
    return languageById(selectedId)?.id ?? defaultLanguageId;
  }

  int? effectiveCurrencyId(int? selectedId) {
    for (final currency in currencies) {
      if (currency.id == selectedId) {
        return currency.id;
      }
    }
    return defaultCurrencyId;
  }
}
