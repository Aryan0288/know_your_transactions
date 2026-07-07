import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:know_your_expenses/features/home/view_model/view_model_group.dart';
import 'package:know_your_expenses/features/home/view_model/view_model_home.dart';
import 'package:know_your_expenses/features/transaction/model/model_transaction.dart';
import 'package:know_your_expenses/features/transaction/view_model/view_model_transaction.dart';
import 'package:know_your_expenses/features/transaction/view/page_add_expenses.dart';
import 'package:know_your_expenses/features/helper/utils.dart';

class TransactionDetailDialog extends ConsumerWidget {
  final TransactionModel transaction;

  const TransactionDetailDialog({super.key, required this.transaction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    bool isExpense = transaction.isExpense;
    // Override for wages group recipients
    if (transaction.groupId != null) {
      final groups = ref.watch(userGroupsStreamProvider).value ?? [];
      final targetGroup = groups.where((g) => g.id == transaction.groupId).firstOrNull;
      if (targetGroup != null && targetGroup.toMap()['type'] == 'wages' &&
          transaction.splitWith != null && transaction.splitWith!.contains(ref.watch(firebaseAuthProvider).currentUser?.uid)) {
        isExpense = false;
      }
    }
    final typeColor = isExpense ? Colors.redAccent : Colors.green;
    final currentUserId = ref.watch(firebaseAuthProvider).currentUser?.uid;

    // Check if it's a group transaction and read group info
    final groupAsync = transaction.groupId != null
        ? ref.watch(groupByIdStreamProvider(transaction.groupId!))
        : const AsyncValue<dynamic>.data(null);
        
    final membersAsync = transaction.groupId != null
        ? ref.watch(groupMembersDetailsByIdProvider(transaction.groupId!))
        : const AsyncValue<List<Map<String, dynamic>>>.data([]);

    return groupAsync.when(
      data: (group) {
        final members = membersAsync.value ?? [];
        final memberNames = {for (var m in members) m['uid'] as String: m['name'] as String? ?? 'Group Member'};
        
        final groupType = group != null ? (group.toMap()['type'] as String? ?? 'split') : 'personal';
        final adminId = group != null ? (group.toMap()['adminId'] as String? ?? '') : '';

        final isGroupAdmin = currentUserId != null && adminId == currentUserId;
        final isPersonal = transaction.groupId == null;

        // Permissions:
        // Admin or Personal/Split group: Can Edit & Delete.
        // Business group member: Cannot Edit & Delete.
        final canEditDelete = isPersonal || groupType == 'split' || isGroupAdmin;
        
        // Everyone in a Business group (or any group/personal) can toggle type,
        // but for Business group members it is their ONLY action.
        final showToggleType = transaction.groupId != null && groupType == 'business';

        // Payer Name
        final payerName = transaction.userId == currentUserId 
            ? 'You' 
            : (transaction.userId == adminId
                ? '${memberNames[transaction.userId] ?? "Admin"} (Admin)'
                : (memberNames[transaction.userId] ?? 'Group Member'));

        return Center(
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 40,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Coloured top strip
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: transaction.color,
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                    child: Column(
                      children: [
                        // Icon
                        Container(
                          width: 74,
                          height: 74,
                          decoration: BoxDecoration(
                            color: transaction.color.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            transaction.icon,
                            color: transaction.color,
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Type badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: typeColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isExpense ? '💸  Expense' : '💰  Income',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: typeColor,
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Amount
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: isExpense
                                ? [Colors.redAccent, Colors.red.shade800]
                                : [Colors.green, Colors.teal],
                          ).createShader(bounds),
                          child: Text(
                            '₹ ${transaction.amount.toStringAsFixed(2)}',
                            style: GoogleFonts.manrope(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Detail rows
                        _DetailRow(
                          label: 'Category',
                          value: transaction.categoryName,
                          icon: Icons.category_rounded,
                        ),
                        const _Divider(),
                        _DetailRow(
                          label: 'Date',
                          value: DateFormat('MMM dd, yyyy  •  hh:mm a').format(transaction.date),
                          icon: Icons.calendar_month_rounded,
                        ),
                        
                        if (transaction.groupId != null && group != null) ...[
                          const _Divider(),
                          _DetailRow(
                            label: 'Group',
                            value: group.name,
                            icon: Icons.group_rounded,
                          ),
                          const _Divider(),
                          _DetailRow(
                            label: 'Paid By',
                            value: payerName,
                            icon: Icons.person_rounded,
                          ),
                        ],

                        if (transaction.description.isNotEmpty) ...[
                          const _Divider(),
                          _DetailRow(
                            label: 'Note',
                            value: transaction.description,
                            icon: Icons.notes_rounded,
                          ),
                        ],

                        const SizedBox(height: 28),

                        // Actions Row
                        if (canEditDelete)
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: Colors.red[300]!),
                                    foregroundColor: Colors.red[700],
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  onPressed: () async {
                                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                        title: Text('Delete Transaction ⚠️', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
                                        content: Text(
                                          'Are you sure you want to delete this transaction? This action cannot be undone.',
                                          style: GoogleFonts.manrope(fontSize: 14),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx, false),
                                            child: Text('Cancel', style: GoogleFonts.manrope(color: Colors.grey[600], fontWeight: FontWeight.bold)),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                            onPressed: () => Navigator.pop(ctx, true),
                                            child: Text('Delete', style: GoogleFonts.manrope(color: Colors.white, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm != true) return;
                                    Navigator.pop(context);
                                    final success = await ref
                                        .read(transactionViewModelProvider.notifier)
                                        .deleteTransaction(transaction);
                                    if (success) {
                                      scaffoldMessenger.showSnackBar(
                                        const SnackBar(content: Text('Transaction deleted successfully.')),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                                  label: Text('Delete', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2E8B57),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    elevation: 0,
                                  ),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => AddExpensePage(editTransaction: transaction),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.edit_outlined, size: 18),
                                  label: Text('Edit', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),

                        if (!canEditDelete && showToggleType)
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF2E8B57)),
                                foregroundColor: const Color(0xFF2E8B57),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: () async {
                                final scaffoldMessenger = ScaffoldMessenger.of(context);
                                Navigator.pop(context);
                                final success = await ref
                                    .read(transactionViewModelProvider.notifier)
                                    .toggleTransactionType(transaction);
                                if (success) {
                                  scaffoldMessenger.showSnackBar(
                                    const SnackBar(content: Text('Transaction type toggled.')),
                                  );
                                }
                              },
                              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                              label: Text(
                                'Mark as ${isExpense ? "Income" : "Expense"}',
                                style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          
                        if (canEditDelete && showToggleType) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF2E7D79),
                              ),
                              onPressed: () async {
                                Navigator.pop(context);
                                await ref
                                    .read(transactionViewModelProvider.notifier)
                                    .toggleTransactionType(transaction);
                              },
                              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                              label: Text(
                                'Convert to ${isExpense ? "Income" : "Expense"}',
                                style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 12),

                        // Done / Close Button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.grey[600],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              'Done',
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF2E8B57))),
      error: (e, s) => Center(child: Text('Error loading details: $e')),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade400),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.manrope(
              color: Colors.grey.shade500,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: const Color(0xFF1E2D2C),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Divider(height: 1, color: Colors.grey.shade100),
    );
  }
}
