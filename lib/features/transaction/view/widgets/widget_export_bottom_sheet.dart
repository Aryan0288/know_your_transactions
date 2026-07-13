import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:know_your_expenses/features/home/view_model/view_model_group.dart';
import 'package:know_your_expenses/features/home/view_model/view_model_home.dart';
import 'package:know_your_expenses/features/transaction/view_model/view_model_transaction.dart';
import 'package:know_your_expenses/features/helper/utils.dart';
import 'package:know_your_expenses/features/helper/pdf_helper.dart';
import 'package:know_your_expenses/features/transaction/view/page_pdf_preview.dart';
import 'package:know_your_expenses/features/home/model/group_model.dart';
import 'package:know_your_expenses/features/transaction/view/page_split_ledger.dart';

final exportSelectedSpaceProvider = StateProvider.autoDispose.family<String, String?>((ref, initialSpace) => initialSpace ?? 'all');
final exportDateRangeOptionProvider = StateProvider.autoDispose<String>((ref) => 'all');
final exportCustomDateRangeProvider = StateProvider.autoDispose<DateTimeRange?>((ref) => null);
final exportTransactionTypeProvider = StateProvider.autoDispose<String>((ref) => 'all');
final exportFormatProvider = StateProvider.autoDispose<String>((ref) => 'pdf');

class ExportBottomSheet extends ConsumerWidget {
  final String? initialGroupId;
  const ExportBottomSheet({super.key, this.initialGroupId});

  static const Color _kGreen = Color(0xFF2E8B57);
  static const Color _darkText = Color(0xFF1E232A);

  Future<void> _selectCustomDateRange(BuildContext context, WidgetRef ref) async {
    final customRange = ref.read(exportCustomDateRangeProvider);
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: customRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _kGreen,
              onPrimary: Colors.white,
              onSurface: _darkText,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      ref.read(exportCustomDateRangeProvider.notifier).state = picked;
      ref.read(exportDateRangeOptionProvider.notifier).state = 'custom';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(userGroupsStreamProvider);
    final allTransactionsAsync = ref.watch(transactionsStreamProvider);

    final selectedSpace = ref.watch(exportSelectedSpaceProvider(initialGroupId));
    final dateRangeOption = ref.watch(exportDateRangeOptionProvider);
    final customDateRange = ref.watch(exportCustomDateRangeProvider);
    final transactionType = ref.watch(exportTransactionTypeProvider);
    final exportFormat = ref.watch(exportFormatProvider);

    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Export Statement',
            style: GoogleFonts.manrope(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _darkText,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 20),

          // 1. Space Selection
          Text(
            'Select Active Space',
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          groupsAsync.when(
            data: (groups) {
              final items = [
                const DropdownMenuItem(value: 'all', child: Text('All Spaces Combined')),
                const DropdownMenuItem(value: 'personal', child: Text('Personal Space')),
                ...groups.map((g) => DropdownMenuItem(value: g.id, child: Text('Group: ${g.name}'))),
              ];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F8F5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withOpacity(0.1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedSpace,
                    isExpanded: true,
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    icon: const Icon(Icons.arrow_drop_down_rounded, color: _kGreen, size: 28),
                    items: items,
                    onChanged: (val) {
                      if (val != null) {
                        ref.read(exportSelectedSpaceProvider(initialGroupId).notifier).state = val;
                      }
                    },
                  ),
                ),
              );
            },
            loading: () => const LinearProgressIndicator(color: _kGreen),
            error: (_, __) => const SizedBox(),
          ),
          const SizedBox(height: 16),

