import 'package:flutter/material.dart';
import 'package:know_your_expenses/features/common_widgets/common_colors.dart';
import 'package:know_your_expenses/features/common_widgets/common_widgets.dart';
import 'package:know_your_expenses/features/common_widgets/common_widgets_png.dart';
import 'package:know_your_expenses/features/constants/string_constants.dart';

class GoogleSignUpWidget extends StatelessWidget {
  const GoogleSignUpWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: textColor_F5F9FF,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 28),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(PngImages.googlePng, width: 20),
            ws(16),
            commonTextCenterAlign(
              title: google,
              style: textStyle_14_700_72788C,
            ),
          ],
        ),
      ),
    );
  }
}
