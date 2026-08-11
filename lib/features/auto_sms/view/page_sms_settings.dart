import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telephony/telephony.dart';
import 'package:know_your_expenses/features/auto_sms/service/auto_sms_service.dart';
import 'package:know_your_expenses/features/auto_sms/view_model/auto_sms_provider.dart';
import 'package:know_your_expenses/features/auto_sms/view/widgets/widget_auto_fill_ledger_sheet.dart';
import 'package:know_your_expenses/features/helper/utils.dart';
import 'package:know_your_expenses/core/widgets/custom_dialogs.dart';
import 'package:know_your_expenses/features/login_signup/view/page_sign_in.dart';

class PageSmsSettings extends ConsumerStatefulWidget {
  const PageSmsSettings({super.key});

  @override
  ConsumerState<PageSmsSettings> createState() => _PageSmsSettingsState();
}

class _PageSmsSettingsState extends ConsumerState<PageSmsSettings> {
  final Telephony _telephony = Telephony.instance;

  @override
  void initState() {
    super.initState();
    _checkInitialStatus();
  }

  Future<void> _checkInitialStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool('auto_sms_enabled') ?? false;
    ref.read(autoSmsEnabledProvider.notifier).state = isEnabled;
    if (isEnabled) {
      _initSmsListener();
    }
  }

  Future<void> _toggleAutoSms(bool value) async {
    if (value) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          CustomDialogs.showSignInRequiredDialog(
            context,
            onSignInTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SignInPage()),
              );
            },
          );
        }
        return;
      }

      // Request SMS & Notification permissions
      await Permission.notification.request();
      final status = await Permission.sms.request();
      if (status.isGranted) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('auto_sms_enabled', true);
        ref.read(autoSmsEnabledProvider.notifier).state = true;
        _initSmsListener();

        if (mounted) {
          Utils.showSuccessToast(context, title: 'Auto SMS Expense Tracking Enabled');
        }
      } else {
        if (mounted) {
          Utils.showErrorToast(
            context,
            title: 'Permission Denied',
            description: 'SMS permission is required to automatically parse bank expense messages.',
          );
        }
      }
    } else {
      // Show Warning Confirmation Dialog before disabling
      final confirmDisable = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              const SizedBox(width: 10),
              Text(
                'Disable Auto SMS?',
                style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Text(
            'Disabling this will pause automatic bank expense detection. You will need to log expenses manually.\n\nAre you sure you want to turn it off?',
            style: GoogleFonts.manrope(fontSize: 14, color: const Color(0xFF1A2332)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Keep Active',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF429690),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE57373),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(
                'Disable',
                style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );

      if (confirmDisable == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('auto_sms_enabled', false);
        ref.read(autoSmsEnabledProvider.notifier).state = false;

        if (mounted) {
          Utils.showSuccessToast(context, title: 'Auto SMS Tracking Disabled');
        }
      }
    }
  }

  void _initSmsListener() {
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

  @override
  Widget build(BuildContext context) {
    final isEnabled = ref.watch(autoSmsEnabledProvider);
    final pendingItems = ref.watch(pendingSmsListProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        title: Text(
          'Auto SMS Expenses',
          style: GoogleFonts.manrope(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF429690),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
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
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF429690).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mark_email_read_rounded, color: Color(0xFF429690), size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Automatic Tracking',
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1A2332),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Automatically detect bank debits & credits from SMS',
                          style: GoogleFonts.manrope(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Toggle Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SwitchListTile(
                value: isEnabled,
                onChanged: _toggleAutoSms,
                activeColor: const Color(0xFF429690),
                title: Text(
                  'Auto-Parse Bank SMS',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: const Color(0xFF1A2332),
                  ),
                ),
                subtitle: Text(
                  'Detect debits & credits in background',
                  style: GoogleFonts.manrope(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Privacy Guarantee Notice
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFA5D6A7)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_rounded, color: Color(0xFF2E7D32), size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '100% Privacy Protection',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1B5E20),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'All SMS processing is performed 100% locally on your device. SMS body text is never stored or sent to any server.',
                          style: GoogleFonts.manrope(fontSize: 11, color: const Color(0xFF2E7D32)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Dedicated Auto SMS Inbox Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Auto SMS Inbox',
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A2332),
                  ),
                ),
                if (pendingItems.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF429690),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${pendingItems.length} Pending',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            if (pendingItems.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(Icons.inbox_rounded, color: Color(0xFF429690), size: 40),
                    const SizedBox(height: 12),
                    Text(
                      'No Pending Expenses',
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A2332),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Auto-detected bank expenses will appear here for review and group assignment.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: pendingItems.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = pendingItems[index];
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => WidgetAutoFillLedgerSheet(pendingSms: item),
                          );
                        },
                        splashColor: const Color(0xFF429690).withOpacity(0.12),
                        highlightColor: const Color(0xFF429690).withOpacity(0.06),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: item.isExpense
                                    ? const Color(0xFFFFEBEE)
                                    : const Color(0xFFE8F5E9),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                item.isExpense ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                color: item.isExpense ? const Color(0xFFE57373) : const Color(0xFF2E7D32),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.vendorName,
                                    style: GoogleFonts.manrope(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF1A2332),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${item.date.day}/${item.date.month}/${item.date.year} • ${item.paymentMode.toUpperCase()}',
                                    style: GoogleFonts.manrope(fontSize: 11, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '₹${item.amount.toStringAsFixed(2)}',
                                  style: GoogleFonts.manrope(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: item.isExpense ? const Color(0xFFE57373) : const Color(0xFF2E7D32),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Premium Soft Delete Button
                                    InkWell(
                                      borderRadius: BorderRadius.circular(10),
                                      onTap: () {
                                        HapticFeedback.mediumImpact();
                                        CustomDialogs.showDiscardSmsDialog(
                                          context,
                                          onConfirm: () {
                                            ref.read(pendingSmsListProvider.notifier).discardPendingSms(item.id);
                                            Utils.showSuccessToast(context, title: 'Transaction Discarded');
                                          },
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFEBEE),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(
                                          Icons.delete_outline_rounded,
                                          color: Color(0xFFE57373),
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Premium Gradient Assign Button
                                    InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          backgroundColor: Colors.transparent,
                                          builder: (_) => WidgetAutoFillLedgerSheet(pendingSms: item),
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFF2E7D79), Color(0xFF429690)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF429690).withOpacity(0.3),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.add_task_rounded, color: Colors.white, size: 14),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Assign',
                                              style: GoogleFonts.manrope(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
              ),
          ],
        ),
      ),
    );
  }
}
