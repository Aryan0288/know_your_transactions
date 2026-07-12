import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ConnectivityWrapper extends StatefulWidget {
  final Widget child;

  const ConnectivityWrapper({
    super.key,
    required this.child,
  });

  @override
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper> {
  bool _isConnected = true;
  late StreamSubscription<dynamic> _subscription;
  final Connectivity _connectivity = Connectivity();

  @override
  void initState() {
    super.initState();
    _checkInitialConnectivity();
    _subscribeToConnectivity();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  Future<void> _checkInitialConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateStatus(result);
    } catch (_) {
      // Fallback
    }
  }

  void _subscribeToConnectivity() {
    _subscription = _connectivity.onConnectivityChanged.listen((dynamic result) {
      _updateStatus(result);
    });
  }

  void _updateStatus(dynamic result) {
    List<ConnectivityResult> results = [];
    if (result is List) {
      results = List<ConnectivityResult>.from(result);
    } else if (result is ConnectivityResult) {
      results = [result];
    }

    final hasInternet = results.isNotEmpty && !results.contains(ConnectivityResult.none);
    if (hasInternet != _isConnected) {
      setState(() {
        _isConnected = hasInternet;
      });
    }
  }

  Future<void> _retryConnection() async {
    // Show manual check
    try {
      final result = await _connectivity.checkConnectivity();
      _updateStatus(result);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (!_isConnected)
          Positioned.fill(
            child: _OfflineOverlay(
              onRetry: _retryConnection,
            ),
          ),
      ],
    );
  }
}

class _OfflineOverlay extends StatefulWidget {
  final Future<void> Function() onRetry;

  const _OfflineOverlay({required this.onRetry});

  @override
  State<_OfflineOverlay> createState() => _OfflineOverlayState();
}

class _OfflineOverlayState extends State<_OfflineOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _handleRetry() async {
    if (_isChecking) return;
    setState(() {
      _isChecking = true;
    });

    // Artificially delay slightly for smooth visual feedback
    await Future.delayed(const Duration(milliseconds: 1000));
    await widget.onRetry();

    if (mounted) {
      setState(() {
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent physical back button pop
      child: Scaffold(
        backgroundColor: const Color(0xFF1E2D2C), // Deep background color matches our main UI
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Pulsing glowing Lost Connection Icon
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFE57373).withOpacity(0.1),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE57373).withOpacity(0.2),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.wifi_off_rounded,
                        size: 64,
                        color: Color(0xFFEF5350),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 48),

                // Title
                Text(
                  'Connection Lost',
                  style: GoogleFonts.manrope(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),

                // Subtitle
                Text(
                  "Oops! Your internet connection is gone.\nCheck your connection and let's try again.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    color: Colors.white70,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 48),

                // Retry Button
                GestureDetector(
                  onTap: _handleRetry,
                  child: Container(
                    height: 54,
                    width: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(27),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF3AAFA9),
                          Color(0xFF2F7E79),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3AAFA9).withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _isChecking
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Try Again',
                              style: GoogleFonts.manrope(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
