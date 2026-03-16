// import 'dart:convert';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/legacy.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:know_your_expenses/features/home/view_model/view_model_home.dart';
import 'package:know_your_expenses/features/transaction/model/model_transaction.dart';
// import 'package:cloudinary/cloudinary.dart';
// import 'package:cloudinary_url_gen/cloudinary.dart';


import 'package:cloudinary_api/uploader/cloudinary_uploader.dart';
import 'package:cloudinary_url_gen/cloudinary.dart';
import 'package:cloudinary_api/src/request/model/uploader_params.dart';

final transactionViewModelProvider =
    StateNotifierProvider<TransactionViewModel, AsyncValue<void>>((ref) {
      return TransactionViewModel(ref);
    });

enum StatisticsPeriod { day, week, month, year }

final selectedPeriodProvider = StateProvider<StatisticsPeriod>(
  (ref) => StatisticsPeriod.week,
);
final touchedIndexProvider = StateProvider<int>((ref) => -1);

final categoriesProvider = StreamProvider<List<CategoryModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);

  final firestore = FirebaseFirestore.instance;

  // Combine default categories and user-added categories
  return firestore
      .collection('users')
      .doc(user.uid)
      .collection('categories')
      .snapshots()
      .map((snapshot) {
        final userCategories = snapshot.docs
            .map((doc) => CategoryModel.fromMap(doc.data(), doc.id))
            .toList();

        final defaultCategories = [
          CategoryModel(
            id: 'food',
            name: 'Food',
            iconCodePoint: Icons.restaurant.codePoint,
            colorValue: Colors.orange.value,
          ),
          CategoryModel(
            id: 'transport',
            name: 'Transport',
            iconCodePoint: Icons.directions_bus.codePoint,
            colorValue: Colors.blue.value,
          ),
          CategoryModel(
            id: 'shopping',
            name: 'Shopping',
            iconCodePoint: Icons.shopping_bag.codePoint,
            colorValue: Colors.pink.value,
          ),
          CategoryModel(
            id: 'utilities',
            name: 'Utilities',
            iconCodePoint: Icons.power.codePoint,
            colorValue: Colors.amber.value,
          ),
          CategoryModel(
            id: 'entertainment',
            name: 'Entertainment',
            iconCodePoint: Icons.movie.codePoint,
            colorValue: Colors.purple.value,
          ),
          CategoryModel(
            id: 'health',
            name: 'Health',
            iconCodePoint: Icons.medical_services.codePoint,
            colorValue: Colors.red.value,
          ),
        ];

        final otherCategory = CategoryModel(
          id: 'other',
          name: 'Other',
          iconCodePoint: Icons.more_horiz.codePoint,
          colorValue: Colors.grey.value,
        );

        // Merge lists, avoiding duplicates by name if any
        final allCategories = [...defaultCategories];
        for (var userCat in userCategories) {
          if (!allCategories.any(
                (element) =>
                    element.name.toLowerCase() == userCat.name.toLowerCase(),
              ) &&
              userCat.name.toLowerCase() != 'other') {
            allCategories.add(userCat);
          }
        }

        // Always add "Other" at the end
        allCategories.add(otherCategory);

        return allCategories;
      });
});

final transactionsStreamProvider = StreamProvider<List<TransactionModel>>((
  ref,
) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('transactions')
      .orderBy('date', descending: true)
      .snapshots()
      .map((snapshot) {
        return snapshot.docs
            .map((doc) => TransactionModel.fromMap(doc.data(), doc.id))
            .toList();
      });
});

final transactionStatsProvider = Provider<TransactionStats>((ref) {
  final transactions = ref.watch(transactionsStreamProvider).value ?? [];

  double totalIncome = 0;
  double totalExpense = 0;

  for (var t in transactions) {
    if (t.isExpense) {
      totalExpense += t.amount;
    } else {
      totalIncome += t.amount;
    }
  }

  return TransactionStats(
    totalBalance: totalIncome - totalExpense,
    totalIncome: totalIncome,
    totalExpense: totalExpense,
  );
});

