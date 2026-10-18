class ModelPendingSms {
  final String id;
  final double amount;
  final String vendorName;
  final DateTime date;
  final String paymentMode;
  final bool isExpense;
  final String rawSmsBody;
  final String status; // 'pending', 'assigned', 'discarded'
  final String? merchantName;
  final String? bankAccount;
  final String? refNumber;
  final String? smartTitle;

  ModelPendingSms({
    required this.id,
    required this.amount,
    required this.vendorName,
    required this.date,
    this.paymentMode = 'online',
    this.isExpense = true,
    required this.rawSmsBody,
    this.status = 'pending',
    this.merchantName,
    this.bankAccount,
    this.refNumber,
    this.smartTitle,
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
      if (merchantName != null) 'merchantName': merchantName,
      if (bankAccount != null) 'bankAccount': bankAccount,
      if (refNumber != null) 'refNumber': refNumber,
      if (smartTitle != null) 'smartTitle': smartTitle,
    };
  }

  factory ModelPendingSms.fromMap(Map<String, dynamic> map, String id) {
    DateTime parsedDate = DateTime.now();
    if (map['date'] != null) {
      parsedDate = DateTime.tryParse(map['date'].toString()) ?? DateTime.now();
    }
    return ModelPendingSms(
      id: id,
      amount: (map['amount'] ?? 0).toDouble(),
      vendorName: map['vendorName'] ?? 'Unknown Vendor',
      date: parsedDate,
      paymentMode: map['paymentMode'] ?? 'online',
      isExpense: map['isExpense'] ?? true,
      rawSmsBody: map['rawSmsBody'] ?? '',
      status: map['status'] ?? 'pending',
      merchantName: map['merchantName'] as String?,
      bankAccount: map['bankAccount'] as String?,
      refNumber: map['refNumber'] as String?,
      smartTitle: map['smartTitle'] as String?,
    );
  }
}
