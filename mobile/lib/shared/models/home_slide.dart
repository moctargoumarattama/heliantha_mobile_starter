class HomeSlide {
  const HomeSlide({
    required this.id,
    required this.type,
    required this.imageUrl,
    required this.position,
    this.title,
    this.subtitle,
    this.productId,
    this.targetUrl,
  });

  final String id;
  final String type;
  final String imageUrl;
  final int position;
  final String? title;
  final String? subtitle;
  final int? productId;
  final String? targetUrl;

  bool get isProduct => type == 'product' && productId != null;

  factory HomeSlide.fromJson(Map<String, dynamic> json) {
    return HomeSlide(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      imageUrl: (json['image_url'] ?? '').toString(),
      title: json['title']?.toString(),
      subtitle: json['subtitle']?.toString(),
      productId: (json['product_id'] as num?)?.toInt(),
      targetUrl: json['target_url']?.toString(),
      position: (json['position'] as num? ?? 1).toInt(),
    );
  }
}
