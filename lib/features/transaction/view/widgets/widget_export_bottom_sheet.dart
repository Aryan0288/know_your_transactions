import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

class ExportBottomSheet extends ConsumerStatefulWidget {
  final String? initialGroupId;
  const ExportBottomSheet({super.key, this.initialGroupId});

  @override
  ConsumerState<ExportBottomSheet> createState() => _ExportBottomSheetState();
}

class _ExportBottomSheetState extends ConsumerState<ExportBottomSheet> {
  static const Color _kGreen = Color(0xFF2E8B57);
  static const Color _darkText = Color(0xFF1E232A);

  late String _selectedSpace; // 'all', 'personal', or groupId
  String _dateRangeOption = 'all'; // 'all', 'this_month', 'last_month', 'custom'
  DateTimeRange? _customDateRange;
  String _transactionType = 'all'; // 'all', 'expense', 'income'
  String _exportFormat = 'pdf'; // 'pdf', 'csv'

  @override
  void initState() {
    super.initState();
    _selectedSpace = widget.initialGroupId ?? 'all';
  }

  Future<void> _selectCustomDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _customDateRange,
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
      setState(() {
        _customDateRange = picked;
        _dateRangeOption = 'custom';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(userGroupsStreamProvider);
    final allTransactionsAsync = ref.watch(transactionsStreamProvider);

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
                    value: _selectedSpace,
                    isExpanded: true,
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    icon: const Icon(Icons.arrow_drop_down_rounded, color: _kGreen, size: 28),
                    items: items,
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedSpace = val;
                        });
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
              _buildSegmentChip('All Time', _dateRangeOption == 'all', () {
                setState(() => _dateRangeOption = 'all');
              }),
              const SizedBox(width: 8),
              _buildSegmentChip('This Month', _dateRangeOption == 'this_month', () {
                setState(() => _dateRangeOption = 'this_month');
              }),
              const SizedBox(width: 8),
              _buildSegmentChip('Last Month', _dateRangeOption == 'last_month', () {
                setState(() => _dateRangeOption = 'last_month');
              }),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _selectCustomDateRange(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _dateRangeOption == 'custom' ? const Color(0xFFF3F8F5) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _dateRangeOption == 'custom' ? _kGreen.withOpacity(0.3) : Colors.grey[300]!,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _dateRangeOption == 'custom' && _customDateRange != null
                        ? "${DateFormat('dd MMM').format(_customDateRange!.start)} - ${DateFormat('dd MMM yyyy').format(_customDateRange!.end)}"
                        : "Custom Date Range...",
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _dateRangeOption == 'custom' ? _kGreen : Colors.grey[600],
                    ),
                  ),
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 16,
                    color: _dateRangeOption == 'custom' ? _kGreen : Colors.grey[500],
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
              _buildSegmentChip('All', _transactionType == 'all', () {
                setState(() => _transactionType = 'all');
              }),
              const SizedBox(width: 8),
              _buildSegmentChip('Expenses Only', _transactionType == 'expense', () {
                setState(() => _transactionType = 'expense');
              }),
              const SizedBox(width: 8),
              _buildSegmentChip('Income Only', _transactionType == 'income', () {
                setState(() => _transactionType = 'income');
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
                  _exportFormat == 'pdf',
                  () => setState(() => _exportFormat = 'pdf'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFormatCard(
                  'CSV Format',
                  'Best for Excel / Google Sheets',
                  Icons.table_rows_rounded,
                  _exportFormat == 'csv',
                  () => setState(() => _exportFormat = 'csv'),
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
                if (_selectedSpace == 'personal') {
                  filtered = filtered.where((t) => !t.isShared || t.groupId == null).toList();
                } else if (_selectedSpace != 'all') {
                  filtered = filtered.where((t) => t.isShared && t.groupId == _selectedSpace).toList();
                }

                // B. Date range filter
                final now = DateTime.now();
                if (_dateRangeOption == 'this_month') {
                  final start = DateTime(now.year, now.month, 1);
                  filtered = filtered.where((t) => t.date.isAfter(start) || t.date.isAtSameMomentAs(start)).toList();
                } else if (_dateRangeOption == 'last_month') {
                  final start = DateTime(now.year, now.month - 1, 1);
                  final end = DateTime(now.year, now.month, 1).subtract(const Duration(milliseconds: 1));
                  filtered = filtered.where((t) => t.date.isAfter(start) && t.date.isBefore(end)).toList();
                } else if (_dateRangeOption == 'custom' && _customDateRange != null) {
                  final start = DateTime(_customDateRange!.start.year, _customDateRange!.start.month, _customDateRange!.start.day, 0, 0, 0);
                  final end = DateTime(_customDateRange!.end.year, _customDateRange!.end.month, _customDateRange!.end.day, 23, 59, 59);
                  filtered = filtered.where((t) => t.date.isAfter(start) && t.date.isBefore(end)).toList();
                }

                // C. Type filter
                if (_transactionType == 'expense') {
                  filtered = filtered.where((t) => t.isExpense).toList();
                } else if (_transactionType == 'income') {
                  filtered = filtered.where((t) => !t.isExpense).toList();
                }

                if (filtered.isEmpty) {
                  Utils.showErrorToast(context, title: "No transactions match selected filters");
                  return;
                }

                // 3. Resolve title
                String title = "All Spaces Combined";
                if (_selectedSpace == 'personal') {
                  title = "Personal Space";
                } else if (_selectedSpace != 'all') {
                  final groups = ref.read(userGroupsStreamProvider).value ?? [];
                  final grp = groups.firstWhere(
                    (g) => g.id == _selectedSpace,
                    orElse: () => GroupModel(id: '', name: 'Group', adminId: '', members: [], memberLimits: {}, type: 'split'),
                  );
                  title = grp.name;
                }

                // Close sheet
                Navigator.pop(context);

                // 4. Trigger Export
                final currentUserId = ref.read(firebaseAuthProvider).currentUser?.uid ?? '';
                final memberNames = ref.read(allGroupsMembersProvider).value ?? {};

                if (_exportFormat == 'csv') {
                  await PdfHelper.exportToCsv(
                    transactions: filtered,
                    title: title,
                    currentUserId: currentUserId,
                    memberNames: memberNames,
                  );
                } else {
                  // PDF Format
                  Uint8List bytes;
                  if (_selectedSpace != 'all' && _selectedSpace != 'personal') {
                    final groups = ref.read(userGroupsStreamProvider).value ?? [];
                    final group = groups.firstWhere((g) => g.id == _selectedSpace);
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
