import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:know_your_expenses/features/transaction/model/model_transaction.dart';
import 'package:know_your_expenses/features/transaction/view_model/view_model_transaction.dart';
import 'package:know_your_expenses/features/home/view_model/view_model_group.dart';
import 'package:know_your_expenses/features/helper/ad_helper.dart';

import 'package:know_your_expenses/features/common_widgets/closable_banner_ad.dart';

// ─── Colours ──────────────────────────────────────────────────────────────────
const _kGreen = Color(0xFF2E8B57);
const _kLightGreen = Color(0xFF3EAF78);
const _kDeepGreen = Color(0xFF1A5C3A);
const _kTeal = Color(0xFF3E7C78);

// ─── Pie palette ──────────────────────────────────────────────────────────────
const _vibrantColors = [
  Color(0xFF3E7C78),
  Color(0xFFFFA726),
  Color(0xFF66BB6A),
  Color(0xFFAB47BC),
  Color(0xFFEC407A),
  Color(0xFF26C6DA),
  Color(0xFF5C6BC0),
];

// ─── Statistics Page ──────────────────────────────────────────────────────────
class StatisticsPage extends ConsumerStatefulWidget {
  const StatisticsPage({super.key});

  @override
  ConsumerState<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends ConsumerState<StatisticsPage>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;

  late Animation<Offset> _headerSlide;
  late Animation<double> _headerOpacity;
  late Animation<Offset> _contentSlide;
  late Animation<double> _contentOpacity;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
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

