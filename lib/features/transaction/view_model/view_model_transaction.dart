import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/legacy.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:know_your_expenses/features/helper/notification_helper.dart';
import 'package:know_your_expenses/features/home/view_model/view_model_home.dart';
import 'package:know_your_expenses/features/transaction/model/model_transaction.dart';
import 'package:know_your_expenses/features/home/view_model/view_model_group.dart';
import 'package:know_your_expenses/features/auto_sms/service/auto_sms_service.dart';
import 'package:know_your_expenses/features/auto_sms/service/sms_parser_service.dart';
import 'package:know_your_expenses/features/auto_sms/view_model/auto_sms_provider.dart';



final transactionViewModelProvider =
    StateNotifierProvider<TransactionViewModel, AsyncValue<void>>((ref) {
      return TransactionViewModel(ref);
    });

enum StatisticsPeriod { all, day, week, month, year }

enum StatisticsType { expense, income }

final selectedPeriodProvider = StateProvider<StatisticsPeriod>(
  (ref) => StatisticsPeriod.all,
);
final statisticsTypeProvider = StateProvider<StatisticsType>(
  (ref) => StatisticsType.expense,
);
final touchedIndexProvider = StateProvider<int>((ref) => -1);

final showShakeOnboardingProvider = StateProvider<bool>((ref) => true);

final userGroupIdProvider = Provider<String?>((ref) {
  final userData = ref.watch(userDataProvider).value;
  return userData?['groupId'] as String?;
});

final personalCategoriesStreamProvider = StreamProvider<List<CategoryModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);

  final firestore = FirebaseFirestore.instance;

  return firestore
      .collection('users')
      .doc(user.uid)
      .collection('categories')
      .snapshots()
      .map((snapshot) {
        return snapshot.docs
            .map((doc) => CategoryModel.fromMap(doc.data(), doc.id))
            .toList();
      });
});

final groupCategoriesStreamProvider = StreamProvider<List<CategoryModel>>((ref) {
  final groupId = ref.watch(userGroupIdProvider);
  if (groupId == null) return Stream.value([]);

  final firestore = FirebaseFirestore.instance;

  return firestore
      .collection('groups')
      .doc(groupId)
      .collection('categories')
      .snapshots()
      .map((snapshot) {
        return snapshot.docs
            .map((doc) => CategoryModel.fromMap(doc.data(), doc.id))
            .toList();
      });
});

final kDefaultCategories = [
  CategoryModel(
    id: 'investments',
    name: 'Investment',
    iconCodePoint: Icons.trending_up_rounded.codePoint,
    colorValue: const Color(0xFF00897B).toARGB32(),
  ),
  CategoryModel(
    id: 'food',
    name: 'Food',
    iconCodePoint: Icons.restaurant_rounded.codePoint,
    colorValue: const Color(0xFFFB8C00).toARGB32(),
  ),
  CategoryModel(
    id: 'groceries',
    name: 'Groceries',
    iconCodePoint: Icons.shopping_cart_rounded.codePoint,
    colorValue: const Color(0xFF43A047).toARGB32(),
  ),
  CategoryModel(
    id: 'shopping',
    name: 'Shopping',
    iconCodePoint: Icons.shopping_bag_rounded.codePoint,
    colorValue: const Color(0xFFE91E63).toARGB32(),
  ),
  CategoryModel(
    id: 'transport',
    name: 'Transport',
    iconCodePoint: Icons.directions_car_rounded.codePoint,
    colorValue: const Color(0xFF1E88E5).toARGB32(),
  ),
  CategoryModel(
    id: 'utilities',
    name: 'Bills & Utilities',
    iconCodePoint: Icons.receipt_long_rounded.codePoint,
    colorValue: const Color(0xFFFFA000).toARGB32(),
  ),
  CategoryModel(
    id: 'bills_emi',
    name: 'Cards & EMI',
    iconCodePoint: Icons.credit_card_rounded.codePoint,
    colorValue: const Color(0xFF3949AB).toARGB32(),
  ),
  CategoryModel(
    id: 'rent',
    name: 'Rent',
    iconCodePoint: Icons.home_work_rounded.codePoint,
    colorValue: const Color(0xFF8D6E63).toARGB32(),
  ),
  CategoryModel(
    id: 'health',
    name: 'Health',
    iconCodePoint: Icons.medical_services_rounded.codePoint,
    colorValue: const Color(0xFFE53935).toARGB32(),
  ),
  CategoryModel(
    id: 'entertainment',
    name: 'Entertainment',
    iconCodePoint: Icons.movie_filter_rounded.codePoint,
    colorValue: const Color(0xFF8E24AA).toARGB32(),
  ),
  CategoryModel(
    id: 'fuel',
    name: 'Fuel',
    iconCodePoint: Icons.local_gas_station_rounded.codePoint,
    colorValue: const Color(0xFFD32F2F).toARGB32(),
  ),
  CategoryModel(
    id: 'education',
    name: 'Education',
    iconCodePoint: Icons.school_rounded.codePoint,
    colorValue: const Color(0xFF5E35B1).toARGB32(),
  ),
  CategoryModel(
    id: 'personal_care',
    name: 'Personal Care',
    iconCodePoint: Icons.face_retouching_natural_rounded.codePoint,
    colorValue: const Color(0xFF00ACC1).toARGB32(),
  ),
  CategoryModel(
    id: 'donations',
    name: 'Donations',
    iconCodePoint: Icons.volunteer_activism_rounded.codePoint,
    colorValue: const Color(0xFFD81B60).toARGB32(),
  ),
  CategoryModel(
    id: 'transfer',
    name: 'Transfers',
    iconCodePoint: Icons.swap_horiz_rounded.codePoint,
    colorValue: const Color(0xFF546E7A).toARGB32(),
  ),
  CategoryModel(
    id: 'self_transfer',
    name: 'Self Transfer',
    iconCodePoint: Icons.sync_alt_rounded.codePoint,
    colorValue: const Color(0xFF607D8B).toARGB32(),
  ),
  CategoryModel(
    id: 'income',
    name: 'Received',
    iconCodePoint: Icons.payments_rounded.codePoint,
    colorValue: const Color(0xFF2E7D32).toARGB32(),
  ),
  CategoryModel(
    id: 'refund',
    name: 'Refunds & Cashback',
    iconCodePoint: Icons.redeem_rounded.codePoint,
    colorValue: const Color(0xFF00897B).toARGB32(),
  ),
  CategoryModel(
    id: 'returns',
    name: 'Returns & Div',
    iconCodePoint: Icons.savings_rounded.codePoint,
    colorValue: const Color(0xFF00838F).toARGB32(),
  ),
  CategoryModel(
    id: 'online',
    name: 'Online',
    iconCodePoint: Icons.account_balance_wallet_rounded.codePoint,
    colorValue: const Color(0xFF429690).toARGB32(),
  ),
  CategoryModel(
    id: 'other',
    name: 'Other',
    iconCodePoint: Icons.category_rounded.codePoint,
    colorValue: const Color(0xFF757575).toARGB32(),
  ),
];

