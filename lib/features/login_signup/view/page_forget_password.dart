import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:know_your_expenses/features/common_widgets/common_widget_textfield.dart';
import 'package:know_your_expenses/features/common_widgets/common_widgets.dart';
import 'package:know_your_expenses/features/common_widgets/common_widgets_scaffold.dart';
import 'package:know_your_expenses/features/constants/string_constants.dart';
import 'package:know_your_expenses/features/helper/utils.dart';
import 'package:know_your_expenses/features/login_signup/view_model/view_model_login_signup.dart';

class ForgetPasswordPage extends ConsumerStatefulWidget {
  const ForgetPasswordPage({super.key});

  @override
  ConsumerState<ForgetPasswordPage> createState() => _ForgetPasswordPageState();
}

class _ForgetPasswordPageState extends ConsumerState<ForgetPasswordPage> {
  final TextEditingController emailController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final _formKey = GlobalKey<FormState>();

  void unFocus() {
    _focusNode.unfocus();
  }

  @override
  void dispose() {
    emailController.dispose();
    _focusNode.dispose();
    super.dispose();
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
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  hs(24),
                  commonTextCenterAlign(
                    title: forgetPass,
                    style: headingTextStyle,
                  ),
                  hs(8),
                  commonTextCenterAlign(
                    title: forgetPassDesc,
                    style: textStyle_14_400_55555A,
                  ),
                  hs(32),
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
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
                      ],
                    ),
                  ),
                  hs(32),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Consumer(
                        builder: (context, ref, child) {
                          final authState = ref.watch(authControllerProvider);
                          return elevatedButton(
                            isLoading: authState.isLoading,
                            title: contin,
                            onPressed: () async {
                              unFocus();
                              if (_formKey.currentState!.validate()) {
                                final success = await ref
                                    .read(authControllerProvider.notifier)
                                    .resetPassword(emailController.text.trim());

                                if (success) {
                                  if (!mounted) return;
                                  Utils.showSuccessToast(
                                    context,
                                    title: "Email Sent",
                                    description:
                                        "A password reset link has been sent to your email.",
                                  );
                                  Navigator.pop(context); // Go back to login
                                } else {
                                  if (!mounted) return;
                                  Utils.showErrorToast(
                                    context,
                                    title: ref.read(authControllerProvider).error ??
                                        "Reset Failed",
                                    description: "Please check your email and try again.",
                                  );
                                }
                              }
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
