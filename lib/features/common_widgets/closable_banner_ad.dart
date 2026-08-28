import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:know_your_expenses/features/helper/ad_helper.dart';

class ClosableBannerAd extends StatefulWidget {
  final AdSize adSize;
  const ClosableBannerAd({super.key, this.adSize = AdSize.banner});

  @override
  State<ClosableBannerAd> createState() => _ClosableBannerAdState();
}

class _ClosableBannerAdState extends State<ClosableBannerAd> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  bool _isAdClosed = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    _bannerAd = BannerAd(
      adUnitId: AdHelper.bannerAdUnitId,
      size: widget.adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) {
            setState(() {
              _isAdLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isAdClosed || _bannerAd == null || !_isAdLoaded) {
      return const SizedBox.shrink();
    }

    return Container(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          AdWidget(ad: _bannerAd!),
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: () {
                if (mounted) {
                  setState(() {
                    _isAdClosed = true;
                  });
                }
                _bannerAd?.dispose();
                _bannerAd = null;
              },
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(4),
                child: const Icon(Icons.close, color: Colors.white, size: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
