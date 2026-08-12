import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:know_your_expenses/features/auto_sms/model/model_pending_sms.dart';
import 'package:know_your_expenses/features/auto_sms/view_model/auto_sms_provider.dart';
import 'package:know_your_expenses/features/home/view_model/view_model_group.dart';
import 'package:know_your_expenses/features/transaction/model/model_transaction.dart';
import 'package:know_your_expenses/features/transaction/view_model/view_model_transaction.dart';
import 'package:know_your_expenses/features/helper/utils.dart';
import 'package:know_your_expenses/core/widgets/custom_dialogs.dart';

class WidgetAutoFillLedgerSheet extends ConsumerStatefulWidget {
  final ModelPendingSms pendingSms;

  const WidgetAutoFillLedgerSheet({
    super.key,
    required this.pendingSms,
  });

  @override
  ConsumerState<WidgetAutoFillLedgerSheet> createState() => _WidgetAutoFillLedgerSheetState();
}

class _WidgetAutoFillLedgerSheetState extends ConsumerState<WidgetAutoFillLedgerSheet> {
  late TextEditingController _amountController;
  late TextEditingController _descriptionController;

  String? _selectedGroupId; // null means Personal Workspace
  CategoryModel? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: widget.pendingSms.amount.toStringAsFixed(2));
    _descriptionController = TextEditingController(text: widget.pendingSms.vendorName);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      Utils.showErrorToast(context, title: 'Invalid Amount', description: 'Please enter a valid expense amount.');
      return;
    }

    final categories = ref.read(categoriesProvider).value ?? [];
    final category = _selectedCategory ??
        PendingSmsNotifier.getSmartCategory(widget.pendingSms, categories);

    await ref.read(pendingSmsListProvider.notifier).assignPendingSms(
          pendingId: widget.pendingSms.id,
          targetGroupId: _selectedGroupId,
          categoryId: category.id,
          categoryName: category.name,
          iconCodePoint: category.iconCodePoint,
          colorValue: category.colorValue,
          description: _descriptionController.text.trim().isEmpty
              ? widget.pendingSms.vendorName
              : _descriptionController.text.trim(),
          amount: amount,
        );

    if (mounted) {
      Navigator.pop(context);
      Utils.showSuccessToast(context, title: 'Expense Assigned Successfully');
    }
  }

  Future<void> _handleDiscard() async {
    CustomDialogs.showDiscardSmsDialog(
      context,
      onConfirm: () async {
        await ref.read(pendingSmsListProvider.notifier).discardPendingSms(widget.pendingSms.id);
        if (mounted) {
          Navigator.pop(context);
          Utils.showSuccessToast(context, title: 'Transaction Discarded');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final allGroups = ref.watch(userGroupsStreamProvider).value ?? [];
    final groups = allGroups.where((group) {
      if (group.type == 'wages') {
        final isAdmin = currentUser != null &&
            (group.adminId == currentUser.uid || group.admins.contains(currentUser.uid));
        return isAdmin;
      }
      return true;
    }).toList();
    final categories = ref.watch(categoriesProvider).value ?? [];

    if (_selectedCategory == null && categories.isNotEmpty) {
      _selectedCategory = PendingSmsNotifier.getSmartCategory(widget.pendingSms, categories);
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF429690).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.sms_rounded, color: Color(0xFF429690), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Auto-Detected Expense',
                        style: GoogleFonts.manrope(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1A2332),
                        ),
                      ),
                      Text(
                        'Assign this SMS expense to a Group',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Amount Input
            Text(
              'Amount (₹)',
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A2332),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.manrope(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF429690),
              ),
              decoration: InputDecoration(
                prefixText: '₹ ',
                prefixStyle: GoogleFonts.manrope(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF429690),
                ),
                filled: true,
                fillColor: const Color(0xFFF4F7F6),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Merchant / Description
            Text(
              'Description / Merchant',
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A2332),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _descriptionController,
              style: GoogleFonts.manrope(fontSize: 15, color: const Color(0xFF1A2332)),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF4F7F6),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Category Selection Chips
            Text(
              'Select Category',
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A2332),
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: categories.map((cat) {
                  final isSelected = _selectedCategory?.id == cat.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      selected: isSelected,
                      avatar: Icon(
                        IconData(cat.iconCodePoint, fontFamily: 'MaterialIcons'),
                        size: 16,
                        color: isSelected ? Colors.white : Color(cat.colorValue),
                      ),
                      label: Text(
                        cat.name,
                        style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
                      ),
                      selectedColor: const Color(0xFF429690),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFF1A2332),
                      ),
                      onSelected: (_) {
                        setState(() {
                          _selectedCategory = cat;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // Target Group Selection Chips
            Text(
              'Select Destination Group',
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A2332),
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Personal option
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      selected: _selectedGroupId == null,
                      label: Text('👤 Personal', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
                      selectedColor: const Color(0xFF429690),
                      labelStyle: TextStyle(
                        color: _selectedGroupId == null ? Colors.white : const Color(0xFF1A2332),
                      ),
                      onSelected: (_) {
                        setState(() {
                          _selectedGroupId = null;
                        });
                      },
                    ),
                  ),
                  ...groups.map((group) {
                    final isSelected = _selectedGroupId == group.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        selected: isSelected,
                        label: Text(
                          '👥 ${group.name}',
                          style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
                        ),
                        selectedColor: const Color(0xFF429690),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF1A2332),
                        ),
                        onSelected: (_) {
                          setState(() {
                            _selectedGroupId = group.id;
                          });
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons (Save & Discard)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _handleDiscard,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE57373),
                      side: const BorderSide(color: Color(0xFFE57373)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      'Discard',
                      style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF429690),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Text(
                      'Assign Expense',
                      style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 15),
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
