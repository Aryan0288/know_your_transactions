import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

class ShakeDetector {
  final void Function() onShake;
  final double shakeThreshold;
  final int shakeCooldownMs;
  final int shakeIntervalMs;

  StreamSubscription? _subscription;
  int _lastShakeTimestamp = 0;
  int _shakeCount = 0;
  int _lastEventTimestamp = 0;

  ShakeDetector({
    required this.onShake,
    this.shakeThreshold = 15.0,
    this.shakeCooldownMs = 2000,
    this.shakeIntervalMs = 500,
  });

  void startListening() {
    // Make sure we don't start duplicate listeners
    stopListening();

    _subscription = userAccelerometerEvents.listen((UserAccelerometerEvent event) {
      double acceleration = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );

      if (acceleration > shakeThreshold) {
        int now = DateTime.now().millisecondsSinceEpoch;

        // Ignore events that are too close (noise filtering)
        if (_lastEventTimestamp > 0 && now - _lastEventTimestamp < 100) {
          return;
        }
        _lastEventTimestamp = now;

        // Reset shake count if too much time has passed since last shake event
        if (now - _lastShakeTimestamp > shakeIntervalMs) {
          _shakeCount = 0;
        }

        _lastShakeTimestamp = now;
        _shakeCount++;

        // Trigger shake callback if target count reached
        if (_shakeCount >= 2) {
          _shakeCount = 0;
          onShake();
          
          // Pause listener temporarily for cooldown
          _pauseListening();
          Future.delayed(Duration(milliseconds: shakeCooldownMs), () {
            _resumeListening();
          });
        }
      }
    });
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  void _pauseListening() {
    _subscription?.pause();
  }

  void _resumeListening() {
    try {
      _subscription?.resume();
    } catch (_) {
      // Handle edge cases if stream was cancelled while paused
    }
  }
}
