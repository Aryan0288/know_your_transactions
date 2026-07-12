import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:know_your_expenses/features/common_widgets/common_widgets_scaffold.dart';
import 'package:know_your_expenses/features/helper/utils.dart';
import 'package:know_your_expenses/features/helper/pdf_helper.dart';
import 'package:know_your_expenses/features/home/model/group_model.dart';
import 'package:know_your_expenses/features/transaction/view/widgets/widget_export_bottom_sheet.dart';
import 'package:know_your_expenses/features/home/view_model/view_model_home.dart';
import 'package:know_your_expenses/features/transaction/view_model/view_model_transaction.dart';
import 'package:know_your_expenses/features/transaction/model/model_transaction.dart';
import 'package:know_your_expenses/features/transaction/view/page_split_ledger.dart';
import 'package:know_your_expenses/features/transaction/view/dialog_transaction_detail.dart';
import 'package:know_your_expenses/features/home/view_model/view_model_group.dart';
import 'package:know_your_expenses/features/common_widgets/closable_banner_ad.dart';
import 'package:know_your_expenses/features/transaction/view/widgets/widget_home_filter_bottom_sheet.dart';

// ─── Constants ─────────────────────────────────────────────────────────────
const _kGreen = Color(0xFF429690);
const _kDeepGreen = Color(0xFF1A5C5A);

class ShowAllExpensesPage extends ConsumerStatefulWidget {
  const ShowAllExpensesPage({super.key});

  @override
  ConsumerState<ShowAllExpensesPage> createState() =>
      _ShowAllExpensesPageState();
}

