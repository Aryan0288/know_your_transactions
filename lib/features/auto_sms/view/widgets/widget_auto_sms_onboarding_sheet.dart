import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:know_your_expenses/features/auto_sms/service/auto_sms_service.dart';
import 'package:know_your_expenses/features/auto_sms/view_model/auto_sms_provider.dart';
import 'package:know_your_expenses/features/auto_sms/view/widgets/widget_auto_sms_sync_celebration_dialog.dart';
import 'package:know_your_expenses/features/helper/utils.dart';

class AutoSmsPermissionHelper {
  /// Shows a clean dialog guiding the user to OS App Settings when SMS permission is permanently blocked.
  static Future<void> showPermissionBlockedDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_person_rounded, color: Colors.orange, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Permission Blocked',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: const Color(0xFF1A2332),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SMS permission is blocked in your phone settings. To enable automatic bank expense tracking, please turn on SMS permission in App Info.',
              style: GoogleFonts.manrope(
                fontSize: 13.5,
                color: Colors.grey[800],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF429690).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.privacy_tip_outlined, size: 18, color: Color(0xFF429690)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '100% Offline & Private — personal SMS never leaves device.',
                      style: GoogleFonts.manrope(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF429690),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await openAppSettings();
            },
            icon: const Icon(Icons.settings_outlined, size: 18),
            label: Text(
              'Open Settings',
              style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF429690),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  /// Unified permission requester for Auto-SMS with blocked status detection.
  static Future<bool> requestAndEnableAutoSms(
    BuildContext context,
    WidgetRef ref, {
    bool showToast = true,
    bool runStartupSync = true,
  }) async {
    try {
      final isBlocked = await Permission.sms.isPermanentlyDenied;
      if (isBlocked) {
        if (context.mounted) {
          await showPermissionBlockedDialog(context);
        }
        return false;
      }

      await Permission.notification.request();
      final status = await Permission.sms.request();

      if (status.isGranted) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('auto_sms_enabled', true);
        ref.read(autoSmsEnabledProvider.notifier).state = true;
        await AutoSmsService.initializeOnAppStart(ref, runStartupSync: runStartupSync);

        if (showToast && context.mounted) {
          Utils.showSuccessToast(
            context,
            title: 'Auto-Tracking Enabled! ⚡',
            description: 'Bank debit & credit SMS will now be recorded automatically.',
          );
        }
        return true;
      } else if (status.isPermanentlyDenied) {
        if (context.mounted) {
          await showPermissionBlockedDialog(context);
        }
        return false;
      } else {
        if (context.mounted) {
          Utils.showErrorToast(
            context,
            title: 'Permission Denied',
            description: 'SMS permission is required to automatically parse bank expense messages.',
          );
        }
        return false;
      }
    } catch (e) {
      debugPrint('[AutoSmsPermissionHelper] Error requesting SMS permission: $e');
      return false;
    }
  }
}

class AutoSmsOnboardingHelper {
  static bool _isSheetShowing = false;

  /// Prompts the user to enable auto SMS tracking whenever app opens if authenticated and not enabled yet.
  static Future<void> checkAndPromptOnboarding(BuildContext context, WidgetRef ref) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final prefs = await SharedPreferences.getInstance();
      final isEnabled = (prefs.getBool('auto_sms_enabled') ?? false) && ref.read(autoSmsEnabledProvider);
      final isGranted = await Permission.sms.isGranted;

      // If user has already enabled auto tracking and permission is granted, do not prompt
      if (isEnabled && isGranted) return;

      // Prevent duplicate stacked sheets if already open
      if (_isSheetShowing) return;
      _isSheetShowing = true;

      // Delay briefly so dashboard layout finishes rendering smoothly
      await Future.delayed(const Duration(milliseconds: 600));

      if (context.mounted) {
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => const WidgetAutoSmsOnboardingSheet(),
        );
      }
    } catch (e) {
      debugPrint('[AutoSmsOnboardingHelper] Error checking onboarding: $e');
    } finally {
      _isSheetShowing = false;
    }
  }
}

class WidgetAutoSmsOnboardingSheet extends ConsumerWidget {
  const WidgetAutoSmsOnboardingSheet({super.key});

  Future<void> _handleEnableAutoTracking(BuildContext context, WidgetRef ref) async {
    ref.read(autoSmsOnboardingSyncingProvider.notifier).state = true;

    final success = await AutoSmsPermissionHelper.requestAndEnableAutoSms(
      context,
      ref,
      showToast: false,
      runStartupSync: false,
    );

    if (!success) {
      ref.read(autoSmsOnboardingSyncingProvider.notifier).state = false;
      return;
    }

    try {
      // Perform complete 30-day comprehensive sync on first enable without startup sync contention
      final result = await ref
          .read(pendingSmsListProvider.notifier)
          .syncPastSms(days: 30);

      ref.read(autoSmsOnboardingSyncingProvider.notifier).state = false;

      if (context.mounted) {
        final nav = Navigator.of(context);
        final rootContext = nav.context;
        if (nav.canPop()) {
          nav.pop();
        }

        // Show non-blocking center celebration overlay with confetti burst on dashboard
        if (rootContext.mounted) {
          WidgetAutoSmsCelebrationOverlay.show(
            rootContext,
            addedCount: result.addedCount,
            skippedCount: result.skippedCount,
            totalIncome: result.totalIncome,
            totalExpense: result.totalExpense,
          );
        }
      }
    } catch (e) {
      debugPrint('[WidgetAutoSmsOnboardingSheet] Error during 30-day initial sync: $e');
      ref.read(autoSmsOnboardingSyncingProvider.notifier).state = false;
      if (context.mounted) {
        final nav = Navigator.of(context);
        if (nav.canPop()) {
          nav.pop();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSyncing = ref.watch(autoSmsOnboardingSyncingProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Glowing Feature Icon
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF429690), Color(0xFF2E8B57)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF429690).withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.mark_email_read_rounded,
              color: Colors.white,
              size: 38,
            ),
          ),
          const SizedBox(height: 18),

          // Title & Subtitle
          Text(
            'Auto-Track Bank Expenses ⚡',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A2332),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Effortlessly record bank debits & credits directly from your SMS alerts without manual entry.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 13.5,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 22),

          // Value Props List
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                _buildValueProp(
                  icon: Icons.history_rounded,
                  iconColor: const Color(0xFF429690),
                  title: 'Instant 30-Day Auto Sync',
                  subtitle: 'Automatically scans and backfills last 30 days of transactions.',
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                ),
                _buildValueProp(
                  icon: Icons.security_rounded,
                  iconColor: Colors.blueAccent,
                  title: '100% Private & Offline',
                  subtitle: 'SMS parsed locally on device. Zero cloud uploads.',
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                ),
                _buildValueProp(
                  icon: Icons.category_rounded,
                  iconColor: Colors.orange,
                  title: 'Smart Categorization',
                  subtitle: 'Auto-maps merchants to Food, Shopping, Bills, Transfers & Income.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Primary Enable Button / Syncing Indicator
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: isSyncing ? null : () => _handleEnableAutoTracking(context, ref),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF429690),
                disabledBackgroundColor: const Color(0xFF429690).withValues(alpha: 0.7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 3,
                shadowColor: const Color(0xFF429690).withValues(alpha: 0.4),
              ),
              child: isSyncing
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Scanning 30-Day SMS History...',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      'Enable Auto-Tracking',
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 10),

          // Secondary Skip Button
          if (!isSyncing)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Maybe Later',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildValueProp({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A2332),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.manrope(
                  fontSize: 11.5,
                  color: Colors.grey[600],
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
