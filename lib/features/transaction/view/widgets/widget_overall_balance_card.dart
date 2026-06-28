import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:know_your_expenses/features/home/view_model/view_model_home.dart';
import 'package:know_your_expenses/features/home/view_model/view_model_group.dart';
import 'package:know_your_expenses/features/transaction/view/page_split_ledger.dart';

class OverallBalanceCard extends ConsumerWidget {
  const OverallBalanceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedGroupId = ref.watch(selectedGroupFilterProvider);
    
    if (selectedGroupId != null) {
      final group = ref.watch(groupByIdStreamProvider(selectedGroupId)).value;
      if (group == null || group.type == 'business') {
        return const SizedBox.shrink();
      }
    }

    final overallBalance = selectedGroupId == null
        ? ref.watch(overallNetBalanceProvider)
        : () {
            final currentUserId = ref
                .watch(firebaseAuthProvider)
                .currentUser
                ?.uid;
            if (currentUserId == null) return 0.0;

            final balances = ref.watch(
              groupSplitBalancesProvider(selectedGroupId),
            );
            double groupNet = 0.0;
            for (var b in balances) {
              if (b.debtorId == currentUserId) {
                groupNet -= b.amount;
              } else if (b.creditorId == currentUserId) {
                groupNet += b.amount;
              }
            }
            return groupNet;
          }();

    final isMeCreditor = overallBalance > 0.01;
    final isMeDebtor = overallBalance < -0.01;

    Color cardColor = const Color(0xFFF1F3F4);
    Color textColor = const Color(0xFF1E232A);
    String titleText = selectedGroupId == null ? "All Settled Up" : "All Settled Up in this Group";
    String descriptionText = "You don't owe anything.";

    if (isMeCreditor) {
      cardColor = const Color(0xFFE6F4EA);
      textColor = Colors.green[800]!;
      titleText = selectedGroupId == null ? "Overall Owed To You" : "Owed To You in this Group";
      descriptionText = selectedGroupId == null
          ? "You are owed a net total of ₹${overallBalance.abs().toStringAsFixed(2)} across groups."
          : "You are owed a net total of ₹${overallBalance.abs().toStringAsFixed(2)} in this group.";
    } else if (isMeDebtor) {
      cardColor = const Color(0xFFFFEBEE);
      textColor = Colors.red[800]!;
      titleText = selectedGroupId == null ? "Overall You Owe" : "You Owe in this Group";
      descriptionText = selectedGroupId == null
          ? "You owe a net total of ₹${overallBalance.abs().toStringAsFixed(2)} across groups."
          : "You owe a net total of ₹${overallBalance.abs().toStringAsFixed(2)} in this group.";
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titleText,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: textColor.withOpacity(0.8),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₹${overallBalance.abs().toStringAsFixed(2)}',
            style: GoogleFonts.manrope(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            descriptionText,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textColor.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}
