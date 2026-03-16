import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:know_your_expenses/features/common_widgets/common_colors.dart';
import 'package:know_your_expenses/features/common_widgets/common_widgets.dart';
import 'package:know_your_expenses/features/common_widgets/common_widgets_scaffold.dart';
import 'package:know_your_expenses/features/transaction/model/model_transaction.dart';
import 'package:know_your_expenses/features/transaction/view_model/view_model_transaction.dart';

class StatisticsPage extends ConsumerWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CommonScaffold(
      backgroundColor: Colors.white,
      appBar: appBarWithoutProgress(
        context,
        appBarTitle: "Statistics",
        appBarColor: Colors.white,
        icon: Icon(Icons.arrow_back_ios_new, size: 20, color: textColor_181636),
        appBarTitleStyle: appBarTitleTextStyle.copyWith(
          fontSize: 18,
          color: textColor_181636,
        ),
        onPressed: () => ref.read(bottomNavIndexProvider.notifier).state = 0,
        actions: [
          IconButton(
            onPressed: () {
              // Handle download
            },
            icon: Icon(Icons.download_outlined, color: textColor_181636),
          ),
          ws(10),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Consumer(
                builder: (context, ref, child) {
                  final selectedPeriod = ref.watch(selectedPeriodProvider);
                  final topSpending = ref.watch(topSpendingProvider);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPeriodSelector(ref, selectedPeriod),
                      hs(24),
                      _buildExpenseDropdown(),
                      hs(20),
                      _buildChartSection(
                        context,
                        ref,
                        selectedPeriod,
                        topSpending,
                      ),
                      hs(52),
                      _buildTopSpendingHeader(),
                      hs(20),
                    ],
                  );
                },
              ),
            ),
            Expanded(
              child: Consumer(
                builder: (context, ref, child) {
                  final topSpending = ref.watch(topSpendingProvider);
                  return _buildTopSpendingList(topSpending);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector(WidgetRef ref, StatisticsPeriod selectedPeriod) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
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
                  height: 48,
                  decoration: BoxDecoration(
                    color: textColor_3E7C78.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Row(
                children: StatisticsPeriod.values.map((period) {
                  final isSelected = selectedPeriod == period;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        ref.read(selectedPeriodProvider.notifier).state =
                            period;
                        ref.read(touchedIndexProvider.notifier).state = -1;
                      },

                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: Text(
                          _getPeriodTitle(period),
                          style: TextStyle(
                            fontFamily: manRopeBold,
                            color: isSelected ? Colors.white : textColor_55555A,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            fontSize: 14,
                          ),
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
        return "Day";
      case StatisticsPeriod.week:
        return "Week";
      case StatisticsPeriod.month:
        return "Month";
      case StatisticsPeriod.year:
        return "Year";
    }
  }

  Widget _buildExpenseDropdown() {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Expense", style: textStyle_14_400_55555A),
            ws(4),
            // Icon(Icons.keyboard_arrow_down, color: textColor_55555A, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildChartSection(
    BuildContext context,
    WidgetRef ref,
    StatisticsPeriod period,
    List<TransactionModel> transactions,
  ) {
    final touchedIndex = ref.watch(touchedIndexProvider);

    final Map<String, double> categoryTotals = {};
    for (var t in transactions) {
      if (!t.isExpense) continue;
      categoryTotals[t.categoryName] =
          (categoryTotals[t.categoryName] ?? 0) + t.amount;
    }
    final categories = categoryTotals.keys.toList();
    final totalValue = categoryTotals.values.fold(
      0.0,
      (sum, item) => sum + item,
    );

    String centerTitle = "Total";
    String centerAmount = "\₹${totalValue.toStringAsFixed(0)}";

    double rotationOffset = -90;
    if (touchedIndex != -1 && touchedIndex < categories.length) {
      centerTitle = categories[touchedIndex];
      centerAmount = "\₹${categoryTotals[centerTitle]!.toStringAsFixed(0)}";

      // Calculate rotation to move selected slice to top (270 degrees)
      double currentAngle = 0;
      for (int i = 0; i < touchedIndex; i++) {
        currentAngle += (categoryTotals[categories[i]]! / totalValue) * 360;
      }
      double sweepAngle =
          (categoryTotals[categories[touchedIndex]]! / totalValue) * 360;
      rotationOffset = 270 - (currentAngle + sweepAngle / 2);
    }

    return SizedBox(
      height: 220,
      width: double.infinity,
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
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  final rotationNotifier = ref.read(
                    rotationOffsetProvider.notifier,
                  );

                  // 🔄 Rotate chart while dragging
                  if (event is FlPanUpdateEvent) {
                    rotationNotifier.state += event.details.delta.dx;
                  }

                  // 👆 Select slice on tap
                  if (event is FlTapUpEvent) {
                    if (pieTouchResponse == null ||
                        pieTouchResponse.touchedSection == null) {
                      ref.read(touchedIndexProvider.notifier).state = -1;
                      return;
                    }

                    ref.read(touchedIndexProvider.notifier).state =
                        pieTouchResponse.touchedSection!.touchedSectionIndex;
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
              onTap: () {
                ref.read(touchedIndexProvider.notifier).state = -1;
              },
              child: Column(
                key: ValueKey(centerTitle + centerAmount),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    centerTitle,
                    style: textStyle_14_600_181636.copyWith(
                      color: touchedIndex != -1
                          ? textColor_3E7C78
                          : textColor_181636.withOpacity(0.6),
                      fontWeight: touchedIndex != -1
                          ? FontWeight.bold
                          : FontWeight.w400,
                    ),
                  ),
                  Text(
                    centerAmount,
                    style: appBarTitleTextStyle.copyWith(
                      fontSize: touchedIndex != -1 ? 24 : 22,
                      color: textColor_181636,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
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

    for (var t in transactions) {
      if (!t.isExpense) continue;
      categoryTotals[t.categoryName] =
          (categoryTotals[t.categoryName] ?? 0) + t.amount;
      categoryColors[t.categoryName] = t.color;
    }

    final totalValue = categoryTotals.values.fold(
      0.0,
      (sum, item) => sum + item,
    );
    final categories = categoryTotals.keys.toList();

    // Premium Color Palette
    final vibrantColors = [
      const Color(0xFF3E7C78), // Original Teal
      const Color(0xFFFFA726), // Orange
      const Color(0xFF66BB6A), // Green
      const Color(0xFFAB47BC), // Purple
      const Color(0xFFEC407A), // Pink
      const Color(0xFF26C6DA), // Cyan
      const Color(0xFF5C6BC0), // Indigo
    ];

    return List.generate(categories.length, (i) {
      final category = categories[i];
      final value = categoryTotals[category]!;
      final isTouched = i == touchedIndex;

      final radius = isTouched ? 80.0 : 70.0;
      final color = vibrantColors[i % vibrantColors.length];
      final rawPercentage = (value / totalValue * 100);

      // Ensure a minimum slice visibility for small values (2% minimum visual width)
      final renderValue = rawPercentage < 2 ? (totalValue * 0.02) : value;

      // Smart Percentage Formatting:
      String displayPercentage;
      if (rawPercentage == 0) {
        displayPercentage = "0";
      } else if (rawPercentage < 1.0) {
        displayPercentage = rawPercentage.toStringAsFixed(1);
        if (displayPercentage == "0.0") {
          displayPercentage = rawPercentage.toStringAsFixed(2);
        }
      } else {
        displayPercentage = rawPercentage.toStringAsFixed(0);
      }

      return PieChartSectionData(
        color: color,
        value: renderValue,
        showTitle: isTouched || rawPercentage > 0,
        title: isTouched ? "" : '$displayPercentage%',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontFamily: manRopeBold,
        ),
        badgeWidget: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: isTouched ? 1.0 : 0.0),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutBack,
          builder: (context, animValue, child) {
            return Transform.scale(
              scale: animValue,
              child: Opacity(opacity: animValue.clamp(0.0, 1.0), child: child),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
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
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 11,
                fontFamily: manRopeBold,
              ),
            ),
          ),
        ),
        badgePositionPercentageOffset: isTouched ? 1.1 : 0.4,
      );
    });
  }

  Widget _buildTopSpendingHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "Top Spending",
          style: appBarTitleTextStyle.copyWith(
            fontSize: 18,
            color: Colors.black,
          ),
        ),
        Icon(Icons.swap_vert, color: Colors.grey.shade600),
      ],
    );
  }

  Widget _buildTopSpendingList(List<TransactionModel> transactions) {
    if (transactions.isEmpty) {
      return Center(
        child: Text("No data found", style: textStyle_14_400_55555A),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: transactions.length,
      separatorBuilder: (context, index) => hs(16),
      itemBuilder: (context, index) {
        final t = transactions[index];
        bool isSelected =
            index == 1; // Just for "wow" matching the image teal highlight
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? textColor_3E7C78 : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isSelected
                ? []
                : [
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
                  color: isSelected
                      ? Colors.white.withOpacity(0.2)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(t.icon, color: isSelected ? Colors.white : t.color),
              ),
              ws(16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.categoryName,
                      style: appBarTitleTextStyle.copyWith(
                        color: isSelected ? Colors.white : textColor_181636,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      DateFormat('MMM d, yyyy').format(t.date),
                      style: textStyle_12_400_55555A.copyWith(
                        color: isSelected ? Colors.white70 : textColor_55555A,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                "- \$${t.amount.toStringAsFixed(2)}",
                style: appBarTitleTextStyle.copyWith(
                  color: isSelected ? Colors.white : textColor_EA3636,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

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
