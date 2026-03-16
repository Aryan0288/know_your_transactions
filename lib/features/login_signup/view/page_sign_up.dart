import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:know_your_expenses/features/common_widgets/common_colors.dart';
import 'package:know_your_expenses/features/common_widgets/common_navigation.dart';
import 'package:know_your_expenses/features/common_widgets/common_widget_textfield.dart';
import 'package:know_your_expenses/features/common_widgets/common_widgets.dart';
import 'package:know_your_expenses/features/common_widgets/common_widgets_scaffold.dart';
import 'package:know_your_expenses/features/constants/string_constants.dart';
import 'package:know_your_expenses/features/helper/utils.dart';
import 'package:know_your_expenses/features/home/view/page_home.dart';
import 'package:know_your_expenses/features/login_signup/view/page_sign_in.dart';
import 'package:know_your_expenses/features/login_signup/view/widgets/widget_google_signup.dart';
import 'package:know_your_expenses/features/login_signup/view_model/view_model_login_signup.dart';
import 'package:know_your_expenses/features/transaction/view/page_expense_transaction.dart';

class SignUpPage extends StatelessWidget {
  SignUpPage({super.key});

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phnController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final FocusNode _focusNode = FocusNode();
  final _formKey = GlobalKey<FormState>();

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
                  commonTextCenterAlign(title: signUp, style: headingTextStyle),
                  hs(8),
                  commonTextCenterAlign(
                    title: getStarted,
                    style: textStyle_14_400_55555A,
                  ),
                  hs(20),
                  GoogleSignUpWidget(),
                  hs(20),
                  Row(
                    children: [
                      Expanded(
                        child: Container(height: 1, color: textColor_72788C),
                      ),
                      ws(8),
                      commonTextCenterAlign(
                        title: or,
                        style: textStyle_14_600_181636,
                      ),
                      ws(8),
                      Expanded(
                        child: Container(height: 1, color: textColor_72788C),
                      ),
                    ],
                  ),
                  hs(32),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        CustomTextFormField(
                          hint: name,
                          controller: nameController,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your name';
                            }
                            if (value.length < 3) {
                              return 'Name must be at least 3 characters long';
                            }
                            return null;
                          },
                        ),
                        hs(12),
                        CustomTextFormField(
                          hint: email,
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            final emailRegex = RegExp(
                              r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                            );
                            if (!emailRegex.hasMatch(value)) {
                              return 'Please enter a valid email address';
                            }
                            return null;
                          },
                        ),
                        hs(12),
                        CustomTextFormField(
                          hint: phone,
                          controller: phnController,
                          keyboardType: TextInputType.phone,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your phone number';
                            }
                            final phoneRegex = RegExp(r'^[6-9]\d{9}$');
                            if (!phoneRegex.hasMatch(value)) {
                              return 'Please enter a valid 10-digit phone number starting with 6-9';
                            }
                            return null;
                          },
                        ),
                        hs(12),
                        CustomTextFormField(
                          hint: password,
                          controller: passwordController,
                          suffixWidget: Icon(Icons.remove_red_eye),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters long';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom > 0
              ? MediaQuery.of(context).viewInsets.bottom * 1.1
              : 24,
          top: 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Consumer(
              builder: (context, ref, child) {
                final authState = ref.watch(authControllerProvider);
                return elevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      final success = await ref
                          .read(authControllerProvider.notifier)
                          .signUp(
                            name: nameController.text.trim(),
                            email: emailController.text.trim(),
                            phone: phnController.text.trim(),
                            password: passwordController.text.trim(),
                          );

                      if (success) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddExpensePageHomePage(),
                          ),
                          (Route<dynamic> route) => route.isFirst,
                        );
                      } else {
                        Utils.showErrorToast(
                          context,
                          title: ref.read(authControllerProvider).error,
                        );
                      }
                    }
                  },
                  title: createAccount,
                  isLoading: authState.isLoading,
                );
              },
            ),
            hs(8),
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  commonTextCenterAlign(
                    title: doYouHaveAccount,
                    style: textStyle_14_400_55555A,
                  ),
                  ws(4),
                  GestureDetector(
                    onTap: () {
                      CustomNavigation.to(context, SignInPage());
                    },
                    child: commonTextCenterAlign(
                      title: signIn,
                      style: textStyle_14_400_0461E5,
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
