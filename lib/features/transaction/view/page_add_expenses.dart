import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:know_your_expenses/features/common_widgets/common_widgets.dart';
import 'package:know_your_expenses/features/helper/utils.dart';
import 'package:know_your_expenses/features/home/view_model/view_model_group.dart';
import 'package:know_your_expenses/features/home/view_model/view_model_home.dart';
import 'package:know_your_expenses/features/transaction/model/model_transaction.dart';
import 'package:know_your_expenses/features/transaction/view_model/view_model_transaction.dart';

class AddExpensePage extends ConsumerStatefulWidget {
  final double? initialAmount;
  final TransactionModel? editTransaction;
  const AddExpensePage({super.key, this.initialAmount, this.editTransaction});

  @override
  ConsumerState<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends ConsumerState<AddExpensePage> {
  final TextEditingController amountController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  
  late final ValueNotifier<CategoryModel?> selectedCategoryNotifier;
  late final ValueNotifier<DateTime> selectedDateNotifier;
  late final ValueNotifier<bool> isSharedNotifier;
  late final ValueNotifier<List<String>> selectedSplitMembersNotifier;
  late final ValueNotifier<String?> selectedGroupIdNotifier;
  late final ValueNotifier<bool> isCustomSplitNotifier;
  late final ValueNotifier<Map<String, double>> splitAmountsNotifier;
  late final ValueNotifier<bool> isExpenseNotifier;
  final Map<String, TextEditingController> _memberSplitControllers = {};
  String? _lastInitializedGroupId;

  @override
  void initState() {
    super.initState();
    selectedCategoryNotifier = ValueNotifier<CategoryModel?>(
      widget.editTransaction != null
          ? CategoryModel(
              id: widget.editTransaction!.categoryId,
              name: widget.editTransaction!.categoryName,
              iconCodePoint: widget.editTransaction!.iconCodePoint,
              colorValue: widget.editTransaction!.colorValue,
            )
          : null,
    );
    selectedDateNotifier = ValueNotifier<DateTime>(widget.editTransaction?.date ?? DateTime.now());
    isSharedNotifier = ValueNotifier<bool>(widget.editTransaction?.isShared ?? false);
    selectedSplitMembersNotifier = ValueNotifier<List<String>>(widget.editTransaction?.splitWith ?? []);
    selectedGroupIdNotifier = ValueNotifier<String?>(
      widget.editTransaction != null
          ? (widget.editTransaction!.isShared
              ? widget.editTransaction!.groupId
              : 'personal')
          : null,
    );
    isCustomSplitNotifier = ValueNotifier<bool>(widget.editTransaction?.splitAmounts != null);
    splitAmountsNotifier = ValueNotifier<Map<String, double>>(widget.editTransaction?.splitAmounts ?? {});
    isExpenseNotifier = ValueNotifier<bool>(widget.editTransaction?.isExpense ?? true);
    
    if (widget.editTransaction != null) {
      amountController.text = widget.editTransaction!.amount % 1 == 0
          ? widget.editTransaction!.amount.toInt().toString()
          : widget.editTransaction!.amount.toString();
      descriptionController.text = widget.editTransaction!.description;
      if (widget.editTransaction!.splitAmounts != null) {
        widget.editTransaction!.splitAmounts!.forEach((uid, val) {
          _memberSplitControllers[uid] = TextEditingController(
            text: val % 1 == 0 ? val.toInt().toString() : val.toString(),
          );
        });
      }
    } else if (widget.initialAmount != null && widget.initialAmount! > 0) {
      amountController.text = widget.initialAmount!.toStringAsFixed(0);
    }

    amountController.addListener(_updateSplitAmounts);
    selectedSplitMembersNotifier.addListener(_updateSplitAmounts);
  }

  @override
  void dispose() {
    amountController.dispose();
    descriptionController.dispose();
    selectedCategoryNotifier.dispose();
    selectedDateNotifier.dispose();
    isSharedNotifier.dispose();
    selectedSplitMembersNotifier.dispose();
    selectedGroupIdNotifier.dispose();
    isCustomSplitNotifier.dispose();
    splitAmountsNotifier.dispose();
    _memberSplitControllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  void _updateSplitAmounts() {
    final selected = selectedSplitMembersNotifier.value;
    final total = double.tryParse(amountController.text) ?? 0.0;

    if (isCustomSplitNotifier.value) {
      final currentMap = <String, double>{};
      for (var uid in selected) {
        final controller = _memberSplitControllers[uid];
        if (controller != null) {
          currentMap[uid] = double.tryParse(controller.text) ?? 0.0;
        }
      }
      splitAmountsNotifier.value = currentMap;
      return;
    }

    if (selected.isEmpty) {
      splitAmountsNotifier.value = {};
      return;
    }

    final share = total / selected.length;
    final shareStr = share.toStringAsFixed(2);
    final shareVal = double.tryParse(shareStr) ?? share;

    final newMap = <String, double>{};
    for (var uid in selected) {
      newMap[uid] = shareVal;
      final controller = _memberSplitControllers[uid];
      if (controller != null && controller.text != shareStr) {
        controller.text = shareStr;
      }
    }
    splitAmountsNotifier.value = newMap;
  }

  String? _getSplitValidationMessage() {
    if (!isSharedNotifier.value) return null;

    final total = double.tryParse(amountController.text) ?? 0.0;
    final selected = selectedSplitMembersNotifier.value;
    if (selected.isEmpty) return "Select at least one member to split with.";

    double sum = 0.0;
    for (var uid in selected) {
      final controller = _memberSplitControllers[uid];
      if (controller != null) {
        sum += double.tryParse(controller.text) ?? 0.0;
      }
    }

    if ((sum - total).abs() > 0.02) {
      return "Sum of splits (₹${sum.toStringAsFixed(2)}) does not match total bill (₹${total.toStringAsFixed(2)})";
    }

    return null;
  }

  void _showAddCategoryDialog() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'New Category',
          style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Category Name (e.g. Rent)',
            hintStyle: GoogleFonts.manrope(color: Colors.grey),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.manrope(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E8B57),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                await ref
                    .read(transactionViewModelProvider.notifier)
                    .addCategory(
                      name: nameController.text.trim(),
                      icon: Icons.category,
                      color: Colors.teal,
                    );
                if (mounted) Navigator.pop(context);
              }
            },
            child: Text('Add', style: GoogleFonts.manrope(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: Text(
          'Add Expense',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF2E8B57),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top Header with Amount
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
              decoration: const BoxDecoration(
                color: Color(0xFF2E8B57),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How much?',
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '\₹',
                        style: GoogleFonts.manrope(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: amountController,
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.manrope(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          decoration: const InputDecoration(
                            hintText: '0',
                            hintStyle: TextStyle(color: Colors.white24),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Transaction Type Selector
                  Text(
                    'Transaction Type',
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E1E1E),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ValueListenableBuilder<bool>(
                    valueListenable: isExpenseNotifier,
                    builder: (context, isExpense, _) {
                      return Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                isExpenseNotifier.value = true;
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: isExpense ? const Color(0xFFFFEBEE) : Colors.white,
                                  border: Border.all(
                                    color: isExpense ? Colors.redAccent : Colors.grey[300]!,
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.arrow_upward_rounded,
                                        color: isExpense ? Colors.redAccent : Colors.grey[600],
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Expense',
                                        style: GoogleFonts.manrope(
                                          fontWeight: FontWeight.bold,
                                          color: isExpense ? Colors.red[800] : Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                isExpenseNotifier.value = false;
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: !isExpense ? const Color(0xFFE8F5E9) : Colors.white,
                                  border: Border.all(
                                    color: !isExpense ? Colors.green : Colors.grey[300]!,
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.arrow_downward_rounded,
                                        color: !isExpense ? Colors.green : Colors.grey[600],
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Income',
                                        style: GoogleFonts.manrope(
                                          fontWeight: FontWeight.bold,
                                          color: !isExpense ? Colors.green[800] : Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Category Selector Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Category',
                        style: GoogleFonts.manrope(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E1E1E),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _showAddCategoryDialog,
                        icon: const Icon(
                          Icons.add_circle_outline,
                          size: 20,
                          color: Color(0xFF2E8B57),
                        ),
                        label: Text(
                          'Add New',
                          style: GoogleFonts.manrope(
                            color: const Color(0xFF2E8B57),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Horizontal Category Scroll
                  ValueListenableBuilder<bool>(
                    valueListenable: isExpenseNotifier,
                    builder: (context, isExpense, _) {
                      if (!isExpense) {
                        final incomeCategories = [
                          CategoryModel(
                            id: 'cash',
                            name: 'Cash',
                            iconCodePoint: Icons.money_rounded.codePoint,
                            colorValue: Colors.green.value,
                          ),
                          CategoryModel(
                            id: 'online',
                            name: 'Online',
                            iconCodePoint: Icons.payment_rounded.codePoint,
                            colorValue: Colors.teal.value,
                          ),
                        ];
                        final currentCat = selectedCategoryNotifier.value;
                        if (currentCat == null || (currentCat.id != 'cash' && currentCat.id != 'online')) {
                          Future.microtask(() => selectedCategoryNotifier.value = incomeCategories.first);
                        }
                        return _buildCategoryListWidget(incomeCategories);
                      }

                      return Consumer(
                        builder: (context, ref, child) {
                          final categoriesAsync = ref.watch(categoriesProvider);
                          return categoriesAsync.when(
                            data: (categories) {
                              final currentCat = selectedCategoryNotifier.value;
                              if (currentCat == null || currentCat.id == 'cash' || currentCat.id == 'online') {
                                if (categories.isNotEmpty) {
                                  Future.microtask(() => selectedCategoryNotifier.value = categories.first);
                                }
                              }
                              return _buildCategoryListWidget(categories);
                            },
                            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF2E8B57))),
                            error: (e, stack) => Text('Error: $e'),
                          );
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 32),

                  // Date Picker Section
                  Text(
                    'Date',
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E1E1E),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ValueListenableBuilder<DateTime>(
                    valueListenable: selectedDateNotifier,
                    builder: (context, currentDate, _) {
                      return GestureDetector(
                        onTap: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: currentDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: Color(0xFF2E8B57),
                                    onPrimary: Colors.white,
                                    onSurface: Colors.black,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            final now = DateTime.now();
                            selectedDateNotifier.value = DateTime(
                              picked.year,
                              picked.month,
                              picked.day,
                              now.hour,
                              now.minute,
                              now.second,
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                color: Color(0xFF2E8B57),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                DateFormat('MMMM dd, yyyy').format(currentDate),
                                style: GoogleFonts.manrope(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const Spacer(),
                              const Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.grey,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 32),

                  // Description Field
                  Text(
                    'Description',
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E1E1E),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: descriptionController,
                      maxLines: 2,
                      style: GoogleFonts.manrope(fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'Add a note...',
                        hintStyle: GoogleFonts.manrope(color: Colors.grey),
                        contentPadding: const EdgeInsets.all(20),
                        border: InputBorder.none,
                      ),
                    ),
                  ),                  // Group/Share Switch and Split checkboxes
                  Consumer(
                    builder: (context, ref, child) {
                      final userGroupsAsync = ref.watch(userGroupsStreamProvider);
                      final currentUserId = ref.watch(firebaseAuthProvider).currentUser?.uid;

                      return userGroupsAsync.when(
                        data: (groups) {
                          if (groups.isEmpty) return const SizedBox();

                          return AnimatedBuilder(
                            animation: Listenable.merge([
                              isSharedNotifier,
                              selectedSplitMembersNotifier,
                              amountController,
                              selectedGroupIdNotifier,
                              isCustomSplitNotifier,
                              splitAmountsNotifier,
                            ]),
                            builder: (context, child) {
                              final isShared = isSharedNotifier.value;
                              final selectedSplitMembers = selectedSplitMembersNotifier.value;
                              final selectedGroupId = selectedGroupIdNotifier.value;
                              final isCustomSplit = isCustomSplitNotifier.value;
                              final selectedGroup = isShared && selectedGroupId != null && selectedGroupId != 'personal'
                                  ? groups.firstWhere(
                                      (g) => g.id == selectedGroupId,
                                      orElse: () => groups.first,
                                    )
                                  : null;
                              final isBusinessGroup = selectedGroup?.type == 'business';

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 32),
                                  Text(
                                    'Post to Space',
                                    style: GoogleFonts.manrope(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String?>(
                                        value: selectedGroupId,
                                        isExpanded: true,
                                        hint: Text(
                                          'Select Space (Group or Personal)',
                                          style: GoogleFonts.manrope(
                                            color: Colors.grey[500],
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF2E8B57)),
                                        style: GoogleFonts.manrope(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                        items: [
                                          DropdownMenuItem<String?>(
                                            value: 'personal',
                                            child: Text('Personal Space', style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
                                          ),
                                          ...groups.map((g) {
                                            return DropdownMenuItem<String?>(
                                              value: g.id,
                                              child: Text('Group: ${g.name}', style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
                                            );
                                          }),
                                        ],
                                        onChanged: (newGroupId) {
                                          if (newGroupId == 'personal') {
                                            isSharedNotifier.value = false;
                                            selectedGroupIdNotifier.value = 'personal';
                                          } else if (newGroupId != null) {
                                            isSharedNotifier.value = true;
                                            selectedGroupIdNotifier.value = newGroupId;
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                  if (isShared && selectedGroupId != null && !isBusinessGroup) ...[
                                    const SizedBox(height: 24),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Split participants:',
                                          style: GoogleFonts.manrope(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                        if (isCustomSplit)
                                          TextButton.icon(
                                            onPressed: () {
                                              isCustomSplitNotifier.value = false;
                                              _updateSplitAmounts();
                                            },
                                            icon: const Icon(Icons.refresh, size: 16, color: Color(0xFF2E8B57)),
                                            label: Text(
                                              'Reset to Equal',
                                              style: GoogleFonts.manrope(
                                                fontSize: 12,
                                                color: const Color(0xFF2E8B57),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'You can customize each member\'s split amount below.',
                                      style: GoogleFonts.manrope(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    ref.watch(groupMembersDetailsByIdProvider(selectedGroupId)).when(
                                      data: (members) {
                                        for (var m in members) {
                                          final uid = m['uid'] as String;
                                          if (!_memberSplitControllers.containsKey(uid)) {
                                            _memberSplitControllers[uid] = TextEditingController();
                                          }
                                        }

                                        if (_lastInitializedGroupId != selectedGroupId && members.isNotEmpty) {
                                          _lastInitializedGroupId = selectedGroupId;
                                          Future.microtask(() {
                                            selectedSplitMembersNotifier.value =
                                                members.map((m) => m['uid'] as String).toList();
                                            _updateSplitAmounts();
                                          });
                                        }

                                        return Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(20),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.05),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: ListView.separated(
                                            shrinkWrap: true,
                                            physics: const NeverScrollableScrollPhysics(),
                                            itemCount: members.length,
                                            separatorBuilder: (context, index) =>
                                                const Divider(height: 1, indent: 20, endIndent: 20),
                                            itemBuilder: (context, index) {
                                              final member = members[index];
                                              final uid = member['uid'] as String;
                                              final name = uid == currentUserId
                                                  ? '${member['name'] as String? ?? 'Group Member'} (You)'
                                                  : (member['name'] as String? ?? 'Group Member');
                                              final isSelected = selectedSplitMembers.contains(uid);

                                              return Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 4),
                                                child: Row(
                                                  children: [
                                                    Checkbox(
                                                      value: isSelected,
                                                      activeColor: const Color(0xFF2E8B57),
                                                      onChanged: (checked) {
                                                        final currentList = List<String>.from(selectedSplitMembersNotifier.value);
                                                        if (checked == true) {
                                                          if (!currentList.contains(uid)) {
                                                            currentList.add(uid);
                                                          }
                                                        } else {
                                                          currentList.remove(uid);
                                                        }
                                                        selectedSplitMembersNotifier.value = currentList;
                                                      },
                                                    ),
                                                    Expanded(
                                                      child: Text(
                                                        name,
                                                        style: GoogleFonts.manrope(
                                                          fontSize: 16,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                    if (isSelected)
                                                      Container(
                                                        width: 90,
                                                        height: 40,
                                                        margin: const EdgeInsets.only(right: 16),
                                                        child: TextField(
                                                          controller: _memberSplitControllers[uid],
                                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                          textAlign: TextAlign.right,
                                                          style: GoogleFonts.manrope(
                                                            fontSize: 14,
                                                            fontWeight: FontWeight.w600,
                                                            color: const Color(0xFF2E8B57),
                                                          ),
                                                          decoration: InputDecoration(
                                                            prefixText: '₹',
                                                            prefixStyle: GoogleFonts.manrope(color: Colors.grey),
                                                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                            border: OutlineInputBorder(
                                                              borderRadius: BorderRadius.circular(8),
                                                              borderSide: const BorderSide(color: Colors.grey),
                                                            ),
                                                            focusedBorder: OutlineInputBorder(
                                                              borderRadius: BorderRadius.circular(8),
                                                              borderSide: const BorderSide(color: Color(0xFF2E8B57), width: 1.5),
                                                            ),
                                                          ),
                                                          onChanged: (val) {
                                                            isCustomSplitNotifier.value = true;
                                                            final newMap = Map<String, double>.from(splitAmountsNotifier.value);
                                                            newMap[uid] = double.tryParse(val) ?? 0.0;
                                                            splitAmountsNotifier.value = newMap;
                                                          },
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        );
                                      },
                                      loading: () => const Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(20.0),
                                          child: CircularProgressIndicator(color: Color(0xFF2E8B57)),
                                        ),
                                      ),
                                      error: (err, stack) => Text('Error loading members: $err'),
                                    ),
                                    // Validation Warning Banner
                                    Builder(
                                      builder: (context) {
                                        final validationError = _getSplitValidationMessage();
                                        if (validationError == null || validationError.startsWith("Select at least")) {
                                          return const SizedBox();
                                        }
                                        return Container(
                                          margin: const EdgeInsets.only(top: 16),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.red[50]!.withOpacity(0.8),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.red[200]!),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(Icons.warning_amber_rounded, color: Colors.red[700]),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  validationError,
                                                  style: GoogleFonts.manrope(
                                                    color: Colors.red[800],
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ],
                              );
                            },
                          );
                        },
                        loading: () => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: CircularProgressIndicator(color: Color(0xFF2E8B57)),
                          ),
                        ),
                        error: (err, stack) => Text('Error loading groups: $err'),
                      );
                    },
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              child: Consumer(
                builder: (context, ref, child) {
                  final isLoading = ref
                      .watch(transactionViewModelProvider)
                      .isLoading;
                  return elevatedButton(
                    color: const Color(0xFF2E8B57),
                    shadowColor: const Color(0xFF2E8B57).withOpacity(0.2),
                    isLoading: isLoading,
                    onPressed: () async {
                      if (amountController.text.isEmpty) {
                        Utils.showErrorToast(
                          context,
                          alignment: Alignment.bottomCenter,
                          title: "Amount Required",
                          description: "Please enter the amount spent.",
                        );
                        return;
                      }

                      final selectedSpace = selectedGroupIdNotifier.value;
                      if (selectedSpace == null) {
                        Utils.showErrorToast(
                          context,
                          alignment: Alignment.bottomCenter,
                          title: "Space Required",
                          description: "Please select where to post this transaction (Personal or Group).",
                        );
                        return;
                      }
                      
                      final cat = selectedCategoryNotifier.value;
                      if (cat == null) return;

                      final shared = selectedSpace != 'personal';
                      final targetGroupId = shared ? selectedSpace : null;
                      final splitWith = selectedSplitMembersNotifier.value;

                      final userGroups = ref.read(userGroupsStreamProvider).value ?? [];
                      final selectedGroup = shared && targetGroupId != null
                          ? userGroups.firstWhere(
                              (g) => g.id == targetGroupId,
                              orElse: () => userGroups.first,
                            )
                          : null;
                      final isBusinessGroup = selectedGroup?.type == 'business';

                      if (shared && !isBusinessGroup) {
                        if (splitWith.isEmpty) {
                          Utils.showErrorToast(
                            context,
                            alignment: Alignment.bottomCenter,
                            title: "Select Participant",
                            description: "Please select at least one group member to split with.",
                          );
                          return;
                        }

                        final errorMsg = _getSplitValidationMessage();
                        if (errorMsg != null) {
                          Utils.showErrorToast(
                            context,
                            alignment: Alignment.bottomCenter,
                            title: "Invalid Split",
                            description: errorMsg,
                          );
                          return;
                        }
                      }

                      Map<String, double>? splitAmounts;
                      if (shared && !isBusinessGroup) {
                        splitAmounts = {};
                        for (var uid in splitWith) {
                          final controller = _memberSplitControllers[uid];
                          if (controller != null) {
                            splitAmounts[uid] = double.tryParse(controller.text) ?? 0.0;
                          }
                        }
                      }

                      final isEdit = widget.editTransaction != null;

                      // If saving a new transaction in a business group as a member (non-admin), warn them with details
                      if (isBusinessGroup && !isEdit) {
                        final currentUserId = ref.read(firebaseAuthProvider).currentUser?.uid;
                        final isAdmin = selectedGroup?.adminId == currentUserId;
                        if (!isAdmin) {
                          final isExpense = isExpenseNotifier.value;
                          final typeColor = isExpense ? Colors.red.shade800 : Colors.green.shade800;
                          final typeBgColor = isExpense ? Colors.red.shade50 : Colors.green.shade50;

                          final proceed = await showDialog<bool>(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) {
                              Widget buildRow(String label, String val, IconData icon) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(icon, size: 18, color: Colors.grey[500]),
                                      const SizedBox(width: 8),
                                      Text(
                                        label,
                                        style: GoogleFonts.manrope(
                                          color: Colors.grey[500],
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          val,
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

                              return AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                title: Row(
                                  children: [
                                    const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Confirm Save',
                                      style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                content: SingleChildScrollView(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        'This is a Business Group transaction. Once saved, only the group Admin can edit or delete this. You will not be able to change it in the future.',
                                        style: GoogleFonts.manrope(fontSize: 13, color: Colors.grey[600]),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 20),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: typeBgColor,
                                          borderRadius: BorderRadius.circular(30),
                                        ),
                                        child: Text(
                                          isExpense ? 'EXPENSE' : 'INCOME',
                                          style: GoogleFonts.manrope(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: typeColor,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        '₹ ${(double.tryParse(amountController.text) ?? 0.0).toStringAsFixed(2)}',
                                        style: GoogleFonts.manrope(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w900,
                                          color: typeColor,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      const Divider(height: 1),
                                      const SizedBox(height: 12),
                                      buildRow('Category', cat.name, Icons.category_rounded),
                                      const SizedBox(height: 2),
                                      buildRow('Date', DateFormat('MMM dd, yyyy  •  hh:mm a').format(selectedDateNotifier.value), Icons.calendar_month_rounded),
                                      if (selectedGroup != null) ...[
                                        const SizedBox(height: 2),
                                        buildRow('Group', selectedGroup.name, Icons.group_rounded),
                                      ],
                                      const SizedBox(height: 2),
                                      buildRow(
                                        'Description',
                                        descriptionController.text.isNotEmpty ? descriptionController.text : '-',
                                        Icons.notes_rounded,
                                      ),
                                      const SizedBox(height: 12),
                                      const Divider(height: 1),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Confirm and Save Transaction?',
                                        style: GoogleFonts.manrope(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: const Color(0xFF1E232A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: Text(
                                      'Cancel',
                                      style: GoogleFonts.manrope(color: Colors.grey[600], fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2E8B57),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    onPressed: () => Navigator.pop(context, true),
                                    child: Text(
                                      'Save Anyway',
                                      style: GoogleFonts.manrope(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                          if (proceed != true) return;
                        }
                      }

                      final success = isEdit
                          ? await ref
                              .read(transactionViewModelProvider.notifier)
                              .editTransaction(
                                originalTransaction: widget.editTransaction!,
                                amount: double.tryParse(amountController.text) ?? 0,
                                description: descriptionController.text,
                                category: cat,
                                date: selectedDateNotifier.value,
                                isExpense: isExpenseNotifier.value,
                                isShared: shared,
                                splitWith: (shared && !isBusinessGroup) ? splitWith : null,
                                targetGroupId: targetGroupId,
                                splitAmounts: splitAmounts,
                              )
                          : await ref
                              .read(transactionViewModelProvider.notifier)
                              .addTransaction(
                                amount: double.tryParse(amountController.text) ?? 0,
                                description: descriptionController.text,
                                category: cat,
                                date: selectedDateNotifier.value,
                                isExpense: isExpenseNotifier.value,
                                isShared: shared,
                                splitWith: (shared && !isBusinessGroup) ? splitWith : null,
                                targetGroupId: targetGroupId,
                                splitAmounts: splitAmounts,
                              );

                      if (success && mounted) {
                        Utils.showSuccessToast(
                          context,
                          title: isEdit
                              ? "Transaction Updated Successfully!"
                              : "Transaction Saved Successfully!",
                        );
                        Navigator.pop(context);
                      }
                    },
                    title: widget.editTransaction != null ? 'Update Transaction' : 'Save Transaction',
                  );
                },
              ),
            ),
          ),
          hs(24),
        ],
      ),
    );
  }

  Widget _buildCategoryListWidget(List<CategoryModel> categories) {
    return ValueListenableBuilder<CategoryModel?>(
      valueListenable: selectedCategoryNotifier,
      builder: (context, currentCategory, _) {
        return SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final isSelected = currentCategory?.id == category.id;
              return GestureDetector(
                onTap: () => selectedCategoryNotifier.value = category,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 90,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? category.color : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected
                            ? category.color.withOpacity(0.3)
                            : Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        category.icon,
                        color: isSelected ? Colors.white : category.color,
                        size: 28,
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          category.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}