import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telephony/telephony.dart';
import 'package:know_your_expenses/features/auto_sms/view_model/auto_sms_provider.dart';

@pragma('vm:entry-point')
void backgroundSmsHandler(SmsMessage message) {
  // Top-level background SMS callback required by Telephony package
}

class AutoSmsService {
  static final Telephony _telephony = Telephony.instance;

  /// Initializes SMS listener on app startup if feature is enabled by user.
  static Future<void> initializeOnAppStart(WidgetRef ref) async {
    try {
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
