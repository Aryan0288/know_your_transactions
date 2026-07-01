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

  // Preload and display interstitial ad
  static void showInterstitialAd(VoidCallback onDismissed) {
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
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
}
