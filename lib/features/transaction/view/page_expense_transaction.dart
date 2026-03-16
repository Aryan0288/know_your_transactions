import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:know_your_expenses/features/home/view_model/view_model_home.dart';
import 'package:know_your_expenses/features/login_signup/view/page_sign_in.dart';
import 'package:know_your_expenses/features/transaction/view/page_add_expenses.dart';
import 'package:know_your_expenses/features/transaction/view/page_profile_section.dart';
import 'package:know_your_expenses/features/transaction/view/page_show_all_expenses.dart';
import 'package:know_your_expenses/core/widgets/custom_dialogs.dart';
import 'package:know_your_expenses/features/transaction/view/page_financial_insights.dart';
import 'package:know_your_expenses/features/transaction/view/page_statistics.dart';
import 'package:know_your_expenses/features/transaction/view_model/view_model_transaction.dart';

class AddExpensePageHomePage extends ConsumerWidget {
  AddExpensePageHomePage({super.key});

  final pages = [
    const ShowAllExpensesPage(),
    StatisticsPage(),
    const SizedBox(),
    const FinancialInsightsPage(),
    const ProfileSectionPage(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Consumer(
        builder: (context, ref, child) {
          final currentIndex = ref.watch(bottomNavIndexProvider);
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, 0.05),
                    end: Offset.zero,
                  ).animate(animation),
                  child: ScaleTransition(
                    scale: Tween<double>(
                      begin: 0.98,
                      end: 1.0,
                    ).animate(animation),
                    child: child,
                  ),
                ),
              );
            },
            child: KeyedSubtree(
              key: ValueKey<int>(currentIndex),
              child: pages[currentIndex],
            ),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2E8B57),
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 30),
        onPressed: () async {
          final user = ref.read(firebaseAuthProvider).currentUser;

          if (user == null) {
            // Not logged in
            CustomDialogs.showSignInRequiredDialog(
              context,
              onSignInTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SignInPage()),
                );
              },
            );
          } else if (!user.emailVerified) {
            await user.reload(); // 🔴 VERY IMPORTANT
            final refreshedUser = FirebaseAuth.instance.currentUser;
            if (refreshedUser!.emailVerified) {
              CustomDialogs.showSignInRequiredDialog(
                context,
                onSignInTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => SignInPage()),
                  );
                },
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AddExpensePage()),
              );
            }
          } else {
            // Logged in + verified
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AddExpensePage()),
            );
          }
        },
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: Colors.white,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: const [
            _BottomNavItem(index: 0, icon: Icons.home),
            _BottomNavItem(index: 1, icon: Icons.bar_chart),
            SizedBox(width: 48),
            _BottomNavItem(index: 3, icon: Icons.wallet),
            _BottomNavItem(index: 4, icon: Icons.person),
          ],
        ),
      ),
    );
  }
}

class _BottomNavItem extends ConsumerWidget {
  final int index;
  final IconData icon;

  const _BottomNavItem({super.key, required this.index, required this.icon});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(bottomNavIndexProvider);
    final isSelected = currentIndex == index;
    final color = isSelected ? const Color(0xFF2E8B57) : Colors.grey;

    return Expanded(
      child: InkWell(
        onTap: () {
          ref.read(bottomNavIndexProvider.notifier).state = index;
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Icon(icon, color: color),
        ),
      ),
    );
  }
}

class DummyPage extends StatelessWidget {
  final String title;
  const DummyPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(
          'This is the $title page.',
          style: const TextStyle(fontSize: 24, color: Colors.grey),
        ),
      ),
    );
  }
}
