import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:know_your_expenses/features/common_widgets/common_widgets_scaffold.dart';
import 'package:know_your_expenses/features/home/view_model/view_model_home.dart';
import 'package:know_your_expenses/features/transaction/view_model/view_model_transaction.dart';
import 'package:know_your_expenses/features/transaction/model/model_transaction.dart';

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

          // ─── Transaction List ─────────────────────────────────────────────
          Expanded(
            child: FadeTransition(
              opacity: _contentOpacity,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // Section header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
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
                          Consumer(
                            builder: (context, ref, _) {
                              final count =
                                  ref
                                      .watch(transactionsStreamProvider)
                                      .value
                                      ?.length ??
                                  0;
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
                        ],
                      ),
                    ),
                  ),

                  // Transaction items
                  Consumer(
                    builder: (context, ref, child) {
                      final transactionsAsync = ref.watch(
                        transactionsStreamProvider,
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
                          if (transactions.isEmpty) {
                            return const SliverFillRemaining(
                              hasScrollBody: false,
                              child: _EmptyState(
                                icon: Icons.receipt_long_rounded,
                                title: 'No Transactions Yet',
                                subtitle:
                                    'Your expenses will appear here once you add them',
                              ),
                            );
                          }
                          return SliverList(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              return _AnimatedTransactionTile(
                                transaction: transactions[index],
                                index: index,
                              );
                            }, childCount: transactions.length),
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
                        // Notification button
                        _GlassIconButton(
                          icon: Icons.notifications_none_rounded,
                          onTap: () {},
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
                        final stats = ref.watch(transactionStatsProvider);
                        return _BalanceCard(stats: stats);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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

// ─── Balance Card (gyroscope tilt + shake – unchanged logic) ─────────────────
class _BalanceCard extends StatefulWidget {
  final TransactionStats stats;

  const _BalanceCard({required this.stats});

  @override
  State<_BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<_BalanceCard>
    with SingleTickerProviderStateMixin {
  StreamSubscription<AccelerometerEvent>? _subscription;

  double _tiltX = 0.0;
  double _tiltY = 0.0;

  static const double _maxAngle = 0.2;
  static const double _smoothing = 0.1;
  static const double _maxAccel = 1.0;

  late final AnimationController _shakeController;
  static const double _shakeThreshold = 12.0;
  double _lastMagnitude = 9.8;
  DateTime _lastShakeTime = DateTime(2000);
  static const Duration _shakeCooldown = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _subscription =
        accelerometerEventStream(
          samplingPeriod: const Duration(milliseconds: 16),
        ).listen((event) {
          if (!mounted) return;

          final magnitude = sqrt(
            event.x * event.x + event.y * event.y + event.z * event.z,
          );
          final delta = (magnitude - _lastMagnitude).abs();
          _lastMagnitude = magnitude;
          final now = DateTime.now();
          if ((delta > 5.0 || magnitude > _shakeThreshold) &&
              now.difference(_lastShakeTime) > _shakeCooldown) {
            _lastShakeTime = now;
            _shakeController.forward(from: 0.0);
          }

          final targetX = (event.x / _maxAccel).clamp(-1.0, 1.0);
          final targetY = (event.y / _maxAccel).clamp(-1.0, 1.0);
          setState(() {
            _tiltX = lerpDouble(_tiltX, targetX, _smoothing)!;
            _tiltY = lerpDouble(_tiltY, targetY, _smoothing)!;
          });
        });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glowAlignX = _tiltX.clamp(-1.0, 1.0);
    final glowAlignY = (-_tiltY + 1).clamp(-1.0, 1.0);
    final glowIntensity = (_tiltX.abs() + _tiltY.abs()).clamp(0.0, 1.0);

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..rotateY(_tiltX * _maxAngle)
        ..rotateX(_tiltY * _maxAngle),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 24,
              offset: Offset(_tiltX * 8, -_tiltY * 8 + 12),
            ),
          ],
          gradient: RadialGradient(
            center: Alignment(glowAlignX, glowAlignY),
            radius: 1.2,
            colors: [
              Color.lerp(
                const Color(0xFF2F7E79),
                const Color(0xFF5EEAD4),
                0.45 * glowIntensity,
              )!,
              const Color(0xFF2F7E79),
            ],
            stops: const [0.0, 0.75],
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
                        'Total Expense',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
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

            const SizedBox(height: 12),

            // Shake-animated amount
            AnimatedBuilder(
              animation: _shakeController,
              builder: (context, _) {
                final amountText =
                    '₹ ${widget.stats.totalBalance.toStringAsFixed(2)}';
                final progress = _shakeController.value;
                final decay = 1.0 - progress;

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(amountText.length, (index) {
                    final phase = index * 0.4;
                    final offsetX =
                        sin((progress * pi * 20) + phase) * 1.0 * decay;
                    final offsetY =
                        cos((progress * pi * 20) + phase) * 2 * decay;
                    return Transform.translate(
                      offset: Offset(offsetX, offsetY),
                      child: Text(
                        amountText[index],
                        style: GoogleFonts.manrope(
                          fontSize: 34,
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    );
                  }),
                );
              },
            ),

            const SizedBox(height: 6),

            // Shake hint
            Text(
              'Shake your phone to animate!',
              style: GoogleFonts.manrope(
                fontSize: 11,
                color: Colors.white38,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 20),

            // Divider
            // Container(height: 1, color: Colors.white.withOpacity(0.12)),
            //
            const SizedBox(height: 20),


            /// For later version

            // Income & Expense row
            /*Row(
              children: [
                Expanded(
                  child: _IncomeExpenseCard(
                    title: 'Income',
                    amount: widget.stats.totalIncome,
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
                    amount: widget.stats.totalExpense,
                    icon: Icons.arrow_upward_rounded,
                    iconBg: Colors.redAccent.shade200,
                  ),
                ),
              ],
            ),*/
          ],
        ),
      ),
    );
  }
}