          // 2. Date Range Filter
          Text(
            'Select Date Range',
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildSegmentChip('All Time', dateRangeOption == 'all', () {
                ref.read(exportDateRangeOptionProvider.notifier).state = 'all';
              }),
              const SizedBox(width: 8),
              _buildSegmentChip('This Month', dateRangeOption == 'this_month', () {
                ref.read(exportDateRangeOptionProvider.notifier).state = 'this_month';
              }),
              const SizedBox(width: 8),
              _buildSegmentChip('Last Month', dateRangeOption == 'last_month', () {
                ref.read(exportDateRangeOptionProvider.notifier).state = 'last_month';
              }),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _selectCustomDateRange(context, ref),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: dateRangeOption == 'custom' ? const Color(0xFFF3F8F5) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: dateRangeOption == 'custom' ? _kGreen.withOpacity(0.3) : Colors.grey[300]!,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    dateRangeOption == 'custom' && customDateRange != null
                        ? "${DateFormat('dd MMM').format(customDateRange.start)} - ${DateFormat('dd MMM yyyy').format(customDateRange.end)}"
                        : "Custom Date Range...",
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: dateRangeOption == 'custom' ? _kGreen : Colors.grey[600],
                    ),
                  ),
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 16,
                    color: dateRangeOption == 'custom' ? _kGreen : Colors.grey[500],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 3. Transaction Type
          Text(
            'Transaction Type',
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildSegmentChip('All', transactionType == 'all', () {
                ref.read(exportTransactionTypeProvider.notifier).state = 'all';
              }),
              const SizedBox(width: 8),
              _buildSegmentChip('Expenses Only', transactionType == 'expense', () {
                ref.read(exportTransactionTypeProvider.notifier).state = 'expense';
              }),
              const SizedBox(width: 8),
              _buildSegmentChip('Income Only', transactionType == 'income', () {
                ref.read(exportTransactionTypeProvider.notifier).state = 'income';
              }),
            ],
          ),
          const SizedBox(height: 16),

          // 4. Export Format Selection
          Text(
            'Export Format',
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildFormatCard(
                  'PDF Format',
                  'Best for sharing & printing',
                  Icons.picture_as_pdf_rounded,
                  exportFormat == 'pdf',
                  () => ref.read(exportFormatProvider.notifier).state = 'pdf',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFormatCard(
                  'CSV Format',
                  'Best for Excel / Google Sheets',
                  Icons.table_rows_rounded,
                  exportFormat == 'csv',
                  () => ref.read(exportFormatProvider.notifier).state = 'csv',
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // CTA Action Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              onPressed: () async {
                // 1. Fetch all transactions
                final allTransactions = allTransactionsAsync.value ?? [];
                if (allTransactions.isEmpty) {
                  Utils.showErrorToast(context, title: "No transactions found to export");
                  return;
                }

                // 2. Apply Filters
                // A. Space filter
                var filtered = allTransactions;
                if (selectedSpace == 'personal') {
                  filtered = filtered.where((t) => !t.isShared || t.groupId == null).toList();
                } else if (selectedSpace != 'all') {
                  filtered = filtered.where((t) => t.isShared && t.groupId == selectedSpace).toList();
                }

                // B. Date range filter
                final now = DateTime.now();
                if (dateRangeOption == 'this_month') {
                  final start = DateTime(now.year, now.month, 1);
                  filtered = filtered.where((t) => t.date.isAfter(start) || t.date.isAtSameMomentAs(start)).toList();
                } else if (dateRangeOption == 'last_month') {
                  final start = DateTime(now.year, now.month - 1, 1);
                  final end = DateTime(now.year, now.month, 1).subtract(const Duration(milliseconds: 1));
                  filtered = filtered.where((t) => t.date.isAfter(start) && t.date.isBefore(end)).toList();
                } else if (dateRangeOption == 'custom' && customDateRange != null) {
                  final start = DateTime(customDateRange.start.year, customDateRange.start.month, customDateRange.start.day, 0, 0, 0);
                  final end = DateTime(customDateRange.end.year, customDateRange.end.month, customDateRange.end.day, 23, 59, 59);
                  filtered = filtered.where((t) => t.date.isAfter(start) && t.date.isBefore(end)).toList();
                }

                // C. Type filter
                if (transactionType == 'expense') {
                  filtered = filtered.where((t) => t.isExpense).toList();
                } else if (transactionType == 'income') {
                  filtered = filtered.where((t) => !t.isExpense).toList();
                }

                if (filtered.isEmpty) {
                  Utils.showErrorToast(context, title: "No transactions match selected filters");
                  return;
                }

                // 3. Resolve title
                String title = "All Spaces Combined";
                if (selectedSpace == 'personal') {
                  title = "Personal Space";
                } else if (selectedSpace != 'all') {
                  final groups = ref.read(userGroupsStreamProvider).value ?? [];
                  final grp = groups.firstWhere(
                    (g) => g.id == selectedSpace,
                    orElse: () => GroupModel(id: '', name: 'Group', adminId: '', members: [], memberLimits: {}, type: 'split'),
                  );
                  title = grp.name;
                }

                // Close sheet
                Navigator.pop(context);

                // 4. Trigger Export
                final currentUserId = ref.read(firebaseAuthProvider).currentUser?.uid ?? '';
                final memberNames = ref.read(allGroupsMembersProvider).value ?? {};

                if (exportFormat == 'csv') {
                  await PdfHelper.exportToCsv(
                    transactions: filtered,
                    title: title,
                    currentUserId: currentUserId,
                    memberNames: memberNames,
                  );
                } else {
                  // PDF Format
                  Uint8List bytes;
                  if (selectedSpace != 'all' && selectedSpace != 'personal') {
                    final groups = ref.read(userGroupsStreamProvider).value ?? [];
                    final group = groups.firstWhere((g) => g.id == selectedSpace);
                    bytes = await PdfHelper.generateGroupStatementBytes(
                      group: group,
                      transactions: filtered,
                      title: title,
                      memberNames: memberNames,
                      currentUserId: currentUserId,
                    );
                  } else {
                    bytes = await PdfHelper.generatePersonalStatementBytes(
                      transactions: filtered,
                      title: title,
                    );
                  }

                  // Open PDF Preview Page
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PdfPreviewPage(
                          pdfBytes: bytes,
                          filename: "${title.replaceAll(' ', '_')}_Statement.pdf",
                          title: "$title Statement",
                        ),
                      ),
                    );
                  }
                }
              },
              child: Text(
                'Export Statement',
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF3F8F5) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _kGreen : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? _kGreen : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildFormatCard(
    String title,
    String desc,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF3F8F5) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _kGreen : Colors.grey[200]!,
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: isSelected ? _kGreen : Colors.grey[400], size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isSelected ? _kGreen : _darkText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              desc,
              style: GoogleFonts.manrope(
                fontSize: 10,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
