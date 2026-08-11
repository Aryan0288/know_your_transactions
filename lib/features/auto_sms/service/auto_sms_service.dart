import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telephony/telephony.dart';
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

    final parsedSms = SmsParserService.parseSms(message.body!);
    if (parsedSms == null) return;

    final String? jsonStr = prefs.getString('pending_auto_sms_items');
    List<dynamic> list = (jsonStr != null && jsonStr.isNotEmpty) ? jsonDecode(jsonStr) : [];

    // Deduplication check
    if (list.any((item) => item['id'] == parsedSms.id)) return;

    list.insert(0, parsedSms.toMap());
    await prefs.setString('pending_auto_sms_items', jsonEncode(list));
  } catch (_) {}
}

class AutoSmsService {
  static final Telephony _telephony = Telephony.instance;
  static const MethodChannel _nativeChannel = MethodChannel('com.anuj.knowyourexpenses/auto_sms');

  /// Initializes SMS listener on app startup if feature is enabled by user.
  static Future<void> initializeOnAppStart(WidgetRef ref) async {
    try {
      _setupNativeChannel(ref);
      final prefs = await SharedPreferences.getInstance();
      final isEnabled = prefs.getBool('auto_sms_enabled') ?? false;
      ref.read(autoSmsEnabledProvider.notifier).state = isEnabled;

      if (isEnabled) {
        final isGranted = await Permission.sms.isGranted;
        if (isGranted) {
          _startListening(ref);
        }
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

  static void _startListening(WidgetRef ref) {
    try {
      _telephony.listenIncomingSms(
        onNewMessage: (SmsMessage message) {
          if (message.body != null) {
            ref.read(pendingSmsListProvider.notifier).processIncomingSms(message.body!);
          }
        },
        listenInBackground: true,
        onBackgroundMessage: backgroundSmsHandler,
      );
    } catch (_) {}
  }
}
