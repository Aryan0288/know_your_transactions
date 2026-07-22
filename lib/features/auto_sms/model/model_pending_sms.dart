class ModelPendingSms {
  final String id;
  final double amount;
  final String vendorName;
  final DateTime date;
  final String paymentMode;
  final bool isExpense;
  final String rawSmsBody;
  final String status; // 'pending', 'assigned', 'discarded'

  ModelPendingSms({
    required this.id,
    required this.amount,
    required this.vendorName,
    required this.date,
    this.paymentMode = 'online',
    this.isExpense = true,
    required this.rawSmsBody,
    this.status = 'pending',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'vendorName': vendorName,
      'date': date.toIso8601String(),
      'paymentMode': paymentMode,
      'isExpense': isExpense,
      'rawSmsBody': rawSmsBody,
      'status': status,
    };
  }

  factory ModelPendingSms.fromMap(Map<String, dynamic> map, String id) {
    return ModelPendingSms(
      id: id,
      amount: (map['amount'] ?? 0).toDouble(),
      vendorName: map['vendorName'] ?? 'Unknown Vendor',
      date: DateTime.parse(map['date'] ?? DateTime.now().toIso8601String()),
      paymentMode: map['paymentMode'] ?? 'online',
      isExpense: map['isExpense'] ?? true,
      rawSmsBody: map['rawSmsBody'] ?? '',
      status: map['status'] ?? 'pending',
    );
  }
}
