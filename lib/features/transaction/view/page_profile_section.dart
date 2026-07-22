import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:know_your_expenses/core/widgets/custom_dialogs.dart';
import 'package:know_your_expenses/features/common_widgets/common_widgets_scaffold.dart';
import 'package:know_your_expenses/features/home/view_model/view_model_home.dart';
import 'package:know_your_expenses/features/login_signup/view_model/view_model_login_signup.dart';
import 'package:know_your_expenses/features/transaction/view_model/view_model_transaction.dart';
import 'package:know_your_expenses/features/home/view/page_home.dart';
import 'package:know_your_expenses/features/login_signup/view/page_sign_in.dart';
import 'package:know_your_expenses/features/transaction/view/page_personal_profile.dart';
import 'package:know_your_expenses/features/transaction/view/page_group_settings.dart';
import 'package:know_your_expenses/features/transaction/view/widgets/widget_export_bottom_sheet.dart';
import 'package:know_your_expenses/features/transaction/view/page_split_ledger.dart';
import 'package:know_your_expenses/features/transaction/view/page_app_lock_settings.dart';
import 'package:know_your_expenses/features/auto_sms/view/page_sms_settings.dart';

class ProfileSectionPage extends ConsumerWidget {
  const ProfileSectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CommonScaffold(
      backgroundColor: const Color(0xFFF2F5F8),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _ProfileHeroSection(ref: ref),
            const SizedBox(height: 80),
            Consumer(
              builder: (context, ref, child) {
                final userData = ref.watch(userDataProvider).value;
                final userName = userData?['name'] ?? 'Guest User';
                return Column(
                  children: [
                    Text(
                      userName,
                      style: GoogleFonts.manrope(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A2332),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Consumer(
                      builder: (context, ref, child) {
                        final userData = ref.read(userDataProvider).value;
                        final userEmail = userData?['email'] ?? "Sign in to sync your data";
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF429690).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            userEmail,
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              color: const Color(0xFF2E7D79),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('Account'),
                  const SizedBox(height: 12),
                  Consumer(
                    builder: (context, ref, child) {
                      final hasGroup = ref.watch(userGroupIdProvider) != null;
                      return _MenuCard(
                        items: [
                          _MenuItemData(
                            icon: Icons.person_outline_rounded,
                            title: 'Personal Profile',
                            subtitle: 'View and edit your details',
                            iconColor: const Color(0xFF429690),
                            iconBg: const Color(0xFFE6F7F6),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const PersonalProfilePage()),
                            ),
                          ),
                          _MenuItemData(
                            icon: Icons.group_outlined,
                            title: 'Group Settings',
                            subtitle: 'Manage your shared ledger and members',
                            iconColor: const Color(0xFF429690),
                            iconBg: const Color(0xFFE6F7F6),
                            onTap: () {
                              final user = ref.read(firebaseAuthProvider).currentUser;
                              if (user == null) {
                                CustomDialogs.showSignInRequiredDialog(
                                  context,
                                  onSignInTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => SignInPage()),
                                    );
                                  },
                                );
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const GroupSettingsPage()),
                                );
                              }
                            },
                          ),
                          if (hasGroup)
                            _MenuItemData(
                              icon: Icons.receipt_long_outlined,
                              title: 'Split Ledger',
                              subtitle: 'View shared bills and who owes what',
                              iconColor: const Color(0xFF429690),
                              iconBg: const Color(0xFFE6F7F6),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const SplitLedgerPage()),
                                );
                              },
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _sectionLabel('Reports & Statements'),
                  const SizedBox(height: 12),
                  _MenuCard(
                    items: [
                      _MenuItemData(
                        icon: Icons.picture_as_pdf_rounded,
                        title: 'Export Statements',
                        subtitle: 'Download PDF or CSV reports of your activity',
                        iconColor: const Color(0xFF429690),
                        iconBg: const Color(0xFFE6F7F6),
                        onTap: () {
                          final user = ref.read(firebaseAuthProvider).currentUser;
                          if (user == null) {
                            CustomDialogs.showSignInRequiredDialog(
                              context,
                              onSignInTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => SignInPage()),
                                );
                              },
                            );
                          } else {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => const ExportBottomSheet(),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _sectionLabel('Security'),
                  const SizedBox(height: 12),
                  _MenuCard(
                    items: [
                      _MenuItemData(
                        icon: Icons.lock_outline_rounded,
                        title: 'App Lock',
                        subtitle: 'Protect your expenses with a 4-digit PIN',
                        iconColor: const Color(0xFF429690),
                        iconBg: const Color(0xFFE6F7F6),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AppLockSettingsPage()),
                          );
                        },
                      ),
                      _MenuItemData(
                        icon: Icons.mark_email_read_rounded,
                        title: 'Auto SMS Expenses',
                        subtitle: 'Automatically detect bank debit & credit SMS',
                        iconColor: const Color(0xFF429690),
                        iconBg: const Color(0xFFE6F7F6),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const PageSmsSettings()),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _sectionLabel('Session'),
                  const SizedBox(height: 12),
                  Consumer(
                    builder: (context, ref, child) {
                      final user = ref.read(firebaseAuthProvider).currentUser;
                      if (user != null) {
                        return _MenuCard(
                          items: [
                            _MenuItemData(
                              icon: Icons.logout_rounded,
                              title: 'Logout',
                              subtitle: 'Sign out of your account',
                              iconColor: const Color(0xFFE57373),
                              iconBg: const Color(0xFFFFEBEE),
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
                            ),
                          ],
                        );
                      } else {
                        return _MenuCard(
                          items: [
                            _MenuItemData(
                              icon: Icons.login_rounded,
                              title: 'Sign In',
                              subtitle: 'Connect to sync your data',
                              iconColor: const Color(0xFF429690),
                              iconBg: const Color(0xFFE6F3F2),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => SignInPage()),
                              ),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 40),
                  Center(
                    child: Text(
                      'Know Your Expenses',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: const Color(0xFFBBC5D0),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
}

class _ProfileHeroSection extends StatelessWidget {
  final WidgetRef ref;

  const _ProfileHeroSection({required this.ref});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Container(
          height: 220,
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF4DBDB7), Color(0xFF1F6461)],
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.elliptical(240, 60),
              bottomRight: Radius.elliptical(240, 60),
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -60,
                right: -40,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.07),
                  ),
                ),
              ),
              Positioned(
                bottom: -20,
                left: -50,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HeaderIconButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () {
                          ref.watch(bottomNavIndexProvider.notifier).state = 0;
                        },
                      ),
                      Text(
                        'Profile',
                        style: GoogleFonts.manrope(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Stack(
                        children: [
                          _HeaderIconButton(
                            icon: Icons.notifications_none_rounded,
                            onTap: () {},
                          ),
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFF9900),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: -68,
          child: Consumer(
            builder: (context, ref, child) {
              final userData = ref.watch(userDataProvider).value;
              final photoUrl = userData?['photoUrl'];
              return Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Colors.white, Color(0xFFB2DFDB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF429690).withOpacity(0.25),
                      blurRadius: 24,
                      spreadRadius: 4,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 56,
                  backgroundColor: const Color(0xFFE0F2F1),
                  child: photoUrl != null
                      ? ClipOval(
                          child: Image.network(
                            photoUrl,
                            width: 112,
                            height: 112,
                            fit: BoxFit.cover,
                          ),
                        )
                      : const Icon(Icons.person_rounded, size: 52, color: Color(0xFF429690)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _MenuItemData {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final Color iconBg;
  final VoidCallback onTap;

  const _MenuItemData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.iconBg,
    required this.onTap,
  });
}

class _MenuCard extends StatelessWidget {
  final List<_MenuItemData> items;

  const _MenuCard({required this.items});

  @override
  Widget build(BuildContext context) {
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
      child: Column(
        children: List.generate(items.length, (index) {
          final item = items[index];
          return Column(
            children: [
              _ProfileMenuItem(item: item),
              if (index < items.length - 1)
                const Padding(
                  padding: EdgeInsets.only(left: 76),
                  child: Divider(height: 1, color: Color(0xFFF0F0F0)),
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  final _MenuItemData item;

  const _ProfileMenuItem({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: item.iconBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(item.icon, color: item.iconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A2332),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: const Color(0xFF9BA5B4),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F5F8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.chevron_right_rounded, color: Color(0xFF9BA5B4), size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
