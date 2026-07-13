import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:know_your_expenses/features/transaction/view_model/view_model_transaction.dart';

class CreateGroupBottomSheet extends ConsumerWidget {
  final VoidCallback onCreate;
  final TextEditingController controller;

  const CreateGroupBottomSheet({
    super.key,
    required this.onCreate,
    required this.controller,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = ref.watch(selectedGroupTypeProvider);

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
          const SizedBox(height: 20),
          Text(
            'Create a Group',
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E232A),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            style: GoogleFonts.manrope(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Enter Group Name (e.g. Roommates)',
              hintStyle: GoogleFonts.manrope(color: Colors.grey, fontSize: 14),
              filled: true,
              fillColor: const Color(0xFFF3F8F5),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Group Type',
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E232A),
            ),
          ),
          const SizedBox(height: 8),
          Material(
            color: Colors.transparent,
            child: RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              title: Text('Split Expense Group', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text('Equally or custom split bills among members.', style: GoogleFonts.manrope(fontSize: 11, color: Colors.grey[600])),
              value: 'split',
              groupValue: type,
              activeColor: const Color(0xFF2E8B57),
              onChanged: (val) {
                if (val != null) {
                  ref.read(selectedGroupTypeProvider.notifier).state = val;
                }
              },
            ),
          ),
          Material(
            color: Colors.transparent,
            child: RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              title: Text('Business Expense Group', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text('Only Admin can edit/delete. Members only see transactions.', style: GoogleFonts.manrope(fontSize: 11, color: Colors.grey[600])),
              value: 'business',
              groupValue: type,
              activeColor: const Color(0xFF2E8B57),
              onChanged: (val) {
                if (val != null) {
                  ref.read(selectedGroupTypeProvider.notifier).state = val;
                }
              },
            ),
          ),
          Material(
            color: Colors.transparent,
            child: RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              title: Text('Wages / Salary Group', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text('Admins record salary payments. Members only see their own wages.', style: GoogleFonts.manrope(fontSize: 11, color: Colors.grey[600])),
              value: 'wages',
              groupValue: type,
              activeColor: const Color(0xFF2E8B57),
              onChanged: (val) {
                if (val != null) {
                  ref.read(selectedGroupTypeProvider.notifier).state = val;
                }
              },
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                onCreate();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E8B57),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
              ),
              child: Text(
                'Create Group',
                style: GoogleFonts.manrope(
                  fontSize: 14,
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
