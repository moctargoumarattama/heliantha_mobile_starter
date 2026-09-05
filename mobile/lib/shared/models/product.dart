class ProductFeature {
  const ProductFeature({
    required this.name,
    required this.value,
  });

  final String name;
  final String value;

  factory ProductFeature.fromJson(Map<String, dynamic> json) {
    return ProductFeature(
      name: (json['name'] ?? '').toString(),
      value: (json['value'] ?? '').toString(),
    );
  }
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.currency,
    required this.currencySymbol,
    required this.available,
    this.currencyId,
    this.reference,
    this.quantity,
    this.descriptionShort,
    this.description,
    this.categoryId,
    this.imageUrl,
    this.features = const [],
  });

  final int id;
  final String name;
  final double price;
  final String currency;
  final String currencySymbol;
  final int? currencyId;
  final bool available;
  final String? reference;
  final int? quantity;
  final String? descriptionShort;
  final String? description;
  final int? categoryId;
  final String? imageUrl;
  final List<ProductFeature> features;

  factory Product.fromJson(Map<String, dynamic> json) {
    final rawFeatures = json['features'] as List<dynamic>? ?? [];
    return Product(
      id: (json['id'] as num).toInt(),
      name: (json['name'] ?? '').toString(),
      price: (json['price'] as num? ?? 0).toDouble(),
      currency: (json['currency'] ?? 'MAD').toString(),
      currencySymbol:
          (json['currency_symbol'] ?? json['currency'] ?? 'MAD').toString(),
      currencyId: (json['currency_id'] as num?)?.toInt(),
      available: json['available'] == true,
      reference: json['reference']?.toString(),
      quantity: (json['quantity'] as num?)?.toInt(),
      descriptionShort: json['description_short']?.toString(),
      description: json['description']?.toString(),
      categoryId: (json['category_id'] as num?)?.toInt(),
      imageUrl: json['image_url']?.toString(),
      features: rawFeatures
          .whereType<Map<String, dynamic>>()
          .map(ProductFeature.fromJson)
          .toList(),
    );
  }
}
