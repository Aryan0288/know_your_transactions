import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:know_your_expenses/features/home/view_model/view_model_home.dart';
import 'package:know_your_expenses/features/login_signup/view/page_sign_in.dart';
import 'package:know_your_expenses/features/transaction/view/page_add_expenses.dart';
import 'package:know_your_expenses/features/transaction/view/page_profile_section.dart';
import 'package:know_your_expenses/features/transaction/view/page_show_all_expenses.dart';
import 'package:know_your_expenses/core/widgets/custom_dialogs.dart';
import 'package:know_your_expenses/features/transaction/view/page_financial_insights.dart';
import 'package:know_your_expenses/features/transaction/view/page_statistics.dart';
import 'package:know_your_expenses/features/transaction/view_model/view_model_transaction.dart';

// ─── Colours ─────────────────────────────────────────────────────────────────
const _kGreen = Color(0xFF2E8B57);
const _kLightGreen = Color(0xFF3EAF78);
const _kDeepGreen = Color(0xFF1A5C3A);

// ─── Nav item descriptor ──────────────────────────────────────────────────────
class _NavItem {
  final int index;
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem({
    required this.index,
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

const _navItems = [
  _NavItem(
    index: 0,
    icon: Icons.home_outlined,
    activeIcon: Icons.home_rounded,
    label: 'Home',
  ),
  _NavItem(
    index: 1,
    icon: Icons.bar_chart_outlined,
    activeIcon: Icons.bar_chart_rounded,
    label: 'Stats',
  ),
  _NavItem(
    index: 3,
    icon: Icons.account_balance_wallet_outlined,
    activeIcon: Icons.account_balance_wallet_rounded,
    label: 'Insights',
  ),
  _NavItem(
    index: 4,
    icon: Icons.person_outline_rounded,
    activeIcon: Icons.person_rounded,
    label: 'Profile',
  ),
];

// ─── Main Shell ───────────────────────────────────────────────────────────────
class AddExpensePageHomePage extends ConsumerWidget {
  AddExpensePageHomePage({super.key});

  final pages = [
    const ShowAllExpensesPage(),
    StatisticsPage(),
    const SizedBox(),
    const FinancialInsightsPage(),
    const ProfileSectionPage(),
  ];

  Future<void> _onFabPressed(BuildContext context, WidgetRef ref) async {
    HapticFeedback.mediumImpact();
    final user = ref.read(firebaseAuthProvider).currentUser;

    if (user == null) {
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
      await user.reload();
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
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AddExpensePage()),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(bottomNavIndexProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF0FAF4),
      extendBody: true,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0.0, 0.04),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey<int>(currentIndex),
          child: pages[currentIndex],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _AnimatedFAB(
        onPressed: (context) => _onFabPressed(context, ref),
      ),
      bottomNavigationBar: _AwesomeBottomBar(
        currentIndex: currentIndex,
        onTap: (index) {
          HapticFeedback.selectionClick();
          ref.read(bottomNavIndexProvider.notifier).state = index;
        },
      ),
    );
  }
}

// ─── Animated FAB ─────────────────────────────────────────────────────────────
class _AnimatedFAB extends StatefulWidget {
  final void Function(BuildContext context) onPressed;

  const _AnimatedFAB({required this.onPressed});

  @override
  State<_AnimatedFAB> createState() => _AnimatedFABState();
}

class _AnimatedFABState extends State<_AnimatedFAB>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotateAnim;
  late Animation<double> _scaleAnim;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _rotateAnim = Tween<double>(
      begin: 0.0,
      end: 0.125,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.88), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 0.88, end: 1.1), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _controller.forward(from: 0);
    widget.onPressed(context);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) => Transform.scale(
        scale: _scaleAnim.value,
        child: Transform.rotate(
          angle: _rotateAnim.value * 3.14159 * 4,
          child: child,
        ),
      ),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          _handleTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_kLightGreen, _kGreen, _kDeepGreen],
            ),
            boxShadow: [
              BoxShadow(
                color: _kGreen.withOpacity(_isPressed ? 0.2 : 0.45),
                blurRadius: _isPressed ? 8 : 20,
                spreadRadius: _isPressed ? 0 : 2,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: _kLightGreen.withOpacity(0.2),
                blurRadius: 30,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
        ),
      ),
    );
  }
}

// ─── Awesome Bottom Bar ───────────────────────────────────────────────────────
class _AwesomeBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _AwesomeBottomBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.92),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: _kGreen.withOpacity(0.12), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: _kGreen.withOpacity(0.12),
                  blurRadius: 24,
                  offset: const Offset(0, -4),
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Left two items
                _NavTile(
                  item: _navItems[0],
                  isSelected: currentIndex == _navItems[0].index,
                  onTap: onTap,
                ),
                _NavTile(
                  item: _navItems[1],
                  isSelected: currentIndex == _navItems[1].index,
                  onTap: onTap,
                ),
                // Centre gap for FAB
                const SizedBox(width: 60),
                // Right two items
                _NavTile(
                  item: _navItems[2],
                  isSelected: currentIndex == _navItems[2].index,
                  onTap: onTap,
                ),
                _NavTile(
                  item: _navItems[3],
                  isSelected: currentIndex == _navItems[3].index,
                  onTap: onTap,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Single Nav Tile ──────────────────────────────────────────────────────────
class _NavTile extends StatefulWidget {
  final _NavItem item;
  final bool isSelected;
  final ValueChanged<int> onTap;

  const _NavTile({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bounceAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _bounceAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -6.0), weight: 35),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 2.0), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 2.0, end: 0.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.2), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 0.95), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(_NavTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onTap(widget.item.index),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, __) => Transform.translate(
            offset: Offset(0, _bounceAnim.value),
            child: Transform.scale(
              scale: _scaleAnim.value,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Pill container
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.symmetric(
                      horizontal: isSelected ? 16 : 8,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _kGreen.withOpacity(0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        isSelected ? widget.item.activeIcon : widget.item.icon,
                        key: ValueKey(isSelected),
                        size: 22,
                        color: isSelected ? _kGreen : Colors.grey.shade400,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  // Label
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 220),
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected ? _kGreen : Colors.grey.shade400,
                    ),
                    child: Text(widget.item.label),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
