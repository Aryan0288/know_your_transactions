import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:know_your_expenses/features/common_widgets/common_colors.dart';
import 'package:know_your_expenses/features/common_widgets/common_widgets.dart';
import 'package:know_your_expenses/features/common_widgets/common_widgets_scaffold.dart';
import 'package:know_your_expenses/features/transaction/view_model/view_model_transaction.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'package:know_your_expenses/features/transaction/model/model_transaction.dart';

class FinancialInsightsPage extends ConsumerWidget {
  const FinancialInsightsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insights = ref.watch(financialInsightsProvider);

    return CommonScaffold(
      backgroundColor: Colors.white,
      appBar: appBarWithoutProgress(
        context,
        appBarTitle: "Smart Insights",
        appBarColor: Colors.white,
        icon: Icon(Icons.auto_awesome, size: 20, color: textColor_3E7C78),
        appBarTitleStyle: appBarTitleTextStyle.copyWith(fontSize: 18, color: textColor_181636),
        onPressed: () => ref.read(bottomNavIndexProvider.notifier).state = 0,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              hs(20),
              _buildHealthScoreCard(insights),
              hs(30),
              _buildHistorySection(context, ref),
              hs(30),
              _buildForecastSection(insights.forecastAmount),
              hs(30),
              _buildWisdomSection(insights.wisdoms),

              hs(40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHealthScoreCard(FinancialInsight insights) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: textColor_3E7C78,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: textColor_3E7C78.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            "Overall Health Score",
            // style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500),
            style: textStyle_14_600_181636.copyWith(color: Colors.white70),
          ),
          hs(20),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 160,
                height: 160,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: insights.healthScore / 100),
                  duration: const Duration(milliseconds: 1500),
                  curve: Curves.easeOutQuart,
                  builder: (context, value, child) {
                    return CustomPaint(
                      painter: HealthGaugePainter(value: value, color: Colors.white),
                    );
                  },
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   TweenAnimationBuilder<int>(
                    tween: IntTween(begin: 0, end: insights.healthScore),
                    duration: const Duration(milliseconds: 1500),
                    builder: (context, value, child) {
                      return Text(
                        "$value",
                        style: textStyle_14_700_72788C.copyWith(color: Colors.white,fontSize: 48),
                      );
                    },
                  ),
                  Text(
                    insights.healthLabel,
                    style: textStyle_14_400_55555A.copyWith(color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
          hs(20),
          Text(
            insights.healthMessage,
            textAlign: TextAlign.center,
            style: textStyle_14_400_55555A.copyWith(color: Colors.white,height: 1.5,fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildForecastSection(double amount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "A.I. Predictive Forecast",
          style: textStyle_14_600_181636.copyWith(fontSize: 18,fontWeight: FontWeight.bold),
        ),
        hs(16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.trending_down, color: Color(0xFF22C55E)),
              ),
              ws(16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Next Month Est. Budget",
                      style: textStyle_14_400_55555A.copyWith(fontSize: 13),
                    ),
                    Text(
                      "\₹${amount.toStringAsFixed(2)}",
                      style: textStyle_14_600_181636.copyWith(fontSize: 20),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWisdomSection(List<InsightWisdom> wisdoms) {
    if (wisdoms.isEmpty) return const SizedBox();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Spending Wisdom",
          style: textStyle_14_600_181636.copyWith(fontSize: 18,fontWeight: FontWeight.bold),
        ),
        hs(16),
        ...wisdoms.map((w) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildWisdomCard(w.title, w.description, w.icon, w.color),
        )),
      ],
    );
  }

  Widget _buildWisdomCard(String title, String desc, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          ws(16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textStyle_14_600_181636.copyWith(fontSize: 16,fontWeight: FontWeight.bold,color: color),
                ),
                hs(4),
                Text(
                  desc,
                  style: textStyle_14_600_181636.copyWith(fontSize: 13,color: color.withOpacity(0.8),height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection(BuildContext context, WidgetRef ref) {
    final selectedMonth = ref.watch(historySelectedMonthProvider);
    final selectedYear = ref.watch(historySelectedYearProvider);
    final transactions = ref.watch(monthlyHistoryTransactionsProvider);
    
    final totalMonthlyExpense = transactions.where((t) => t.isExpense).fold(0.0, (sum, t) => sum + t.amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Monthly History",
          style: textStyle_14_600_181636.copyWith(fontSize: 18,fontWeight: FontWeight.bold),
        ),
        hs(16),
        _buildMonthYearSelectors(ref, selectedMonth, selectedYear),
        hs(20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFBFBFB),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Column(
            children: [
              Text(
                "Total Spent in ${DateFormat('MMMM').format(DateTime(2022, selectedMonth))}",
                style: textStyle_14_400_55555A,
              ),
              hs(8),
              Text(
                "\₹${totalMonthlyExpense.toStringAsFixed(2)}",
                style: textStyle_14_600_181636.copyWith(fontSize: 28,fontWeight: FontWeight.bold),
              ),
              hs(24),
              const Divider(height: 1),
              hs(20),
              if (transactions.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text("No transactions found for this month"),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: transactions.length,
                  separatorBuilder: (context, index) => hs(15),
                  itemBuilder: (context, index) {
                    final t = transactions[index];
                    return _buildMonthlyTransactionItem(t);
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMonthYearSelectors(WidgetRef ref, int selectedMonth, int selectedYear) {
    final months = List.generate(12, (i) => i + 1);
    final years = List.generate(5, (i) => DateTime.now().year - i);

    return Column(
      children: [
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: months.length,
            separatorBuilder: (context, index) => ws(10),
            itemBuilder: (context, index) {
              final month = months[index];
              final isSelected = month == selectedMonth;
              return GestureDetector(
                onTap: () => ref.read(historySelectedMonthProvider.notifier).state = month,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isSelected ? textColor_3E7C78 : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isSelected ? textColor_3E7C78 : Colors.grey.shade200),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    DateFormat('MMM').format(DateTime(2022, month)),
                    style: textStyle_14_600_181636.copyWith(fontSize: 14,fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,color: isSelected ? Colors.white : textColor_55555A),
                  ),
                ),
              );
            },
          ),
        ),
        hs(12),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: years.length,
            separatorBuilder: (context, index) => ws(10),
            itemBuilder: (context, index) {
              final year = years[index];
              final isSelected = year == selectedYear;
              return GestureDetector(
                onTap: () => ref.read(historySelectedYearProvider.notifier).state = year,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isSelected ? textColor_3E7C78 : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isSelected ? textColor_3E7C78 : Colors.grey.shade200),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    "$year",
                    style: textStyle_14_600_181636.copyWith(fontSize: 14,fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,color: isSelected ? Colors.white : textColor_55555A,),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMonthlyTransactionItem(TransactionModel t) {
    String title = t.description.isEmpty ? t.categoryName : t.description;
    if (title.length > 10) {
      title = "${title.substring(0, 10)}...";
    }
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: t.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(t.icon, color: t.color, size: 20),
        ),
        ws(12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textStyle_14_600_181636,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                DateFormat('MMM dd').format(t.date),
                style: textStyle_12_400_55555A,
              ),
            ],
          ),
        ),
        Text(
          "${t.isExpense ? '-' : '+'}\₹${t.amount.toStringAsFixed(0)}",
          style: textStyle_12_400_55555A.copyWith(color: t.isExpense ? Colors.redAccent : Colors.green,fontSize: 14,fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class HealthGaugePainter extends CustomPainter {
  final double value;
  final Color color;

  HealthGaugePainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width / 2, size.height / 2);
    const strokeWidth = 14.0;

    // Background Arc
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

    // Value Arc
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
  bool shouldRepaint(covariant HealthGaugePainter oldDelegate) => oldDelegate.value != value;
}
