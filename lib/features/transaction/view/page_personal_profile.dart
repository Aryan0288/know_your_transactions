import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:know_your_expenses/features/login_signup/view/page_sign_in.dart';
import 'package:know_your_expenses/features/transaction/view_model/view_model_transaction.dart';
import 'package:know_your_expenses/core/widgets/custom_dialogs.dart';

import 'package:know_your_expenses/features/home/view_model/view_model_home.dart';

class PersonalProfilePage extends ConsumerStatefulWidget {
  const PersonalProfilePage({super.key});

  @override
  ConsumerState<PersonalProfilePage> createState() => _PersonalProfilePageState();
}

class _PersonalProfilePageState extends ConsumerState<PersonalProfilePage> {
  bool _initialized = false;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userDataAsync = ref.watch(userDataProvider);
    final user = ref.watch(firebaseAuthProvider).currentUser;

    final isLoggedOut = userDataAsync.value == null || user == null;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F8),
      appBar: isLoggedOut
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1A2332)),
                onPressed: () => Navigator.pop(context),
              ),
            )
          : null,
      body: userDataAsync.when(
        data: (userData) {
          if (userData == null || user == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E8B57).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      size: 40,
                      color: Color(0xFF2E8B57),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'You\'re not signed in',
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A2332),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to view your profile',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => SignInPage()),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E8B57),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Sign In',
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          final userName = userData['name'] ?? 'Guest User';
          final userEmail = userData['email'] ?? 'No email';
          final userPhone = userData['phone'] ?? 'No phone number';
          final photoUrl = userData['photoUrl'];

          if (!_initialized) {
            _nameController.text = userName;
            _phoneController.text = userPhone == 'No phone number' ? '' : userPhone;
            _initialized = true;
          }
          final isEditing = ref.watch(profileEditModeProvider);

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 260,
                floating: false,
                pinned: true,
                backgroundColor: const Color(0xFF2E7D79),
                iconTheme: const IconThemeData(color: Colors.white),
                title: Text(
                  'Personal Profile',
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                actions: [
                  if (isEditing)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      tooltip: 'Cancel',
                      onPressed: () {
                        ref.read(profileEditModeProvider.notifier).state = false;
                        _nameController.text = userName;
                        _phoneController.text = userPhone == 'No phone number' ? '' : userPhone;
                      },
                    ),
                  IconButton(
                    icon: Icon(isEditing ? Icons.check_rounded : Icons.edit_rounded, color: Colors.white),
                    tooltip: isEditing ? 'Save Changes' : 'Edit Profile',
                    onPressed: () async {
                      if (isEditing) {
                        final nameInput = _nameController.text.trim();
                        final phoneInput = _phoneController.text.trim();
                        if (nameInput.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Name cannot be empty')),
                          );
                          return;
                        }
                        CustomDialogs.showLoadingDialog(context, "Saving Profile...");
                        final success = await ref
                            .read(transactionViewModelProvider.notifier)
                            .updatePersonalDetails(name: nameInput, phone: phoneInput);
                        if (mounted) {
                          Navigator.pop(context); // Dismiss loading dialog
                          if (success) {
                            ref.read(profileEditModeProvider.notifier).state = false;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Profile updated successfully!')),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Failed to update profile.')),
                            );
                          }
                        }
                      } else {
                        ref.read(profileEditModeProvider.notifier).state = true;
                      }
                    },
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.parallax,
                  background: _ProfileHeader(
                    userName: userName,
                    userEmail: userEmail,
                    photoUrl: photoUrl,
                    onCameraTap: () async {
                      CustomDialogs.showLoadingDialog(context, "Updating Image...");
                      final success = await ref
                          .read(transactionViewModelProvider.notifier)
                          .updateProfileImage();
                      if (mounted) {
                        Navigator.pop(context);
                        if (!success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Failed to update image.')),
                          );
                        }
                      }
                    },
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel('Profile Details'),
                      const SizedBox(height: 12),
                      _buildInfoCard([
                        isEditing
                            ? _buildEditProfileRow('Full Name', _nameController, Icons.person_outline)
                            : _buildProfileRow('Full Name', userName, Icons.person_outline),
                        _buildDivider(),
                        _buildProfileRow('Email Address', userEmail, Icons.email_outlined),
                        _buildDivider(),
                        isEditing
                            ? _buildEditProfileRow('Phone Number', _phoneController, Icons.phone_outlined, keyboardType: TextInputType.phone)
                            : _buildProfileRow('Phone Number', userPhone.isEmpty ? 'No phone number' : userPhone, Icons.phone_outlined),
                      ]),
                      const SizedBox(height: 28),
                      _sectionLabel('Account'),
                      const SizedBox(height: 12),
                      _buildInfoCard([
                        _buildProfileRow('Member Since', _formatDate(user.metadata.creationTime), Icons.calendar_today_outlined),
                      ]),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF429690))),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Unknown';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  Widget _sectionLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: GoogleFonts.manrope(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF9BA5B4),
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.only(left: 72),
      child: Divider(height: 1, color: Color(0xFFF0F0F0)),
    );
  }

  Widget _buildEditProfileRow(String label, TextEditingController controller, IconData icon, {TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF56C1BB), Color(0xFF2E7D79)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    color: const Color(0xFF9BA5B4),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 3),
                TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    color: const Color(0xFF1A2332),
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 4),
                    border: InputBorder.none,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF56C1BB), Color(0xFF2E7D79)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    color: const Color(0xFF9BA5B4),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    color: const Color(0xFF1A2332),
                    fontWeight: FontWeight.w600,
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

class _ProfileHeader extends StatelessWidget {
  final String userName;
  final String userEmail;
  final String? photoUrl;
  final VoidCallback onCameraTap;

  const _ProfileHeader({
    required this.userName,
    required this.userEmail,
    required this.photoUrl,
    required this.onCameraTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4DBDB7), Color(0xFF1F6461)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            left: -30,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Positioned(
            top: 80,
            left: 30,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 16),
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Colors.white, Color(0xFFB2DFDB)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 24,
                              spreadRadius: 2,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 52,
                          backgroundColor: const Color(0xFFE0F2F1),
                          child: photoUrl != null
                              ? ClipOval(
                                  child: Image.network(
                                    photoUrl!,
                                    width: 104,
                                    height: 104,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : const Icon(Icons.person_rounded, size: 52, color: Color(0xFF429690)),
                        ),
                      ),
                      GestureDetector(
                        onTap: onCameraTap,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF2E7D79), size: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    userName,
                    style: GoogleFonts.manrope(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    userEmail,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.75),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
