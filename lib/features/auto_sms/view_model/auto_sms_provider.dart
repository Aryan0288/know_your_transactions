import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:know_your_expenses/features/auto_sms/model/model_pending_sms.dart';
import 'package:know_your_expenses/features/auto_sms/service/sms_parser_service.dart';
import 'package:know_your_expenses/features/auto_sms/service/auto_sms_service.dart';
import 'package:know_your_expenses/features/home/view_model/view_model_home.dart';
import 'package:know_your_expenses/features/transaction/view_model/view_model_transaction.dart';
import 'package:know_your_expenses/features/transaction/model/model_transaction.dart';

final autoSmsEnabledProvider = StateProvider<bool>((ref) => false);
final autoSmsOnboardingSyncingProvider = StateProvider.autoDispose<bool>((ref) => false);

final pendingSmsListProvider = StateNotifierProvider<PendingSmsNotifier, List<ModelPendingSms>>((ref) {
  return PendingSmsNotifier(ref);
});

class PendingSmsNotifier extends StateNotifier<List<ModelPendingSms>> {
  final Ref ref;
  static const String _prefsKey = 'pending_auto_sms_items';
  static bool _isSyncingInProgress = false;
  static bool _isSilentSyncRunning = false;
  static bool _isProcessingPersonalItems = false;

