import 'package:flutter/material.dart';
import 'package:know_your_expenses/features/auto_sms/model/model_pending_sms.dart';

class CategoryModel {
  final String id;
  final String name;
  final int iconCodePoint;
  final int colorValue;

  CategoryModel({
    required this.id,
    required this.name,
    required this.iconCodePoint,
    required this.colorValue,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'iconCodePoint': iconCodePoint,
      'colorValue': colorValue,
    };
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map, String id) {
    return CategoryModel(
      id: id,
      name: map['name'] ?? '',
      iconCodePoint: map['iconCodePoint'] ?? Icons.category.codePoint,
      colorValue: map['colorValue'] ?? Colors.grey.value,
    );
  }

  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');
  Color get color => Color(colorValue);
}

class TransactionModel {
  final String id;
  final double amount;
  final String description;
  final String categoryId;
  final String categoryName;
  final int iconCodePoint;
  final int colorValue;
  final DateTime date;
  final String userId;
  final bool isExpense;
  final bool isShared;
  final List<String>? splitWith;
  final Map<String, double>? splitAmounts;
  final String? groupId;
  final String? paymentMode; // 'cash' or 'online'
  final String? smsHash; // Unique identifier for Auto-SMS deduplication
  final String? merchantName;
  final String? bankAccount;
  final String? refNumber;
  final String? rawSmsBody;

  TransactionModel({
    required this.id,
    required this.amount,
    required this.description,
    required this.categoryId,
    required this.categoryName,
    required this.iconCodePoint,
    required this.colorValue,
    required this.date,
    required this.userId,
    this.isExpense = true,
    this.isShared = false,
    this.splitWith,
    this.splitAmounts,
    this.groupId,
    this.paymentMode,
    this.smsHash,
    this.merchantName,
    this.bankAccount,
    this.refNumber,
    this.rawSmsBody,
  });

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'description': description,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'iconCodePoint': iconCodePoint,
      'colorValue': colorValue,
      'date': date.toIso8601String(),
      'userId': userId,
      'isExpense': isExpense,
      'isShared': isShared,
      'splitWith': splitWith,
      'splitAmounts': splitAmounts,
      'groupId': groupId,
      'paymentMode': paymentMode,
      if (smsHash != null) 'smsHash': smsHash,
      if (merchantName != null) 'merchantName': merchantName,
      if (bankAccount != null) 'bankAccount': bankAccount,
      'refNumber': refNumber ?? '',
      if (rawSmsBody != null) 'rawSmsBody': rawSmsBody,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map, String id) {
    return TransactionModel(
      id: id,
      amount: (map['amount'] ?? 0).toDouble(),
      description: map['description'] ?? '',
      categoryId: map['categoryId'] ?? '',
      categoryName: map['categoryName'] ?? '',
      iconCodePoint: map['iconCodePoint'] ?? Icons.shopping_bag.codePoint,
      colorValue: map['colorValue'] ?? Colors.grey.value,
      date: DateTime.parse(map['date'] ?? DateTime.now().toIso8601String()),
      userId: map['userId'] ?? '',
      isExpense: map['isExpense'] ?? true,
      isShared: map['isShared'] ?? false,
      splitWith: map['splitWith'] != null ? List<String>.from(map['splitWith']) : null,
      splitAmounts: map['splitAmounts'] != null
          ? (map['splitAmounts'] as Map<String, dynamic>).map(
              (key, value) => MapEntry(key, (value as num).toDouble()),
            )
          : null,
      groupId: map['groupId'] as String?,
      paymentMode: map['paymentMode'] as String?,
      smsHash: map['smsHash'] as String?,
      merchantName: map['merchantName'] as String?,
      bankAccount: map['bankAccount'] as String?,
      refNumber: map['refNumber'] as String?,
      rawSmsBody: map['rawSmsBody'] as String?,
    );
  }

  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');
  Color get color => Color(colorValue);

  ModelPendingSms toPendingSms() {
    return ModelPendingSms(
      id: smsHash ?? id,
      amount: amount,
      vendorName: merchantName ?? 'Unknown',
      date: date,
      paymentMode: paymentMode ?? 'online',
      isExpense: isExpense,
      rawSmsBody: rawSmsBody ?? '',
      merchantName: merchantName,
      bankAccount: bankAccount,
      refNumber: refNumber,
    );
  }
}
