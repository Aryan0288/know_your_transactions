import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:know_your_expenses/features/home/model/group_model.dart';
import 'package:know_your_expenses/features/home/view_model/view_model_group.dart';
import 'package:know_your_expenses/features/home/view_model/view_model_home.dart';
import 'package:know_your_expenses/features/transaction/model/model_transaction.dart';

class GroupLedgerCard extends ConsumerWidget {
  final GroupModel group;
  final String currentUserId;
  final Function(SplitBalance) onSettle;

  const GroupLedgerCard({
    super.key,
    required this.group,
    required this.currentUserId,
    required this.onSettle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balances = ref.watch(groupSplitBalancesProvider(group.id));
    final transactions =
        ref.watch(groupTransactionsStreamByIdProvider(group.id)).value ?? [];

    final groupType = group.toMap()['type'] as String? ?? 'split';
    final isBusiness = groupType == 'business';
    final isWages = groupType == 'wages';

    final userBalances = isBusiness
        ? <SplitBalance>[]
        : balances
            .where((b) =>
                b.debtorId == currentUserId || b.creditorId == currentUserId)
            .toList();

    double groupNetBalance = 0.0;
    if (!isBusiness) {
      for (var b in balances) {
        if (b.debtorId == currentUserId) {
          groupNetBalance -= b.amount;
        } else if (b.creditorId == currentUserId) {
          groupNetBalance += b.amount;
        }
      }
    }

    double totalUserSpending = 0.0;
    double totalWagesPaidOrReceived = 0.0;

    for (var t in transactions) {
      if (isBusiness) {
        if (t.userId == currentUserId) {
          totalUserSpending += t.amount;
        }
      } else if (isWages) {
        final isAdmin = group.adminId == currentUserId || (group.admins?.contains(currentUserId) ?? false);
        if (isAdmin) {
          totalWagesPaidOrReceived += t.amount;
        } else {
          if (t.splitWith != null && t.splitWith!.contains(currentUserId)) {
            totalWagesPaidOrReceived += t.amount;
          }
        }
      } else {
        if (t.isShared &&
            t.splitWith != null &&
            t.splitWith!.contains(currentUserId)) {
          if (t.splitAmounts != null &&
              t.splitAmounts!.containsKey(currentUserId)) {
            totalUserSpending += t.splitAmounts![currentUserId]!;
          } else {
            totalUserSpending += t.amount / t.splitWith!.length;
          }
        }
      }
    }

    final isMeCreditor = groupNetBalance > 0.01;
    final isMeDebtor = groupNetBalance < -0.01;

    Color statusColor = Colors.grey[600]!;
    if (isMeCreditor) {
      statusColor = Colors.green[700]!;
    } else if (isMeDebtor) {
      statusColor = Colors.red[700]!;
    }

    return Container(
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isBusiness
                      ? const Color(0xFFE3F2FD)
                      : (isWages ? Colors.indigo.withOpacity(0.12) : const Color(0xFFE6F3F2)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isBusiness
                      ? Icons.business_center_rounded
                      : (isWages ? Icons.payments : Icons.group_rounded),
                  color: isBusiness
                      ? Colors.blue[800]
                      : (isWages ? Colors.indigo : const Color(0xFF2E7D79)),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            group.name,
                            style: GoogleFonts.manrope(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E232A),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isBusiness
                                ? Colors.blue[50]
                                : (isWages ? Colors.indigo[50] : const Color(0xFFE6F3F2)),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isBusiness
                                  ? Colors.blue[100]!
                                  : (isWages ? Colors.indigo[100]! : Colors.transparent),
                            ),
                          ),
                          child: Text(
                            isBusiness ? 'Business' : (isWages ? 'Wages' : 'Split'),
                            style: GoogleFonts.manrope(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: isBusiness
                                  ? Colors.blue[800]
                                  : (isWages ? Colors.indigo[800] : const Color(0xFF2E7D79)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isBusiness
                          ? 'Your total spending: ₹${totalUserSpending.toStringAsFixed(2)}'
                          : isWages
                              ? (group.adminId == currentUserId || (group.admins?.contains(currentUserId) ?? false)
                                  ? 'Total wages paid: ₹${totalWagesPaidOrReceived.toStringAsFixed(2)}'
                                  : 'Total wages received: ₹${totalWagesPaidOrReceived.toStringAsFixed(2)}')
                              : 'Your total spending here: ₹${totalUserSpending.toStringAsFixed(2)}',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isBusiness && !isWages)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isMeCreditor
                        ? 'Owed ₹${groupNetBalance.abs().toStringAsFixed(2)}'
                        : isMeDebtor
                        ? 'Owe ₹${groupNetBalance.abs().toStringAsFixed(2)}'
                        : 'Settled',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
            ],
          ),

          if (!isBusiness && !isWages && userBalances.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: Color(0xFFF0F2F5)),
            ),
            ...userBalances.asMap().entries.map((entry) {
              final index = entry.key;
              final balance = entry.value;
              final isMeDebtorForThis = currentUserId == balance.debtorId;

              return Padding(
                padding: EdgeInsets.only(top: index > 0 ? 8.0 : 0.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        isMeDebtorForThis
                            ? 'You owe ${balance.creditorName}'
                            : '${balance.debtorName} owes you',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E232A),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '₹${balance.amount.toStringAsFixed(2)}',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isMeDebtorForThis
                                ? Colors.red[700]
                                : Colors.green[700],
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () => onSettle(balance),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E8B57),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Settle',
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
