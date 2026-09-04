class OrderModel {
  const OrderModel({
    required this.id,
    required this.reference,
    required this.totalPaid,
    this.stateId,
    this.stateName,
    this.dateAdd,
  });

  final int id;
  final String reference;
  final double totalPaid;
  final int? stateId;
  final String? stateName;
  final String? dateAdd;

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: (json['id'] as num).toInt(),
      reference: (json['reference'] ?? '').toString(),
      totalPaid: (json['total_paid'] as num? ?? 0).toDouble(),
      stateId: (json['state_id'] as num?)?.toInt(),
      stateName: json['state_name']?.toString(),
      dateAdd: json['date_add']?.toString(),
    );
  }
}
