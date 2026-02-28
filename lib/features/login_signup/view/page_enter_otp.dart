import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:know_your_expenses/features/common_widgets/common_colors.dart';
import 'package:know_your_expenses/features/common_widgets/common_widgets.dart';
import 'package:know_your_expenses/features/common_widgets/common_widgets_scaffold.dart';
import 'package:know_your_expenses/features/constants/string_constants.dart';
import 'package:know_your_expenses/features/login_signup/view_model/view_model_login_signup.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

class EnterOtpPage extends ConsumerWidget {
  EnterOtpPage({super.key});

  final StreamController<ErrorAnimationType> errorController =
  StreamController<ErrorAnimationType>();
  final TextEditingController otpController = TextEditingController();

  final FocusNode _focusNode = FocusNode();

  void unFocus() {
    _focusNode.unfocus();
  }

  Future<bool> verifyOtp(String otp)async{
    print("verify otp called");
    if(otp == "123456") return true;
    return false;
  }
  Future<void> resendOtp()async{
    print("resend otp");
  }


  @override
  Widget build(BuildContext context,WidgetRef ref) {
    // final errorText = ref.watch(errorTextProvider);
    final authState = ref.watch(authControllerProvider);
    print("rebuild errorText --- ${authState.error}");
    return CommonScaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(backgroundColor: scaffoldColor),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: unFocus,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsetsGeometry.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  commonTextCenterAlign(title: enterOtp, style: headingTextStyle),
                  hs(8),
                  commonTextCenterAlign(title: enterOtpDesc, style: textStyle_14_400_55555A),
                  hs(32),
                  PinCodeTextField(

                    textStyle: textStyle_14_400_55555A,
                    appContext: context,
                    length: 5,
                    obscureText: false,
                    obscuringCharacter: '*',
                    hintCharacter: '-',
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    blinkWhenObscuring: true,
                    animationType: AnimationType.fade,
                    pinTheme: PinTheme(
                      shape: PinCodeFieldShape.box,
                      borderRadius: BorderRadius.circular(16),
                      activeColor: Color(0xFFE1ECFC),
                      selectedFillColor: Colors.white,
                      inactiveFillColor: Colors.white,
                      borderWidth: 1,
                      inactiveColor: Color(0xFFE1ECFC),
                      selectedColor: Color(0xFF0461E5),
                      errorBorderColor: textColor_EA3636,
                      fieldHeight: 65,
                      fieldWidth: 65,
                      activeFillColor: Colors.white,
                      activeBorderWidth: 1,
                      selectedBorderWidth: 1,
                      inactiveBorderWidth: 1,
                      errorBorderWidth: 1,
                    ),
                    cursorColor: Color(0xFF0461E5),
                    animationDuration: const Duration(milliseconds: 450),
                    enableActiveFill: true,
                    focusNode: _focusNode,
                    errorAnimationController: errorController,
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    boxShadows: const [
                      BoxShadow(
                        offset: Offset(0, 1),
                        color: Colors.black12,
                        blurRadius: 10,
                      )
                    ],
                    onCompleted: (v) {
                      _focusNode.unfocus();
                    },
                    onChanged: (value) {
                      debugPrint(value);
                      // errorText = "";
                      ref.read(authControllerProvider.notifier).clearError();
                    },
                  ),
                  
                  if(authState.error!=null)
                    commonTextStartAlign(title: authState.error ?? '',style: errorTextStyle_w500),



                  hs(32),
                  elevatedButton(
                    onPressed: () {
                      if(otpController.text.length==6){

                      }else{
                        errorController.add(ErrorAnimationType.shake);
                        ref.read(authControllerProvider.notifier).setError("Please enter OTP to proceed");
                      }
                    },
                    title: resetPassword,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Row(
                      children: [
                        commonTextStartAlign(title: didNotGetOTP, style: textStyle_14_400_55555A),
                        TextButton(
                          style: ButtonStyle(
                            padding: WidgetStatePropertyAll(EdgeInsets.all(0)),
                          ),
                          onPressed: () {},
                          child:commonTextStartAlign(title: resendOTP, style: textStyle_14_400_0461E5),)
                      ],
                    ),
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