class TransactionStats {
  final double totalBalance;
  final double totalIncome;
  final double totalExpense;

  TransactionStats({
    required this.totalBalance,
    required this.totalIncome,
    required this.totalExpense,
  });
}

final rotationOffsetProvider = StateProvider<double>((ref) => 0);

final filteredTransactionsProvider = Provider<List<TransactionModel>>((ref) {
  final transactions = ref.watch(transactionsStreamProvider).value ?? [];
  final period = ref.watch(selectedPeriodProvider);
  final now = DateTime.now();

  return transactions.where((t) {
    if (period == StatisticsPeriod.day) {
      // Today (from midnight)
      final todayMidnight = DateTime(now.year, now.month, now.day);
      return t.date.isAfter(todayMidnight);
    } else if (period == StatisticsPeriod.week) {
      // Last 7 days
      return t.date.isAfter(now.subtract(const Duration(days: 7)));
    } else if (period == StatisticsPeriod.month) {
      // Last 30 days
      return t.date.isAfter(now.subtract(const Duration(days: 30)));
    } else {
      // Current Calendar Year
      return t.date.year == now.year;
    }
  }).toList();
});

final topSpendingProvider = Provider<List<TransactionModel>>((ref) {
  final transactions = ref.watch(filteredTransactionsProvider);
  final expenses = transactions.where((t) => t.isExpense).toList();

  expenses.sort((a, b) => b.amount.compareTo(a.amount));
  return expenses;
});

class FinancialInsight {
  final int healthScore;
  final String healthLabel;
  final String healthMessage;
  final double forecastAmount;
  final List<InsightWisdom> wisdoms;

  FinancialInsight({
    required this.healthScore,
    required this.healthLabel,
    required this.healthMessage,
    required this.forecastAmount,
    required this.wisdoms,
  });
}

