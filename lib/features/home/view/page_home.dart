// lib/features/onboarding/onboarding_page.dart
import 'package:flutter/material.dart';
import 'package:know_your_expenses/features/common_widgets/common_colors.dart';
import 'package:know_your_expenses/features/common_widgets/common_widgets.dart';
import 'package:know_your_expenses/features/common_widgets/common_widgets_png.dart';
import 'package:know_your_expenses/features/common_widgets/common_widgets_scaffold.dart';
import 'package:know_your_expenses/features/constants/string_constants.dart';
import 'package:know_your_expenses/features/home/view/widget/widget_floating_icon.dart';
import 'package:know_your_expenses/features/transaction/view/page_expense_transaction.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<HomePage> {
  late List<IconData> randomIcons;
  late List<Color> randomColors;

  @override
  void initState() {
    super.initState();
    randomIcons = _getRandomIcons();
    randomColors = _getRandomColors();
  }

  List<IconData> _getRandomIcons() {
    final icons = [
      Icons.monetization_on,
      Icons.trending_up,
      Icons.savings,
      Icons.credit_card,
      Icons.wallet,
      Icons.pie_chart,
    ];
    icons.shuffle();
    return icons.take(2).toList();
  }

  List<Color> _getRandomColors() {
    final colors = [
      const Color(0xFF6366F1),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFFF59E0B),
      const Color(0xFF10B981),
    ];
    colors.shuffle();
    return colors.take(2).toList();
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      backgroundColor: textColor_FFFFFF,
      body: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 600,
            child: Stack(
              children: [
                ClipRect(
                  child: Align(
                    alignment: .topCenter,
                    child: Image.asset(
                      PngImages.homePageBackPng,
                      fit: BoxFit.fitWidth, // ✅ KEY FIX
                      width: MediaQuery.of(context).size.width,
                    ),
                  ),
                ),

                Positioned(
                  // top: 120,
                  left: 0,
                  right: 0,
                  bottom: 15,
                  child: Image.asset(
                    PngImages.homePageManPng,
                    height: 460,
                    fit: BoxFit.contain,
                  ),
                ),

                Positioned(
                  left: 40,
                  top: 0,
                  bottom: 270,
                  child: FloatingIconBubble(
                    icon: randomIcons[0],
                    color: randomColors[0],
                  ),
                ),
                // Right floating icon
                Positioned(
                  right: 50,
                  top: 0,
                  bottom: 180,
                  child: FloatingIconBubble(
                    icon: randomIcons[1],
                    color: randomColors[1],
                  ),
                ),
              ],
            ),
          ),

          hs(32),
          Padding(
            padding: const EdgeInsets.only(left: 24, right: 24),
            child: Column(
              children: [
                commonTextCenterAlign(
                  title: spendSmarter,
                  style: headingTextStyle_438883,
                ),
              ],
            ),
          ),
        ],
      ),

      bottomNavigationBar: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            elevatedButton(
              color: textColor_3E7C78,
              shadowColor: textColor_69AEA9,
              borderRadius: 40,
              onPressed: () {
                // Navigate to next screen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddExpensePageHomePage(),
                  ),
                );
              },
              title: getStart,
            ),
          ],
        ),
      ),
    );
  }
}
