import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:know_your_expenses/core/widgets/custom_dialogs.dart';
import 'package:know_your_expenses/features/login_signup/view/page_sign_in.dart';
import 'package:know_your_expenses/features/transaction/view/page_add_expenses.dart';

class QuickAddAmountDialog extends StatefulWidget {
  const QuickAddAmountDialog({super.key});

  static bool isDialogOpen = false;

  static void show(BuildContext context) {
    if (isDialogOpen) return;
    isDialogOpen = true;

    showGeneralDialog(
      context: context,
      barrierLabel: "QuickAddAmountDialog",
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (context, anim1, anim2) => const QuickAddAmountDialog(),
      transitionBuilder: (context, anim1, anim2, child) {
        final curve = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 0.05),
            end: Offset.zero,
          ).animate(curve),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(curve),
            child: FadeTransition(
              opacity: anim1,
              child: child,
            ),
          ),
        );
      },
    ).then((_) {
      isDialogOpen = false;
    });
  }

  @override
  State<QuickAddAmountDialog> createState() => _QuickAddAmountDialogState();
}

class _QuickAddAmountDialogState extends State<QuickAddAmountDialog> {
  final TextEditingController _amountController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _onNext() {
    final amountText = _amountController.text.trim();
    final double? amount = double.tryParse(amountText);

    Navigator.pop(context); // Close dialog

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      CustomDialogs.showSignInRequiredDialog(
        context,
        onSignInTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SignInPage()),
          );
        },
      );
      return;
    }

    if (amount != null && amount > 0) {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              AddExpensePage(initialAmount: amount),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.05),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Quick Add Expense',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E232A),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF3F8F5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2EEE8)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Text(
                    '₹',
                    style: GoogleFonts.manrope(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2E8B57),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      autofocus: false,
                      style: GoogleFonts.manrope(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E232A),
                      ),
                      decoration: InputDecoration(
                        hintText: '0',
                        hintStyle: GoogleFonts.manrope(
                          color: const Color(0xFFBBC5D0),
                        ),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _onNext(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.manrope(
                        color: const Color(0xFF6E7D8F),
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _onNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E8B57),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Next',
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
