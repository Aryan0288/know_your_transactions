
import 'package:flutter/material.dart';

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
    );
  }

  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');
  Color get color => Color(colorValue);
}