final categoriesProvider = StreamProvider<List<CategoryModel>>((ref) {
  final personalCategories = ref.watch(personalCategoriesStreamProvider).value ?? [];
  final groupCategories = ref.watch(groupCategoriesStreamProvider).value ?? [];

  final defaultCategories = kDefaultCategories;

  final otherCategory = CategoryModel(
    id: 'other',
    name: 'Other',
    iconCodePoint: Icons.more_horiz.codePoint,
    colorValue: Colors.grey.toARGB32(),
  );

  // Merge lists, avoiding duplicates by name
  final allCategories = [...defaultCategories];
  
  // Add personal categories
  for (var userCat in personalCategories) {
    if (!allCategories.any(
          (element) => element.name.toLowerCase() == userCat.name.toLowerCase(),
        ) &&
        userCat.name.toLowerCase() != 'other') {
      allCategories.add(userCat);
    }
  }

  // Add group categories
  for (var groupCat in groupCategories) {
    if (!allCategories.any(
          (element) => element.name.toLowerCase() == groupCat.name.toLowerCase(),
        ) &&
        groupCat.name.toLowerCase() != 'other') {
      allCategories.add(groupCat);
    }
  }

  // Always add "Other" at the end
  allCategories.add(otherCategory);

  return Stream.value(allCategories);
});

bool _isAutoHealingRunning = false;
bool _hasPendingHeal = false;
List<TransactionModel>? _pendingHealTransactions;
String? _pendingHealUserId;
List<CategoryModel>? _pendingHealCategories;

void _queueAutoHeal(List<TransactionModel> transactions, String userId, List<CategoryModel> categories) {
  if (transactions.isEmpty || userId.isEmpty) return;
  if (_isAutoHealingRunning) {
    _hasPendingHeal = true;
    _pendingHealTransactions = transactions;
    _pendingHealUserId = userId;
    _pendingHealCategories = categories;
    return;
  }
  _runAutoHeal(transactions, userId, categories);
}

