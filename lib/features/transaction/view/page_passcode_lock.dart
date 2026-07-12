import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:know_your_expenses/features/helper/utils.dart';

class PasscodeLockPage extends StatefulWidget {
  final Widget destination;

  const PasscodeLockPage({
    super.key,
    required this.destination,
  });

  @override
  State<PasscodeLockPage> createState() => _PasscodeLockPageState();
}

class _PasscodeLockPageState extends State<PasscodeLockPage> with TickerProviderStateMixin {
  String _pin = '';
  String? _correctPin;
  bool _isLoading = true;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _loadPin();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 10.0)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _loadPin() async {
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool('app_lock_enabled') ?? false;
    final pin = prefs.getString('app_lock_pin');

    if (!isEnabled || pin == null) {
      // If lock is disabled or no PIN is saved, bypass to destination immediately
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => widget.destination),
        );
      }
      return;
    }

    setState(() {
      _correctPin = pin;
      _isLoading = false;
    });
  }

  void _onDigitPressed(String digit) {
    if (_pin.length >= 4) return;
    setState(() {
      _pin += digit;
    });
    if (_pin.length == 4) {
      _verifyPin();
    }
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
    });
  }

  Future<void> _verifyPin() async {
    if (_pin == _correctPin) {
      // Successful unlocking!
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, _, _) => widget.destination,
            transitionDuration: const Duration(milliseconds: 500),
            transitionsBuilder: (_, animation, _, child) => FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOut,
              ),
              child: child,
            ),
          ),
        );
      }
    } else {
      // Incorrect PIN: vibrate/shake and clear input
      _shakeController.forward(from: 0.0);
      if (mounted) {
        Utils.showErrorToast(
          context,
          title: "Incorrect PIN",
          description: "The PIN you entered is incorrect. Please try again.",
        );
      }
      setState(() {
        _pin = '';
      });
    }
  }

  Widget _buildDot(int index) {
    final hasVal = index < _pin.length;
    return Container(
      width: 18,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hasVal ? Colors.white : Colors.white24,
        border: Border.all(
          color: hasVal ? Colors.white : Colors.white38,
          width: 1.5,
        ),
      ),
    );
  }

  Widget _buildKey(String val) {
    return InkWell(
      onTap: () => _onDigitPressed(val),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.08),
        ),
        child: Center(
          child: Text(
            val,
            style: GoogleFonts.manrope(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF2E7D79),
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF245E5B),
              Color(0xFF2E7D79),
              Color(0xFF429690),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Lock Header Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  size: 40,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'Enter security PIN to unlock',
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Enter the 4-digit code you set in Security settings.',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  color: Colors.white70,
                ),
              ),

              const SizedBox(height: 48),

              // Shakeable Dots
              AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) {
                  final dx = sin(_shakeAnimation.value * 2 * pi) * 8;
                  return Transform.translate(
                    offset: Offset(dx, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, _buildDot),
                    ),
                  );
                },
              ),

              const Spacer(flex: 2),

              // Keypad
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [_buildKey('1'), _buildKey('2'), _buildKey('3')],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [_buildKey('4'), _buildKey('5'), _buildKey('6')],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [_buildKey('7'), _buildKey('8'), _buildKey('9')],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        const SizedBox(width: 76),
                        _buildKey('0'),
                        SizedBox(
                          width: 76,
                          height: 76,
                          child: IconButton(
                            onPressed: _onBackspace,
                            icon: const Icon(
                              Icons.backspace_rounded,
                              size: 26,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