  PendingSmsNotifier(this.ref) : super([]) {
    _loadFromPrefs();

    // Auto-flush pending SMS whenever Firebase Auth state is resolved or user logs in
    ref.listen<AsyncValue<User?>>(authStateProvider, (previous, next) {
      if (next.value != null) {
        _loadFromPrefs();
      }
    });
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(_prefsKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(jsonStr);
        final List<ModelPendingSms> normalized = [];
        final Set<String> seenIds = {};

        for (final rawItem in list) {
          final map = Map<String, dynamic>.from(rawItem);
          final fallbackItem = ModelPendingSms.fromMap(map, map['id']?.toString() ?? '');
          // Re-parse through Dart SmsParserService so native SmsReceiver items get canonical Dart hashId, refNumber & spam filtering
          if (fallbackItem.rawSmsBody.isNotEmpty) {
            final reparsed = SmsParserService.parseSms(
              fallbackItem.rawSmsBody,
              sender: map['sender'] as String?,
              messageTimestamp: fallbackItem.date,
            );
            if (reparsed == null) {
              // Blocked by updated spam/scam filters
              continue;
            }
            if (!seenIds.contains(reparsed.id)) {
              seenIds.add(reparsed.id);
              normalized.add(reparsed);
            }
          } else if (fallbackItem.id.isNotEmpty && !seenIds.contains(fallbackItem.id)) {
            seenIds.add(fallbackItem.id);
            normalized.add(fallbackItem);
          }
        }

        state = normalized;
        await _saveToPrefs();
        await _autoProcessPersonalItems();
      }
    } catch (_) {}
  }

  /// Called by AppLifecycleObserver or page mount when app resumes/opens
  Future<void> reloadFromPrefs() => _loadFromPrefs();

  Future<void> _autoProcessPersonalItems() async {
    if (state.isEmpty || _isProcessingPersonalItems) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    _isProcessingPersonalItems = true;
    try {

    final itemsToProcess = List<ModelPendingSms>.from(state);
    final categories = ref.read(categoriesProvider).value ?? kDefaultCategories;
    final Set<String> processedIds = {};
    final syncedHashes = await AutoSmsService.getSyncedHashes();
    final discardedHashes = await AutoSmsService.getDiscardedHashes();

    debugPrint('[AutoSms] Auto-processing ${itemsToProcess.length} pending SMS items for user ${currentUser.uid}...');

    // 1. First pass: Pair debit + credit SMS sharing same refNumber into Self Transfer
    final Map<String, List<ModelPendingSms>> refGroups = {};
    for (final item in itemsToProcess) {
      if (syncedHashes.contains(item.id) || discardedHashes.contains(item.id)) {
        processedIds.add(item.id);
        continue;
      }
      final ref = item.refNumber?.toLowerCase().trim();
      if (ref != null && ref.isNotEmpty) {
        refGroups.putIfAbsent(ref, () => []).add(item);
      }
    }

    for (final entry in refGroups.entries) {
      final list = entry.value;
      final debitItem = list.where((i) => i.isExpense).firstOrNull;
      final creditItem = list.where((i) => !i.isExpense).firstOrNull;

      if (debitItem != null && creditItem != null) {
        for (final grpItem in list) {
          processedIds.add(grpItem.id);
        }

        final fromStr = (debitItem.bankAccount != null && debitItem.bankAccount!.isNotEmpty)
            ? debitItem.bankAccount!
            : 'Account';
        final toStr = (creditItem.bankAccount != null && creditItem.bankAccount!.isNotEmpty)
            ? creditItem.bankAccount!
            : 'Account';
        final selfTransferDesc = 'Self Transfer ($fromStr ➔ $toStr)';

        final success = await ref.read(transactionViewModelProvider.notifier).addTransaction(
              amount: debitItem.amount,
              description: selfTransferDesc,
              category: CategoryModel(
                id: 'self_transfer',
                name: 'Self Transfer',
                iconCodePoint: 0xe627,
                colorValue: 0xFF607D8B,
              ),
              date: debitItem.date,
              isExpense: true,
              paymentMode: debitItem.paymentMode,
              smsHash: debitItem.id,
              merchantName: creditItem.bankAccount ?? 'Self Transfer',
              bankAccount: debitItem.bankAccount,
              refNumber: debitItem.refNumber,
              rawSmsBody: '${debitItem.rawSmsBody}\n---\n${creditItem.rawSmsBody}',
              silentNotification: true,
            );

        if (success) {
          await AutoSmsService.markHashesSynced(list.map((e) => e.id));
          debugPrint('[AutoSms] Successfully added paired Self Transfer: ₹${debitItem.amount} ($selfTransferDesc)');
        }
      }
    }

    // 2. Second pass: Check if any remaining pending item matches an existing transaction
    for (final item in itemsToProcess) {
      if (processedIds.contains(item.id)) continue;

      final cleanRef = item.refNumber?.toLowerCase().trim();
      if (cleanRef != null && cleanRef.isNotEmpty) {
        // Layer 1: In-Memory Live Stream Match (0ms Latency)
        final activeTransactions = ref.read(transactionsStreamProvider).value ?? [];
        final alreadyMergedSelfTransfer = activeTransactions.any((t) =>
            t.refNumber != null &&
            t.refNumber!.toLowerCase().trim() == cleanRef &&
            (t.amount - item.amount).abs() < 0.01 &&
            t.categoryId == 'self_transfer');
        if (alreadyMergedSelfTransfer) {
          processedIds.add(item.id);
          await AutoSmsService.markHashSynced(item.id);
          continue;
        }

        final inMemoryMatch = activeTransactions.where((t) {
          if (t.refNumber == null || t.refNumber!.isEmpty) return false;
          if (t.refNumber!.toLowerCase().trim() != cleanRef) return false;
          if ((t.amount - item.amount).abs() >= 0.01) return false;
          if (t.categoryId == 'self_transfer') return false;
          return true;
        }).firstOrNull;

        if (inMemoryMatch != null) {
          final isOpposite = inMemoryMatch.isExpense != item.isExpense;
          final isSameRefDifferentBank = inMemoryMatch.bankAccount != null &&
              item.bankAccount != null &&
              inMemoryMatch.bankAccount!.toLowerCase().trim() !=
                  (item.bankAccount ?? '').toLowerCase().trim();

          if (isOpposite || isSameRefDifferentBank) {
            String? debitBank;
            String? creditBank;
            if (isOpposite) {
              debitBank = item.isExpense ? item.bankAccount : inMemoryMatch.bankAccount;
              creditBank = item.isExpense ? inMemoryMatch.bankAccount : item.bankAccount;
            } else {
              debitBank = inMemoryMatch.bankAccount;
              creditBank = item.bankAccount;
            }

            final fromStr = (debitBank != null && debitBank.isNotEmpty) ? debitBank : 'Account';
            final toStr = (creditBank != null && creditBank.isNotEmpty) ? creditBank : 'Account';
            final selfTransferDesc = 'Self Transfer ($fromStr ➔ $toStr)';

            final existingRawBody = inMemoryMatch.rawSmsBody ?? '';
            final mergedRawBody = existingRawBody.isNotEmpty
                ? '$existingRawBody\n---\n${item.rawSmsBody}'
                : item.rawSmsBody;

            await FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser.uid)
                .collection('transactions')
                .doc(inMemoryMatch.id)
                .update({
              'categoryId': 'self_transfer',
              'categoryName': 'Self Transfer',
              'iconCodePoint': Icons.sync_alt_rounded.codePoint,
              'colorValue': const Color(0xFF607D8B).toARGB32(),
              'description': selfTransferDesc,
              'isExpense': true,
              'bankAccount': debitBank,
              'merchantName': creditBank ?? 'Self Transfer',
              'rawSmsBody': mergedRawBody,
            });

            processedIds.add(item.id);
            await AutoSmsService.markHashSynced(item.id);
            debugPrint('[AutoSms] Layer 1 In-Memory Pending Paired Self Transfer: ${inMemoryMatch.id} upgraded to $selfTransferDesc');
            continue;
          }
        }

        // Layer 3: Remote Firestore Database Lookup (Fallback)
        try {
          final existingDocs = await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .collection('transactions')
              .where('refNumber', isEqualTo: item.refNumber)
              .limit(3)
              .get();

          bool merged = false;
          for (final doc in existingDocs.docs) {
            final data = doc.data();
            final bool existingIsExpense = data['isExpense'] as bool? ?? true;
            final double existingAmount = (data['amount'] as num?)?.toDouble() ?? 0.0;
            final String existingCatId = data['categoryId'] as String? ?? '';
            final String? existingBankAccount = data['bankAccount'] as String?;

            if (existingCatId == 'self_transfer' && (existingAmount - item.amount).abs() < 0.01) {
              processedIds.add(item.id);
              await AutoSmsService.markHashSynced(item.id);
              merged = true;
              break;
            }

            // Branch 1: Classic Debit + Credit pair (opposite directions)
            // Branch 2: Same-direction (e.g. Credit + Credit) pair from different banks with same Ref ID
            final bool isOppositeDirection = existingIsExpense != item.isExpense;
            final bool isSameRefAmountDifferentBank =
                (existingAmount - item.amount).abs() < 0.01 &&
                existingCatId != 'self_transfer' &&
                existingBankAccount != null &&
                item.bankAccount != null &&
                existingBankAccount.toLowerCase().trim() !=
                    (item.bankAccount ?? '').toLowerCase().trim();

            if ((isOppositeDirection || isSameRefAmountDifferentBank) &&
                (existingAmount - item.amount).abs() < 0.01 &&
                existingCatId != 'self_transfer') {
              String? debitBank;
              String? creditBank;
              if (isOppositeDirection) {
                final isDebitIncoming = item.isExpense;
                debitBank = isDebitIncoming ? item.bankAccount : existingBankAccount;
                creditBank = isDebitIncoming ? existingBankAccount : item.bankAccount;
              } else {
                debitBank = existingBankAccount;
                creditBank = item.bankAccount;
              }

              final fromStr = (debitBank != null && debitBank.isNotEmpty) ? debitBank : 'Account';
              final toStr = (creditBank != null && creditBank.isNotEmpty) ? creditBank : 'Account';
              final selfTransferDesc = 'Self Transfer ($fromStr ➔ $toStr)';

              final existingRawBody = data['rawSmsBody'] as String? ?? '';
              final mergedRawBody = '$existingRawBody\n---\n${item.rawSmsBody}';

              await doc.reference.update({
                'categoryId': 'self_transfer',
                'categoryName': 'Self Transfer',
                'iconCodePoint': Icons.sync_alt_rounded.codePoint,
                'colorValue': const Color(0xFF607D8B).toARGB32(),
                'description': selfTransferDesc,
                'isExpense': true,
                'bankAccount': debitBank,
                'merchantName': creditBank ?? 'Self Transfer',
                'rawSmsBody': mergedRawBody,
              });

              processedIds.add(item.id);
              await AutoSmsService.markHashSynced(item.id);
              debugPrint('[AutoSms] Pending item paired with existing Firestore doc ${doc.id} -> $selfTransferDesc');
              merged = true;
              break;
            }
          }
          if (merged) continue;
        } catch (e) {
          debugPrint('[AutoSms] Error checking pending item self transfer counterpart: $e');
        }
      }

      // 3. Fallback: Process single transaction
      final category = getSmartCategory(item, categories);
      final displayTitle = item.smartTitle ?? item.vendorName;

      final success = await ref.read(transactionViewModelProvider.notifier).addTransaction(
            amount: item.amount,
            description: displayTitle,
            category: category,
            date: item.date,
            isExpense: item.isExpense,
            paymentMode: item.paymentMode,
            smsHash: item.id,
            merchantName: item.merchantName ?? item.vendorName,
            bankAccount: item.bankAccount,
            refNumber: item.refNumber,
            rawSmsBody: item.rawSmsBody,
            silentNotification: true,
          );

      if (success) {
        processedIds.add(item.id);
        await AutoSmsService.markHashSynced(item.id);
        debugPrint('[AutoSms] Successfully added transaction: ₹${item.amount} ($displayTitle)');
      }
    }

      state = state.where((item) => !processedIds.contains(item.id)).toList();
      await _saveToPrefs();
    } finally {
      _isProcessingPersonalItems = false;
    }
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> mapList = state.map((item) => item.toMap()).toList();
      await prefs.setString(_prefsKey, jsonEncode(mapList));
    } catch (_) {}
  }

  /// One-time silent migration to backfill SMS hashes for legacy transactions created in older app builds.
  Future<void> _migrateOldBuildTransactions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool isMigrated = prefs.getBool('sms_migration_v2_done') ?? false;
      if (isMigrated) return;

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final isGranted = await Permission.sms.isGranted;
      if (!isGranted) return;

      final recentSms = await AutoSmsService.scanInboxSms(days: 45);
      if (recentSms.isEmpty) {
        await prefs.setBool('sms_migration_v2_done', true);
        return;
      }

      final firestoreSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('transactions')
          .get();

      final Map<String, int> naturalKeySlots = {};
      for (final doc in firestoreSnap.docs) {
        final data = doc.data();
        final amount = (data['amount'] as num?)?.toDouble();
        final isExpense = data['isExpense'] as bool? ?? true;
        final rawDate = data['date'];
        DateTime? d;
        if (rawDate is String) {
          d = DateTime.tryParse(rawDate);
        } else if (rawDate is Timestamp) {
          d = rawDate.toDate();
        }
        if (amount != null && d != null) {
          final natKey = AutoSmsService.buildNaturalKey(
            amount: amount,
            date: d,
            isExpense: isExpense,
          );
          naturalKeySlots[natKey] = (naturalKeySlots[natKey] ?? 0) + 1;
        }
      }

      final List<String> matchedHashes = [];
      for (final sms in recentSms) {
        final natKey = AutoSmsService.buildNaturalKey(
          amount: sms.amount,
          date: sms.date,
          isExpense: sms.isExpense,
        );
        final slots = naturalKeySlots[natKey] ?? 0;
        if (slots > 0) {
          naturalKeySlots[natKey] = slots - 1;
          matchedHashes.add(sms.id);
        }
      }

      if (matchedHashes.isNotEmpty) {
        await AutoSmsService.markHashesSynced(matchedHashes);
        debugPrint('[AutoSms] Migrated & backfilled ${matchedHashes.length} legacy transaction hashes.');
      }
      await prefs.setBool('sms_migration_v2_done', true);
    } catch (e) {
      debugPrint('[AutoSms] Error during legacy SMS migration: $e');
    }
  }

  Future<void> processIncomingSms(String smsBody, {String? sender, DateTime? timestamp}) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final prefs = await SharedPreferences.getInstance();
    final bool isEnabled = (prefs.getBool('auto_sms_enabled') ?? ref.read(autoSmsEnabledProvider)) == true;
    if (!isEnabled) {
      return;
    }

    final parsedSms = SmsParserService.parseSms(smsBody, sender: sender, messageTimestamp: timestamp);
    if (parsedSms == null) {
      return;
    }

    // 1. Deduplication check: Local registry (synced or discarded)
    final syncedHashes = await AutoSmsService.getSyncedHashes();
    if (syncedHashes.contains(parsedSms.id)) {
      debugPrint('[AutoSms] Skipping SMS ${parsedSms.id} - already synced.');
      return;
    }
    final discardedHashes = await AutoSmsService.getDiscardedHashes();
    if (discardedHashes.contains(parsedSms.id)) {
      debugPrint('[AutoSms] Skipping SMS ${parsedSms.id} - discarded.');
      return;
    }

    // 2. Deduplication check: In-memory pending state
    if (state.any((item) => item.id == parsedSms.id)) return;

    // 3. Real-Time Self-Transfer Pairing Check:
    // If incoming SMS has a refNumber (e.g. UPI Ref ID / RRN), check if Firestore already contains
    // an opposite transaction (Debit vs Credit) with matching amount and refNumber.
    final cleanRef = parsedSms.refNumber?.toLowerCase().trim();
    if (cleanRef != null && cleanRef.isNotEmpty) {
      // Layer 1: In-Memory Live Stream Match (0ms Latency)
      final activeTransactions = ref.read(transactionsStreamProvider).value ?? [];
      final alreadyMergedSelfTransfer = activeTransactions.any((t) =>
          t.refNumber != null &&
          t.refNumber!.toLowerCase().trim() == cleanRef &&
          (t.amount - parsedSms.amount).abs() < 0.01 &&
          t.categoryId == 'self_transfer');
      if (alreadyMergedSelfTransfer) {
        await AutoSmsService.markHashSynced(parsedSms.id);
        return;
      }

      final inMemoryMatch = activeTransactions.where((t) {
        if (t.refNumber == null || t.refNumber!.isEmpty) return false;
        if (t.refNumber!.toLowerCase().trim() != cleanRef) return false;
        if ((t.amount - parsedSms.amount).abs() >= 0.01) return false;
        if (t.categoryId == 'self_transfer') return false;
        return true;
      }).firstOrNull;

      if (inMemoryMatch != null) {
        final isOpposite = inMemoryMatch.isExpense != parsedSms.isExpense;
        final isSameRefDifferentBank = inMemoryMatch.bankAccount != null &&
            parsedSms.bankAccount != null &&
            inMemoryMatch.bankAccount!.toLowerCase().trim() !=
                (parsedSms.bankAccount ?? '').toLowerCase().trim();

        if (isOpposite || isSameRefDifferentBank) {
          String? debitBank;
          String? creditBank;
          if (isOpposite) {
            debitBank = parsedSms.isExpense ? parsedSms.bankAccount : inMemoryMatch.bankAccount;
            creditBank = parsedSms.isExpense ? inMemoryMatch.bankAccount : parsedSms.bankAccount;
          } else {
            debitBank = inMemoryMatch.bankAccount;
            creditBank = parsedSms.bankAccount;
          }

          final fromStr = (debitBank != null && debitBank.isNotEmpty) ? debitBank : 'Account';
          final toStr = (creditBank != null && creditBank.isNotEmpty) ? creditBank : 'Account';
          final selfTransferDesc = 'Self Transfer ($fromStr ➔ $toStr)';

          final existingRawBody = inMemoryMatch.rawSmsBody ?? '';
          final mergedRawBody = existingRawBody.isNotEmpty
              ? '$existingRawBody\n---\n${parsedSms.rawSmsBody}'
              : parsedSms.rawSmsBody;

          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .collection('transactions')
              .doc(inMemoryMatch.id)
              .update({
            'categoryId': 'self_transfer',
            'categoryName': 'Self Transfer',
            'iconCodePoint': Icons.sync_alt_rounded.codePoint,
            'colorValue': const Color(0xFF607D8B).toARGB32(),
            'description': selfTransferDesc,
            'isExpense': true,
            'bankAccount': debitBank,
            'merchantName': creditBank ?? 'Self Transfer',
            'rawSmsBody': mergedRawBody,
          });

          await AutoSmsService.markHashSynced(parsedSms.id);
          debugPrint('[AutoSms] Layer 1 In-Memory Paired Self Transfer: ${inMemoryMatch.id} upgraded to $selfTransferDesc');
          return;
        }
      }

      // Layer 3: Remote Firestore Database Lookup (Fallback)
      try {
        final existingDocs = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('transactions')
            .where('refNumber', isEqualTo: parsedSms.refNumber)
            .limit(3)
            .get();

        for (final doc in existingDocs.docs) {
          final data = doc.data();
          final bool existingIsExpense = data['isExpense'] as bool? ?? true;
          final double existingAmount = (data['amount'] as num?)?.toDouble() ?? 0.0;
          final String existingCatId = data['categoryId'] as String? ?? '';
          final String? existingBankAccount = data['bankAccount'] as String?;

          if (existingCatId == 'self_transfer' && (existingAmount - parsedSms.amount).abs() < 0.01) {
            await AutoSmsService.markHashSynced(parsedSms.id);
            return;
          }

          // Branch 1: Classic Debit + Credit pair (opposite directions)
          // Branch 2: Same-direction (e.g. Credit + Credit) pair from different banks with same Ref ID
          final bool isOppositeDirection = existingIsExpense != parsedSms.isExpense;
          final bool isSameRefAmountDifferentBank =
              (existingAmount - parsedSms.amount).abs() < 0.01 &&
              existingCatId != 'self_transfer' &&
              existingBankAccount != null &&
              parsedSms.bankAccount != null &&
              existingBankAccount.toLowerCase().trim() !=
                  (parsedSms.bankAccount ?? '').toLowerCase().trim();

          if ((isOppositeDirection || isSameRefAmountDifferentBank) &&
              (existingAmount - parsedSms.amount).abs() < 0.01 &&
              existingCatId != 'self_transfer') {
            // Determine source (debit) and destination (credit) banks
            String? debitBank;
            String? creditBank;
            if (isOppositeDirection) {
              final isDebitIncoming = parsedSms.isExpense;
              debitBank = isDebitIncoming ? parsedSms.bankAccount : existingBankAccount;
              creditBank = isDebitIncoming ? existingBankAccount : parsedSms.bankAccount;
            } else {
              // Both credits: treat existing as first leg, incoming as second leg
              debitBank = existingBankAccount;
              creditBank = parsedSms.bankAccount;
            }

            final fromStr = (debitBank != null && debitBank.isNotEmpty) ? debitBank : 'Account';
            final toStr = (creditBank != null && creditBank.isNotEmpty) ? creditBank : 'Account';
            final selfTransferDesc = 'Self Transfer ($fromStr ➔ $toStr)';

            final existingRawBody = data['rawSmsBody'] as String? ?? '';
            final mergedRawBody = '$existingRawBody\n---\n${parsedSms.rawSmsBody}';

            await doc.reference.update({
              'categoryId': 'self_transfer',
              'categoryName': 'Self Transfer',
              'iconCodePoint': Icons.sync_alt_rounded.codePoint,
              'colorValue': const Color(0xFF607D8B).toARGB32(),
              'description': selfTransferDesc,
              'isExpense': true,
              'bankAccount': debitBank,
              'merchantName': creditBank ?? 'Self Transfer',
              'rawSmsBody': mergedRawBody,
            });

            await AutoSmsService.markHashSynced(parsedSms.id);
            debugPrint('[AutoSms] Real-time paired Self Transfer: Upgraded transaction ${doc.id} to $selfTransferDesc');
            return;
          }
        }
      } catch (e) {
        debugPrint('[AutoSms] Error checking real-time self transfer counterpart: $e');
      }
    }

    // 4. Auto-Add directly to Personal Workspace in Firestore
    final categories = ref.read(categoriesProvider).value ?? kDefaultCategories;
    final category = getSmartCategory(parsedSms, categories);
    final displayTitle = parsedSms.smartTitle ?? parsedSms.vendorName;

    // Mark hash as synced immediately to prevent concurrent thread duplicate attempts
    await AutoSmsService.markHashSynced(parsedSms.id);

    final success = await ref.read(transactionViewModelProvider.notifier).addTransaction(
          amount: parsedSms.amount,
          description: displayTitle,
          category: category,
          date: parsedSms.date,
          isExpense: parsedSms.isExpense,
          paymentMode: parsedSms.paymentMode,
          smsHash: parsedSms.id,
          merchantName: parsedSms.merchantName ?? parsedSms.vendorName,
          bankAccount: parsedSms.bankAccount,
          refNumber: parsedSms.refNumber,
          rawSmsBody: parsedSms.rawSmsBody,
          silentNotification: true,
        );

    if (success) {
      debugPrint('[AutoSms] Real-time SMS successfully added to Firestore!');
    }
  }

  /// Scans past SMS messages from device inbox (last [days]), parses transactions, and imports them.
  /// Firestore acts as the single source of truth for deduplication.
  /// Returns a record of `({int addedCount, int skippedCount, double totalIncome, double totalExpense})`.
  Future<({int addedCount, int skippedCount, double totalIncome, double totalExpense})> syncPastSms({int days = 30}) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return (addedCount: 0, skippedCount: 0, totalIncome: 0.0, totalExpense: 0.0);

    final isGranted = await Permission.sms.isGranted;
    if (!isGranted) {
      final status = await Permission.sms.request();
      if (!status.isGranted) return (addedCount: 0, skippedCount: 0, totalIncome: 0.0, totalExpense: 0.0);
    }

    // If a background silent sync is currently in-flight, wait briefly for it to yield/finish
    int waitIterations = 0;
    while (_isSyncingInProgress && _isSilentSyncRunning && waitIterations < 25) {
      await Future.delayed(const Duration(milliseconds: 100));
      waitIterations++;
    }

    if (_isSyncingInProgress && !_isSilentSyncRunning) {
      debugPrint('[AutoSms] Another explicit sync is already in progress, skipping duplicate.');
      return (addedCount: 0, skippedCount: 0, totalIncome: 0.0, totalExpense: 0.0);
    }
    _isSyncingInProgress = true;

    try {
      // Explicit user manual sync clears discarded blacklist so missing/deleted SMS can be restored from inbox
      await AutoSmsService.clearDiscardedHashes();

      final newItems = await AutoSmsService.scanInboxSms(days: days);
      if (newItems.isEmpty) return (addedCount: 0, skippedCount: 0, totalIncome: 0.0, totalExpense: 0.0);

      await _loadFromPrefs();

      // 1. Single Source of Truth: Fetch active transactions from Firestore
      final Set<String> activeFirestoreHashes = {};
      final Set<String> activeRefNumbers = {};
      final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> existingRefDocs = {};
      final Map<String, int> naturalKeySlots = {};

      try {
        final firestoreSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('transactions')
            .get();

        for (final doc in firestoreSnap.docs) {
          final data = doc.data();
          final hash = data['smsHash'] as String?;
          if (hash != null && hash.isNotEmpty) {
            activeFirestoreHashes.add(hash);
          }
          final ref = data['refNumber'] as String?;
          if (ref != null && ref.isNotEmpty) {
            final cleanRef = ref.toLowerCase().trim();
            activeRefNumbers.add(cleanRef);
            existingRefDocs[cleanRef] = doc;
          }
          final amount = (data['amount'] as num?)?.toDouble();
          final isExpense = data['isExpense'] as bool? ?? true;
          final rawDate = data['date'];
          DateTime? d;
          if (rawDate is String) {
            d = DateTime.tryParse(rawDate);
          } else if (rawDate is Timestamp) {
            d = rawDate.toDate();
          }
          if (amount != null && d != null) {
            final natKey = AutoSmsService.buildNaturalKey(
              amount: amount,
              date: d,
              isExpense: isExpense,
            );
            naturalKeySlots[natKey] = (naturalKeySlots[natKey] ?? 0) + 1;
          }
        }
      } catch (e) {
        debugPrint('[AutoSms] Error fetching Firestore transactions during sync: $e');
        final localSynced = await AutoSmsService.getSyncedHashes();
        activeFirestoreHashes.addAll(localSynced);
      }

      // Synchronize local persistent storage with Firestore active state
      await AutoSmsService.setSyncedHashes(activeFirestoreHashes);

      final categories = ref.read(categoriesProvider).value ?? kDefaultCategories;
      final List<TransactionModel> toAddBatch = [];
      final List<String> newlyAddedHashes = [];
      int skippedCount = 0;

      // Group newItems by refNumber to detect Self-Transfer pairs (matching refNumber with 1 Debit and 1 Credit)
      final Map<String, List<ModelPendingSms>> refGroups = {};
      for (final item in newItems) {
        final ref = item.refNumber?.toLowerCase().trim();
        if (ref != null && ref.isNotEmpty) {
          refGroups.putIfAbsent(ref, () => []).add(item);
        }
      }

      final Set<String> pairedSmsIds = {};

      for (final entry in refGroups.entries) {
        final ref = entry.key;
        final list = entry.value;
        final debitItem = list.where((i) => i.isExpense).firstOrNull;
        final creditItem = list.where((i) => !i.isExpense).firstOrNull;

        if (debitItem != null && creditItem != null) {
          for (final grpItem in list) {
            pairedSmsIds.add(grpItem.id);
          }

          // Check if already active in Firestore
          if (activeFirestoreHashes.contains(debitItem.id) ||
              activeFirestoreHashes.contains(creditItem.id) ||
              activeRefNumbers.contains(ref)) {
            activeFirestoreHashes.add(debitItem.id);
            activeFirestoreHashes.add(creditItem.id);
            skippedCount += 2;
            continue;
          }

          final fromStr = (debitItem.bankAccount != null && debitItem.bankAccount!.isNotEmpty)
              ? debitItem.bankAccount!
              : 'Account';
          final toStr = (creditItem.bankAccount != null && creditItem.bankAccount!.isNotEmpty)
              ? creditItem.bankAccount!
              : 'Account';
          final selfTransferDesc = 'Self Transfer ($fromStr ➔ $toStr)';

          final selfTx = TransactionModel(
            id: '',
            amount: debitItem.amount,
            description: selfTransferDesc,
            categoryId: 'self_transfer',
            categoryName: 'Self Transfer',
            iconCodePoint: Icons.sync_alt_rounded.codePoint,
            colorValue: const Color(0xFF607D8B).toARGB32(),
            date: debitItem.date,
            userId: currentUser.uid,
            isExpense: true,
            paymentMode: debitItem.paymentMode,
            smsHash: debitItem.id,
            merchantName: creditItem.bankAccount ?? 'Self Transfer',
            bankAccount: debitItem.bankAccount,
            refNumber: debitItem.refNumber,
            rawSmsBody: '${debitItem.rawSmsBody}\n---\n${creditItem.rawSmsBody}',
          );

          toAddBatch.add(selfTx);
          newlyAddedHashes.add(debitItem.id);
          newlyAddedHashes.add(creditItem.id);
          activeFirestoreHashes.add(debitItem.id);
          activeFirestoreHashes.add(creditItem.id);
          activeRefNumbers.add(ref);
        }
      }

      for (final parsedSms in newItems) {
        if (pairedSmsIds.contains(parsedSms.id)) {
          continue;
        }

        // 1. Check if already active in Firestore by exact SMS hash
        if (activeFirestoreHashes.contains(parsedSms.id)) {
          skippedCount++;
          continue;
        }

        // 2. Exact UPI Ref / Txn ID match
        final cleanRef = parsedSms.refNumber?.toLowerCase().trim();
        if (cleanRef != null && cleanRef.isNotEmpty && existingRefDocs.containsKey(cleanRef)) {
          final existingDoc = existingRefDocs[cleanRef]!;
          final existingData = existingDoc.data();
          final existingIsExpense = existingData['isExpense'] as bool? ?? true;
          final existingCatId = existingData['categoryId'] as String? ?? '';

          if (existingIsExpense != parsedSms.isExpense && existingCatId != 'self_transfer') {
            debugPrint('[AutoSms] Upgrading existing Firestore doc to Self Transfer for ref: $cleanRef');
            final debitBank = parsedSms.isExpense ? parsedSms.bankAccount : (existingData['bankAccount'] as String?);
            final creditBank = !parsedSms.isExpense ? parsedSms.bankAccount : (existingData['bankAccount'] as String?);

            final fromStr = (debitBank != null && debitBank.isNotEmpty) ? debitBank : 'Account';
            final toStr = (creditBank != null && creditBank.isNotEmpty) ? creditBank : 'Account';
            final selfTransferDesc = 'Self Transfer ($fromStr ➔ $toStr)';

            await existingDoc.reference.update({
              'categoryId': 'self_transfer',
              'categoryName': 'Self Transfer',
              'iconCodePoint': Icons.sync_alt_rounded.codePoint,
              'colorValue': const Color(0xFF607D8B).toARGB32(),
              'description': selfTransferDesc,
              if (parsedSms.bankAccount != null && (existingData['bankAccount'] == null || (existingData['bankAccount'] as String).isEmpty))
                'bankAccount': parsedSms.bankAccount,
              if (parsedSms.merchantName != null && (existingData['merchantName'] == null || (existingData['merchantName'] as String).isEmpty))
                'merchantName': parsedSms.merchantName,
            });

            newlyAddedHashes.add(parsedSms.id);
            activeFirestoreHashes.add(parsedSms.id);
            continue;
          }

          activeFirestoreHashes.add(parsedSms.id);
          skippedCount++;
          continue;
        }

        // 3. In-memory pending items
        if (state.any((item) => item.id == parsedSms.id)) {
          skippedCount++;
          continue;
        }

        // 4. Backward-Compatible Natural Key Slot Match (Amount + Date + IsExpense)
        final natKey = AutoSmsService.buildNaturalKey(
          amount: parsedSms.amount,
          date: parsedSms.date,
          isExpense: parsedSms.isExpense,
        );
        final availableSlots = naturalKeySlots[natKey] ?? 0;
        if (availableSlots > 0) {
          naturalKeySlots[natKey] = availableSlots - 1;
          activeFirestoreHashes.add(parsedSms.id);
          skippedCount++;
          continue;
        }

        final category = getSmartCategory(parsedSms, categories);
        final displayTitle = parsedSms.smartTitle ?? parsedSms.vendorName;

        final transaction = TransactionModel(
          id: '',
          amount: parsedSms.amount,
          description: displayTitle,
          categoryId: category.id,
          categoryName: category.name,
          iconCodePoint: category.iconCodePoint,
          colorValue: category.colorValue,
          date: parsedSms.date,
          userId: currentUser.uid,
          isExpense: parsedSms.isExpense,
          paymentMode: parsedSms.paymentMode,
          smsHash: parsedSms.id,
          merchantName: parsedSms.merchantName ?? parsedSms.vendorName,
          bankAccount: parsedSms.bankAccount,
          refNumber: parsedSms.refNumber,
          rawSmsBody: parsedSms.rawSmsBody,
        );

        toAddBatch.add(transaction);
        newlyAddedHashes.add(parsedSms.id);
        activeFirestoreHashes.add(parsedSms.id);
        if (cleanRef != null && cleanRef.isNotEmpty) {
          activeRefNumbers.add(cleanRef);
        }
      }

      int addedCount = 0;
      double totalIncome = 0.0;
      double totalExpense = 0.0;
      if (toAddBatch.isNotEmpty) {
        for (final tx in toAddBatch) {
          if (tx.categoryId == 'self_transfer') continue; // Net zero fund movement
          if (tx.isExpense) {
            totalExpense += tx.amount;
          } else {
            totalIncome += tx.amount;
          }
        }
        addedCount = await ref
            .read(transactionViewModelProvider.notifier)
            .addTransactionsBatch(toAddBatch);

        if (addedCount > 0) {
          await AutoSmsService.markHashesSynced(newlyAddedHashes);
          await AutoSmsService.setSyncedHashes(activeFirestoreHashes);
          await AutoSmsService.clearDiscardedHashes();
        }
      }

      return (
        addedCount: addedCount,
        skippedCount: skippedCount,
        totalIncome: totalIncome,
        totalExpense: totalExpense,
      );
    } finally {
      _isSyncingInProgress = false;
    }
  }

  /// Performs a quick silent background delta scan on app start / resume to catch any SMS
  /// that may have arrived while device was in deep sleep or killed by OEM.
  Future<void> performStartupSilentSync({int days = 2}) async {
    if (_isSyncingInProgress) {
      debugPrint('[AutoSms] Sync already in progress, skipping startup silent sync.');
      return;
    }
    _isSyncingInProgress = true;
    _isSilentSyncRunning = true;

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final isGranted = await Permission.sms.isGranted;
      if (!isGranted) return;

      final prefs = await SharedPreferences.getInstance();
      final isEnabled = prefs.getBool('auto_sms_enabled') ?? false;
      if (!isEnabled) return;

      // Flush any pending native receiver items first before scanning inbox
      await _loadFromPrefs();

      // Run one-time legacy build migration if not done yet
      await _migrateOldBuildTransactions();

      final newItems = await AutoSmsService.scanInboxSms(days: days);
      if (newItems.isEmpty) return;

      final discardedHashes = await AutoSmsService.getDiscardedHashes();

      // 1. DIRECT FIRESTORE QUERY - Absolute Source of Truth
      final Set<String> activeFirestoreHashes = {};
      final Set<String> activeRefNumbers = {};
      final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> existingRefDocs = {};
      final Map<String, int> naturalKeySlots = {};

      try {
        final firestoreSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('transactions')
            .get();

        for (final doc in firestoreSnap.docs) {
          final data = doc.data();
          final hash = data['smsHash'] as String?;
          if (hash != null && hash.isNotEmpty) {
            activeFirestoreHashes.add(hash);
          }
          final ref = data['refNumber'] as String?;
          if (ref != null && ref.isNotEmpty) {
            final cleanRef = ref.toLowerCase().trim();
            activeRefNumbers.add(cleanRef);
            existingRefDocs[cleanRef] = doc;
          }
          final amount = (data['amount'] as num?)?.toDouble();
          final isExpense = data['isExpense'] as bool? ?? true;
          final rawDate = data['date'];
          DateTime? d;
          if (rawDate is String) {
            d = DateTime.tryParse(rawDate);
          } else if (rawDate is Timestamp) {
            d = rawDate.toDate();
          }
          if (amount != null && d != null) {
            final natKey = AutoSmsService.buildNaturalKey(
              amount: amount,
              date: d,
              isExpense: isExpense,
            );
            naturalKeySlots[natKey] = (naturalKeySlots[natKey] ?? 0) + 1;
          }
        }
      } catch (e) {
        debugPrint('[AutoSms] Error fetching Firestore transactions during silent sync: $e');
        final localSynced = await AutoSmsService.getSyncedHashes();
        activeFirestoreHashes.addAll(localSynced);
      }

      await AutoSmsService.setSyncedHashes(activeFirestoreHashes);

      final categories = ref.read(categoriesProvider).value ?? kDefaultCategories;
      final List<TransactionModel> toAddBatch = [];
      final List<String> newlyAddedHashes = [];

      // Group newItems by refNumber to detect Self-Transfer pairs
      final Map<String, List<ModelPendingSms>> refGroups = {};
      for (final item in newItems) {
        final ref = item.refNumber?.toLowerCase().trim();
        if (ref != null && ref.isNotEmpty) {
          refGroups.putIfAbsent(ref, () => []).add(item);
        }
      }

      final Set<String> pairedSmsIds = {};

      for (final entry in refGroups.entries) {
        final ref = entry.key;
        final list = entry.value;
        final debitItem = list.where((i) => i.isExpense).firstOrNull;
        final creditItem = list.where((i) => !i.isExpense).firstOrNull;

        if (debitItem != null && creditItem != null) {
          for (final grpItem in list) {
            pairedSmsIds.add(grpItem.id);
          }

          if (activeFirestoreHashes.contains(debitItem.id) ||
              activeFirestoreHashes.contains(creditItem.id) ||
              activeRefNumbers.contains(ref)) {
            activeFirestoreHashes.add(debitItem.id);
            activeFirestoreHashes.add(creditItem.id);
            continue;
          }

          final fromStr = (debitItem.bankAccount != null && debitItem.bankAccount!.isNotEmpty)
              ? debitItem.bankAccount!
              : 'Account';
          final toStr = (creditItem.bankAccount != null && creditItem.bankAccount!.isNotEmpty)
              ? creditItem.bankAccount!
              : 'Account';
          final selfTransferDesc = 'Self Transfer ($fromStr ➔ $toStr)';

          final selfTx = TransactionModel(
            id: '',
            amount: debitItem.amount,
            description: selfTransferDesc,
            categoryId: 'self_transfer',
            categoryName: 'Self Transfer',
            iconCodePoint: Icons.sync_alt_rounded.codePoint,
            colorValue: const Color(0xFF607D8B).toARGB32(),
            date: debitItem.date,
            userId: currentUser.uid,
            isExpense: true,
            paymentMode: debitItem.paymentMode,
            smsHash: debitItem.id,
            merchantName: creditItem.bankAccount ?? 'Self Transfer',
            bankAccount: debitItem.bankAccount,
            refNumber: debitItem.refNumber,
            rawSmsBody: '${debitItem.rawSmsBody}\n---\n${creditItem.rawSmsBody}',
          );

          toAddBatch.add(selfTx);
          newlyAddedHashes.add(debitItem.id);
          newlyAddedHashes.add(creditItem.id);
          activeFirestoreHashes.add(debitItem.id);
          activeFirestoreHashes.add(creditItem.id);
          activeRefNumbers.add(ref);
        }
      }

      for (final parsedSms in newItems) {
        if (pairedSmsIds.contains(parsedSms.id)) continue;
        if (activeFirestoreHashes.contains(parsedSms.id)) continue;

        final cleanRef = parsedSms.refNumber?.toLowerCase().trim();
        if (cleanRef != null && cleanRef.isNotEmpty && existingRefDocs.containsKey(cleanRef)) {
          final existingDoc = existingRefDocs[cleanRef]!;
          final existingData = existingDoc.data();
          final existingIsExpense = existingData['isExpense'] as bool? ?? true;
          final existingCatId = existingData['categoryId'] as String? ?? '';

          if (existingIsExpense != parsedSms.isExpense && existingCatId != 'self_transfer') {
            debugPrint('[AutoSms] Silent sync: Upgrading existing doc to Self Transfer for ref: $cleanRef');
            final debitBank = parsedSms.isExpense ? parsedSms.bankAccount : (existingData['bankAccount'] as String?);
            final creditBank = !parsedSms.isExpense ? parsedSms.bankAccount : (existingData['bankAccount'] as String?);

            final fromStr = (debitBank != null && debitBank.isNotEmpty) ? debitBank : 'Account';
            final toStr = (creditBank != null && creditBank.isNotEmpty) ? creditBank : 'Account';
            final selfTransferDesc = 'Self Transfer ($fromStr ➔ $toStr)';

            await existingDoc.reference.update({
              'categoryId': 'self_transfer',
              'categoryName': 'Self Transfer',
              'iconCodePoint': Icons.sync_alt_rounded.codePoint,
              'colorValue': const Color(0xFF607D8B).toARGB32(),
              'description': selfTransferDesc,
              if (parsedSms.bankAccount != null && (existingData['bankAccount'] == null || (existingData['bankAccount'] as String).isEmpty))
                'bankAccount': parsedSms.bankAccount,
              if (parsedSms.merchantName != null && (existingData['merchantName'] == null || (existingData['merchantName'] as String).isEmpty))
                'merchantName': parsedSms.merchantName,
            });

            newlyAddedHashes.add(parsedSms.id);
            activeFirestoreHashes.add(parsedSms.id);
            continue;
          }

          activeFirestoreHashes.add(parsedSms.id);
          continue;
        }

        if (discardedHashes.contains(parsedSms.id)) continue;
        if (state.any((item) => item.id == parsedSms.id)) continue;

        // Backward-Compatible Natural Key Slot Match
        final natKey = AutoSmsService.buildNaturalKey(
          amount: parsedSms.amount,
          date: parsedSms.date,
          isExpense: parsedSms.isExpense,
        );
        final availableSlots = naturalKeySlots[natKey] ?? 0;
        if (availableSlots > 0) {
          naturalKeySlots[natKey] = availableSlots - 1;
          activeFirestoreHashes.add(parsedSms.id);
          continue;
        }

        final category = getSmartCategory(parsedSms, categories);
        final displayTitle = parsedSms.smartTitle ?? parsedSms.vendorName;
        final transaction = TransactionModel(
          id: '',
          amount: parsedSms.amount,
          description: displayTitle,
          categoryId: category.id,
          categoryName: category.name,
          iconCodePoint: category.iconCodePoint,
          colorValue: category.colorValue,
          date: parsedSms.date,
          userId: currentUser.uid,
          isExpense: parsedSms.isExpense,
          paymentMode: parsedSms.paymentMode,
          smsHash: parsedSms.id,
          merchantName: parsedSms.merchantName ?? parsedSms.vendorName,
          bankAccount: parsedSms.bankAccount,
          refNumber: parsedSms.refNumber,
          rawSmsBody: parsedSms.rawSmsBody,
        );

        toAddBatch.add(transaction);
        newlyAddedHashes.add(parsedSms.id);
        activeFirestoreHashes.add(parsedSms.id);
        if (cleanRef != null && cleanRef.isNotEmpty) {
          activeRefNumbers.add(cleanRef);
        }
      }

      if (toAddBatch.isNotEmpty) {
        final added = await ref
            .read(transactionViewModelProvider.notifier)
            .addTransactionsBatch(toAddBatch);

        if (added > 0) {
          await AutoSmsService.markHashesSynced(newlyAddedHashes);
          await AutoSmsService.setSyncedHashes(activeFirestoreHashes);
          debugPrint('[AutoSms] Silent startup sync added $added transactions in 1 batch.');
        }
      }
    } catch (e) {
      debugPrint('[AutoSms] Silent startup sync error: $e');
    } finally {
      _isSilentSyncRunning = false;
      _isSyncingInProgress = false;
    }
  }

  static CategoryModel getSmartCategory(ModelPendingSms sms, List<CategoryModel> categories) {
    final activeCategories = categories.isNotEmpty ? categories : kDefaultCategories;

    final vendor = sms.vendorName.toLowerCase();
    var body = sms.rawSmsBody.toLowerCase();

    // Strip common bank disclaimers that cause false positives (e.g. cheque clearing footer, security lines)
    body = body
        .replaceAll(RegExp(r'cheque deposits? in a\/c are subject to clearing', caseSensitive: false), '')
        .replaceAll(RegExp(r'subject to clearing', caseSensitive: false), '')
        .replaceAll(RegExp(r'not you\?.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'if not requested.*$', caseSensitive: false), '');

    final combined = '$vendor $body';

    CategoryModel? findCategory(String targetId, [List<String> altNames = const []]) {
      for (final c in activeCategories) {
        final cid = c.id.toLowerCase();
        final cname = c.name.toLowerCase();
        if (cid == targetId || cname == targetId) return c;
        for (final alt in altNames) {
          if (cid == alt || cname == alt || cname.contains(alt)) return c;
        }
      }
      return null;
    }

    // 🟢 Income / Credit Transactions
    if (!sms.isExpense) {
      // 1. Refunds, Cashbacks, Rewards & Reversals (Priority 1 to prevent false positives on corporate names)
      if (combined.contains('refund') ||
          combined.contains('cashback') ||
          combined.contains('reward') ||
          combined.contains('reversal') ||
          combined.contains('reversed') ||
          combined.contains('scratch') ||
          combined.contains('goog-payments') ||
          combined.contains('google payment') ||
          combined.contains('google india') ||
          combined.contains('chargeback') ||
          (sms.amount <= 500 && (combined.contains('google') || combined.contains('gpay') || combined.contains('phonepe') || combined.contains('paytm') || combined.contains('amazon pay')))) {
        final match = findCategory('refund', ['refunds', 'cashback', 'reward']);
        if (match != null) return match;
      }

      // 2. APY / NPS Pension Schemes (Government pension)
      if (RegExp(r'\bpran\b|pran[\s\:\#\-xX\*]*\d+', caseSensitive: false).hasMatch(combined) ||
          RegExp(r'\bapy\b|atal pension', caseSensitive: false).hasMatch(combined) ||
          RegExp(r'\bnps\b|national pension', caseSensitive: false).hasMatch(combined) ||
          combined.contains('protean') ||
          combined.contains('pfrda')) {
        final match = findCategory('investments', ['investment', 'wealth']);
        if (match != null) return match;
      }

      // 3. Bank Interest / Dividends / Returns
      if (combined.contains('towards interest') ||
          combined.contains('interest of') ||
          combined.contains('interest credited') ||
          combined.contains('sb interest') ||
          combined.contains('term deposit interest') ||
          combined.contains('dividend') ||
          combined.contains('yield') ||
          RegExp(r'\binterest\b', caseSensitive: false).hasMatch(combined)) {
        final match = findCategory('returns', ['returns & div', 'dividend', 'interest']);
        if (match != null) return match;
      }

      // 4. Peer-to-Peer / UPI Inflow from identifiable person/VPA
      if (combined.contains('from vpa') ||
          combined.contains('vpa ') ||
          combined.contains('upi/cr') ||
          combined.contains('upi/dr') ||
          combined.contains('@ok') ||
          combined.contains('@axis') ||
          combined.contains('@hdfc') ||
          combined.contains('@icici') ||
          combined.contains('@sbi') ||
          combined.contains('@ybl') ||
          combined.contains('@paytm') ||
          combined.contains('from aryan') ||
          combined.contains('received from') ||
          combined.contains('transfer from') ||
          combined.contains('credited by')) {
        final match = findCategory('transfer', ['transfers']);
        if (match != null) return match;
      }

      // 5. Unified Primary Income (Salary, Employer Payouts, Earnings, Deposits, Inflows)
      final incomeMatch = findCategory('income', ['general income', 'inflow', 'earnings', 'other income']);
      if (incomeMatch != null) return incomeMatch;

      return activeCategories.first;
    }

    // 🔴 Expense / Debit Transactions
    // 1. Investment & Wealth (Mutual funds, SIP, Stocks, Demat, Gold, Clearing Houses, APY, NPS, PRAN)
    if (combined.contains('indian clearing') ||
        combined.contains('iccl') ||
        combined.contains('nse clearing') ||
        combined.contains('ncl') ||
        combined.contains('clearing corp') ||
        combined.contains('clearing corporation') ||
        combined.contains('mf central') ||
        combined.contains('groww') ||
        combined.contains('zerodha') ||
        combined.contains('upstox') ||
        combined.contains('angelone') ||
        combined.contains('angel one') ||
        combined.contains('angel broking') ||
        combined.contains('kuvera') ||
        combined.contains('smallcase') ||
        combined.contains('indmoney') ||
        combined.contains('motilal') ||
        combined.contains('hdfc sec') ||
        combined.contains('icici direct') ||
        combined.contains('kotak sec') ||
        combined.contains('paytm money') ||
        combined.contains('et money') ||
        combined.contains('mutual fund') ||
        combined.contains('demat') ||
        combined.contains('cams') ||
        combined.contains('kfintech') ||
        combined.contains('sharekhan') ||
        combined.contains('5paisa') ||
        combined.contains('protean') ||
        combined.contains('pfrda') ||
        RegExp(r'\bpran\b|pran[\s\:\#\-xX\*]*\d+', caseSensitive: false).hasMatch(combined) ||
        RegExp(r'\bapy\b|atal pension', caseSensitive: false).hasMatch(combined) ||
        RegExp(r'\bnps\b|national pension', caseSensitive: false).hasMatch(combined) ||
        RegExp(r'\bsip\b').hasMatch(combined) ||
        RegExp(r'\bppf\b').hasMatch(combined) ||
        RegExp(r'\bbse\b').hasMatch(combined) ||
        RegExp(r'\bnse\b').hasMatch(combined) ||
        RegExp(r'\bstocks?\b').hasMatch(combined) ||
        RegExp(r'\bnav\b').hasMatch(combined)) {
      final match = findCategory('investments', ['investment', 'wealth', 'stock']);
      if (match != null) return match;
    }

    // 2. Groceries & Quick Commerce
    if (combined.contains('blinkit') ||
        combined.contains('zepto') ||
        combined.contains('instamart') ||
        combined.contains('bigbasket') ||
        combined.contains('bbdaily') ||
        combined.contains('dunzo') ||
        combined.contains('dmart') ||
        combined.contains('spencer') ||
        combined.contains("nature's basket") ||
        combined.contains('jiomart') ||
        combined.contains('reliance fresh') ||
        combined.contains('more retail') ||
        combined.contains('dairy') ||
        combined.contains('country delight') ||
        combined.contains('grocery') ||
        combined.contains('supermarket') ||
        combined.contains('kirana') ||
        combined.contains('bhandar') ||
        combined.contains('general store') ||
        combined.contains('vegetable') ||
        combined.contains('vegitables') ||
        combined.contains('fruit') ||
        RegExp(r'\bmart\b').hasMatch(combined) ||
        RegExp(r'\bmilk\b').hasMatch(combined)) {
      final match = findCategory('groceries', ['grocery', 'quick commerce']);
      if (match != null) return match;
    }

    // 3. Food & Dining
    if (combined.contains('zomato') ||
        combined.contains('swiggy') ||
        combined.contains('eatclub') ||
        combined.contains('domino') ||
        combined.contains('pizza') ||
        combined.contains('kfc') ||
        combined.contains('mcdonald') ||
        combined.contains('burger king') ||
        combined.contains('starbucks') ||
        combined.contains('chaayos') ||
        combined.contains('cafe coffee day') ||
        combined.contains('barbeque nation') ||
        combined.contains('haldiram') ||
        combined.contains('bikanervala') ||
        combined.contains('restaurant') ||
        combined.contains('cafe') ||
        combined.contains('dining') ||
        combined.contains('dhaba') ||
        combined.contains('bakery') ||
        combined.contains('subway') ||
        combined.contains('behrouz') ||
        combined.contains('faasos') ||
        combined.contains('ovenstory') ||
        combined.contains('dinner') ||
        combined.contains('lunch') ||
        combined.contains('breakfast') ||
        combined.contains('meal') ||
        combined.contains('snacks') ||
        combined.contains('food') ||
        combined.contains('sweet') ||
        combined.contains('fast food') ||
        combined.contains('fast fo') ||
        combined.contains('juice') ||
        RegExp(r'\bdine\b').hasMatch(combined) ||
        RegExp(r'\beats\b').hasMatch(combined)) {
      final match = findCategory('food', ['dining', 'restaurant']);
      if (match != null) return match;
    }

    // 4. Shopping & Retail
    if (combined.contains('amazon') ||
        combined.contains('flipkart') ||
        combined.contains('myntra') ||
        combined.contains('ajio') ||
        combined.contains('nykaa') ||
        combined.contains('tata cliq') ||
        combined.contains('meesho') ||
        combined.contains('zara') ||
        combined.contains('h&m') ||
        combined.contains('uniqlo') ||
        combined.contains('croma') ||
        combined.contains('reliance digital') ||
        combined.contains('vijay sales') ||
        combined.contains('ikea') ||
        combined.contains('decathlon') ||
        combined.contains('lenskart') ||
        combined.contains('snitch') ||
        combined.contains('mall') ||
        combined.contains('retail') ||
        combined.contains('apparel') ||
        combined.contains('dry cleaner') ||
        combined.contains('dry cleaners') ||
        combined.contains('garment') ||
        combined.contains('clothing') ||
        combined.contains('shoe') ||
        combined.contains('footwear') ||
        combined.contains('tailor') ||
        combined.contains('salon') ||
        combined.contains('boutique') ||
        (combined.contains('store') && !combined.contains('play store') && !combined.contains('app store') && !combined.contains('general store')) ||
        RegExp(r'\bmart\b').hasMatch(combined)) {
      final match = findCategory('shopping', ['retail']);
      if (match != null) return match;
    }

    // 5. Fuel
    if (combined.contains('fuel') ||
        combined.contains('petrol') ||
        combined.contains('diesel') ||
        combined.contains('cng') ||
        combined.contains('filling') ||
        combined.contains('pump') ||
        combined.contains('hpcl') ||
        combined.contains('bpcl') ||
        combined.contains('iocl') ||
        combined.contains('shell')) {
      final match = findCategory('fuel', ['gas', 'petrol']) ?? findCategory('transport', ['travel', 'fuel']);
      if (match != null) return match;
    }

    // 6. Transport & Travel
    if (combined.contains('uber') ||
        combined.contains('ola') ||
        combined.contains('rapido') ||
        combined.contains('namma yatri') ||
        combined.contains('blusmart') ||
        combined.contains('irctc') ||
        combined.contains('makemytrip') ||
        combined.contains('goibibo') ||
        combined.contains('easemytrip') ||
        combined.contains('ixigo') ||
        combined.contains('redbus') ||
        combined.contains('indigo') ||
        combined.contains('air india') ||
        combined.contains('spicejet') ||
        combined.contains('fastag') ||
        combined.contains('metro') ||
        combined.contains('parking') ||
        combined.contains('flight') ||
        combined.contains('train') ||
        (combined.contains('toll') && !combined.contains('toll-free') && !combined.contains('tollfree')) ||
        RegExp(r'\bcabs?\b').hasMatch(combined) ||
        RegExp(r'\bauto\s+(?:ride|fare|rickshaw|meter|stand|charge)\b').hasMatch(combined) ||
        (RegExp(r'\bauto\b').hasMatch(combined) &&
            !combined.contains('auto debit') &&
            !combined.contains('auto-debit') &&
            !combined.contains('autopay') &&
            !combined.contains('auto pay') &&
            !combined.contains('auto renew'))) {
      final match = findCategory('transport', ['travel', 'fuel']);
      if (match != null) return match;
    }

    // 6. Bills & Utilities / Recharges
    if (combined.contains('jio') ||
        combined.contains('airtel') ||
        combined.contains('vodafone') ||
        combined.contains('bsnl') ||
        combined.contains('act fibernet') ||
        combined.contains('tata play') ||
        combined.contains('dish tv') ||
        combined.contains('dth') ||
        combined.contains('recharge') ||
        combined.contains('electricity') ||
        combined.contains('water bill') ||
        combined.contains('gas bill') ||
        combined.contains('bescom') ||
        combined.contains('msedcl') ||
        combined.contains('tneb') ||
        combined.contains('cesc') ||
        combined.contains('uppcl') ||
        combined.contains('bses') ||
        combined.contains('adani power') ||
        combined.contains('tata power') ||
        combined.contains('igl') ||
        combined.contains('mgl') ||
        combined.contains('broadband') ||
        combined.contains('wifi') ||
        combined.contains('billdesk') ||
        combined.contains('bbps') ||
        RegExp(r'\bvi\s*(?:recharge|prepaid|postpaid|bill|mobile|pack)\b').hasMatch(combined) ||
        combined.contains('vodafone idea') ||
        (combined.contains('power') && !combined.contains('powered by') && !combined.contains('powered-by'))) {
      final match = findCategory('utilities', ['bills & utilities', 'recharge', 'bills', 'utilities']);
      if (match != null) return match;
    }

    // 7. Subscriptions & Entertainment
    if (combined.contains('netflix') ||
        combined.contains('prime') ||
        combined.contains('spotify') ||
        combined.contains('hotstar') ||
        combined.contains('disney') ||
        combined.contains('youtube') ||
        combined.contains('apple') ||
        combined.contains('google play') ||
        combined.contains('play store') ||
        combined.contains('sony liv') ||
        combined.contains('zee5') ||
        combined.contains('bookmyshow') ||
        combined.contains('pvr') ||
        combined.contains('inox') ||
        combined.contains('cinepolis') ||
        combined.contains('steam') ||
        combined.contains('playstation') ||
        combined.contains('xbox') ||
        combined.contains('gaana') ||
        combined.contains('wynk') ||
        combined.contains('jiosaavn') ||
        combined.contains('museum') ||
        combined.contains('park') ||
        combined.contains('cinema') ||
        combined.contains('theatre') ||
        combined.contains('movie')) {
      final match = findCategory('entertainment', ['subscription', 'subscriptions']);
      if (match != null) return match;
    }

    // 8. Health & Medical
    if (combined.contains('apollo') ||
        combined.contains('1mg') ||
        combined.contains('tata 1mg') ||
        combined.contains('pharmeasy') ||
        combined.contains('practo') ||
        combined.contains('netmeds') ||
        combined.contains('medplus') ||
        combined.contains('cult.fit') ||
        combined.contains('gym') ||
        combined.contains('hospital') ||
        combined.contains('clinic') ||
        combined.contains('pharmacy') ||
        combined.contains('doctor') ||
        combined.contains('diagnostic') ||
        combined.contains('lal path') ||
        combined.contains('metropolis') ||
        combined.contains('healthians') ||
        combined.contains('chemist') ||
        combined.contains('medicines') ||
        combined.contains('dental')) {
      final match = findCategory('health', ['medical', 'pharmacy']);
      if (match != null) return match;
    }

    // 9. Credit Card & EMI Payments
    if (combined.contains('credit card') ||
        combined.contains('card bill') ||
        combined.contains('loan') ||
        combined.contains('cheq') ||
        combined.contains('hdfc card') ||
        combined.contains('sbi card') ||
        combined.contains('icici card') ||
        combined.contains('axis card') ||
        RegExp(r'\bemi\b').hasMatch(combined) ||
        (RegExp(r'\bcred\b').hasMatch(combined) && !combined.contains('credited') && !combined.contains('credit to'))) {
      final match = findCategory('bills_emi', ['cards & emi', 'credit card', 'emi']);
      if (match != null) return match;
    }

    // 10. Rent & Housing
    if (combined.contains('house rent') ||
        combined.contains('nobroker') ||
        combined.contains('mygate') ||
        combined.contains('society') ||
        combined.contains('maintenance fee') ||
        (RegExp(r'\brent\b').hasMatch(combined) && !combined.contains('current'))) {
      final match = findCategory('rent', ['housing']);
      if (match != null) return match;
    }

    // 11. Payment Gateways / Mandates (Online / Utilities)
    if (combined.contains('razorpay') ||
        combined.contains('cashfree') ||
        combined.contains('payu') ||
        combined.contains('billdesk') ||
        combined.contains('upi mandate') ||
        combined.contains('autopay mandate')) {
      final match = findCategory('online', ['digital', 'e-commerce']) ??
          findCategory('utilities', ['bills & utilities', 'bills']);
      if (match != null) return match;
    }

    // 12. Transfers (Personal P2P / RTGS / NEFT / IMPS to beneficiary / UPI to VPA or person)
    if (combined.contains('transfer') ||
        combined.contains('trf') ||
        combined.contains('paid to') ||
        combined.contains('sent to') ||
        combined.contains('sent rs') ||
        combined.contains('sent inr') ||
        combined.contains('debited to') ||
        combined.contains('debited for inr') ||
        combined.contains('debited by') ||
        combined.contains('to vpa') ||
        combined.contains('from vpa') ||
        combined.contains('/to:') ||
        combined.contains('to:') ||
        RegExp(r'\bto\s+[a-zA-Z]', caseSensitive: false).hasMatch(combined) ||
        combined.contains('thru upi') ||
        combined.contains('through upi') ||
        combined.contains('via upi') ||
        combined.contains('upi:') ||
        combined.contains('upi/') ||
        combined.contains('upi/dr') ||
        combined.contains('via rtgs') ||
        combined.contains('via neft') ||
        combined.contains('via imps') ||
        combined.contains('@')) {
      final match = findCategory('transfer', ['transfers', 'peer to peer', 'p2p']);
      if (match != null) return match;
    }

    // Default fallback to 'Other' if available, otherwise first category
    final otherMatch = findCategory('other', []);
    return otherMatch ?? activeCategories.first;
  }

  Future<void> discardPendingSms(String id) async {
    await AutoSmsService.markHashDiscarded(id);
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
          smsHash: pendingItem.id,
          merchantName: pendingItem.merchantName ?? pendingItem.vendorName,
          bankAccount: pendingItem.bankAccount,
          refNumber: pendingItem.refNumber,
          rawSmsBody: pendingItem.rawSmsBody,
        );

    // Mark hash as synced
    await AutoSmsService.markHashSynced(pendingItem.id);

    // Remove from pending state
    state = state.where((item) => item.id != pendingId).toList();
    await _saveToPrefs();
  }
}
