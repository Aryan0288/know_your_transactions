import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telephony/telephony.dart';
import 'package:know_your_expenses/features/auto_sms/model/model_pending_sms.dart';
import 'package:know_your_expenses/features/auto_sms/view_model/auto_sms_provider.dart';
import 'package:know_your_expenses/features/auto_sms/service/sms_parser_service.dart';

@pragma('vm:entry-point')
Future<void> backgroundSmsHandler(SmsMessage message) async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    if (message.body == null || message.body!.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final bool isEnabled = prefs.getBool('auto_sms_enabled') ?? false;
    if (!isEnabled) return;

    DateTime? messageDate;
    if (message.date != null) {
      messageDate = DateTime.fromMillisecondsSinceEpoch(message.date!);
    }

    final parsedSms = SmsParserService.parseSms(
      message.body!,
      sender: message.address,
      messageTimestamp: messageDate,
    );
    if (parsedSms == null) return;

    final String? jsonStr = prefs.getString('pending_auto_sms_items');
    List<dynamic> list = (jsonStr != null && jsonStr.isNotEmpty)
        ? jsonDecode(jsonStr)
        : [];

    // Deduplication check with existing pending items and synced registry
    if (list.any((item) => item['id'] == parsedSms.id)) return;
    final syncedHashes = prefs.getStringList('synced_sms_hashes') ?? [];
    if (syncedHashes.contains(parsedSms.id)) return;
    final discardedHashes = prefs.getStringList('discarded_sms_hashes') ?? [];
    if (discardedHashes.contains(parsedSms.id)) return;

    list.insert(0, parsedSms.toMap());
    await prefs.setString('pending_auto_sms_items', jsonEncode(list));
  } catch (_) {}
}

class AutoSmsService {
  static final Telephony _telephony = Telephony.instance;
  static const MethodChannel _nativeChannel = MethodChannel(
    'com.apps.knowyourexpenses/auto_sms',
  );

