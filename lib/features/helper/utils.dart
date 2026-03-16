import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:toastification/toastification.dart';

class Utils {
  static void showSuccessToast(
    BuildContext context, {
    String? title,
    String? description,
  }) {
    toastification.show(
      context: context,
      type: ToastificationType.success,
      style: ToastificationStyle.fillColored, // Vibrant filled style
      autoCloseDuration: const Duration(seconds: 4),
      title: Text(
        title ?? "Success",
        style: GoogleFonts.manrope(
          fontWeight: FontWeight.w800,
          fontSize: 15,
          color: Colors.white, // High contrast
        ),
      ),
      description: description != null
          ? Text(
              description,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.9),
              ),
            )
          : null,
      alignment: Alignment.topCenter,
      direction: TextDirection.ltr,
      animationDuration: const Duration(milliseconds: 400),
      borderRadius: BorderRadius.circular(16),
      showProgressBar: true,
      progressBarTheme: ProgressIndicatorThemeData(
        color: Colors.white.withOpacity(0.6),
        linearTrackColor: Colors.black12,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.green.withOpacity(0.3),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ],
      closeButtonShowType: CloseButtonShowType.onHover,
    );
  }

  static void showErrorToast(
    BuildContext context, {
    String? title,
    String? description,
    Alignment? alignment,
  }) {
    toastification.show(
      context: context,
      type: ToastificationType.error,
      style: ToastificationStyle.fillColored, // Vibrant filled style
      autoCloseDuration: const Duration(seconds: 5),
      title: Text(
        title ?? "Error Found",
        style: GoogleFonts.manrope(
          fontWeight: FontWeight.w800,
          fontSize: 15,
          color: Colors.white, // High contrast
        ),
      ),
      description: description != null
          ? Text(
              description,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.9),
              ),
            )
          : null,
      alignment: alignment ?? Alignment.topCenter,
      direction: TextDirection.ltr,
      animationDuration: const Duration(milliseconds: 400),
      borderRadius: BorderRadius.circular(16),
      showProgressBar: true,
      progressBarTheme: ProgressIndicatorThemeData(
        color: Colors.white.withOpacity(0.6),
        linearTrackColor: Colors.black12,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.red.withOpacity(0.3),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ],
      closeButtonShowType: CloseButtonShowType.onHover,
    );
  }
}
