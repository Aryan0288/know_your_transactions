import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomDialogs {
  static void showSignInRequiredDialog(
    BuildContext context, {
    required VoidCallback onSignInTap,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28.0),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: _awesomeDialogContent(
            context,
            title: "Sign In Required",
            description:
                "To keep your expenses organized and synced, you need to sign in first.",
            icon: Icons.lock_person_rounded,
            primaryButtonText: "Sign In Now",
            onPrimaryButtonPressed: () {
              Navigator.pop(context);
              onSignInTap();
            },
            secondaryButtonText: "Maybe Later",
            onSecondaryButtonPressed: () {
              Navigator.pop(context);
            },
            color: const Color(0xFF429690),
          ),
        );
      },
    );
  }

  static void showEmailVerificationDialog(
    BuildContext context, {
    required User user,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28.0),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: _awesomeDialogContent(
            context,
            title: "Verify Your Email",
            description:
                "We've sent a verification link to ${user.email}. Please check your inbox (and spam folder) to verify your email.",
            icon: Icons.mark_email_unread_rounded,
            primaryButtonText: "Resend Email",
            onPrimaryButtonPressed: () async {
              try {
                await user.sendEmailVerification();
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Verification email sent!"),
                      backgroundColor: Color(0xFF429690),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Error: ${e.toString()}"),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            },
            secondaryButtonText: "I'll do it later",
            onSecondaryButtonPressed: () {
              Navigator.pop(context);
            },
            color: Colors.orangeAccent,
          ),
        );
      },
    );
  }

  static void showLogoutDialog(
    BuildContext context, {
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28.0),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: _awesomeDialogContent(
            context,
            title: "Logout?",
            description: "Are you sure you want to log out of your account?",
            icon: Icons.logout_rounded,
            primaryButtonText: "Logout",
            onPrimaryButtonPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            secondaryButtonText: "Cancel",
            onSecondaryButtonPressed: () {
              Navigator.pop(context);
            },
            color: const Color(0xFFE57373),
          ),
        );
      },
    );
  }

  static void showLeaveGroupDialog(
    BuildContext context, {
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28.0),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: _awesomeDialogContent(
            context,
            title: "Leave Group?",
            description: "Are you sure you want to leave this group? Your shared ledger access will be removed.",
            icon: Icons.exit_to_app_rounded,
            primaryButtonText: "Leave Group",
            onPrimaryButtonPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            secondaryButtonText: "Cancel",
            onSecondaryButtonPressed: () {
              Navigator.pop(context);
            },
            color: const Color(0xFFE57373),
          ),
        );
      },
    );
  }

  static void showDiscardSmsDialog(
    BuildContext context, {
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28.0),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: _awesomeDialogContent(
            context,
            title: "Discard Expense?",
            description:
                "Are you sure you want to delete this auto-detected expense? This action cannot be undone.",
            icon: Icons.delete_outline_rounded,
            primaryButtonText: "Delete",
            onPrimaryButtonPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            secondaryButtonText: "Cancel",
            onSecondaryButtonPressed: () {
              Navigator.pop(context);
            },
            color: const Color(0xFFE57373),
          ),
        );
      },
    );
  }

  static void showSignupSuccessDialog(
    BuildContext context, {
    required VoidCallback onOkPressed,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28.0),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: _awesomeDialogContent(
            context,
            title: "Account Created!",
            description:
                "We've sent a verification link to your email.\n\nPlease check your inbox (and spam folder) to verify your account before signing in.",
            icon: Icons.mark_email_unread_rounded,
            primaryButtonText: "Continue to Sign In",
            onPrimaryButtonPressed: () {
              Navigator.pop(context);
              onOkPressed();
            },
            color: const Color(0xFF429690),
          ),
        );
      },
    );
  }

  static void showErrorDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28.0),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: _awesomeDialogContent(
            context,
            title: title,
            description: message,
            icon: Icons.error_outline_rounded,
            primaryButtonText: "OK",
            onPrimaryButtonPressed: () {
              Navigator.pop(context);
            },
            color: const Color(0xFFE57373),
          ),
        );
      },
    );
  }

  static Widget _awesomeDialogContent(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required String primaryButtonText,
    required VoidCallback onPrimaryButtonPressed,
    String? secondaryButtonText,
    VoidCallback? onSecondaryButtonPressed,
    required Color color,
  }) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final isSmallScreen = screenWidth < 360;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 380,
          maxHeight: mediaQuery.size.height * 0.85,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 18 : 24,
            vertical: isSmallScreen ? 22 : 28,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 14 : 18),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: color.withOpacity(0.2), width: 2),
                  ),
                  child: Icon(icon, size: isSmallScreen ? 32 : 38, color: color),
                ),
                SizedBox(height: isSmallScreen ? 14 : 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: isSmallScreen ? 19 : 22,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E1E1E),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: isSmallScreen ? 13 : 14.5,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
                SizedBox(height: isSmallScreen ? 20 : 26),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final hasSecondary = secondaryButtonText != null && onSecondaryButtonPressed != null;
                    final shouldStack = isSmallScreen || constraints.maxWidth < 270;

                    if (shouldStack && hasSecondary) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton(
                            onPressed: onPrimaryButtonPressed,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: color,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              primaryButtonText,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.manrope(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: onSecondaryButtonPressed,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(color: Colors.grey[300]!),
                              ),
                            ),
                            child: Text(
                              secondaryButtonText,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.manrope(
                                fontSize: 15,
                                color: const Color(0xFF1E1E1E),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        if (hasSecondary) ...[
                          Expanded(
                            child: TextButton(
                              onPressed: onSecondaryButtonPressed,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(color: Colors.grey[300]!),
                                ),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  secondaryButtonText,
                                  style: GoogleFonts.manrope(
                                    fontSize: 14.5,
                                    color: const Color(0xFF1E1E1E),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: ElevatedButton(
                            onPressed: onPrimaryButtonPressed,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: color,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                primaryButtonText,
                                style: GoogleFonts.manrope(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFF429690),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Text(
                    message,
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E1E1E),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