void _runAutoHeal(List<TransactionModel> transactions, String userId, List<CategoryModel> categories) async {
  _isAutoHealingRunning = true;
  _hasPendingHeal = false;

  try {
    final userTxCol = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('transactions');
    final batch = FirebaseFirestore.instance.batch();
    int batchOps = 0;

    final Map<String, List<TransactionModel>> refMap = {};
    final Map<String, List<TransactionModel>> noRefDupMap = {};
    final Set<String> deletedTxIds = {};

    for (final tx in transactions) {
      // 0. Auto-Healer Purge: Use SmsParserService as single source of truth to purge any fake/spam/scam SMS
      if (tx.rawSmsBody != null && tx.rawSmsBody!.isNotEmpty) {
        final rawBody = tx.rawSmsBody!;
        final bodyLower = rawBody.toLowerCase();
        final isMergedSelfTransferBody = rawBody.contains('\n---\n');

        final bool isLegacySpam = bodyLower.contains('start sip') ||
            bodyLower.contains('start sips') ||
            bodyLower.contains('start investing') ||
            bodyLower.contains('invest from') ||
            bodyLower.contains('build wealth') ||
            bodyLower.contains('grow wealth') ||
            bodyLower.contains('credited instantly') ||
            bodyLower.contains('ready to be credited') ||
            bodyLower.contains('can be credited') ||
            bodyLower.contains('get instant funds credited') ||
            bodyLower.contains('if debited') ||
            bodyLower.contains('use code: claim') ||
            bodyLower.contains('open demat') ||
            bodyLower.contains('open trading account') ||
            bodyLower.contains('bit.ly/') ||
            bodyLower.contains('dearclient') ||
            bodyLower.contains('pleasecheck') ||
            bodyLower.contains('check account details') ||
            bodyLower.contains('regardsitisbl') ||
            bodyLower.contains('itisbl');

        final bool isPreDebitNotice = (bodyLower.contains('is due on') ||
                bodyLower.contains('due on') ||
                bodyLower.contains('ensure availability of fund')) &&
            (bodyLower.contains('mandate debit') || bodyLower.contains('nach mandate'));

        // Re-validate single SMS through SmsParserService so any newly added spam/anchor rules automatically heal old builds
        final bool isRejectedByParser = !isMergedSelfTransferBody &&
            SmsParserService.parseSms(rawBody, messageTimestamp: tx.date) == null;

        if (isLegacySpam || isPreDebitNotice || isRejectedByParser) {
          debugPrint('[AutoHeal] Purging non-financial/fake SMS transaction ${tx.id} (${tx.categoryName}, ₹${tx.amount})');
          batch.delete(userTxCol.doc(tx.id));
          batchOps++;
          deletedTxIds.add(tx.id);
          if (tx.smsHash != null && tx.smsHash!.isNotEmpty) {
            await AutoSmsService.markHashDiscarded(tx.smsHash!);
          }
          continue;
        }
      }

      String? r = tx.refNumber;
      String? bankAcc = tx.bankAccount;
      final Map<String, dynamic> updateData = {};

      // 1. Smart Retroactive Healer for Legacy / Native-Receiver Transactions with empty or null refNumber / bankAccount
      if ((r == null || r.trim().isEmpty) && tx.rawSmsBody != null && tx.rawSmsBody!.isNotEmpty) {
        final newlyFoundRef = SmsParserService.extractReference(tx.rawSmsBody!);
        if (newlyFoundRef != null && newlyFoundRef.isNotEmpty) {
          r = newlyFoundRef;
          updateData['refNumber'] = r;
          debugPrint('[AutoHeal] Backfilled missing refNumber on tx ${tx.id}: $newlyFoundRef');
        }
      }

      if ((bankAcc == null || bankAcc.trim().isEmpty) && tx.rawSmsBody != null && tx.rawSmsBody!.isNotEmpty) {
        final newlyFoundBank = SmsParserService.extractBankAccount(tx.rawSmsBody!);
        if (newlyFoundBank != null && newlyFoundBank.isNotEmpty) {
          bankAcc = newlyFoundBank;
          updateData['bankAccount'] = bankAcc;
        }
      }

      // 2. Smart Retroactive Categorizer for fallback categories ('transfer', 'transport', 'other', 'income')
      if (const {'transfer', 'transport', 'other', 'income'}.contains(tx.categoryId) &&
          tx.rawSmsBody != null &&
          tx.rawSmsBody!.isNotEmpty &&
          !tx.rawSmsBody!.contains('\n---\n')) {
        final pendingSms = tx.toPendingSms();
        final newCategory = PendingSmsNotifier.getSmartCategory(pendingSms, categories);

        if (newCategory.id != tx.categoryId) {
          updateData['categoryId'] = newCategory.id;
          updateData['categoryName'] = newCategory.name;
          updateData['iconCodePoint'] = newCategory.iconCodePoint;
          updateData['colorValue'] = newCategory.colorValue;
          debugPrint('[AutoHeal] Upgraded category for ${tx.id} from ${tx.categoryName} to ${newCategory.name}');
        }
      }

      // 3. Retroactive Name Updater (e.g. Income -> Received)
      if (tx.categoryId == 'income' && tx.categoryName != 'Received' && !updateData.containsKey('categoryName')) {
        updateData['categoryName'] = 'Received';
        debugPrint('[AutoHeal] Upgraded categoryName for ${tx.id} from ${tx.categoryName} to Received');
      }

      // 4. Retroactive APY / PRAN Healer: Migrate mistakenly stored income to Expense (Investment)
      if (!tx.isExpense && tx.rawSmsBody != null && tx.rawSmsBody!.isNotEmpty) {
        final bLower = tx.rawSmsBody!.toLowerCase();
        final bool isApyContribution = (bLower.contains('contribution') ||
                bLower.contains('contributed') ||
                bLower.contains('installment')) &&
            (bLower.contains('pran') ||
                bLower.contains('apy') ||
                bLower.contains('nps') ||
                bLower.contains('atal pension') ||
                bLower.contains('protean') ||
                bLower.contains('pfrda'));

        if (isApyContribution) {
          updateData['isExpense'] = true;
          final invCat = categories.firstWhere(
            (c) => c.id == 'investments' || c.name.toLowerCase().contains('investment'),
            orElse: () => categories.first,
          );
          updateData['categoryId'] = invCat.id;
          updateData['categoryName'] = invCat.name;
          updateData['iconCodePoint'] = invCat.iconCodePoint;
          updateData['colorValue'] = invCat.colorValue;
          debugPrint('[AutoHeal] Healed APY contribution ${tx.id} from Income to Expense (Investment)');
        }
      }

      if (updateData.isNotEmpty) {
        updateData['updatedAt'] = FieldValue.serverTimestamp();
        batch.update(userTxCol.doc(tx.id), updateData);
        batchOps++;
      }

      final healedTx = TransactionModel(
        id: tx.id,
        amount: tx.amount,
        description: tx.description,
        categoryId: (updateData['categoryId'] as String?) ?? tx.categoryId,
        categoryName: (updateData['categoryName'] as String?) ?? tx.categoryName,
        iconCodePoint: (updateData['iconCodePoint'] as int?) ?? tx.iconCodePoint,
        colorValue: (updateData['colorValue'] as int?) ?? tx.colorValue,
        date: tx.date,
        userId: tx.userId,
        isExpense: (updateData['isExpense'] as bool?) ?? tx.isExpense,
        isShared: tx.isShared,
        splitWith: tx.splitWith,
        splitAmounts: tx.splitAmounts,
        groupId: tx.groupId,
        paymentMode: tx.paymentMode,
        smsHash: tx.smsHash,
        merchantName: tx.merchantName,
        bankAccount: bankAcc,
        refNumber: r,
        rawSmsBody: tx.rawSmsBody,
      );

      final cleanRef = r?.toLowerCase().trim();
      if (cleanRef != null && cleanRef.isNotEmpty) {
        refMap.putIfAbsent(cleanRef, () => []).add(healedTx);
      } else if (healedTx.rawSmsBody != null && healedTx.rawSmsBody!.trim().isNotEmpty) {
        final dupKey = '${healedTx.amount.toStringAsFixed(2)}_${healedTx.isExpense}_${healedTx.rawSmsBody!.trim()}';
        noRefDupMap.putIfAbsent(dupKey, () => []).add(healedTx);
      }
    }

    // 5. Consolidate 2, 3, or N transactions sharing the same refNumber
    for (final entry in refMap.entries) {
      final list = entry.value;
      if (list.length >= 2) {
        final double firstAmount = list.first.amount;
        final matchingAmountList = list
            .where((t) => !deletedTxIds.contains(t.id) && (t.amount - firstAmount).abs() < 0.01)
            .toList();

        if (matchingAmountList.length >= 2) {
          matchingAmountList.sort((a, b) => a.date.compareTo(b.date));

          // Case A: A self_transfer record ALREADY exists in this ref group -> delete all residual legs!
          final existingSelfTx = matchingAmountList.where((t) => t.categoryId == 'self_transfer').firstOrNull;
          if (existingSelfTx != null) {
            for (final extra in matchingAmountList) {
              if (extra.id != existingSelfTx.id) {
                debugPrint('[AutoHeal] Deleting residual leg ${extra.id} (${extra.categoryName}) for existing self_transfer ${existingSelfTx.id} (ref: ${entry.key})');
                batch.delete(userTxCol.doc(extra.id));
                batchOps++;
                deletedTxIds.add(extra.id);
              }
            }
            continue;
          }

          // Case B: Both Debit and Credit legs exist (or different bank accounts) -> upgrade one to self_transfer & delete all others
          final debitTx = matchingAmountList.where((t) => t.isExpense).firstOrNull;
          final creditTx = matchingAmountList.where((t) => !t.isExpense).firstOrNull;
          final firstBank = matchingAmountList.first.bankAccount?.toLowerCase().trim() ?? '';
          final diffBankTx = firstBank.isNotEmpty
              ? matchingAmountList.where((t) {
                  final b = t.bankAccount?.toLowerCase().trim() ?? '';
                  return b.isNotEmpty && b != firstBank;
                }).firstOrNull
              : null;

          if ((debitTx != null && creditTx != null) || diffBankTx != null) {
            final primaryTx = debitTx ?? matchingAmountList.first;
            final counterpartTx = creditTx ?? diffBankTx!;

            final fromStr = (primaryTx.bankAccount != null && primaryTx.bankAccount!.isNotEmpty)
                ? primaryTx.bankAccount!
                : 'Account';
            final toStr = (counterpartTx.bankAccount != null && counterpartTx.bankAccount!.isNotEmpty)
                ? counterpartTx.bankAccount!
                : 'Account';
            final selfTransferDesc = 'Self Transfer ($fromStr ➔ $toStr)';

            final raw1 = primaryTx.rawSmsBody ?? '';
            final raw2 = counterpartTx.rawSmsBody ?? '';
            final mergedRaw = raw1.isNotEmpty && raw2.isNotEmpty && !raw1.contains(raw2)
                ? '$raw1\n---\n$raw2'
                : (raw1.isNotEmpty ? raw1 : raw2);

            debugPrint('[AutoHeal] Consolidating ${matchingAmountList.length} legs for refNumber ${entry.key} into Self Transfer ${primaryTx.id}');

            batch.update(userTxCol.doc(primaryTx.id), {
              'categoryId': 'self_transfer',
              'categoryName': 'Self Transfer',
              'iconCodePoint': Icons.sync_alt_rounded.codePoint,
              'colorValue': const Color(0xFF607D8B).toARGB32(),
              'description': selfTransferDesc,
              'isExpense': true,
              'bankAccount': primaryTx.bankAccount,
              'merchantName': counterpartTx.bankAccount ?? 'Self Transfer',
              'rawSmsBody': mergedRaw,
              if (primaryTx.refNumber != null && primaryTx.refNumber!.isNotEmpty)
                'refNumber': primaryTx.refNumber,
              'updatedAt': FieldValue.serverTimestamp(),
            });
            batchOps++;

            for (final other in matchingAmountList) {
              if (other.id != primaryTx.id) {
                batch.delete(userTxCol.doc(other.id));
                batchOps++;
                deletedTxIds.add(other.id);
              }
            }
          } else {
            // Case C: Pure duplicates (same direction & same bank) -> keep oldest, delete all remaining
            final keepTx = matchingAmountList.first;
            for (final dup in matchingAmountList.skip(1)) {
              debugPrint('[AutoHeal] Deleting pure duplicate refNumber ${entry.key}: Keeping ${keepTx.id}, Deleting ${dup.id}');
              batch.delete(userTxCol.doc(dup.id));
              batchOps++;
              deletedTxIds.add(dup.id);
            }
          }
        }
      }
    }

    // 6. Deduplicate no-ref transactions that share identical amount, direction, and rawSmsBody
    for (final entry in noRefDupMap.entries) {
      final list = entry.value.where((t) => !deletedTxIds.contains(t.id)).toList();
      if (list.length >= 2) {
        list.sort((a, b) => a.date.compareTo(b.date));
        final keepTx = list.first;
        for (final dup in list.skip(1)) {
          debugPrint('[AutoHeal] Deleting duplicate no-ref SMS transaction ${dup.id} (keeping ${keepTx.id})');
          batch.delete(userTxCol.doc(dup.id));
          batchOps++;
          deletedTxIds.add(dup.id);
        }
      }
    }

    if (batchOps > 0) {
      await batch.commit();
      debugPrint('[AutoHeal] Committed $batchOps healing operations in 1 atomic batch.');
    }
  } catch (e) {
    debugPrint('[AutoHeal] Error during duplicate ref reconciliation: $e');
  } finally {
    _isAutoHealingRunning = false;
    if (_hasPendingHeal && _pendingHealTransactions != null && _pendingHealUserId != null && _pendingHealCategories != null) {
      Future.microtask(() => _queueAutoHeal(_pendingHealTransactions!, _pendingHealUserId!, _pendingHealCategories!));
    }
  }
}

