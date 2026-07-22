import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:know_your_expenses/features/auto_sms/view_model/auto_sms_provider.dart';
import 'package:know_your_expenses/features/auto_sms/view/page_sms_settings.dart';

final autoSmsGuideDismissedProvider = StateProvider<bool>((ref) => false);

class WidgetAutoSmsFeatureGuideBanner extends ConsumerStatefulWidget {
  const WidgetAutoSmsFeatureGuideBanner({super.key});

  @override
  ConsumerState<WidgetAutoSmsFeatureGuideBanner> createState() => _WidgetAutoSmsFeatureGuideBannerState();
}

class _WidgetAutoSmsFeatureGuideBannerState extends ConsumerState<WidgetAutoSmsFeatureGuideBanner> {
  @override
  void initState() {
    super.initState();
    _checkDismissStatus();
  }

  Future<void> _checkDismissStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isDismissed = prefs.getBool('auto_sms_guide_dismissed') ?? false;
    ref.read(autoSmsGuideDismissedProvider.notifier).state = isDismissed;
  }

  Future<void> _dismissBanner() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_sms_guide_dismissed', true);
    ref.read(autoSmsGuideDismissedProvider.notifier).state = true;
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = ref.watch(autoSmsEnabledProvider);
    final isDismissed = ref.watch(autoSmsGuideDismissedProvider);

    // If feature is enabled OR guide is dismissed, hide the guide banner
    if (isEnabled || isDismissed) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF429690).withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF429690).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mark_email_read_rounded, color: Color(0xFF429690), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Auto-Track Expenses ⚡',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A2332),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Auto-log bank debits & credits from SMS with 100% privacy.',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const PageSmsSettings()),
                      );
                    },
                    child: Text(
                      'Enable Feature →',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF429690),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 18),
              onPressed: _dismissBanner,
            ),
          ],
        ),
      ),
    );
  }
}
