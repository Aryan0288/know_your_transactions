import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'common_colors.dart';

/// Common Text
Text commonTextStartAlign({
  required String title,
  required TextStyle style,
  TextAlign textAlign = TextAlign.start,
}) {
  return Text(
    title,
    style: style,
    textAlign: textAlign,
    textDirection: TextDirection.ltr,
  );
}

Text commonTextCenterAlign({required String title, required TextStyle style}) {
  return Text(title, style: style, textAlign: TextAlign.center);
}

/// Common TextStyle
TextStyle get headingTextStyle => TextStyle(
  fontSize: 24,
  fontWeight: .w800,
  fontFamily: manRope,
  color: textColor_0461E5,
);

TextStyle get headingTextStyle_438883 =>
    TextStyle(fontSize: 28, fontFamily: manRopeBold, color: textColor_438883);

TextStyle get textStyle_14_400_55555A => TextStyle(
  fontSize: 14,
  fontWeight: .w400,
  fontFamily: manRope,
  color: textColor_55555A,
);

TextStyle get textStyle_12_400_55555A => TextStyle(
  fontSize: 12,
  fontWeight: .w400,
  fontFamily: manRope,
  color: textColor_55555A,
);

TextStyle get textStyle_14_400_0461E5 => TextStyle(
  fontSize: 14,
  fontWeight: .w400,
  fontFamily: manRope,
  color: textColor_0461E5,
);

TextStyle get textStyle_14_700_72788C => TextStyle(
  fontSize: 16,
  fontWeight: .w700,
  fontFamily: manRope,
  color: textColor_72788C,
);

TextStyle get textStyle_14_600_181636 => TextStyle(
  fontSize: 16,
  fontWeight: .w700,
  fontFamily: manRope,
  color: textColor_181636,
);

TextStyle get textFieldEnteredTextStyle => TextStyle(
  color: textColor_181636,
  fontSize: 16,
  fontFamily: manRope,
  fontWeight: FontWeight.w500,
);

TextStyle get textFieldHintTextStyle => TextStyle(
  color: textColor_55555A,
  fontSize: 16,
  fontFamily: manRope,
  fontWeight: FontWeight.w500,
);

TextStyle get textFieldErrorTextStyle => TextStyle(
  color: textTypographyError,
  fontSize: 14,
  fontFamily: manRope,
  fontWeight: FontWeight.w500,
);

TextStyle get appBarTitleTextStyle => TextStyle(
  color: textColor_181636,
  fontSize: 14,
  fontFamily: manRopeSemiBold,
  fontWeight: FontWeight.w600,
);

TextStyle get errorTextStyle_w500 => TextStyle(
  color: textColor_EA3636,
  fontSize: 14,
  fontFamily: manRopeMedium,
  fontWeight: FontWeight.w500,
);

/// height and width
SizedBox hs(double height) {
  return SizedBox(height: height);
}

SizedBox ws(double width) {
  return SizedBox(width: width);
}

/// Elevated Button
Widget elevatedButton({
  required VoidCallback? onPressed,
  required String title,
  Color? color,
  Key? key,
  Widget? icon,
  bool isShowShadow = true,
  Color? shadowColor,
  double? borderRadius,
  bool isLoading = false,
}) => Container(
  width: double.infinity,
  height: 52,
  decoration: isShowShadow
      ? BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: shadowColor ?? Color(0xFFBFC5FE),
              spreadRadius: 0,
              blurRadius: 4,
              offset: const Offset(0, 0),
            ),
          ],
        )
      : BoxDecoration(),
  child: ElevatedButton(
    key: const ValueKey('CupertinoBtn'),
    style: ElevatedButton.styleFrom(
      shadowColor: Color(0xFFBFC5FE),
      elevation: 4,
      backgroundColor: color ?? elevatedBtnBackGroundColor,
      disabledBackgroundColor: disabledColor,
      foregroundColor: elevatedBtnForGroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
    ),
    onPressed: isLoading
        ? null
        : () {
            if (FocusManager.instance.primaryFocus != null) {
              FocusManager.instance.primaryFocus!.unfocus();
            }
            onPressed?.call();
          },
    child: isLoading
        ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon ?? SizedBox(),
              Text(
                title,
                textAlign: TextAlign.start,
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: manRopeMedium,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
  ),
);
