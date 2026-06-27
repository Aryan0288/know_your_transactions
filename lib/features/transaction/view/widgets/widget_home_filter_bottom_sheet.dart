import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:know_your_expenses/features/home/view_model/view_model_group.dart';
import 'package:know_your_expenses/features/transaction/view_model/view_model_transaction.dart';

class HomeFilterBottomSheet extends ConsumerWidget {
  const HomeFilterBottomSheet({super.key});

  static const Color _kGreen = Color(0xFF2E8B57);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedFilter = ref.watch(selectedHomeGroupIdFilterProvider);
    final groupsAsync = ref.watch(userGroupsStreamProvider);

    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 32),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filter Space',
                style: GoogleFonts.manrope(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E232A),
                ),
              ),
              TextButton(
                onPressed: () {
                  ref.read(selectedHomeGroupIdFilterProvider.notifier).state = 'all';
                  Navigator.pop(context);
                },
                child: Text(
                  'Reset',
                  style: GoogleFonts.manrope(
                    color: _kGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 20),

          // Spaces Dropdown List
          Text(
            'Select Active Space',
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          groupsAsync.when(
            data: (groups) {
              final items = [
                _FilterItem(id: 'all', name: 'All Spaces'),
                _FilterItem(id: 'personal', name: 'Personal Space'),
                ...groups.map((g) => _FilterItem(id: g.id, name: g.name)),
              ];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F8F5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withOpacity(0.1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedFilter,
                    isExpanded: true,
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    icon: const Icon(Icons.arrow_drop_down_rounded, color: _kGreen),
                    items: items.map((item) {
                      return DropdownMenuItem<String>(
                        value: item.id,
                        child: Text(
                          item.name,
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: const Color(0xFF1E2D2C),
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        ref.read(selectedHomeGroupIdFilterProvider.notifier).state = val;
                      }
                    },
                  ),
                ),
              );
            },
            loading: () => const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: _kGreen),
              ),
            ),
            error: (e, s) => const SizedBox(),
          ),
          const SizedBox(height: 32),

          // Apply Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
              ),
              child: Text(
                'Apply Filter',
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterItem {
  final String id;
  final String name;
  _FilterItem({required this.id, required this.name});
}