class InsightWisdom {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  InsightWisdom({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

final financialInsightsProvider = Provider<FinancialInsight>((ref) {
  final allTransactions = ref.watch(transactionsStreamProvider).value ?? [];
  final now = DateTime.now();

  // 1. Calculate Expenses (Calendar Month)
  final startOfCurrentMonth = DateTime(now.year, now.month, 1);
  final startOfPrevMonth = DateTime(now.year, now.month - 1, 1);

  final currentMonthExpenses = allTransactions
      .where(
        (t) =>
            t.isExpense &&
            (t.date.isAfter(startOfCurrentMonth) ||
                t.date.isAtSameMomentAs(startOfCurrentMonth)),
      )
      .toList();

  final prevMonthExpenses = allTransactions
      .where(
        (t) =>
            t.isExpense &&
            (t.date.isAfter(startOfPrevMonth) ||
                t.date.isAtSameMomentAs(startOfPrevMonth)) &&
            t.date.isBefore(startOfCurrentMonth),
      )
      .toList();

  final currentTotal = currentMonthExpenses.fold(
    0.0,
    (sum, t) => sum + t.amount,
  );
  final prevTotal = prevMonthExpenses.fold(0.0, (sum, t) => sum + t.amount);

  final currentIncome = allTransactions
      .where(
        (t) =>
            !t.isExpense &&
            (t.date.isAfter(startOfCurrentMonth) ||
                t.date.isAtSameMomentAs(startOfCurrentMonth)),
      )
      .fold(0.0, (sum, t) => sum + t.amount);

  // 2. Health Score Logic
  int score = 75; // Baseline
  if (prevTotal > 0) {
    if (currentTotal < prevTotal)
      score += 10;
    else
      score -= 10;
  }

  if (currentIncome > 0) {
    final savingsRate = (currentIncome - currentTotal) / currentIncome;
    if (savingsRate > 0.2)
      score += 10;
    else if (savingsRate < 0)
      score -= 15;
  }

  score = score.clamp(10, 100);

  String label = "Good";
  String message = "Your spending is stable. Try to save 5% more next month.";

  if (score >= 85) {
    label = "Excellent";
    message = "Outstanding! You're managing your finances like a pro.";
  } else if (score < 50) {
    label = "Warning";
    message =
        "Your expenses are high compared to your income. Review your 'Other' category.";
  }

  // 3. Wisdom Logic
  final List<InsightWisdom> wisdoms = [];

  // Categorical insight
  final Map<String, double> catTotals = {};
  for (final t in currentMonthExpenses) {
    catTotals[t.categoryName] = (catTotals[t.categoryName] ?? 0) + t.amount;
  }

  if (catTotals.isNotEmpty) {
    final topCat = catTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final highest = topCat.first;
    wisdoms.add(
      InsightWisdom(
        title: "High ${highest.key} Spending",
        description:
            "You spent \₹${highest.value.toStringAsFixed(0)} on ${highest.key}. This is ${((highest.value / currentTotal) * 100).toStringAsFixed(0)}% of your monthly budget.",
        icon: Icons.analytics,
        color: Colors.purple,
      ),
    );
  }

  if (currentTotal > prevTotal && prevTotal > 0) {
    wisdoms.add(
      InsightWisdom(
        title: "Spending Increase",
        description:
            "Your expenses increased by \₹${(currentTotal - prevTotal).toStringAsFixed(0)} compared to last month.",
        icon: Icons.trending_up,
        color: Colors.redAccent,
      ),
    );
  }

  // Handle Savings / Income Wisdom
  if (currentIncome == 0) {
    wisdoms.add(
      InsightWisdom(
        title: "Track Your Income",
        description:
            "You haven't added any income this month. Add it to see your real savings and financial health score!",
        icon: Icons.account_balance_wallet,
        color: Colors.blueAccent,
      ),
    );
  } else if (currentIncome > currentTotal) {
    wisdoms.add(
      InsightWisdom(
        title: "Saving Power",
        description:
            "Great! You have saved \₹${(currentIncome - currentTotal).toStringAsFixed(0)} this month.",
        icon: Icons.savings,
        color: Colors.green,
      ),
    );
  } else if (currentTotal > currentIncome) {
    wisdoms.add(
      InsightWisdom(
        title: "Over Budget",
        description:
            "You've spent \₹${(currentTotal - currentIncome).toStringAsFixed(0)} more than your income. Consider reviewing unnecessary expenses.",
        icon: Icons.warning_amber_rounded,
        color: Colors.orange,
      ),
    );
  }

  return FinancialInsight(
    healthScore: score,
    healthLabel: label,
    healthMessage: message,
    forecastAmount: currentTotal * 1.08, // Dynamic estimate
    wisdoms: wisdoms,
  );
});

final historySelectedMonthProvider = StateProvider<int>(
  (ref) => DateTime.now().month,
);
final historySelectedYearProvider = StateProvider<int>(
  (ref) => DateTime.now().year,
);

final monthlyHistoryTransactionsProvider = Provider<List<TransactionModel>>((
  ref,
) {
  final transactions = ref.watch(transactionsStreamProvider).value ?? [];
  final month = ref.watch(historySelectedMonthProvider);
  final year = ref.watch(historySelectedYearProvider);

  return transactions
      .where((t) => t.date.month == month && t.date.year == year)
      .toList();
});

final userDataProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final user = ref.watch(authStateProvider).value;

  if (user == null) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((doc) => doc.data());
});

class TransactionViewModel extends StateNotifier<AsyncValue<void>> {
  final Ref ref;
  TransactionViewModel(this.ref) : super(const AsyncValue.data(null));

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  Future<bool> addTransaction({
    required double amount,
    required String description,
    required CategoryModel category,
    DateTime? date,
    bool isExpense = true,
  }) async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return false;

