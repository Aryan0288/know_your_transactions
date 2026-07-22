import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:know_your_expenses/features/auto_sms/model/model_pending_sms.dart';
import 'package:know_your_expenses/features/auto_sms/service/sms_parser_service.dart';
import 'package:know_your_expenses/features/home/view_model/view_model_group.dart';
import 'package:know_your_expenses/features/transaction/view_model/view_model_transaction.dart';
import 'package:know_your_expenses/features/transaction/model/model_transaction.dart';
import 'package:know_your_expenses/features/helper/notification_helper.dart';

final autoSmsEnabledProvider = StateProvider<bool>((ref) => false);

final pendingSmsListProvider = StateNotifierProvider<PendingSmsNotifier, List<ModelPendingSms>>((ref) {
  return PendingSmsNotifier(ref);
});

class PendingSmsNotifier extends StateNotifier<List<ModelPendingSms>> {
  final Ref ref;
  static const String _prefsKey = 'pending_auto_sms_items';

  PendingSmsNotifier(this.ref) : super([]) {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(_prefsKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(jsonStr);
        state = list.map((item) => ModelPendingSms.fromMap(Map<String, dynamic>.from(item), item['id'])).toList();
      }
    } catch (_) {}
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> mapList = state.map((item) => item.toMap()).toList();
      await prefs.setString(_prefsKey, jsonEncode(mapList));
    } catch (_) {}
  }

  Future<void> processIncomingSms(String smsBody) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final prefs = await SharedPreferences.getInstance();
    final bool isEnabled = (prefs.getBool('auto_sms_enabled') ?? ref.read(autoSmsEnabledProvider)) == true;
    if (!isEnabled) {
      return;
    }

    final parsedSms = SmsParserService.parseSms(smsBody);
    if (parsedSms == null) {
      return;
    }

    // Check deduplication
    if (state.any((item) => item.id == parsedSms.id)) return;

    // Check user groups eligible for transactions
    final allGroups = ref.read(userGroupsStreamProvider).value ?? [];
    final groups = allGroups.where((group) {
      if (group.type == 'wages') {
        final isAdmin = currentUser != null &&
            (group.adminId == currentUser.uid || group.admins.contains(currentUser.uid));
        return isAdmin;
      }
      return true;
    }).toList();

    if (groups.isEmpty) {
      // 🟢 Case A: No groups created -> Auto-Add directly to Personal Workspace
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final categories = ref.read(categoriesProvider).value ?? [];
        final defaultCategory = categories.isNotEmpty
            ? categories.first
            : CategoryModel(
                id: 'shopping',
                name: 'Shopping',
                iconCodePoint: 0xe59c,
                colorValue: 0xFF429690,
              );

        await ref.read(transactionViewModelProvider.notifier).addTransaction(
              amount: parsedSms.amount,
              description: parsedSms.vendorName,
              category: defaultCategory,
              date: parsedSms.date,
              isExpense: parsedSms.isExpense,
              paymentMode: parsedSms.paymentMode,
            );

        NotificationHelper.showLocalNotification(
          title: 'Auto Expense Recorded 💳',
          body: '₹${parsedSms.amount.toStringAsFixed(2)} at ${parsedSms.vendorName} added to Personal expenses.',
        );
      }
    } else {
      // 🟡 Case B: Multi-group user -> Add to Pending Auto-Fill Ledger
      state = [parsedSms, ...state];
      await _saveToPrefs();

      NotificationHelper.showLocalNotification(
        title: 'New Auto-Detected Expense 📱',
        body: '₹${parsedSms.amount.toStringAsFixed(2)} at ${parsedSms.vendorName}. Tap to assign Group.',
      );
    }
  }

  Future<void> discardPendingSms(String id) async {
    state = state.where((item) => item.id != id).toList();
    await _saveToPrefs();
  }

  Future<void> assignPendingSms({
    required String pendingId,
    required String? targetGroupId, // null for Personal
    required String categoryId,
    required String categoryName,
    required int iconCodePoint,
    required int colorValue,
    required String description,
    required double amount,
  }) async {
    final pendingItem = state.firstWhere((item) => item.id == pendingId, orElse: () => ModelPendingSms(id: '', amount: 0, vendorName: '', date: DateTime.now(), rawSmsBody: ''));
    if (pendingItem.id.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final categories = ref.read(categoriesProvider).value ?? [];
    final category = categories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => CategoryModel(
        id: categoryId,
        name: categoryName,
        iconCodePoint: iconCodePoint,
        colorValue: colorValue,
      ),
    );

    await ref.read(transactionViewModelProvider.notifier).addTransaction(
          amount: amount,
          description: description,
          category: category,
          date: pendingItem.date,
          isExpense: pendingItem.isExpense,
          targetGroupId: targetGroupId,
          isShared: targetGroupId != null && targetGroupId.isNotEmpty,
          paymentMode: pendingItem.paymentMode,
        );

    // Remove from pending state
    state = state.where((item) => item.id != pendingId).toList();
    await _saveToPrefs();
  }
}