    _contentSlide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: const Interval(0.25, 1.0, curve: Curves.easeOut),
          ),
        );

    _contentOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.25, 0.75, curve: Curves.easeIn),
      ),
    );

    _entranceController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AdHelper.showStatsAdWithCooldown(() {});
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FAF4),
      extendBodyBehindAppBar: true,
      body: Column(
        children: [
          // ── Gradient Header ────────────────────────────────────────────
          SlideTransition(
            position: _headerSlide,
            child: FadeTransition(
              opacity: _headerOpacity,
              child: _buildHeader(),
            ),
          ),

          // ── Scrollable body ────────────────────────────────────────────
          Expanded(
            child: SlideTransition(
              position: _contentSlide,
              child: FadeTransition(
                opacity: _contentOpacity,
                child: Consumer(
                  builder: (context, ref, _) {
                    final topSpending = ref.watch(topSpendingProvider);
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                      children: [
                        _buildChartCard(context, ref, topSpending),
                        const SizedBox(height: 20),
                        _buildTopSpendingHeader(ref, topSpending.length),
                        const SizedBox(height: 12),
                        ..._buildTopSpendingItems(topSpending),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          const ClosableBannerAd(),
        ],
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final selectedGroup = ref.watch(selectedStatsGroupIdFilterProvider);
    final selectedPeriod = ref.watch(selectedPeriodProvider);
    final selectedType = ref.watch(statisticsTypeProvider);

    final isDefault = selectedGroup == 'all' &&
        selectedPeriod == StatisticsPeriod.week &&
        selectedType == StatisticsType.expense;

    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(36),
            bottomRight: Radius.circular(36),
          ),
          child: Container(
            height: 148,
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
                  top: -20,
                  right: -20,
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.07),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -25,
                  left: 20,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.06),
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
            height: 148,
            child: Padding(
              padding: const EdgeInsets.only(left: 8, right: 8, bottom: 16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () =>
                        ref.read(bottomNavIndexProvider.notifier).state = 0,
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Statistics',
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: GestureDetector(
                      onTap: () => _showFilterBottomSheet(context),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              const Icon(
                                Icons.filter_list_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                              if (!isDefault)
                                Positioned(
                                  right: -2,
                                  top: -2,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Colors.amberAccent,
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
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Period Selector ──────────────────────────────────────────────────────
  Widget _buildPeriodSelector(WidgetRef ref, StatisticsPeriod selectedPeriod) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _kGreen.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth / 4;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                left: _getLeftOffset(selectedPeriod, itemWidth),
                child: Container(
                  width: itemWidth,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_kGreen, _kLightGreen],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: _kGreen.withOpacity(0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: StatisticsPeriod.values.map((period) {
                  final isSelected = selectedPeriod == period;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref.read(selectedPeriodProvider.notifier).state =
                            period;
                        ref.read(touchedIndexProvider.notifier).state = -1;
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: GoogleFonts.manrope(
                            color: isSelected
                                ? Colors.white
                                : Colors.grey.shade500,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: 13,
                          ),
                          child: Text(_getPeriodTitle(period)),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }

  double _getLeftOffset(StatisticsPeriod period, double width) {
    switch (period) {
      case StatisticsPeriod.day:
        return 0;
      case StatisticsPeriod.week:
        return width;
      case StatisticsPeriod.month:
        return width * 2;
      case StatisticsPeriod.year:
        return width * 3;
    }
  }

  String _getPeriodTitle(StatisticsPeriod period) {
    switch (period) {
      case StatisticsPeriod.day:
        return 'Day';
      case StatisticsPeriod.week:
        return 'Week';
      case StatisticsPeriod.month:
        return 'Month';
      case StatisticsPeriod.year:
        return 'Year';
    }
  }

  Widget _buildTypeSelector(WidgetRef ref, StatisticsType selectedType) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _kGreen.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth / 2;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                left: selectedType == StatisticsType.expense ? 0 : itemWidth,
                child: Container(
                  width: itemWidth,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_kGreen, _kLightGreen],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: _kGreen.withOpacity(0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref.read(statisticsTypeProvider.notifier).state =
                            StatisticsType.expense;
                        ref.read(touchedIndexProvider.notifier).state = -1;
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: Text(
                          'Expense',
                          style: GoogleFonts.manrope(
                            color: selectedType == StatisticsType.expense
                                ? Colors.white
                                : Colors.grey.shade500,
                            fontWeight: selectedType == StatisticsType.expense
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref.read(statisticsTypeProvider.notifier).state =
                            StatisticsType.income;
                        ref.read(touchedIndexProvider.notifier).state = -1;
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: Text(
                          'Income',
                          style: GoogleFonts.manrope(
                            color: selectedType == StatisticsType.income
                                ? Colors.white
                                : Colors.grey.shade500,
                            fontWeight: selectedType == StatisticsType.income
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── Chart Card ───────────────────────────────────────────────────────────
  Widget _buildChartCard(
    BuildContext context,
    WidgetRef ref,
    List<TransactionModel> transactions,
  ) {
    final touchedIndex = ref.watch(touchedIndexProvider);
    final type = ref.watch(statisticsTypeProvider);
    final isExpense = type == StatisticsType.expense;

    final Map<String, double> categoryTotals = {};
    for (var t in transactions) {
      if (t.isExpense != isExpense) continue;
      categoryTotals[t.categoryName] =
          (categoryTotals[t.categoryName] ?? 0) + t.amount;
    }
    final categories = categoryTotals.keys.toList();
    final totalValue = categoryTotals.values.fold(0.0, (s, v) => s + v);

    String centerTitle = 'Total';
    String centerAmount = '₹${totalValue.toStringAsFixed(0)}';

    if (touchedIndex != -1 && touchedIndex < categories.length) {
      centerTitle = categories[touchedIndex];
      centerAmount = '₹${categoryTotals[centerTitle]!.toStringAsFixed(0)}';
    }

    return Container(
      padding: const EdgeInsets.all(18),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                isExpense ? 'Expense Breakdown' : 'Income Breakdown',
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E2D2C),
                ),
              ),
              const Spacer(),
              Text(
                'Drag · Tap slice',
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 44),
          if (totalValue == 0)
            SizedBox(
              height: 180,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.pie_chart_outline_rounded,
                      size: 48,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isExpense
                          ? 'No expenses in this period'
                          : 'No income in this period',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        color: Colors.grey.shade400,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sectionsSpace: 4,
                      centerSpaceRadius: 65,
                      startDegreeOffset: ref.watch(rotationOffsetProvider),
                      sections: _generatePieSections(transactions, ref),
                      pieTouchData: PieTouchData(
                        enabled: true,
                        touchCallback: (FlTouchEvent event, response) {
                          final rotationNotifier = ref.read(
                            rotationOffsetProvider.notifier,
                          );
                          if (event is FlPanUpdateEvent) {
                            rotationNotifier.state += event.details.delta.dx;
                          }
                          if (event is FlTapUpEvent) {
                            if (response == null ||
                                response.touchedSection == null) {
                              ref.read(touchedIndexProvider.notifier).state =
                                  -1;
                              return;
                            }
                            ref.read(touchedIndexProvider.notifier).state =
                                response.touchedSection!.touchedSectionIndex;
                          }
                        },
                      ),
                    ),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.decelerate,
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: GestureDetector(
                      onTap: () =>
                          ref.read(touchedIndexProvider.notifier).state = -1,
                      child: Column(
                        key: ValueKey('$centerTitle$centerAmount'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            centerTitle,
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: touchedIndex != -1
                                  ? _kTeal
                                  : Colors.grey.shade500,
                              fontWeight: touchedIndex != -1
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            centerAmount,
                            style: GoogleFonts.manrope(
                              fontSize: touchedIndex != -1 ? 22 : 20,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF1E2D2C),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Legend
          if (totalValue > 0 && categories.isNotEmpty) ...[
            const SizedBox(height: 34),
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: List.generate(categories.length, (i) {
                final isActive = touchedIndex == -1 || touchedIndex == i;
                return GestureDetector(
                  onTap: () {
                    ref.read(touchedIndexProvider.notifier).state =
                        touchedIndex == i ? -1 : i;
                  },
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: isActive ? 1.0 : 0.3,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _vibrantColors[i % _vibrantColors.length],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          categories[i],
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF3A4A48),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }

  List<PieChartSectionData> _generatePieSections(
    List<TransactionModel> transactions,
    WidgetRef ref,
  ) {
    final touchedIndex = ref.watch(touchedIndexProvider);
    final Map<String, double> categoryTotals = {};
    final Map<String, Color> categoryColors = {};

    print("transactions ---- $transactions");

    final type = ref.watch(statisticsTypeProvider);
    final isExpense = type == StatisticsType.expense;

    for (var t in transactions) {
      if (t.isExpense != isExpense) continue;
      categoryTotals[t.categoryName] =
          (categoryTotals[t.categoryName] ?? 0) + t.amount;
      categoryColors[t.categoryName] = t.color;
    }

    final totalValue = categoryTotals.values.fold(0.0, (s, v) => s + v);
    final categories = categoryTotals.keys.toList();

    return List.generate(categories.length, (i) {
      final category = categories[i];
      final value = categoryTotals[category]!;
      final isTouched = i == touchedIndex;
      final color = _vibrantColors[i % _vibrantColors.length];
      final rawPercentage = value / totalValue * 100;
      final renderValue = rawPercentage < 2 ? (totalValue * 0.02) : value;

      String displayPercentage;
      if (rawPercentage == 0) {
        displayPercentage = '0';
      } else if (rawPercentage < 1.0) {
        displayPercentage = rawPercentage.toStringAsFixed(1);
        if (displayPercentage == '0.0') {
          displayPercentage = rawPercentage.toStringAsFixed(2);
        }
      } else {
        displayPercentage = rawPercentage.toStringAsFixed(0);
      }

      return PieChartSectionData(
        color: color,
        value: renderValue,
        showTitle: isTouched || rawPercentage > 0,
        title: isTouched ? '' : '$displayPercentage%',
        radius: isTouched ? 80.0 : 70.0,
        titleStyle: GoogleFonts.manrope(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        badgeWidget: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: isTouched ? 1.0 : 0.0),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutBack,
          builder: (context, animValue, child) => Transform.scale(
            scale: animValue,
            child: Opacity(opacity: animValue.clamp(0.0, 1.0), child: child),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Text(
              '$displayPercentage%',
              style: GoogleFonts.manrope(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
        ),
        badgePositionPercentageOffset: isTouched ? 1.1 : 0.4,
      );
    });
  }

  // ─── Top Spending Header ──────────────────────────────────────────────────
  Widget _buildTopSpendingHeader(WidgetRef ref, int count) {
    final type = ref.watch(statisticsTypeProvider);
    final isExpense = type == StatisticsType.expense;
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
          Text(
            isExpense ? 'Top Spending' : 'Top Income',
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1E2D2C),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _kGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count items',
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _kGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Top Spending Items ───────────────────────────────────────────────────
  List<Widget> _buildTopSpendingItems(List<TransactionModel> transactions) {
    if (transactions.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 48,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 12),
              Text(
                'No data found',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ];
    }

    final items = <Widget>[];
    for (int index = 0; index < transactions.length; index++) {
      final t = transactions[index];
      if (index > 0) items.add(const SizedBox(height: 10));
      items.add(
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: t.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(t.icon, color: t.color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.categoryName,
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E2D2C),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('MMM d, yyyy').format(t.date),
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: t.isExpense
                      ? const Color(0xFFEA3636).withOpacity(0.08)
                      : const Color(0xFF2E8B57).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${t.isExpense ? '-' : '+'}₹${t.amount.toStringAsFixed(2)}',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: t.isExpense ? const Color(0xFFEA3636) : const Color(0xFF2E8B57),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return items;
  }
}

// ─── Keep for backward compatibility ─────────────────────────────────────────
AppBar appBarWithoutProgress(
  BuildContext context, {
  required String appBarTitle,
  required Color appBarColor,
  required Widget icon,
  required TextStyle appBarTitleStyle,
  required VoidCallback onPressed,
  List<Widget>? actions,
}) {
  return AppBar(
    backgroundColor: appBarColor,
    elevation: 0,
    leading: IconButton(onPressed: onPressed, icon: icon),
    title: Text(appBarTitle, style: appBarTitleStyle),
    centerTitle: true,
    actions: actions,
  );
}

void _showFilterBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => const _StatsFilterBottomSheet(),
  );
}

class _StatsFilterBottomSheet extends ConsumerWidget {
  const _StatsFilterBottomSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedGroup = ref.watch(selectedStatsGroupIdFilterProvider);
    final selectedPeriod = ref.watch(selectedPeriodProvider);
    final selectedType = ref.watch(statisticsTypeProvider);
    final groupsAsync = ref.watch(userGroupsStreamProvider);

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
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filters',
                style: GoogleFonts.manrope(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E232A),
                ),
              ),
              TextButton(
                onPressed: () {
                  ref.read(selectedStatsGroupIdFilterProvider.notifier).state = 'all';
                  ref.read(selectedPeriodProvider.notifier).state = StatisticsPeriod.week;
                  ref.read(statisticsTypeProvider.notifier).state = StatisticsType.expense;
                  Navigator.pop(context);
                },
                child: Text(
                  'Reset All',
                  style: GoogleFonts.manrope(
                    color: _kGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 20),

          // 1. Group Filter
          Text(
            'Select Space',
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          groupsAsync.when(
            data: (groups) {
              final items = [
                _FilterItem(id: 'all', name: 'All Spaces'),
                _FilterItem(id: 'personal', name: 'Personal Space'),
                ...groups.map((g) => _FilterItem(id: g.id, name: g.name)),
              ];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F8F5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withOpacity(0.1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedGroup,
                    isExpanded: true,
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    icon: const Icon(Icons.arrow_drop_down_rounded, color: _kGreen),
                    items: items.map((item) {
                      return DropdownMenuItem<String>(
                        value: item.id,
                        child: Text(
                          item.name,
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: const Color(0xFF1E2D2C),
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        ref.read(selectedStatsGroupIdFilterProvider.notifier).state = val;
                      }
                    },
                  ),
                ),
              );
            },
            loading: () => const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: _kGreen),
              ),
            ),
            error: (e, s) => const SizedBox(),
          ),
          const SizedBox(height: 24),

          // 2. Period Filter
          Text(
            'Time Frame',
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: StatisticsPeriod.values.map((period) {
              final isSelected = selectedPeriod == period;
              final name = period.name[0].toUpperCase() + period.name.substring(1);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Center(
                      child: Text(
                        name,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : const Color(0xFF1E2D2C),
                        ),
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: _kGreen,
                    backgroundColor: const Color(0xFFF3F8F5),
                    checkmarkColor: Colors.white,
                    showCheckmark: false,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide.none,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        ref.read(selectedPeriodProvider.notifier).state = period;
                      }
                    },
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // 3. Type Filter
          Text(
            'Transaction Type',
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: StatisticsType.values.map((type) {
              final isSelected = selectedType == type;
              final name = type == StatisticsType.expense ? 'Expenses' : 'Income';
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Center(
                      child: Text(
                        name,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : const Color(0xFF1E2D2C),
                        ),
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: _kGreen,
                    backgroundColor: const Color(0xFFF3F8F5),
                    checkmarkColor: Colors.white,
                    showCheckmark: false,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide.none,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        ref.read(statisticsTypeProvider.notifier).state = type;
                      }
                    },
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),

          // Apply Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
              ),
              child: Text(
                'Apply Filters',
                style: GoogleFonts.manrope(
                  fontSize: 16,
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

class _FilterItem {
  final String id;
  final String name;
  _FilterItem({required this.id, required this.name});
}
