import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:know_your_expenses/features/common_widgets/common_widgets.dart';
import 'package:know_your_expenses/features/helper/utils.dart';
import 'package:know_your_expenses/features/transaction/model/model_transaction.dart';
import 'package:know_your_expenses/features/transaction/view_model/view_model_transaction.dart';

class AddExpensePage extends ConsumerStatefulWidget {
  const AddExpensePage({super.key});

  @override
  ConsumerState<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends ConsumerState<AddExpensePage> {
  CategoryModel? selectedCategory;
  final TextEditingController amountController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  DateTime selectedDate = DateTime.now();

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
                  Consumer(
                    builder: (context, ref, child) {
                      final categoriesAsync = ref.watch(categoriesProvider);
                      return categoriesAsync.when(
                        data: (categories) {
                          if (selectedCategory == null &&
                              categories.isNotEmpty) {
                            Future.microtask(
                              () => setState(
                                () => selectedCategory = categories.first,
                              ),
                            );
                          }
                          return SizedBox(
                            height: 100,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: categories.length,
                              itemBuilder: (context, index) {
                                final category = categories[index];
                                final isSelected =
                                    selectedCategory?.id == category.id;
                                return GestureDetector(
                                  onTap: () => setState(
                                    () => selectedCategory = category,
                                  ),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 90,
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? category.color
                                          : Colors.white,
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          category.icon,
                                          color: isSelected
                                              ? Colors.white
                                              : category.color,
                                          size: 28,
                                        ),
                                        const SizedBox(height: 8),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                          ),
                                          child: Text(
                                            category.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.manrope(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: isSelected
                                                  ? Colors.white
                                                  : Colors.black87,
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
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, stack) => Text('Error: $e'),
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
                  GestureDetector(
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
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
                      if (picked != null && picked != selectedDate) {
                        setState(() {
                          selectedDate = picked;
                        });
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
                            DateFormat('MMMM dd, yyyy').format(selectedDate),
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
                      if (selectedCategory == null) return;

                      final success = await ref
                          .read(transactionViewModelProvider.notifier)
                          .addTransaction(
                            amount: double.tryParse(amountController.text) ?? 0,
                            description: descriptionController.text,
                            category: selectedCategory!,
                            date: selectedDate,
                          );

                      if (success && mounted) {
                        Utils.showSuccessToast(
                          context,
                          title: "Expense Saved Successfully!",
                        );
                        Navigator.pop(context);
                      }
                    },
                    title: 'Save Expense',
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
}
