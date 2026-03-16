import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:know_your_expenses/features/transaction/view_model/view_model_transaction.dart';
import 'package:know_your_expenses/core/widgets/custom_dialogs.dart';
import 'package:cloudinary_flutter/cloudinary_context.dart';
import 'package:cloudinary_flutter/image/cld_image.dart';
import 'package:cloudinary_url_gen/transformation/transformation.dart';
import 'package:cloudinary_url_gen/transformation/resize/resize.dart';
import 'package:cloudinary_url_gen/transformation/effect/effect.dart';

import 'package:know_your_expenses/features/home/view_model/view_model_home.dart';

class PersonalProfilePage extends ConsumerWidget {
  const PersonalProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userDataAsync = ref.watch(userDataProvider);
    final user = ref.watch(firebaseAuthProvider).currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Personal Profile',
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E1E1E),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1E1E1E)),
      ),
      body: userDataAsync.when(
        data: (userData) {
          if (userData == null || user == null) {
            return const Center(
              child: Text("Please sign in to view your profile"),
            );
          }
          final userName = userData['name'] ?? 'Guest User';
          final userEmail = userData['email'] ?? 'No email';
          final userPhone = userData['phone'] ?? 'No phone number';
          final photoUrl = userData['photoUrl'];
          
          // Since we hardcoded the upload public_id as 'profile_${user.uid}'
          // We can just construct it here if the user has a photoUrl
          // final String? publicId = photoUrl != null ? 'profile_${user.uid}' : null;

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.grey[200],
                          child: photoUrl != null
                              ? ClipOval(
                                  child: Image.network(photoUrl),
                                )
                              : const Icon(
                                  Icons.person,
                                  size: 50,
                                  color: Colors.grey,
                                ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () async {
                          CustomDialogs.showLoadingDialog(
                            context,
                            "Updating Image...",
                          );
                          final success = await ref
                              .read(transactionViewModelProvider.notifier)
                              .updateProfileImage();
                          if (context.mounted) {
                            Navigator.pop(context); // loading dialog
                            if (!success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Failed to update image.'),
                                ),
                              );
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFF429690),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  _buildProfileField('Name', userName, Icons.person_outline),
                  _buildProfileField('Email', userEmail, Icons.email_outlined),
                  _buildProfileField(
                    'Phone Number',
                    userPhone,
                    Icons.phone_outlined,
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF429690)),
        ),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildProfileField(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 14,
              color: const Color(0xFF666666),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF0F0F0)),
            ),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFF429690), size: 22),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    value,
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      color: const Color(0xFF1E1E1E),
                      fontWeight: FontWeight.w600,
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