// ─── Income / Expense Card ───────────────────────────────────────────────────
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconBg.withOpacity(0.22),
            ),
            child: Icon(icon, color: iconBg, size: 16),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: Colors.white60,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '₹ ${amount.toStringAsFixed(2)}',
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
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
class _TransactionTile extends StatelessWidget {
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
          _TransactionDetailDialog(transaction: transaction),
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
  Widget build(BuildContext context) {
    final isExpense = transaction.isExpense;
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

// ─── Transaction Detail Dialog (scale-in animation) ──────────────────────────
class _TransactionDetailDialog extends StatelessWidget {
  final TransactionModel transaction;

  const _TransactionDetailDialog({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.isExpense;
    final typeColor = isExpense ? Colors.redAccent : Colors.green;

    return Center(
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Coloured top strip ──
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: transaction.color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                child: Column(
                  children: [
                    // Icon
                    Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        color: transaction.color.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        transaction.icon,
                        color: transaction.color,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Type badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isExpense ? '💸  Expense' : '💰  Income',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: typeColor,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Amount
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: isExpense
                            ? [Colors.redAccent, Colors.red.shade800]
                            : [Colors.green, Colors.teal],
                      ).createShader(bounds),
                      child: Text(
                        '₹ ${transaction.amount.toStringAsFixed(2)}',
                        style: GoogleFonts.manrope(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Detail rows
                    _DetailRow(
                      label: 'Category',
                      value: transaction.categoryName,
                      icon: Icons.category_rounded,
                    ),
                    const _Divider(),
                    _DetailRow(
                      label: 'Date',
                      value: DateFormat(
                        'MMM dd, yyyy  •  hh:mm a',
                      ).format(transaction.date),
                      icon: Icons.calendar_month_rounded,
                    ),
                    if (transaction.description.isNotEmpty) ...[
                      const _Divider(),
                      _DetailRow(
                        label: 'Note',
                        value: transaction.description,
                        icon: Icons.notes_rounded,
                      ),
                    ],

                    const SizedBox(height: 28),

                    // Close button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D79),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Done',
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade400),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.manrope(
              color: Colors.grey.shade500,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: const Color(0xFF1E2D2C),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Divider(height: 1, color: Colors.grey.shade100),
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
