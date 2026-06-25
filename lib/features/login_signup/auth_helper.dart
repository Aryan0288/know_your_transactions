import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Web client ID from Firebase (client_type 3 in google-services.json).
/// Required on Android so Google Sign-In returns an idToken for Firebase Auth.
const kGoogleWebClientId =
    '89507154805-kvcse5h6nsskmncosjvejjqi1il1ace4.apps.googleusercontent.com';

GoogleSignIn createGoogleSignIn() => GoogleSignIn(
      serverClientId: kGoogleWebClientId,
    );

bool isGoogleUser(User user) =>
    user.providerData.any((provider) => provider.providerId == 'google.com');

/// Email/password users must verify email; Google users are already verified by Google.
bool isAppAccessGranted(User user) =>
    user.emailVerified || isGoogleUser(user);