  /// Retrieves the set of all previously processed/synced SMS hash IDs.
  static Future<Set<String>> getSyncedHashes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('synced_sms_hashes') ?? [];
      return list.toSet();
    } catch (_) {
      return {};
    }
  }

  /// Marks a single SMS hash ID as synced.
  static Future<void> markHashSynced(String hash) async {
    if (hash.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('synced_sms_hashes') ?? [];
      if (!list.contains(hash)) {
        list.add(hash);
        // Keep registry trimmed to latest 2000 hashes to save storage
        if (list.length > 2000) {
          list.removeRange(0, list.length - 2000);
        }
        await prefs.setStringList('synced_sms_hashes', list);
      }
    } catch (_) {}
  }

  /// Marks multiple SMS hash IDs as synced in bulk.
  static Future<void> markHashesSynced(Iterable<String> hashes) async {
    if (hashes.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final set = (prefs.getStringList('synced_sms_hashes') ?? []).toSet();
      set.addAll(hashes.where((h) => h.isNotEmpty));
      final list = set.toList();
      if (list.length > 2000) {
        list.removeRange(0, list.length - 2000);
      }
      await prefs.setStringList('synced_sms_hashes', list);
    } catch (_) {}
  }

  /// Unmarks an SMS hash ID from synced/discarded registry (used when user deletes transaction).
  static Future<void> unmarkHashSynced(String hash) async {
    if (hash.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final synced = prefs.getStringList('synced_sms_hashes') ?? [];
      synced.remove(hash);
      await prefs.setStringList('synced_sms_hashes', synced);

      final discarded = prefs.getStringList('discarded_sms_hashes') ?? [];
      discarded.remove(hash);
      await prefs.setStringList('discarded_sms_hashes', discarded);
    } catch (_) {}
  }

  /// Sets the complete synced hashes registry to match active state.
  static Future<void> setSyncedHashes(Iterable<String> hashes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = hashes.where((h) => h.isNotEmpty).toSet().toList();
      if (list.length > 2000) {
        list.removeRange(0, list.length - 2000);
      }
      await prefs.setStringList('synced_sms_hashes', list);
    } catch (_) {}
  }

  /// Retrieves the set of all user-discarded SMS hash IDs.
  static Future<Set<String>> getDiscardedHashes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('discarded_sms_hashes') ?? [];
      return list.toSet();
    } catch (_) {
      return {};
    }
  }

  /// Marks an SMS hash ID as discarded (so silent background sync never re-imports it).
  static Future<void> markHashDiscarded(String hash) async {
    if (hash.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final synced = prefs.getStringList('synced_sms_hashes') ?? [];
      if (synced.contains(hash)) {
        synced.remove(hash);
        await prefs.setStringList('synced_sms_hashes', synced);
      }

      final list = prefs.getStringList('discarded_sms_hashes') ?? [];
      if (!list.contains(hash)) {
        list.add(hash);
        if (list.length > 2000) {
          list.removeRange(0, list.length - 2000);
        }
        await prefs.setStringList('discarded_sms_hashes', list);
      }
    } catch (_) {}
  }

  /// Clears all discarded SMS hashes (used during explicit manual sync to allow restoring deleted SMS).
  static Future<void> clearDiscardedHashes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('discarded_sms_hashes');
    } catch (_) {}
  }

  /// Generates a standardized Natural Key string: "Amount_Year_Month_Day_IsExpense".
  /// Used for backward-compatible deduplication with older app builds.
  static String buildNaturalKey({
    required double amount,
    required DateTime date,
    required bool isExpense,
  }) {
    return '${amount.toStringAsFixed(2)}_${date.year}_${date.month}_${date.day}_$isExpense';
  }

  /// Checks if battery optimization is currently ignored (whitelisted) for this app.
  static Future<bool> isBatteryOptimizationIgnored() async {
    try {
      final result = await _nativeChannel.invokeMethod<bool>('isBatteryOptimizationIgnored');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Triggers the Android system direct 1-tap dialog to ignore battery optimizations.
  static Future<bool> requestIgnoreBatteryOptimization() async {
    try {
      final result = await _nativeChannel.invokeMethod<bool>('requestIgnoreBatteryOptimization');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Deep-links directly to manufacturer Auto-Start permission screen if present.
  static Future<bool> openAutoStartSettings() async {
    try {
      final result = await _nativeChannel.invokeMethod<bool>('openAutoStartSettings');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Initializes SMS listener on app startup if feature is enabled by user.
  static Future<void> initializeOnAppStart(WidgetRef ref, {bool runStartupSync = true}) async {
    try {
      _setupNativeChannel(ref);
      final prefs = await SharedPreferences.getInstance();
      final isEnabled = prefs.getBool('auto_sms_enabled') ?? false;
      ref.read(autoSmsEnabledProvider.notifier).state = isEnabled;

      if (isEnabled) {
        final isGranted = await Permission.sms.isGranted;
        if (isGranted) {
          _startListening(ref);
          await ref.read(pendingSmsListProvider.notifier).reloadFromPrefs();
          if (runStartupSync) {
            await ref.read(pendingSmsListProvider.notifier).performStartupSilentSync();
          }
        }
      }
    } catch (_) {}
  }

  /// Syncs app state if user toggled SMS permission in OS App Info Settings and returned to app.
  static Future<void> syncStateWithPermission(WidgetRef ref) async {
    try {
      final isGranted = await Permission.sms.isGranted;
      final prefs = await SharedPreferences.getInstance();
      final isEnabled = prefs.getBool('auto_sms_enabled') ?? false;

      if (isGranted && !isEnabled) {
        await prefs.setBool('auto_sms_enabled', true);
        ref.read(autoSmsEnabledProvider.notifier).state = true;
        await initializeOnAppStart(ref, runStartupSync: false);
      } else if (!isGranted && isEnabled) {
        await prefs.setBool('auto_sms_enabled', false);
        ref.read(autoSmsEnabledProvider.notifier).state = false;
      }
    } catch (_) {}
  }

  static void _setupNativeChannel(WidgetRef ref) {
    _nativeChannel.setMethodCallHandler((call) async {
      if (call.method == 'onSmsReceived') {
        await ref.read(pendingSmsListProvider.notifier).reloadFromPrefs();
      }
    });
  }

  static bool _isListening = false;

  static void _startListening(WidgetRef ref) {
    if (_isListening) return;
    try {
      _isListening = true;
      _telephony.listenIncomingSms(
        onNewMessage: (SmsMessage message) {
          if (message.body != null && message.body!.isNotEmpty) {
            DateTime? messageDate;
            if (message.date != null) {
              messageDate = DateTime.fromMillisecondsSinceEpoch(message.date!);
            }
            ref
                .read(pendingSmsListProvider.notifier)
                .processIncomingSms(
                  message.body!,
                  sender: message.address,
                  timestamp: messageDate,
                );
          }
        },
        listenInBackground: true,
        onBackgroundMessage: backgroundSmsHandler,
      );
    } catch (_) {
      _isListening = false;
    }
  }

  /// Scans device SMS inbox for bank transactions within the last [days].
  /// Returns a list of parsed [ModelPendingSms].
  static Future<List<ModelPendingSms>> scanInboxSms({int days = 30}) async {
    try {
      final isGranted = await Permission.sms.isGranted;
      if (!isGranted) {
        final status = await Permission.sms.request();
        if (!status.isGranted) return [];
      }

      final messages = await _telephony.getInboxSms(
        columns: [
          SmsColumn.ADDRESS,
          SmsColumn.BODY,
          SmsColumn.DATE,
          SmsColumn.DATE_SENT,
        ],
        sortOrder: [
          OrderBy(SmsColumn.DATE, sort: Sort.DESC),
        ],
      );

      final cutoffTime = DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;
      final List<ModelPendingSms> parsedList = [];
      final Set<String> seenIds = {};

      for (final msg in messages) {
        final body = msg.body;
        if (body == null || body.trim().isEmpty) continue;

        final dateMillis = msg.date ?? msg.dateSent;
        if (dateMillis != null && dateMillis < cutoffTime) {
          continue; // Older than cutoff
        }

        DateTime? messageDate;
        if (dateMillis != null) {
          messageDate = DateTime.fromMillisecondsSinceEpoch(dateMillis);
        }

        final parsed = SmsParserService.parseSms(
          body,
          sender: msg.address,
          messageTimestamp: messageDate,
        );

        if (parsed != null && !seenIds.contains(parsed.id)) {
          seenIds.add(parsed.id);
          parsedList.add(parsed);
        }
      }

      // Sort by latest date first
      parsedList.sort((a, b) => b.date.compareTo(a.date));
      return parsedList;
    } catch (_) {
      return [];
    }
  }
}