class _ShowAllExpensesPageState extends ConsumerState<ShowAllExpensesPage>
    with TickerProviderStateMixin {
  late AnimationController _headerController;
  late AnimationController _contentController;

  late Animation<Offset> _greetingSlide;
  late Animation<double> _greetingOpacity;
  late Animation<Offset> _cardSlide;
  late Animation<double> _cardOpacity;
  late Animation<double> _contentOpacity;

  @override
  void initState() {
    super.initState();

    _headerController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );

    _contentController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    _greetingSlide =
        Tween<Offset>(begin: const Offset(0, -0.4), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _headerController,
            curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
          ),
        );

    _greetingOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _headerController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _cardSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _headerController,
            curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
          ),
        );

    _cardOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _headerController,
        curve: const Interval(0.4, 0.9, curve: Curves.easeIn),
      ),
    );

    _contentOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeIn),
    );

    _headerController.forward().then((_) {
      _contentController.forward();
    });
  }

  @override
  void dispose() {
    _headerController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      bottomNavigationBar: const ClosableBannerAd(),
      body: Column(
        children: [
          // ─── Fixed Header ────────────────────────────────────────────────
          _AnimatedHeader(
            greetingSlide: _greetingSlide,
            greetingOpacity: _greetingOpacity,
            cardSlide: _cardSlide,
            cardOpacity: _cardOpacity,
            greeting: _getGreeting(),
          ),

          const SizedBox(height: 12),

          // ─── Transaction List ─────────────────────────────────────────────
          Expanded(
            child: FadeTransition(
              opacity: _contentOpacity,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // Shake Onboarding Hint
                  const SliverToBoxAdapter(
                    child: _ShakeOnboardingCard(),
                  ),
                  // Section header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Transactions',
                                style: GoogleFonts.manrope(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF1E2D2C),
                                ),
                              ),
                              Text(
                                'History',
                                style: GoogleFonts.manrope(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: _kGreen,
                                  height: 1.0,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Consumer(
                                builder: (context, ref, _) {
                                  final transactions = ref.watch(homeFilteredTransactionsStreamProvider).value ?? [];
                                  final typeFilter = ref.watch(homeTransactionTypeFilterProvider);
                                  final user = ref.watch(firebaseAuthProvider).currentUser;
                                  final currentUserId = user?.uid;
                                  final groups = ref.watch(userGroupsStreamProvider).value ?? [];

                                  final count = transactions.where((t) {
                                    if (typeFilter == 'all') return true;

                                    bool isExpenseForUser = t.isExpense;
                                    if (t.groupId != null && currentUserId != null) {
                                      final group = groups.where((g) => g.id == t.groupId).firstOrNull;
                                       if (group != null && group.toMap()['type'] == 'wages' &&
                                          (t.splitWith?.contains(currentUserId) ?? false)) {
                                        isExpenseForUser = false;
                                      }
                                    }

                                    if (typeFilter == 'expense') {
                                      return isExpenseForUser;
                                    } else {
                                      return !isExpenseForUser;
                                    }
                                  }).length;

                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _kGreen.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '$count total',
                                      style: GoogleFonts.manrope(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: _kGreen,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 14),
                              Consumer(
                                builder: (context, ref, _) {
                                  return GestureDetector(
                                    onTap: () {
                                      final selectedFilter = ref.read(selectedHomeGroupIdFilterProvider);
                                      showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        backgroundColor: Colors.transparent,
                                        builder: (_) => ExportBottomSheet(
                                          initialGroupId: selectedFilter,
                                        ),
                                      );
                                    },
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.picture_as_pdf_rounded,
                                          color: _kGreen,
                                          size: 24,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Export',
                                          style: GoogleFonts.manrope(
                                            fontSize: 10,
                                            color: _kGreen,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 14),
                              Consumer(
                                builder: (context, ref, _) {
                                  final selectedFilter = ref.watch(selectedHomeGroupIdFilterProvider);
                                  return GestureDetector(
                                    onTap: () => _showHomeFilterBottomSheet(context),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            const Icon(
                                              Icons.filter_list_rounded,
                                              color: _kGreen,
                                              size: 24,
                                            ),
                                            if (selectedFilter != 'all')
                                              Positioned(
                                                right: -2,
                                                top: -2,
                                                child: Container(
                                                  width: 8,
                                                  height: 8,
                                                  decoration: const BoxDecoration(
                                                    color: Colors.amber,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Apply',
                                          style: GoogleFonts.manrope(
                                            fontSize: 10,
                                            color: _kGreen,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Horizontal type filter chips (All / Expenses / Income)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: Consumer(
                        builder: (context, ref, _) {
                          final activeFilter = ref.watch(homeTransactionTypeFilterProvider);
                          Widget buildChip(String label, String value, IconData icon, Color activeColor) {
                            final isSelected = activeFilter == value;
                            return GestureDetector(
                              onTap: () => ref.read(homeTransactionTypeFilterProvider.notifier).state = value,
                              child: Container(
                                margin: const EdgeInsets.only(right: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected ? activeColor.withOpacity(0.12) : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected ? activeColor : Colors.grey[200]!,
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    if (isSelected)
                                      BoxShadow(
                                        color: activeColor.withOpacity(0.1),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      )
                                    else
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.02),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      icon,
                                      size: 16,
                                      color: isSelected ? activeColor : Colors.grey[600],
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      label,
                                      style: GoogleFonts.manrope(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected ? activeColor : Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children: [
                                buildChip('All', 'all', Icons.receipt_long_rounded, _kGreen),
                                buildChip('Expenses', 'expense', Icons.arrow_upward_rounded, Colors.redAccent),
                                buildChip('Income', 'income', Icons.arrow_downward_rounded, Colors.green),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // Transaction items
                  Consumer(
                    builder: (context, ref, child) {
                      final transactionsAsync = ref.watch(
                        homeFilteredTransactionsStreamProvider,
                      );
                      return transactionsAsync.when(
                        data: (transactions) {
                          final user = ref
                              .watch(firebaseAuthProvider)
                              .currentUser;
                          if (user == null) {
                            return const SliverFillRemaining(
                              hasScrollBody: false,
                              child: _EmptyState(
                                icon: Icons.lock_outline_rounded,
                                title: 'Sign in Required',
                                subtitle: 'Sign in to view your transactions',
                              ),
                            );
                          }

                          // Filter by transaction type
                          final typeFilter = ref.watch(homeTransactionTypeFilterProvider);
                          final currentUserId = user.uid;
                          final groups = ref.watch(userGroupsStreamProvider).value ?? [];

                          final displayTransactions = transactions.where((t) {
                            if (typeFilter == 'all') return true;

                            // Determine if this is an expense or income for the user
                            bool isExpenseForUser = t.isExpense;
                            if (t.groupId != null) {
                              final group = groups.where((g) => g.id == t.groupId).firstOrNull;
                               if (group != null && group.toMap()['type'] == 'wages' &&
                                  (t.splitWith?.contains(currentUserId) ?? false)) {
                                isExpenseForUser = false;
                              }
                            }

                            if (typeFilter == 'expense') {
                              return isExpenseForUser;
                            } else {
                              return !isExpenseForUser;
                            }
                          }).toList();

                          if (displayTransactions.isEmpty) {
                            return const SliverFillRemaining(
                              hasScrollBody: false,
                              child: _EmptyState(
                                icon: Icons.receipt_long_rounded,
                                title: 'No Transactions Found',
                                subtitle: 'No transactions match the selected filter',
                              ),
                            );
                          }

                          // Group transactions by date
                          final List<_HistoryItem> items = [];
                          String? lastDateStr;

                          for (int i = 0; i < displayTransactions.length; i++) {
                            final tx = displayTransactions[i];
                            final dateStr = _formatHeaderDate(tx.date);
                            if (dateStr != lastDateStr) {
                              items.add(_DateHeaderItem(dateStr));
                              lastDateStr = dateStr;
                            }
                            items.add(_TransactionTileItem(tx, i));
                          }

                          return SliverList(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final item = items[index];
                              if (item is _DateHeaderItem) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                                      child: Text(
                                        item.dateText,
                                        style: GoogleFonts.manrope(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF667C7A),
                                        ),
                                      ),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 24),
                                      child: Divider(
                                        color: Color(0xFFE2E8F0),
                                        height: 1,
                                        thickness: 1,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                );
                              } else if (item is _TransactionTileItem) {
                                return _AnimatedTransactionTile(
                                  transaction: item.transaction,
                                  index: item.index,
                                  key: ValueKey(item.transaction.id),
                                );
                              }
                              return const SizedBox.shrink();
                            }, childCount: items.length),
                          );
                        },
                        loading: () => const SliverFillRemaining(
                          hasScrollBody: false,
                          child: _LoadingShimmer(),
                        ),
                        error: (e, r) => SliverToBoxAdapter(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Text(
                                'Error: $e',
                                style: GoogleFonts.manrope(color: Colors.red),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 110)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Animated Header ─────────────────────────────────────────────────────────
class _AnimatedHeader extends ConsumerWidget {
  final Animation<Offset> greetingSlide;
  final Animation<double> greetingOpacity;
  final Animation<Offset> cardSlide;
  final Animation<double> cardOpacity;
  final String greeting;
  const _AnimatedHeader({
    required this.greetingSlide,
    required this.greetingOpacity,
    required this.cardSlide,
    required this.cardOpacity,
    required this.greeting,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        // ── Background gradient container ──
        ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(48),
            bottomRight: Radius.circular(48),
          ),
          child: Container(
            height: 295,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_kDeepGreen, _kGreen, Color(0xFF52B8B3)],
              ),
            ),
            child: Stack(
              children: [
                // decorative blobs
                Positioned(
                  top: -40,
                  left: -40,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.06),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 30,
                  right: -30,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.05),
                    ),
                  ),
                ),
                Positioned(
                  top: 20,
                  right: 60,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.08),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Content ──
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Greeting row
                SlideTransition(
                  position: greetingSlide,
                  child: FadeTransition(
                    opacity: greetingOpacity,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              greeting,
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Consumer(
                              builder: (context, ref, child) {
                                final user = ref
                                    .watch(firebaseAuthProvider)
                                    .currentUser;
                                user?.reload();
                                final userData = ref
                                    .watch(userDataProvider)
                                    .value;
                                final userName =
                                    userData?['name'] ??
                                    (user != null ? 'User' : 'Guest');
                                return Text(
                                  userName,
                                  style: GoogleFonts.manrope(
                                    fontSize: 24,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Consumer(
                              builder: (context, ref, child) {
                                final groupId = ref.watch(userGroupIdProvider);
                                if (groupId == null) return const SizedBox();
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: _GlassIconButton(
                                    icon: Icons.group_outlined,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const SplitLedgerPage()),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                            // Notification button
                            _GlassIconButton(
                              icon: Icons.notifications_none_rounded,
                              onTap: () {},
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Balance card
                SlideTransition(
                  position: cardSlide,
                  child: FadeTransition(
                    opacity: cardOpacity,
                    child: Consumer(
                      builder: (context, ref, child) {
                        final stats = ref.watch(homeFilteredTransactionStatsProvider);
                        return _BalanceCard(stats: stats);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Ad removed from header stack
      ],
    );
  }
}

// ─── Glass Icon Button ────────────────────────────────────────────────────────
class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withOpacity(0.25),
                width: 1,
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

// ─── Balance Card (Static Available Balance Card) ───────────────────────────
class _BalanceCard extends StatelessWidget {
  final TransactionStats stats;

  const _BalanceCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final amountText = '₹ ${stats.totalBalance.toStringAsFixed(2)}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        gradient: const RadialGradient(
          center: Alignment(0.0, -0.5),
          radius: 1.2,
          colors: [
            Color(0xFF3AAFA9),
            Color(0xFF2F7E79),
          ],
          stops: [0.0, 1.0],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Colors.white70,
                      size: 14,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Available Balance',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.more_horiz_rounded,
                color: Colors.white54,
                size: 20,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Static amount
          Text(
            amountText,
            style: GoogleFonts.manrope(
              fontSize: 34,
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 20),

          // Income & Expense row
          Row(
            children: [
              Expanded(
                child: _IncomeExpenseCard(
                  title: 'Income',
                  amount: stats.totalIncome,
                  icon: Icons.arrow_downward_rounded,
                  iconBg: Colors.greenAccent.shade400,
                ),
              ),
              Container(
                width: 1,
                height: 44,
                color: Colors.white.withOpacity(0.15),
              ),
              Expanded(
                child: _IncomeExpenseCard(
                  title: 'Expenses',
                  amount: stats.totalExpense,
                  icon: Icons.arrow_upward_rounded,
                  iconBg: Colors.redAccent.shade200,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Animated Transaction Tile ────────────────────────────────────────────────
class _AnimatedTransactionTile extends StatefulWidget {
  final TransactionModel transaction;
  final int index;

  const _AnimatedTransactionTile({
    super.key,
    required this.transaction,
    required this.index,
  });

  @override
  State<_AnimatedTransactionTile> createState() =>
      _AnimatedTransactionTileState();
}

class _AnimatedTransactionTileState extends State<_AnimatedTransactionTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0.08, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _fadeAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    // Staggered delay based on index (cap at 8 to avoid long waits)
    final delay = Duration(milliseconds: 60 * min(widget.index, 8));
    Future.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnim,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: _TransactionTile(transaction: widget.transaction),
      ),
    );
  }
}

// ─── Transaction Tile ─────────────────────────────────────────────────────────
class _TransactionTile extends ConsumerWidget {
  final TransactionModel transaction;

  const _TransactionTile({required this.transaction});

  String _limitChars(String text, int max) =>
      text.length <= max ? text : '${text.substring(0, max)}...';

  void _showDetail(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, __, ___) =>
          TransactionDetailDialog(transaction: transaction),
      transitionBuilder: (_, animation, __, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userGroupsAsync = ref.watch(userGroupsStreamProvider);
    final groups = userGroupsAsync.value ?? [];
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    GroupModel? targetGroup;
    for (final g in groups) {
      if (g.id == transaction.groupId) {
        targetGroup = g;
        break;
      }
    }
    final isWagesGroup = targetGroup?.toMap()['type'] == 'wages';
    final isRecipient = transaction.splitWith != null && transaction.splitWith!.contains(currentUserId);
    final isExpense = isWagesGroup && isRecipient ? false : transaction.isExpense;

    final amountColor = isExpense
        ? const Color(0xFFE57373)
        : const Color(0xFF66BB6A);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showDetail(context),
          borderRadius: BorderRadius.circular(20),
          splashColor: transaction.color.withOpacity(0.1),
          highlightColor: transaction.color.withOpacity(0.05),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Icon container
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: transaction.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    transaction.icon,
                    color: transaction.color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),

                // Title + date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.categoryName,
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E2D2C),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 11,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(transaction.date),
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Amount + desc
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isExpense ? '-' : '+'} ₹${transaction.amount.toStringAsFixed(2)}',
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: amountColor,
                      ),
                    ),
                    if (transaction.description.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _limitChars(transaction.description, 18),
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final txDate = DateTime(date.year, date.month, date.day);

    if (txDate == today) return 'Today';
    if (txDate == yesterday) return 'Yesterday';
    return DateFormat('MMM dd, yyyy').format(date);
  }
}

class _IncomeExpenseCard extends StatelessWidget {
  final String title;
  final double amount;
  final IconData icon;
  final Color iconBg;

  const _IncomeExpenseCard({
    required this.title,
    required this.amount,
    required this.icon,
    required this.iconBg,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconBg.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '₹${amount.toStringAsFixed(2)}',
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────
class _EmptyState extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  State<_EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<_EmptyState>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();

    _scaleAnim = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
    _fadeAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnim,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: _kGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.icon,
                size: 48,
                color: _kGreen.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.title,
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E2D2C),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                widget.subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Loading Shimmer ──────────────────────────────────────────────────────────
class _LoadingShimmer extends StatefulWidget {
  const _LoadingShimmer();

  @override
  State<_LoadingShimmer> createState() => _LoadingShimmerState();
}

class _LoadingShimmerState extends State<_LoadingShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shimmerAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();

    _shimmerAnim = Tween<double>(
      begin: -2.0,
      end: 2.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerAnim,
      builder: (_, __) {
        return Column(
          children: List.generate(
            6,
            (i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Container(
                height: 74,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment(_shimmerAnim.value - 1, 0),
                    end: Alignment(_shimmerAnim.value + 1, 0),
                    colors: [
                      Colors.grey.shade200,
                      Colors.grey.shade100,
                      Colors.grey.shade200,
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Shake Onboarding Card ───────────────────────────────────────────────────
class _ShakeOnboardingCard extends ConsumerWidget {
  const _ShakeOnboardingCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final show = ref.watch(showShakeOnboardingProvider);
    if (!show) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE6F7F6), Color(0xFFD1F2F0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFB2E5E2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF429690).withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Color(0xFF429690),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.vibration_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Add by Shaking!',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A5C5A),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Did you know? Shake your phone at any screen to quickly add a new expense.',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: const Color(0xFF2E7D79),
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              color: const Color(0xFF2E7D79),
              onPressed: () {
                ref.read(showShakeOnboardingProvider.notifier).state = false;
              },
            ),
          ],
        ),
      ),
    );
  }
}

abstract class _HistoryItem {}

class _DateHeaderItem extends _HistoryItem {
  final String dateText;
  _DateHeaderItem(this.dateText);
}

class _TransactionTileItem extends _HistoryItem {
  final TransactionModel transaction;
  final int index;
  _TransactionTileItem(this.transaction, this.index);
}

String _formatHeaderDate(DateTime date) {
  return DateFormat('dd MMMM yyyy').format(date);
}

void _showHomeFilterBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => const HomeFilterBottomSheet(),
  );
}
