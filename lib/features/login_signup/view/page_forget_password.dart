import 'package:flutter/material.dart';
import 'package:know_your_expenses/features/common_widgets/common_widget_textfield.dart';
import 'package:know_your_expenses/features/common_widgets/common_widgets.dart';
import 'package:know_your_expenses/features/common_widgets/common_widgets_scaffold.dart';
import 'package:know_your_expenses/features/constants/string_constants.dart';

class ForgetPasswordPage extends StatelessWidget {
  ForgetPasswordPage({super.key});

  final TextEditingController emailController = TextEditingController();

  final FocusNode _focusNode = FocusNode();

  void unFocus() {
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: unFocus,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsetsGeometry.all(24),
              child: Column(
                children: [
                  hs(24),
                  commonTextCenterAlign(title: forgetPass, style: headingTextStyle),
                  hs(8),
                  commonTextCenterAlign(title: forgetPassDesc, style: textStyle_14_400_55555A),
                  hs(32),
                  Form(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        hs(12),
                        CustomTextFormField(hint: email, controller: emailController),
                      ],
                    ),
                  ),
                  hs(32),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      elevatedButton(onPressed: () {}, title: contin),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
