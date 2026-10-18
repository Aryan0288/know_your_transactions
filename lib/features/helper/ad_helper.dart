import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdHelper {
  static String get bannerAdUnitId {
    if (kDebugMode) {
      if (Platform.isAndroid) {
        return 'ca-app-pub-3940256099942544/6300978111'; // Android Test Banner
      } else if (Platform.isIOS) {
        return 'ca-app-pub-3940256099942544/2934735716'; // iOS Test Banner
      }
    }
    // TODO: Paste production Banner Ad Unit IDs here
    if (Platform.isAndroid) {
      return 'ca-app-pub-xxxxxxxxxxxxxxxx/yyyyyyyyyy';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-xxxxxxxxxxxxxxxx/yyyyyyyyyy';
    }
    throw UnsupportedError('Unsupported platform');
  }

  static String get interstitialAdUnitId {
    if (kDebugMode) {
      if (Platform.isAndroid) {
        return 'ca-app-pub-3940256099942544/1033173712'; // Android Test Interstitial
      } else if (Platform.isIOS) {
        return 'ca-app-pub-3940256099942544/4411468910'; // iOS Test Interstitial
      }
    }
    // TODO: Paste production Interstitial Ad Unit IDs here
    if (Platform.isAndroid) {
      return 'ca-app-pub-xxxxxxxxxxxxxxxx/yyyyyyyyyy';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-xxxxxxxxxxxxxxxx/yyyyyyyyyy';
    }
    throw UnsupportedError('Unsupported platform');
  }

  static int _transactionCount = 0;
  static DateTime? _lastInterstitialShownTime;
  static const Duration _globalInterstitialCooldown = Duration(minutes: 3);

  /// Preload and display interstitial ad with global cooldown protection.
  static void showInterstitialAd(
    VoidCallback onDismissed, {
    Duration cooldown = _globalInterstitialCooldown,
    bool force = false,
  }) {
    final now = DateTime.now();
    if (!force && _lastInterstitialShownTime != null && now.difference(_lastInterstitialShownTime!) < cooldown) {
      // Cooldown active, skip ad gracefully without interrupting user flow
      onDismissed();
      return;
    }

    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _lastInterstitialShownTime = DateTime.now();
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              onDismissed();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              onDismissed();
            },
          );
          ad.show();
        },
        onAdFailedToLoad: (error) {
          onDismissed();
        },
      ),
    );
  }

  /// Increments transaction counter and shows ad only on the 5th transaction.
  /// If counter is not 5, executes [onDismissed] immediately without ad.
  static void show5thTransactionAd(VoidCallback onDismissed) {
    _transactionCount++;
    if (_transactionCount >= 5) {
      _transactionCount = 0;
      showInterstitialAd(onDismissed);
    } else {
      onDismissed();
    }
  }

  /// Shows interstitial ad for Stats with a cooldown.
  static void showStatsAdWithCooldown(VoidCallback onDismissed, {Duration cooldown = const Duration(minutes: 10)}) {
    onDismissed();
  }
}

