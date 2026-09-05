class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.metadata,
    this.orderId,
    this.productId,
    this.readAt,
  });

  final int id;
  final String type;
  final String title;
  final String body;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;
  final int? orderId;
  final int? productId;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: (json['id'] as num).toInt(),
      type: (json['type'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      orderId: (json['order_id'] as num?)?.toInt(),
      productId: (json['product_id'] as num?)?.toInt(),
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
      readAt: DateTime.tryParse((json['read_at'] ?? '').toString()),
    );
  }
}