final personalTransactionsStreamProvider = StreamProvider<List<TransactionModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('transactions')
      .orderBy('date', descending: true)
      .snapshots()
      .map((snapshot) {
        final list = snapshot.docs
            .map((doc) => TransactionModel.fromMap(doc.data(), doc.id))
            .toList();
        final categories = ref.read(categoriesProvider).value ?? kDefaultCategories;
        _queueAutoHeal(list, user.uid, categories);
        return list;
      });
});

final groupTransactionsStreamProvider = StreamProvider<List<TransactionModel>>((ref) {
  final groupsAsync = ref.watch(userGroupsStreamProvider);

  if (groupsAsync.value == null && groupsAsync.isLoading) {
    return const Stream.empty();
  }

  final groups = groupsAsync.value ?? [];
  if (groups.isEmpty) {
    return Stream.value(<TransactionModel>[]);
  }

  final List<List<TransactionModel>> groupsTransactions = [];
  for (var group in groups) {
    final txsAsync = ref.watch(groupTransactionsStreamByIdProvider(group.id));
    if (txsAsync.value != null) {
      groupsTransactions.add(txsAsync.value!);
    }
  }

  final combined = groupsTransactions.expand((x) => x).toList();
  combined.sort((a, b) => b.date.compareTo(a.date));

  return Stream.value(combined);
});

final transactionsStreamProvider = StreamProvider<List<TransactionModel>>((ref) {
  final controller = StreamController<List<TransactionModel>>();

  List<TransactionModel> personalList = [];
  List<TransactionModel> groupList = [];

  void emitCombined() {
    final combined = [...personalList, ...groupList];
    combined.sort((a, b) => b.date.compareTo(a.date));
    if (!controller.isClosed) {
      controller.add(combined);
    }
  }

  // Set initial lists if they are already available in their respective providers
  personalList = ref.read(personalTransactionsStreamProvider).value ?? [];
  groupList = ref.read(groupTransactionsStreamProvider).value ?? [];
  emitCombined();

  ref.listen<AsyncValue<List<TransactionModel>>>(
    personalTransactionsStreamProvider,
    (previous, next) {
      personalList = next.value ?? [];
      emitCombined();
    },
    fireImmediately: true,
  );

  ref.listen<AsyncValue<List<TransactionModel>>>(
    groupTransactionsStreamProvider,
    (previous, next) {
      groupList = next.value ?? [];
      emitCombined();
    },
    fireImmediately: true,
  );

  ref.onDispose(() {
    controller.close();
  });

  return controller.stream;
});

