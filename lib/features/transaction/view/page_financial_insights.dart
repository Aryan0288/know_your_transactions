import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:know_your_expenses/features/home/view_model/view_model_home.dart';
import 'package:know_your_expenses/features/transaction/model/model_transaction.dart';
import 'package:know_your_expenses/features/transaction/view_model/view_model_transaction.dart';

// ─── Colours ──────────────────────────────────────────────────────────────────
const _kGreen = Color(0xFF2E8B57);
const _kLightGreen = Color(0xFF3EAF78);
const _kDeepGreen = Color(0xFF1A5C3A);
const _kRed = Color(0xFFEA3636);

// ─── Month names ──────────────────────────────────────────────────────────────
const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

// ─── Page ─────────────────────────────────────────────────────────────────────
class FinancialInsightsPage extends ConsumerStatefulWidget {
  const FinancialInsightsPage({super.key});

  @override
  ConsumerState<FinancialInsightsPage> createState() =>
      _FinancialInsightsPageState();
}

class _FinancialInsightsPageState extends ConsumerState<FinancialInsightsPage>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _calendarController;

  late Animation<Offset> _headerSlide;
  late Animation<double> _headerOpacity;
  late Animation<Offset> _bodySlide;
  late Animation<double> _bodyOpacity;

  final ValueNotifier<bool> _calendarExpandedNotifier = ValueNotifier<bool>(true);

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 950),
      vsync: this,
    );

    _calendarController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
      value: 1.0,
    );

    _headerSlide =
        Tween<Offset>(begin: const Offset(0, -0.25), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
          ),
        );

    _headerOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    _bodySlide = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: const Interval(0.25, 1.0, curve: Curves.easeOut),
          ),
        );

    _bodyOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.25, 0.75, curve: Curves.easeIn),
      ),
    );

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _calendarController.dispose();
    _calendarExpandedNotifier.dispose();
    super.dispose();
  }

  void _toggleCalendar() {
    _calendarExpandedNotifier.value = !_calendarExpandedNotifier.value;
    _calendarExpandedNotifier.value
        ? _calendarController.forward()
        : _calendarController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final insights = ref.watch(financialInsightsProvider);
    final user = ref.watch(firebaseAuthProvider).currentUser;
    final selectedMonth = ref.watch(historySelectedMonthProvider);
    final selectedYear = ref.watch(historySelectedYearProvider);
    final transactions = ref.watch(monthlyHistoryTransactionsProvider);

    final monthLabel = DateFormat(
      'MMMM yyyy',
    ).format(DateTime(selectedYear, selectedMonth));

    return Scaffold(
      backgroundColor: const Color(0xFFF0FAF4),
      extendBodyBehindAppBar: true,
      body: Column(
        children: [
          // ── Gradient Header ─────────────────────────────────────────────
          SlideTransition(
            position: _headerSlide,
            child: FadeTransition(
              opacity: _headerOpacity,
              child: _GradientHeader(
                monthLabel: monthLabel,
                onBack: () =>
                    ref.read(bottomNavIndexProvider.notifier).state = 0,
              ),
            ),
          ),

          // ── Body ────────────────────────────────────────────────────────
          Expanded(
            child: SlideTransition(
              position: _bodySlide,
              child: FadeTransition(
                opacity: _bodyOpacity,
                child: user == null
                    ? _buildSignInPrompt()
                    : _buildContent(
                        insights,
                        selectedMonth,
                        selectedYear,
                        transactions,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Sign-in prompt ────────────────────────────────────────────────────────
  Widget _buildSignInPrompt() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.7, end: 1.0),
            duration: const Duration(milliseconds: 900),
            curve: Curves.elasticOut,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _kGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                size: 40,
                color: _kGreen,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Sign in to see your insights',
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF3A4A48),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Track your expenses and get\npersonalised financial wisdom.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: Colors.grey.shade400,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Main scrollable content ───────────────────────────────────────────────
  Widget _buildContent(
    FinancialInsight insights,
    int selectedMonth,
    int selectedYear,
    List<TransactionModel> transactions,
  ) {
    final now = DateTime.now();

    final totalExpense = transactions
        .where((t) => t.isExpense)
        .fold(0.0, (s, t) => s + t.amount);
    final totalIncome = transactions
        .where((t) => !t.isExpense)
        .fold(0.0, (s, t) => s + t.amount);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
      children: [
        // ── Health Score ──────────────────────────────────────────────
        // _HealthScoreCard(insights: insights),

        // const SizedBox(height: 20),

        // ── Section title: Monthly History ────────────────────────────
        _SectionTitle(
          icon: Icons.calendar_month_rounded,
          title: 'Monthly History',
        ),
        const SizedBox(height: 12),

        // ── Calendar picker card ──────────────────────────────────────
        ValueListenableBuilder<bool>(
          valueListenable: _calendarExpandedNotifier,
          builder: (context, calendarExpanded, _) {
            return _CalendarCard(
              expanded: calendarExpanded,
              calendarController: _calendarController,
              selectedMonth: selectedMonth,
              selectedYear: selectedYear,
              now: now,
              onToggle: _toggleCalendar,
              onMonthSelected: (m) {
                HapticFeedback.selectionClick();
                ref.read(historySelectedMonthProvider.notifier).state = m;
              },
              onYearChanged: (y) {
                HapticFeedback.selectionClick();
                ref.read(historySelectedYearProvider.notifier).state = y;
              },
            );
          },
        ),

        const SizedBox(height: 14),

        // ── Monthly summary mini-row ───────────────────────────────────
        _MonthSummaryRow(
          totalExpense: totalExpense,
          totalIncome: totalIncome,
          count: transactions.length,
          monthLabel: _monthNames[selectedMonth - 1],
        ),

        const SizedBox(height: 14),

        // ── Transaction list ──────────────────────────────────────────
        _TransactionListCard(transactions: transactions),

        const SizedBox(height: 24),

        // ── AI Forecast ───────────────────────────────────────────────
        // _SectionTitle(
        //   icon: Icons.auto_awesome_rounded,
        //   title: 'A.I. Predictive Forecast',
        // ),
        // const SizedBox(height: 12),
        // _ForecastCard(amount: insights.forecastAmount),

        const SizedBox(height: 24),

        // ── Wisdom ───────────────────────────────────────────────────
        if (insights.wisdoms.isNotEmpty) ...[
          _SectionTitle(
            icon: Icons.lightbulb_outline_rounded,
            title: 'Spending Wisdom',
          ),
          const SizedBox(height: 12),
          ...insights.wisdoms.asMap().entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _WisdomCard(
                wisdom: e.value,
                delay: Duration(milliseconds: 80 * e.key),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Gradient Header ──────────────────────────────────────────────────────────
class _GradientHeader extends StatelessWidget {
  final String monthLabel;
  final VoidCallback onBack;

  const _GradientHeader({required this.monthLabel, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(36),
            bottomRight: Radius.circular(36),
          ),
          child: Container(
            height: 168,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_kDeepGreen, _kGreen, _kLightGreen],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -24,
                  right: -24,
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.07),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -28,
                  left: 24,
                  child: Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.06),
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  left: 70,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.07),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: SizedBox(
            height: 168,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16,left: 8,right: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: onBack,
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Smart Insights',
                        style: GoogleFonts.manrope(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 38,
                        height: 38,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.calendar_month_rounded,
                        color: Colors.white70,
                        size: 14,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        monthLabel,
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Health Score Card ────────────────────────────────────────────────────────
// class _HealthScoreCard extends StatelessWidget {
//   final FinancialInsight insights;
//
//   const _HealthScoreCard({required this.insights});
//
//   String get _emoji {
//     if (insights.healthScore >= 85) return '🏆';
//     if (insights.healthScore >= 60) return '📈';
//     return '⚠️';
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(24),
//       decoration: BoxDecoration(
//         gradient: const LinearGradient(
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//           colors: [_kDeepGreen, _kGreen, _kLightGreen],
//         ),
//         borderRadius: BorderRadius.circular(28),
//         boxShadow: [
//           BoxShadow(
//             color: _kGreen.withOpacity(0.35),
//             blurRadius: 24,
//             offset: const Offset(0, 10),
//           ),
//         ],
//       ),
//       child: Column(
//         children: [
//           Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Text(_emoji, style: const TextStyle(fontSize: 18)),
//               const SizedBox(width: 8),
//               Text(
//                 'Overall Health Score',
//                 style: GoogleFonts.manrope(
//                   fontSize: 15,
//                   fontWeight: FontWeight.w700,
//                   color: Colors.white70,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 20),
//
//           // Gauge
//           Stack(
//             alignment: Alignment.center,
//             children: [
//               SizedBox(
//                 width: 160,
//                 height: 160,
//                 child: TweenAnimationBuilder<double>(
//                   tween: Tween<double>(
//                     begin: 0,
//                     end: insights.healthScore / 100,
//                   ),
//                   duration: const Duration(milliseconds: 1500),
//                   curve: Curves.easeOutQuart,
//                   builder: (_, value, __) => CustomPaint(
//                     painter: HealthGaugePainter(
//                       value: value,
//                       color: Colors.white,
//                     ),
//                   ),
//                 ),
//               ),
//               Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   TweenAnimationBuilder<int>(
//                     tween: IntTween(begin: 0, end: insights.healthScore),
//                     duration: const Duration(milliseconds: 1500),
//                     builder: (_, value, __) => Text(
//                       '$value',
//                       style: GoogleFonts.manrope(
//                         fontSize: 52,
//                         fontWeight: FontWeight.w900,
//                         color: Colors.white,
//                         height: 1.0,
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 4),
//                   Container(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 10,
//                       vertical: 3,
//                     ),
//                     decoration: BoxDecoration(
//                       color: Colors.white.withOpacity(0.2),
//                       borderRadius: BorderRadius.circular(20),
//                     ),
//                     child: Text(
//                       insights.healthLabel,
//                       style: GoogleFonts.manrope(
//                         fontSize: 12,
//                         fontWeight: FontWeight.w700,
//                         color: Colors.white,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//
//           const SizedBox(height: 18),
//           Container(
//             padding: const EdgeInsets.all(14),
//             decoration: BoxDecoration(
//               color: Colors.white.withOpacity(0.12),
//               borderRadius: BorderRadius.circular(16),
//             ),
//             child: Text(
//               insights.healthMessage,
//               textAlign: TextAlign.center,
//               style: GoogleFonts.manrope(
//                 fontSize: 13,
//                 color: Colors.white,
//                 height: 1.55,
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// ─── Section Title ────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_kLightGreen, _kDeepGreen],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Icon(icon, size: 18, color: _kGreen),
          const SizedBox(width: 6),
          Text(
            title,
            style: GoogleFonts.manrope(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1E2D2C),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Calendar Card ────────────────────────────────────────────────────────────
class _CalendarCard extends StatelessWidget {
  final bool expanded;
  final AnimationController calendarController;
  final int selectedMonth;
  final int selectedYear;
  final DateTime now;
  final VoidCallback onToggle;
  final ValueChanged<int> onMonthSelected;
  final ValueChanged<int> onYearChanged;

  const _CalendarCard({
    required this.expanded,
    required this.calendarController,
    required this.selectedMonth,
    required this.selectedYear,
    required this.now,
    required this.onToggle,
    required this.onMonthSelected,
    required this.onYearChanged,
  });

  @override
  Widget build(BuildContext context) {
    final canNextYear = selectedYear < now.year;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _kGreen.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Year navigation row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                _YearArrow(
                  icon: Icons.chevron_left_rounded,
                  enabled: true,
                  onTap: () => onYearChanged(selectedYear - 1),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Text(
                        '$selectedYear',
                        key: ValueKey(selectedYear),
                        style: GoogleFonts.manrope(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1E2D2C),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _YearArrow(
                  icon: Icons.chevron_right_rounded,
                  enabled: canNextYear,
                  onTap: canNextYear
                      ? () => onYearChanged(selectedYear + 1)
                      : null,
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: onToggle,
                  child: AnimatedRotation(
                    turns: expanded ? 0.0 : -0.5,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _kGreen.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.keyboard_arrow_up_rounded,
                        color: _kGreen,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Expandable month grid
          SizeTransition(
            sizeFactor: CurvedAnimation(
              parent: calendarController,
              curve: Curves.easeOutCubic,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 1.65,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: 12,
                itemBuilder: (_, i) {
                  final month = i + 1;
                  final isFuture =
                      selectedYear == now.year && month > now.month;
                  final isSelected = month == selectedMonth;
                  final isCurrent =
                      month == now.month && selectedYear == now.year;

                  return GestureDetector(
                    onTap: isFuture ? null : () => onMonthSelected(month),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? const LinearGradient(
                                colors: [_kGreen, _kLightGreen],
                              )
                            : null,
                        color: isSelected
                            ? null
                            : isFuture
                            ? Colors.grey.shade50
                            : _kGreen.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: isCurrent && !isSelected
                            ? Border.all(color: _kGreen, width: 1.5)
                            : null,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: _kGreen.withOpacity(0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _monthNames[i],
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : isFuture
                                  ? Colors.grey.shade300
                                  : const Color(0xFF3A4A48),
                            ),
                          ),
                          if (isCurrent && !isSelected) ...[
                            const SizedBox(height: 3),
                            Container(
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(
                                color: _kGreen,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Year Arrow ───────────────────────────────────────────────────────────────
class _YearArrow extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  const _YearArrow({required this.icon, required this.enabled, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: enabled ? _kGreen.withOpacity(0.1) : Colors.grey.shade100,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? _kGreen : Colors.grey.shade300,
        ),
      ),
    );
  }
}

// ─── Month Summary Row ────────────────────────────────────────────────────────
class _MonthSummaryRow extends StatelessWidget {
  final double totalExpense;
  final double totalIncome;
  final int count;
  final String monthLabel;

  const _MonthSummaryRow({
    required this.totalExpense,
    required this.totalIncome,
    required this.count,
    required this.monthLabel,
  });

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MiniCard(
            label: 'Spent in $monthLabel',
            value: '-₹${_fmt(totalExpense)}',
            icon: Icons.arrow_upward_rounded,
            iconBg: _kRed.withOpacity(0.1),
            iconColor: _kRed,
            valueColor: _kRed,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniCard(
            label: 'Earned in $monthLabel',
            value: '+₹${_fmt(totalIncome)}',
            icon: Icons.arrow_downward_rounded,
            iconBg: _kGreen.withOpacity(0.1),
            iconColor: _kGreen,
            valueColor: _kGreen,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniCard(
            label: 'Transactions',
            value: '$count',
            icon: Icons.receipt_long_rounded,
            iconBg: const Color(0xFF0461E5).withOpacity(0.1),
            iconColor: const Color(0xFF0461E5),
            valueColor: const Color(0xFF0461E5),
          ),
        ),
      ],
    );
  }
}

class _MiniCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final Color valueColor;

  const _MiniCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: iconColor.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 9.5,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── Transaction List Card ────────────────────────────────────────────────────
class _TransactionListCard extends StatelessWidget {
  final List<TransactionModel> transactions;

  const _TransactionListCard({required this.transactions});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _kGreen.withOpacity(0.07),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Row(
              children: [
                Text(
                  'Transactions',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E2D2C),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _kGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${transactions.length} items',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _kGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (transactions.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 28, top: 12),
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 40,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'No transactions this month',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: Colors.grey.shade400,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              itemCount: transactions.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: Colors.grey.shade100, indent: 54),
              itemBuilder: (_, i) => _TransactionTile(
                t: transactions[i],
                delay: Duration(milliseconds: 40 * i),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Transaction Tile ─────────────────────────────────────────────────────────
class _TransactionTile extends StatefulWidget {
  final TransactionModel t;
  final Duration delay;

  const _TransactionTile({required this.t, required this.delay});

  @override
  State<_TransactionTile> createState() => _TransactionTileState();
}

class _TransactionTileState extends State<_TransactionTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 450),
      vsync: this,
    );
    _opacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
    _slide = Tween<Offset>(
      begin: const Offset(0.05, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final label = t.description.isNotEmpty ? t.description : t.categoryName;

    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: t.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(t.icon, color: t.color, size: 20),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E2D2C),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 10,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          DateFormat('d MMM, yyyy').format(t.date),
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            color: Colors.grey.shade400,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Amount
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: t.isExpense
                      ? _kRed.withOpacity(0.08)
                      : _kGreen.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${t.isExpense ? '-' : '+'}₹${t.amount.toStringAsFixed(0)}',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: t.isExpense ? _kRed : _kGreen,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ─── Wisdom Card ──────────────────────────────────────────────────────────────
class _WisdomCard extends StatefulWidget {
  final InsightWisdom wisdom;
  final Duration delay;

  const _WisdomCard({required this.wisdom, required this.delay});

  @override
  State<_WisdomCard> createState() => _WisdomCardState();
}

class _WisdomCardState extends State<_WisdomCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _scale = Tween<double>(
      begin: 0.94,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _opacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));

    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.wisdom;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => FadeTransition(
        opacity: _opacity,
        child: Transform.scale(scale: _scale.value, child: child),
      ),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: w.color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: w.color.withOpacity(0.15), width: 1.2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: w.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(w.icon, color: w.color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    w.title,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: w.color,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    w.description,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: w.color.withOpacity(0.75),
                      height: 1.55,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Health Gauge Painter (unchanged) ─────────────────────────────────────────
class HealthGaugePainter extends CustomPainter {
  final double value;
  final Color color;

  HealthGaugePainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width / 2, size.height / 2);
    const strokeWidth = 14.0;

    final bgPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.75,
      math.pi * 1.5,
      false,
      bgPaint,
    );

    final valuePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.75,
      math.pi * 1.5 * value,
      false,
      valuePaint,
    );
  }

  @override
  bool shouldRepaint(covariant HealthGaugePainter oldDelegate) =>
      oldDelegate.value != value;
}
