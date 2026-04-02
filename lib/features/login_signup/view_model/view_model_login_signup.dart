import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:know_your_expenses/features/home/view_model/view_model_home.dart';
import 'package:know_your_expenses/features/login_signup/model/model_auth.dart';
import 'package:know_your_expenses/features/transaction/view_model/view_model_transaction.dart';

// final errorTextProvider = StateProvider<String?>((ref) {
//   return null;
// });

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(ref),
);

class AuthController extends StateNotifier<AuthState> {
  AuthController(this.ref) : super(const AuthState());

  final Ref ref;

  FirebaseAuth get _auth => ref.read(firebaseAuthProvider);

  Future<bool> signIn(String email, String password) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = cred.user; /**/

      if (user != null && !user.emailVerified) {
        // 🔹 Resend verification email/**/
        await user.sendEmailVerification();

        state = state.copyWith(
          isLoading: false,
          error:
              "Email not verified. Verification link sent again to your email.",
        );

        return false; // ❌ Don't allow login into app
      }

      state = state.copyWith(isLoading: false, error: null);
      return true;
    } on FirebaseAuthException catch (e) {
      String message = "Something went wrong";

      if (e.code == 'invalid-credential') {
        message = "Account not found or wrong password. Please sign up.";
      } else if (e.code == 'user-not-found') {
        message = "No account found. Please sign up first.";
      } else if (e.code == 'wrong-password') {
        message = "Wrong password. Try again.";
      } else if (e.code == 'invalid-email') {
        message = "Invalid email format.";
      }

      state = state.copyWith(isLoading: false, error: message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: "Something went wrong");
      return false;
    }
  }

  Future<bool> signUp({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 🔹 Send email verification link
      await cred.user!.sendEmailVerification();

      // 🔹 Save user profile in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(cred.user!.uid)
          .set({
            'name': name,
            'email': email,
            'phone': phone,
            'createdAt': FieldValue.serverTimestamp(),
          });

      state = state.copyWith(isLoading: false);
      return true;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message ?? "Signup failed",
      );
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      print("call signIn func with google");
      final googleSignIn = GoogleSignIn();
      print("googleSignIn ---- $googleSignIn");
      final googleUser = await googleSignIn.signIn();
      print("googleUser ---- $googleUser");

      if (googleUser == null) {
        state = state.copyWith(isLoading: false, error: null);
        return false;
      }

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (!userDoc.exists) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
                'name': user.displayName ?? googleUser.displayName ?? 'Google User',
                'email': user.email ?? googleUser.email,
                'phone': '',
                'photoUrl': user.photoURL ?? googleUser.photoUrl,
                'createdAt': FieldValue.serverTimestamp(),
              });
        }
      }

      state = state.copyWith(isLoading: false, error: null);
      return true;
    } catch (e,stackTrace) {
      print("");
      print("");
      print("");
      print("");
      print("Google sign-in error: $e");        // Add this
      print("Stack trace: $stackTrace");
      print("");
      print("");
      print("");
      print("");
      state = state.copyWith(
        isLoading: false,
        error: 'Google sign-in failed. Please try again.',
      );
      return false;
    }
  }

  Future<bool> resetPassword(String email) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      await _auth.sendPasswordResetEmail(email: email);

      state = state.copyWith(isLoading: false);
      return true;
    } on FirebaseAuthException catch (e) {
      String message = "Failed to send reset email";

      if (e.code == 'user-not-found') {
        message = "No account found for this email.";
      } else if (e.code == 'invalid-email') {
        message = "Invalid email format.";
      }

      state = state.copyWith(isLoading: false, error: message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: "Something went wrong");
      return false;
    }
  }

  void setError(String error) {
    state = state.copyWith(error: error, isLoading: false);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await GoogleSignIn().signOut();
    ref.read(bottomNavIndexProvider.notifier).state = 0;
  }
}