final transactionStatsProvider = Provider<TransactionStats>((ref) {
  final transactions = ref.watch(transactionsStreamProvider).value ?? [];
  final user = ref.watch(authStateProvider).value;
  final currentUserId = user?.uid;
  final groups = ref.watch(userGroupsStreamProvider).value ?? [];

  double totalIncome = 0;
  double totalExpense = 0;

  for (var t in transactions) {
    if (t.categoryId == 'self_transfer') continue;
    double amount = t.amount;

    // Wages received by employee = income, not expense
    bool isExpenseForUser = t.isExpense;
    if (t.groupId != null && currentUserId != null) {
      final group = groups.where((g) => g.id == t.groupId).firstOrNull;
      if (group != null && group.toMap()['type'] == 'wages' &&
          (t.splitWith?.contains(currentUserId) ?? false)) {
        isExpenseForUser = false;
      }
    }

    if (isExpenseForUser) {
      totalExpense += amount;
    } else {
      totalIncome += amount;
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

final selectedHomeGroupIdFilterProvider = StateProvider<String>((ref) => 'all');
final homeTransactionTypeFilterProvider = StateProvider<String>((ref) => 'all');

final selectedGroupTypeProvider = StateProvider.autoDispose<String>((ref) => 'split');

final exportDateRangeProvider = StateProvider.autoDispose<String>((ref) => 'all');
final exportTransactionTypeProvider = StateProvider.autoDispose<String>((ref) => 'all');
final exportFormatProvider = StateProvider.autoDispose<String>((ref) => 'pdf');

final addExpensePaymentModeProvider = StateProvider.autoDispose<String>((ref) => 'cash');

final profileEditModeProvider = StateProvider.autoDispose<bool>((ref) => false);

final homeFilteredTransactionsStreamProvider = Provider<AsyncValue<List<TransactionModel>>>((ref) {
  final transactionsAsync = ref.watch(transactionsStreamProvider);
  final filter = ref.watch(selectedHomeGroupIdFilterProvider);

  return transactionsAsync.whenData((transactions) {
    if (filter == 'all') {
      return transactions;
    } else if (filter == 'personal') {
      return transactions.where((t) => !t.isShared || t.groupId == null).toList();
    } else {
      return transactions.where((t) => t.isShared && t.groupId == filter).toList();
    }
  });
});

final homeFilteredTransactionStatsProvider = Provider<TransactionStats>((ref) {
  final transactions = ref.watch(homeFilteredTransactionsStreamProvider).value ?? [];
  final user = ref.watch(authStateProvider).value;
  final currentUserId = user?.uid;
  final groups = ref.watch(userGroupsStreamProvider).value ?? [];

  double totalIncome = 0;
  double totalExpense = 0;

  for (var t in transactions) {
    if (t.categoryId == 'self_transfer') continue;
    double amount = t.amount;

    // Wages received by employee = income, not expense
    bool isExpenseForUser = t.isExpense;
    if (t.groupId != null && currentUserId != null) {
      final group = groups.where((g) => g.id == t.groupId).firstOrNull;
      if (group != null && group.toMap()['type'] == 'wages' &&
          (t.splitWith?.contains(currentUserId) ?? false)) {
        isExpenseForUser = false;
      }
    }

    if (isExpenseForUser) {
      totalExpense += amount;
    } else {
      totalIncome += amount;
    }
  }

  return TransactionStats(
    totalBalance: totalIncome - totalExpense,
    totalIncome: totalIncome,
    totalExpense: totalExpense,
  );
});

final rotationOffsetProvider = StateProvider<double>((ref) => 0);

final selectedStatsGroupIdFilterProvider = StateProvider<String>((ref) => 'all');

final filteredTransactionsProvider = Provider<List<TransactionModel>>((ref) {
  final transactions = ref.watch(transactionsStreamProvider).value ?? [];
  final period = ref.watch(selectedPeriodProvider);
  final filter = ref.watch(selectedStatsGroupIdFilterProvider);
  final now = DateTime.now();

  List<TransactionModel> groupFiltered;
  if (filter == 'all') {
    groupFiltered = transactions;
  } else if (filter == 'personal') {
    groupFiltered = transactions.where((t) => !t.isShared || t.groupId == null).toList();
  } else {
    groupFiltered = transactions.where((t) => t.isShared && t.groupId == filter).toList();
  }

  return groupFiltered.where((t) {
    if (period == StatisticsPeriod.all) {
      // All time
      return true;
    } else if (period == StatisticsPeriod.day) {
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
  final type = ref.watch(statisticsTypeProvider);
  final isExpense = type == StatisticsType.expense;
  final filtered = transactions
      .where((t) => t.isExpense == isExpense && t.categoryId != 'self_transfer')
      .toList();

  filtered.sort((a, b) => b.amount.compareTo(a.amount));
  return filtered;
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
            t.categoryId != 'self_transfer' &&
            (t.date.isAfter(startOfCurrentMonth) ||
                t.date.isAtSameMomentAs(startOfCurrentMonth)),
      )
      .toList();

  final prevMonthExpenses = allTransactions
      .where(
        (t) =>
            t.isExpense &&
            t.categoryId != 'self_transfer' &&
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
            t.categoryId != 'self_transfer' &&
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

class InFlightRefInfo {
  final double amount;
  final bool isExpense;
  final String? bankAccount;
  final String? merchantName;
  final String? smsHash;
  final String? rawSmsBody;
  bool isMerged;

  InFlightRefInfo({
    required this.amount,
    required this.isExpense,
    this.bankAccount,
    this.merchantName,
    this.smsHash,
    this.rawSmsBody,
    this.isMerged = false,
  });
}

class TransactionViewModel extends StateNotifier<AsyncValue<void>> {
  final Ref ref;
  static final Set<String> _inFlightSmsHashes = {};
  static final Set<String> _inFlightRefNumbers = {};
  static final Map<String, InFlightRefInfo> _inFlightSelfTransferMap = {};

  TransactionViewModel(this.ref) : super(const AsyncValue.data(null));

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  Future<void> _logGroupAction(String groupId, String action, String details, {String? targetUserId}) async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;
    
    try {
      final userSnap = await _firestore.collection('users').doc(user.uid).get();
      final userName = userSnap.data()?['name'] as String? ?? 'Group Member';
      
      final groupSnap = await _firestore.collection('groups').doc(groupId).get();
      final groupData = groupSnap.data();
      final groupAdmins = List<String>.from(groupData?['admins'] ?? []);
      final isAdmin = groupAdmins.contains(user.uid) || groupData?['adminId'] == user.uid;
      final role = isAdmin ? 'admin' : 'member';
      final groupType = groupData?['type'] as String? ?? 'split';
      
      if ((groupType == 'business' || groupType == 'wages') && role != 'admin') {
        return; // Only log Admin actions in business and wages groups
      }
      
      await _firestore.collection('groups').doc(groupId).collection('logs').add({
        'userId': user.uid,
        'userName': userName,
        'userRole': role,
        'action': action,
        'details': details,
        'targetUserId': targetUserId,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Failed to write group action log: $e");
    }
  }

  Future<bool> addTransaction({
    required double amount,
    required String description,
    required CategoryModel category,
    DateTime? date,
    bool isExpense = true,
    bool isShared = false,
    List<String>? splitWith,
    String? targetGroupId,
    Map<String, double>? splitAmounts,
    String? overrideUserId,
    String? paymentMode,
    String? smsHash,
    String? merchantName,
    String? bankAccount,
    String? refNumber,
    String? rawSmsBody,
    bool silentNotification = false,
  }) async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return false;
    final groupId = targetGroupId ?? ref.read(userGroupIdProvider);

    final cleanHash = smsHash?.trim() ?? '';
    final cleanRef = refNumber?.trim().toLowerCase() ?? '';

    // 1. In-flight memory deduplication guard
    if (cleanHash.isNotEmpty) {
      if (_inFlightSmsHashes.contains(cleanHash)) {
        debugPrint('[TransactionViewModel] addTransaction skipped - smsHash $cleanHash already in-flight.');
        return true;
      }
      _inFlightSmsHashes.add(cleanHash);
      Future.delayed(const Duration(seconds: 30), () => _inFlightSmsHashes.remove(cleanHash));
    }

    // Layer 2: In-Flight Concurrency Map (Instant Multi-SMS Race Condition Intercept)
    if (cleanRef.isNotEmpty && !isShared && groupId == null) {
      final inFlight = _inFlightSelfTransferMap[cleanRef];
      if (inFlight != null && (inFlight.amount - amount).abs() < 0.01) {
        if (inFlight.isMerged) {
          debugPrint('[TransactionViewModel] Layer 2 In-Flight match skipped - already merged. Duplicate broadcast.');
          return true;
        }

        final isOpposite = inFlight.isExpense != isExpense;
        final isDifferentBank = (inFlight.bankAccount?.toLowerCase().trim() ?? '') != (bankAccount?.toLowerCase().trim() ?? '');
        
        if (!isOpposite && !isDifferentBank) {
          debugPrint('[TransactionViewModel] Layer 2 In-Flight match skipped - same direction and same bank. Duplicate broadcast.');
          return true;
        }

        inFlight.isMerged = true;
        debugPrint('[TransactionViewModel] Layer 2 In-Flight match for ref $cleanRef! Merging directly.');

        String? debitBank;
        String? creditBank;
        if (isOpposite) {
          debitBank = isExpense ? bankAccount : inFlight.bankAccount;
          creditBank = isExpense ? inFlight.bankAccount : bankAccount;
        } else {
          debitBank = inFlight.bankAccount;
          creditBank = bankAccount;
        }

        final fromStr = (debitBank != null && debitBank.isNotEmpty) ? debitBank : 'Account';
        final toStr = (creditBank != null && creditBank.isNotEmpty) ? creditBank : 'Account';
        final selfTransferDesc = 'Self Transfer ($fromStr ➔ $toStr)';
        final mergedRaw = '${inFlight.rawSmsBody ?? ""}\n---\n${rawSmsBody ?? ""}';

        final existingRefDocs = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('transactions')
            .where('refNumber', isEqualTo: cleanRef)
            .limit(1)
            .get();

        if (existingRefDocs.docs.isNotEmpty) {
          await existingRefDocs.docs.first.reference.update({
            'categoryId': 'self_transfer',
            'categoryName': 'Self Transfer',
            'iconCodePoint': Icons.sync_alt_rounded.codePoint,
            'colorValue': const Color(0xFF607D8B).toARGB32(),
            'description': selfTransferDesc,
            'isExpense': true,
            'bankAccount': debitBank,
            'merchantName': creditBank ?? 'Self Transfer',
            'rawSmsBody': mergedRaw,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          final stTx = TransactionModel(
            id: '',
            amount: amount,
            description: selfTransferDesc,
            categoryId: 'self_transfer',
            categoryName: 'Self Transfer',
            iconCodePoint: Icons.sync_alt_rounded.codePoint,
            colorValue: const Color(0xFF607D8B).toARGB32(),
            date: date ?? DateTime.now(),
            userId: overrideUserId ?? user.uid,
            isExpense: true,
            isShared: isShared && groupId != null,
            groupId: (isShared && groupId != null) ? groupId : null,
            paymentMode: paymentMode,
            smsHash: smsHash,
            merchantName: creditBank ?? 'Self Transfer',
            bankAccount: debitBank,
            refNumber: refNumber,
            rawSmsBody: mergedRaw,
          );
          final map = stTx.toMap();
          map['createdAt'] = FieldValue.serverTimestamp();
          await _firestore.collection('users').doc(user.uid).collection('transactions').add(map);
        }

        if (cleanHash.isNotEmpty) {
          await AutoSmsService.markHashSynced(cleanHash);
        }
        if (inFlight.smsHash != null && inFlight.smsHash!.isNotEmpty) {
          await AutoSmsService.markHashSynced(inFlight.smsHash!);
        }

        state = const AsyncValue.data(null);
        return true;
      }

      _inFlightSelfTransferMap[cleanRef] = InFlightRefInfo(
        amount: amount,
        isExpense: isExpense,
        bankAccount: bankAccount,
        merchantName: merchantName,
        smsHash: smsHash,
        rawSmsBody: rawSmsBody,
      );
      Future.delayed(const Duration(seconds: 45), () => _inFlightSelfTransferMap.remove(cleanRef));
    }

    final inFlightRefKey = cleanRef.isNotEmpty ? '${cleanRef}_$isExpense' : '';
    if (inFlightRefKey.isNotEmpty) {
      if (_inFlightRefNumbers.contains(inFlightRefKey)) {
        debugPrint('[TransactionViewModel] addTransaction skipped - ref $inFlightRefKey already in-flight.');
        return true;
      }
      _inFlightRefNumbers.add(inFlightRefKey);
      Future.delayed(const Duration(seconds: 30), () => _inFlightRefNumbers.remove(inFlightRefKey));
    }

    state = const AsyncValue.loading();
    try {
      // 2. Database level deduplication verification for personal transactions
      if (!isShared && groupId == null) {
        if (cleanHash.isNotEmpty) {
          final hashDoc = await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('transactions')
              .where('smsHash', isEqualTo: cleanHash)
              .limit(1)
              .get();
          if (hashDoc.docs.isNotEmpty) {
            debugPrint('[TransactionViewModel] Duplicate smsHash $cleanHash found in Firestore. Skipping.');
            state = const AsyncValue.data(null);
            return true;
          }
        }

        if (cleanRef.isNotEmpty) {
          final refDoc = await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('transactions')
              .where('refNumber', isEqualTo: cleanRef)
              .limit(1)
              .get();
          if (refDoc.docs.isNotEmpty) {
            final existingDoc = refDoc.docs.first;
            final existingData = existingDoc.data();
            final existingIsExpense = existingData['isExpense'] as bool? ?? true;
            final String existingCatId = existingData['categoryId'] as String? ?? '';
            final double existingAmount = (existingData['amount'] as num?)?.toDouble() ?? 0.0;
            final String? existingBankAccount = existingData['bankAccount'] as String?;

            // Branch 1: Classic Debit + Credit pair (opposite directions)
            // Branch 2: Same-direction (e.g. Credit + Credit) pair from different banks with same Ref ID
            final bool isOppositeDirection = existingIsExpense != isExpense;
            final bool isSameRefAmountDifferentBank =
                (existingAmount - amount).abs() < 0.01 &&
                existingCatId != 'self_transfer' &&
                existingBankAccount != null &&
                bankAccount != null &&
                existingBankAccount.toLowerCase().trim() != bankAccount.toLowerCase().trim();

            if ((isOppositeDirection || isSameRefAmountDifferentBank) &&
                (existingAmount - amount).abs() < 0.01 &&
                existingCatId != 'self_transfer') {
              debugPrint('[TransactionViewModel] Self Transfer detected for refNumber: $cleanRef! Upgrading to Self Transfer.');
              String? debitBank;
              String? creditBank;
              if (isOppositeDirection) {
                debitBank = isExpense ? bankAccount : existingBankAccount;
                creditBank = isExpense ? existingBankAccount : bankAccount;
              } else {
                debitBank = existingBankAccount;
                creditBank = bankAccount;
              }

              final fromStr = (debitBank != null && debitBank.isNotEmpty) ? debitBank : 'Account';
              final toStr = (creditBank != null && creditBank.isNotEmpty) ? creditBank : 'Account';
              final selfTransferDesc = 'Self Transfer ($fromStr ➔ $toStr)';

              final existingRawBody = existingData['rawSmsBody'] as String? ?? '';
              final mergedRawBody = (rawSmsBody != null && rawSmsBody.isNotEmpty)
                  ? (existingRawBody.isNotEmpty ? '$existingRawBody\n---\n$rawSmsBody' : rawSmsBody)
                  : existingRawBody;

              await existingDoc.reference.update({
                'categoryId': 'self_transfer',
                'categoryName': 'Self Transfer',
                'iconCodePoint': Icons.sync_alt_rounded.codePoint,
                'colorValue': const Color(0xFF607D8B).toARGB32(),
                'description': selfTransferDesc,
                'isExpense': true,
                'bankAccount': debitBank,
                'merchantName': creditBank ?? 'Self Transfer',
                'rawSmsBody': mergedRawBody,
                'updatedAt': FieldValue.serverTimestamp(),
              });

              if (cleanHash.isNotEmpty) {
                await AutoSmsService.markHashSynced(cleanHash);
              }

              state = const AsyncValue.data(null);
              return true;
            }

            debugPrint('[TransactionViewModel] Duplicate refNumber $cleanRef found in Firestore. Skipping.');
            state = const AsyncValue.data(null);
            return true;
          }
        }
      }
      final transaction = TransactionModel(
        id: '',
        amount: amount,
        description: description,
        categoryId: category.id,
        categoryName: category.name,
        iconCodePoint: category.iconCodePoint,
        colorValue: category.colorValue,
        date: date ?? DateTime.now(),
        userId: overrideUserId ?? user.uid,
        isExpense: isExpense,
        isShared: isShared && groupId != null,
        splitWith: (isShared && groupId != null) ? splitWith : null,
        splitAmounts: (isShared && groupId != null) ? splitAmounts : null,
        groupId: (isShared && groupId != null) ? groupId : null,
        paymentMode: paymentMode,
        smsHash: smsHash,
        merchantName: merchantName,
        bankAccount: bankAccount,
        refNumber: refNumber,
        rawSmsBody: rawSmsBody,
      );

      final map = transaction.toMap();
      map['createdAt'] = FieldValue.serverTimestamp();

      if (isShared && groupId != null) {
        String? wagesTargetUserId;
        final groupSnap = await _firestore.collection('groups').doc(groupId).get();
        if (groupSnap.exists) {
          final type = groupSnap.data()?['type'] as String?;
          if (type == 'wages' && splitWith != null && splitWith.isNotEmpty) {
            wagesTargetUserId = splitWith.first;
          }
        }

        await _firestore
            .collection('groups')
            .doc(groupId)
            .collection('transactions')
            .add(map);
            
        await _logGroupAction(
          groupId,
          'add',
          "Added transaction: ₹${amount.toStringAsFixed(2)} (${isExpense ? 'Paid' : 'Received'}) for ${description.isNotEmpty ? description : category.name}",
          targetUserId: wagesTargetUserId ?? (overrideUserId ?? user.uid),
        );
      } else {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('transactions')
            .add(map);
      }

      if (!silentNotification) {
        await NotificationHelper().showAddExpenseNotification(
          amount: amount,
          categoryName: category.name,
          isExpense: isExpense, // Passes your boolean flag cleanly
        );
      }

      state = const AsyncValue.data(null);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  /// Adds multiple transactions in a single atomic Firestore WriteBatch roundtrip.
  /// Returns the count of successfully committed transactions.
  Future<int> addTransactionsBatch(List<TransactionModel> transactions) async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null || transactions.isEmpty) return 0;

    state = const AsyncValue.loading();
    try {
      final batch = _firestore.batch();
      final userTxCol = _firestore.collection('users').doc(user.uid).collection('transactions');
      int committedCount = 0;

      for (final tx in transactions) {
        final cleanHash = tx.smsHash?.trim() ?? '';
        final cleanRef = tx.refNumber?.trim().toLowerCase() ?? '';
        final inFlightRefKey = cleanRef.isNotEmpty ? '${cleanRef}_${tx.isExpense}' : '';

        if (cleanHash.isNotEmpty && _inFlightSmsHashes.contains(cleanHash)) {
          debugPrint('[TransactionViewModel] addTransactionsBatch skipped in-flight smsHash $cleanHash');
          continue;
        }
        if (inFlightRefKey.isNotEmpty && _inFlightRefNumbers.contains(inFlightRefKey)) {
          debugPrint('[TransactionViewModel] addTransactionsBatch skipped in-flight ref $inFlightRefKey');
          continue;
        }

        if (cleanHash.isNotEmpty) {
          _inFlightSmsHashes.add(cleanHash);
          Future.delayed(const Duration(seconds: 30), () => _inFlightSmsHashes.remove(cleanHash));
        }
        if (inFlightRefKey.isNotEmpty) {
          _inFlightRefNumbers.add(inFlightRefKey);
          Future.delayed(const Duration(seconds: 30), () => _inFlightRefNumbers.remove(inFlightRefKey));
        }

        final docRef = userTxCol.doc();
        final map = tx.toMap();
        map['createdAt'] = FieldValue.serverTimestamp();
        batch.set(docRef, map);
        committedCount++;
      }

      if (committedCount > 0) {
        await batch.commit();
      }
      state = const AsyncValue.data(null);
      return committedCount;
    } catch (e, stack) {
      debugPrint('[TransactionViewModel] addTransactionsBatch error: $e');
      state = AsyncValue.error(e, stack);
      return 0;
    }
  }

  Future<bool> editTransaction({
    required TransactionModel originalTransaction,
    required double amount,
    required String description,
    required CategoryModel category,
    DateTime? date,
    bool isExpense = true,
    bool isShared = false,
    List<String>? splitWith,
    String? targetGroupId,
    Map<String, double>? splitAmounts,
    String? paymentMode,
  }) async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return false;
    final groupId = targetGroupId ?? ref.read(userGroupIdProvider);

    state = const AsyncValue.loading();
    try {
      final updated = TransactionModel(
        id: originalTransaction.id,
        amount: amount,
        description: description,
        categoryId: category.id,
        categoryName: category.name,
        iconCodePoint: category.iconCodePoint,
        colorValue: category.colorValue,
        date: date ?? originalTransaction.date,
        userId: originalTransaction.userId,
        isExpense: isExpense,
        isShared: isShared && groupId != null,
        splitWith: (isShared && groupId != null) ? splitWith : null,
        splitAmounts: (isShared && groupId != null) ? splitAmounts : null,
        groupId: (isShared && groupId != null) ? groupId : null,
        paymentMode: paymentMode ?? originalTransaction.paymentMode,
        smsHash: originalTransaction.smsHash,
        merchantName: originalTransaction.merchantName,
        bankAccount: originalTransaction.bankAccount,
        refNumber: originalTransaction.refNumber,
        rawSmsBody: originalTransaction.rawSmsBody,
      );

      if (isShared && groupId != null) {
        String? wagesTargetUserId;
        final groupSnap = await _firestore.collection('groups').doc(groupId).get();
        if (groupSnap.exists) {
          final type = groupSnap.data()?['type'] as String?;
          if (type == 'wages' && splitWith != null && splitWith.isNotEmpty) {
            wagesTargetUserId = splitWith.first;
          }
        }

        await _firestore
            .collection('groups')
            .doc(groupId)
            .collection('transactions')
            .doc(originalTransaction.id)
            .update(updated.toMap());
            
        final logDetails = <String>[];
        if (originalTransaction.amount != amount) {
          logDetails.add("Amount: ₹${originalTransaction.amount.toStringAsFixed(2)} -> ₹${amount.toStringAsFixed(2)}");
        }
        final oldCatName = originalTransaction.categoryName.isNotEmpty
            ? originalTransaction.categoryName
            : "No Category";
        final newCatName = category.name.isNotEmpty
            ? category.name
            : "No Category";
        if (originalTransaction.categoryId != category.id) {
          logDetails.add("Category: $oldCatName -> $newCatName");
        }
        if (originalTransaction.description != description) {
          logDetails.add("Note: '${originalTransaction.description}' -> '$description'");
        }
        if (originalTransaction.isExpense != isExpense) {
          logDetails.add("Type: ${originalTransaction.isExpense ? 'Paid' : 'Received'} -> ${isExpense ? 'Paid' : 'Received'}");
        }
        final detailsStr = logDetails.isEmpty ? "Updated fields" : logDetails.join("; ");
        await _logGroupAction(
          groupId,
          'edit',
          "Edited transaction '${description.isNotEmpty ? description : category.name}': $detailsStr",
          targetUserId: wagesTargetUserId ?? (originalTransaction.splitWith?.firstOrNull ?? originalTransaction.userId),
        );
      } else {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('transactions')
            .doc(originalTransaction.id)
            .update(updated.toMap());
      }

      state = const AsyncValue.data(null);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  Future<bool> deleteTransaction(TransactionModel transaction) async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return false;

    state = const AsyncValue.loading();
    try {
      if (transaction.groupId != null) {
        String? wagesTargetUserId;
        final groupSnap = await _firestore.collection('groups').doc(transaction.groupId!).get();
        if (groupSnap.exists) {
          final type = groupSnap.data()?['type'] as String?;
          if (type == 'wages' && transaction.splitWith != null && transaction.splitWith!.isNotEmpty) {
            wagesTargetUserId = transaction.splitWith!.first;
          }
        }

        await _firestore
            .collection('groups')
            .doc(transaction.groupId!)
            .collection('transactions')
            .doc(transaction.id)
            .delete();
            
        await _logGroupAction(
          transaction.groupId!,
          'delete',
          "Deleted transaction: ₹${transaction.amount.toStringAsFixed(2)} for ${transaction.description.isNotEmpty ? transaction.description : transaction.categoryName}",
          targetUserId: wagesTargetUserId ?? (transaction.splitWith?.firstOrNull ?? transaction.userId),
        );
      } else {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('transactions')
            .doc(transaction.id)
            .delete();
      }

      if (transaction.smsHash != null && transaction.smsHash!.isNotEmpty) {
        await AutoSmsService.markHashDiscarded(transaction.smsHash!);
      }

      state = const AsyncValue.data(null);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  Future<bool> toggleTransactionType(TransactionModel transaction) async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return false;

    state = const AsyncValue.loading();
    try {
      final newIsExpense = !transaction.isExpense;
      if (transaction.groupId != null) {
        String? wagesTargetUserId;
        final groupSnap = await _firestore.collection('groups').doc(transaction.groupId!).get();
        if (groupSnap.exists) {
          final type = groupSnap.data()?['type'] as String?;
          if (type == 'wages' && transaction.splitWith != null && transaction.splitWith!.isNotEmpty) {
            wagesTargetUserId = transaction.splitWith!.first;
          }
        }

        await _firestore
            .collection('groups')
            .doc(transaction.groupId!)
            .collection('transactions')
            .doc(transaction.id)
            .update({'isExpense': newIsExpense});
            
        await _logGroupAction(
          transaction.groupId!,
          'toggle_type',
          "Changed type of transaction '${transaction.description.isNotEmpty ? transaction.description : transaction.categoryName}' from ${transaction.isExpense ? 'Paid' : 'Received'} to ${newIsExpense ? 'Paid' : 'Received'}",
          targetUserId: wagesTargetUserId ?? (transaction.splitWith?.firstOrNull ?? transaction.userId),
        );
      } else {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('transactions')
            .doc(transaction.id)
            .update({'isExpense': newIsExpense});
      }

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
    final groupId = ref.read(userGroupIdProvider);

    try {
      final category = CategoryModel(
        id: '',
        name: name,
        iconCodePoint: icon.codePoint,
        colorValue: color.value,
      );

      if (groupId != null) {
        await _firestore
            .collection('groups')
            .doc(groupId)
            .collection('categories')
            .add(category.toMap());
      } else {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('categories')
            .add(category.toMap());
      }

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

  Future<bool> updatePersonalDetails({required String name, required String phone}) async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return false;

    state = const AsyncValue.loading();
    try {
      await _firestore.collection('users').doc(user.uid).update({
        'name': name,
        'phone': phone,
      });
      state = const AsyncValue.data(null);
      // Force refreshing user data provider
      ref.invalidate(userDataProvider);
      return true;
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