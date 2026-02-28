import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:know_your_expenses/core/widgets/custom_dialogs.dart';
import 'package:know_your_expenses/features/common_widgets/common_widgets_scaffold.dart';
import 'package:know_your_expenses/features/home/view_model/view_model_home.dart';
import 'package:know_your_expenses/features/login_signup/view_model/view_model_login_signup.dart';
import 'package:know_your_expenses/features/transaction/view/page_show_all_expenses.dart';
import 'package:know_your_expenses/features/transaction/view_model/view_model_transaction.dart';
import 'package:know_your_expenses/features/home/view/page_home.dart';
import 'package:know_your_expenses/features/login_signup/view/page_sign_in.dart';

class ProfileSectionPage extends ConsumerWidget {
  const ProfileSectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CommonScaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Curved Header
                Container(
                  height: 240,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF429690), Color(0xFF2E7D79)],
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.elliptical(200, 50),
                      bottomRight: Radius.elliptical(200, 50),
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          IconButton(
                            onPressed: () {
                              ref.watch(bottomNavIndexProvider.notifier).state = 0;
                            },
                            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                          ),
                          Text(
                            'Profile',
                            style: GoogleFonts.manrope(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Stack(
                              children: [
                                const Icon(
                                  Icons.notifications_none_rounded,
                                  color: Colors.white,
                                ),
                                Positioned(
                                  right: 2,
                                  top: 2,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFFF9900),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Profile Image overlapping
                Positioned(
                  bottom: -60,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: const NetworkImage(
                        'https://api.dicebear.com/7.x/avataaars/png?seed=Enjelin',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 70),
            // User Name and Handle
            Consumer(
              builder: (context,ref,child) {
                final userData = ref.watch(userDataProvider).value;
                final userName = userData?['name'] ?? 'Guest User';
                return Text(
                  userName,
                  style: GoogleFonts.manrope(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E1E1E),
                  ),
                );
              }
            ),
            const SizedBox(height: 4),
            Consumer(
              builder: (context,ref,child) {
                final userData = ref.read(userDataProvider).value;
                final userEmail = userData?['email'] ?? "Sign in to sync your data";
                return Text(
                  userEmail,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    color: const Color(0xFF429690),
                    fontWeight: FontWeight.w600,
                  ),
                );
              }
            ),
            const SizedBox(height: 32),
            // Profile Menu Items
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  _ProfileMenuItem(
                    icon: Icons.diamond_outlined,
                    title: 'Invite Friends',
                    iconColor: const Color(0xFF429690),
                    backgroundColor: const Color(0xFFE6F3F2),
                    onTap: () {},
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 60),
                    child: Divider(height: 32, thickness: 1, color: Color(0xFFF0F0F0)),
                  ),
                  _ProfileMenuItem(
                    icon: Icons.person_outline,
                    title: 'Account info',
                    onTap: () {},
                  ),
                  _ProfileMenuItem(
                    icon: Icons.people_outline,
                    title: 'Personal profile',
                    onTap: () {},
                  ),
                  _ProfileMenuItem(
                    icon: Icons.lock_outline,
                    title: 'Data and privacy',
                    onTap: () {},
                  ),
                    Consumer(
                      builder: (context,ref,child) {
                        final user = ref.read(firebaseAuthProvider).currentUser;
                        if(user!=null){
                          return _ProfileMenuItem(
                            icon: Icons.logout_rounded,
                            title: 'Logout',
                            iconColor: const Color(0xFFE57373),
                            backgroundColor: const Color(0xFFFFEBEE),
                            onTap: () {
                              CustomDialogs.showLogoutDialog(
                                context,
                                onConfirm: () async {
                                  await ref.read(authControllerProvider.notifier).signOut();
                                  if (context.mounted) {
                                    Navigator.pushAndRemoveUntil(
                                      context,
                                      MaterialPageRoute(builder: (context) => const HomePage()),
                                          (route) => false,
                                    );
                                  }
                                },
                              );
                            },
                          );
                        } else {
                          return _ProfileMenuItem(
                            icon: Icons.login_rounded,
                            title: 'Sign In',
                            iconColor: const Color(0xFF429690),
                            backgroundColor: const Color(0xFFE6F3F2),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => SignInPage()),
                              );
                            },
                          );
                        }
                      }
                    )

                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? iconColor;
  final Color? backgroundColor;
  final VoidCallback onTap;

  const _ProfileMenuItem({
    required this.icon,
    required this.title,
    this.iconColor,
    this.backgroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: backgroundColor ?? Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor ?? const Color(0xFF666666), size: 24),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E1E1E),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
