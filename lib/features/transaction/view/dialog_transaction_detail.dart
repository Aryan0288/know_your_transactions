import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    final isSelfTransfer = transaction.categoryId == 'self_transfer';
    final typeColor = isSelfTransfer
        ? const Color(0xFF607D8B)
        : (isExpense ? Colors.redAccent : Colors.green);
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
        final groupAdmins = group != null ? List<String>.from(group.toMap()['admins'] ?? []) : <String>[];

        final isGroupAdmin = currentUserId != null && (adminId == currentUserId || groupAdmins.contains(currentUserId));
        final isPersonal = transaction.groupId == null;

        // Permissions:
        // Business Group & Wages Group: ONLY Admin can Edit, Delete, Repeat, or Toggle Type.
        // Non-admin members in Business Groups can ONLY VIEW details.
        final isBusinessGroup = groupType == 'business';
        final isWagesGroup = groupType == 'wages';

        final canEditDelete = isPersonal || groupType == 'split' || ((isBusinessGroup || isWagesGroup) && isGroupAdmin);
        final showToggleType = isBusinessGroup && isGroupAdmin;

        // Payer Name
        final payerName = transaction.userId == currentUserId 
            ? 'You' 
            : (transaction.userId == adminId
                ? '${memberNames[transaction.userId] ?? "Admin"} (Admin)'
                : (memberNames[transaction.userId] ?? 'Group Member'));

        return Center(
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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

                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
                        child: Column(
                          children: [
                            // Icon
                            Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                color: transaction.color.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                transaction.icon,
                                color: transaction.color,
                                size: 34,
                              ),
                            ),
                            const SizedBox(height: 12),

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
                                isSelfTransfer
                                    ? '🔁  Self Transfer'
                                    : (isExpense ? '💸  Expense' : '💰  Income'),
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: typeColor,
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Amount
                            ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                colors: isSelfTransfer
                                    ? [const Color(0xFF455A64), const Color(0xFF607D8B)]
                                    : (isExpense
                                        ? [Colors.redAccent, Colors.red.shade800]
                                        : [Colors.green, Colors.teal]),
                              ).createShader(bounds),
                              child: Text(
                                '₹ ${transaction.amount.toStringAsFixed(2)}',
                                style: GoogleFonts.manrope(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Detail rows
                            if (transaction.merchantName != null && transaction.merchantName!.isNotEmpty) ...[
                              _DetailRow(
                                label: 'Merchant / Entity',
                                value: transaction.merchantName!,
                                icon: Icons.storefront_rounded,
                              ),
                              const _Divider(),
                            ],

                            _DetailRow(
                              label: 'Category',
                              value: transaction.categoryName,
                              icon: Icons.category_rounded,
                            ),
                            const _Divider(),

                            _DetailRow(
                              label: 'Date & Time',
                              value: DateFormat('MMM dd, yyyy  •  hh:mm a').format(transaction.date),
                              icon: Icons.calendar_month_rounded,
                            ),

                            if (transaction.bankAccount != null && transaction.bankAccount!.isNotEmpty) ...[
                              const _Divider(),
                              _DetailRow(
                                label: 'Account / Bank',
                                value: transaction.bankAccount!,
                                icon: Icons.account_balance_rounded,
                              ),
                            ],

                            if (transaction.refNumber != null && transaction.refNumber!.isNotEmpty) ...[
                              const _Divider(),
                              _CopyableDetailRow(
                                label: 'Ref / UPI ID',
                                value: transaction.refNumber!,
                                icon: Icons.tag_rounded,
                              ),
                            ],
                            
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
                                label: 'Note / Title',
                                value: transaction.description,
                                icon: Icons.notes_rounded,
                              ),
                            ],

                            if (transaction.rawSmsBody != null && transaction.rawSmsBody!.isNotEmpty)
                              _RawSmsCard(rawSms: transaction.rawSmsBody!),

                            const SizedBox(height: 24),

                            // Actions Row
                            if (canEditDelete) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(color: Colors.red[300]!),
                                        foregroundColor: Colors.red[700],
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        padding: const EdgeInsets.symmetric(vertical: 13),
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
                                        padding: const EdgeInsets.symmetric(vertical: 13),
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
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFF429690)),
                                    foregroundColor: const Color(0xFF429690),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    padding: const EdgeInsets.symmetric(vertical: 13),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => AddExpensePage(repeatTransaction: transaction),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.replay_rounded, size: 18),
                                  label: Text(
                                    'Repeat Transaction',
                                    style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],

                            if (!canEditDelete && showToggleType)
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFF2E8B57)),
                                    foregroundColor: const Color(0xFF2E8B57),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    padding: const EdgeInsets.symmetric(vertical: 13),
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

                            const SizedBox(height: 8),

                            // Done / Close Button
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.grey[600],
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: () => Navigator.pop(context),
                                child: Text(
                                  'Done',
                                  style: GoogleFonts.manrope(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
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

class _CopyableDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _CopyableDetailRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: const Color(0xFF1E2D2C),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$label copied to clipboard!'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.copy_rounded,
                      size: 14,
                      color: const Color(0xFF2E8B57),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RawSmsCard extends StatefulWidget {
  final String rawSms;
  const _RawSmsCard({required this.rawSms});

  @override
  State<_RawSmsCard> createState() => _RawSmsCardState();
}

class _RawSmsCardState extends State<_RawSmsCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.sms_outlined, size: 16, color: const Color(0xFF2E8B57)),
                  const SizedBox(width: 8),
                  Text(
                    'Original Bank SMS',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E2D2C),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(height: 1, color: Colors.grey.shade200),
                  const SizedBox(height: 10),
                  SelectableText(
                    widget.rawSms,
                    style: GoogleFonts.robotoMono(
                      fontSize: 11,
                      color: Colors.grey.shade800,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: widget.rawSms));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('SMS copied to clipboard!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.copy_rounded, size: 13, color: const Color(0xFF2E8B57)),
                            const SizedBox(width: 4),
                            Text(
                              'Copy SMS',
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF2E8B57),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Divider(height: 1, color: Colors.grey.shade100),
    );
  }
}

