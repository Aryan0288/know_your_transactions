import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomDialogs {
  static void showSignInRequiredDialog(BuildContext context, {required VoidCallback onSignInTap}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.0)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: _awesomeDialogContent(
            context,
            title: "Sign In Required",
            description: "To keep your expenses organized and synced, you need to sign in first.",
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

  static void showEmailVerificationDialog(BuildContext context, {required User user}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.0)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: _awesomeDialogContent(
            context,
            title: "Verify Your Email",
            description: "We've sent a verification link to **${user.email}**. Please verify your email to access all features.",
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

  static void showLogoutDialog(BuildContext context, {required VoidCallback onConfirm}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.0)),
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

  static Widget _awesomeDialogContent(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required String primaryButtonText,
    required VoidCallback onPrimaryButtonPressed,
    required String secondaryButtonText,
    required VoidCallback onSecondaryButtonPressed,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.2), width: 2),
            ),
            child: Icon(
              icon,
              size: 40,
              color: color,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: GoogleFonts.manrope(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E1E1E),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 16,
              color: Colors.grey[600],
              height: 1.6,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: onSecondaryButtonPressed,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                  child: Text(
                    secondaryButtonText,
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      color: const Color(0xFF1E1E1E),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: onPrimaryButtonPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    primaryButtonText,
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