    state = const AsyncValue.loading();
    try {
      final transaction = TransactionModel(
        id: '',
        amount: amount,
        description: description,
        categoryId: category.id,
        categoryName: category.name,
        iconCodePoint: category.iconCodePoint,
        colorValue: category.colorValue,
        date: date ?? DateTime.now(),
        userId: user.uid,
        isExpense: isExpense,
      );

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('transactions')
          .add(transaction.toMap());

      state = const AsyncValue.data(null);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }
  // ...

  Future<bool> addCategory({
    required String name,
    required IconData icon,
    required Color color,
  }) async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return false;

    try {
      final category = CategoryModel(
        id: '',
        name: name,
        iconCodePoint: icon.codePoint,
        colorValue: color.value,
      );

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('categories')
          .add(category.toMap());

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateProfileImage() async {
    print("pickedFile ---111111");
    final user = ref.read(firebaseAuthProvider).currentUser;
    print("user ---- pickedFile ---$user");
    if (user == null) return false;

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      print("pickedFile --- $pickedFile");

      if (pickedFile == null) return false;

      state = const AsyncValue.loading();

      // Cloudinary SDK upload
      // final File file = File(pickedFile.path);
      // Cloudinary cloudinary = Cloudinary.fromCloudName(cloudName: "dl0b0wqdk");
      
      // final response = await cloudinary.uploader().upload(
      //   file,
      //   params: UploadParams(
      //     uploadPreset: "dl0b0wqdk",
      //     publicId: "profile_${user.uid}",
      //     // user snippet has type: "raw" but 'image' is default and correct, we can pass it if required, but let's test without 'raw' first since it's an image
      //   ),
      // );

      final File file = File(pickedFile.path);


      String? filepath = await uploadImageDirectly(file,"dl0b0wqdk","know-your-transaction");

      print("filepath ---- ${filepath}");

      // final cloudinary = Cloudinary.fromCloudName(
      //   cloudName: "dl0b0wqdk",
      // );
      //
      // final response = await cloudinary.uploader().upload(
      //   file.path,
      //   params: UploadParams(
      //     uploadPreset: "know-your-transaction",   // your upload preset name
      //     publicId: "profile_${user.uid}",
      //     folder: 'public',
      //   ),
      // );
      //
      // if (response != null && response.data != null) {
      //   final imageUrl = response.data!.secureUrl;
      //   print("Uploaded URL: $imageUrl");
      // } else {
      //   print("Upload failed");
      // }


      // print("Upload success: ${response?.data}");

      // if (response != null && response.data?.url != null) {
      if (filepath!=null) {
        // final downloadUrl = response.secureUrl!;
        // final downloadUrl = response.data?.url;
        final downloadUrl = filepath;

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'photoUrl': downloadUrl});

        state = const AsyncValue.data(null);
        return true;
      } else {
        state = AsyncValue.error(
          "Upload failed: Invalid response from Cloudinary",
          StackTrace.current,
        );
        return false;
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }
}

Future<String?> uploadImageDirectly(File imageFile, String cloudName, String uploadPreset) async {
  final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
  final request = http.MultipartRequest('POST', uri)
    ..fields['upload_preset'] = uploadPreset
    ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

  print("request --- $request");
  final response = await request.send();
  print("response --- $response");
  print("response.statusCode --- ${response.statusCode}");


  if (response.statusCode == 200) {
    final responseData = await response.stream.toBytes();
    print("responseData --- ${responseData}");
    final result = jsonDecode(utf8.decode(responseData));
    print("responseData -result-- ${result}");
    final secureUrl = result['secure_url'];
    print("secureUrl -secureUrl-- ${secureUrl}");
    print('Uploaded image URL: $secureUrl');
    return secureUrl;
  } else {
    print('Upload failed with status: ${response.statusCode}');
    return null;
  }
}

final bottomNavIndexProvider = StateProvider<int>((ref) => 0);
