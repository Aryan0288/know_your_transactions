import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:know_your_expenses/features/helper/utils.dart';

final appLockSettingsEnabledProvider = StateProvider.autoDispose<bool>((ref) => false);
final appLockSettingsSavedPinProvider = StateProvider.autoDispose<String?>((ref) => null);
final appLockSettingsLoadingProvider = StateProvider.autoDispose<bool>((ref) => true);
final appLockSettingsPinInputProvider = StateProvider.autoDispose<String>((ref) => '');

class AppLockSettingsPage extends ConsumerStatefulWidget {
  const AppLockSettingsPage({super.key});

  @override
  ConsumerState<AppLockSettingsPage> createState() => _AppLockSettingsPageState();
}

class _AppLockSettingsPageState extends ConsumerState<AppLockSettingsPage> {
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    ref.read(appLockSettingsEnabledProvider.notifier).state = prefs.getBool('app_lock_enabled') ?? false;
    ref.read(appLockSettingsSavedPinProvider.notifier).state = prefs.getString('app_lock_pin');
    ref.read(appLockSettingsLoadingProvider.notifier).state = false;
  }

  Future<void> _toggleLock(bool value) async {
    if (value) {
      // Prompt user to set a new PIN
      final newPin = await _showPinEntryDialog(
        title: 'Set 4-Digit PIN 🔒',
        message: 'Create a security PIN to secure your app access.',
      );
      if (newPin == null) return;

      final confirmPin = await _showPinEntryDialog(
        title: 'Confirm PIN 🔒',
        message: 'Re-enter your 4-digit PIN to confirm.',
      );

      if (newPin != confirmPin) {
        if (mounted) {
          Utils.showErrorToast(
            context,
            title: "PIN Mismatch",
            description: "The entered PINs do not match. Please try again.",
          );
        }
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('app_lock_enabled', true);
      await prefs.setString('app_lock_pin', newPin);

      ref.read(appLockSettingsEnabledProvider.notifier).state = true;
      ref.read(appLockSettingsSavedPinProvider.notifier).state = newPin;

      if (mounted) {
        Utils.showSuccessToast(
          context,
          title: "App Lock Enabled",
        );
      }
    } else {
      // Disabling App Lock: Ask for current PIN
      final savedPin = ref.read(appLockSettingsSavedPinProvider);
      final pin = await _showPinEntryDialog(
        title: 'Enter PIN to Disable 🔓',
        message: 'Please enter your current 4-digit PIN.',
        checkCorrectPin: savedPin,
      );

      if (pin == null) return; // cancelled or wrong PIN

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('app_lock_enabled', false);

      ref.read(appLockSettingsEnabledProvider.notifier).state = false;

      if (mounted) {
        Utils.showSuccessToast(
          context,
          title: "App Lock Disabled",
        );
      }
    }
  }

  Future<void> _changePin() async {
    // Current PIN validation
    final savedPin = ref.read(appLockSettingsSavedPinProvider);
    final currentPin = await _showPinEntryDialog(
      title: 'Current PIN',
      message: 'Please enter your current 4-digit PIN.',
      checkCorrectPin: savedPin,
    );
    if (currentPin == null) return;

    // Set new PIN
    final newPin = await _showPinEntryDialog(
      title: 'New PIN',
      message: 'Enter a new 4-digit PIN.',
    );
    if (newPin == null) return;

    // Confirm new PIN
    final confirmPin = await _showPinEntryDialog(
      title: 'Confirm New PIN',
      message: 'Re-enter your new 4-digit PIN.',
    );

    if (newPin != confirmPin) {
      if (mounted) {
        Utils.showErrorToast(
          context,
          title: "PIN Mismatch",
          description: "New PINs do not match. Please try again.",
        );
      }
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_lock_pin', newPin);

    ref.read(appLockSettingsSavedPinProvider.notifier).state = newPin;

    if (mounted) {
      Utils.showSuccessToast(
        context,
        title: "PIN Updated Successfully",
      );
    }
  }

  Future<String?> _showPinEntryDialog({
    required String title,
    required String message,
    String? checkCorrectPin,
  }) async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _PinEntryDialog(
          title: title,
          message: message,
          checkCorrectPin: checkCorrectPin,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(appLockSettingsLoadingProvider);
    final isLockEnabled = ref.watch(appLockSettingsEnabledProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F8),
      appBar: AppBar(
        title: Text(
          'App Lock Settings',
          style: GoogleFonts.manrope(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF429690),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF429690)))
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'App Security',
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E2C2B),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        SwitchListTile(
                          value: isLockEnabled,
                          onChanged: _toggleLock,
                          activeColor: const Color(0xFF429690),
                          title: Text(
                            'Passcode Lock',
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: const Color(0xFF1A2332),
                            ),
                          ),
                          subtitle: Text(
                            'Require a 4-digit PIN to open the app',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                        if (isLockEnabled) ...[
                          const Divider(height: 1, indent: 16, endIndent: 16),
                          ListTile(
                            leading: const Icon(Icons.password_rounded, color: Color(0xFF429690)),
                            title: Text(
                              'Change PIN',
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: const Color(0xFF1A2332),
                              ),
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                            onTap: _changePin,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _PinEntryDialog extends ConsumerStatefulWidget {
  final String title;
  final String message;
  final String? checkCorrectPin;

  const _PinEntryDialog({
    required this.title,
    required this.message,
    this.checkCorrectPin,
  });

  @override
  ConsumerState<_PinEntryDialog> createState() => _PinEntryDialogState();
}

class _PinEntryDialogState extends ConsumerState<_PinEntryDialog> with TickerProviderStateMixin {
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appLockSettingsPinInputProvider.notifier).state = '';
    });
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

  void _onDigitPressed(String digit) {
    final currentPin = ref.read(appLockSettingsPinInputProvider);
    if (currentPin.length >= 4) return;

    final newPin = currentPin + digit;
    ref.read(appLockSettingsPinInputProvider.notifier).state = newPin;

    if (newPin.length == 4) {
      _verifyPin(newPin);
    }
  }

  void _onBackspace() {
    final currentPin = ref.read(appLockSettingsPinInputProvider);
    if (currentPin.isEmpty) return;
    ref.read(appLockSettingsPinInputProvider.notifier).state = currentPin.substring(0, currentPin.length - 1);
  }

  Future<void> _verifyPin(String pin) async {
    if (widget.checkCorrectPin != null && pin != widget.checkCorrectPin) {
      _shakeController.forward(from: 0.0);
      Utils.showErrorToast(
        context,
        title: "Incorrect PIN",
        description: "Please enter the correct PIN code.",
      );
      ref.read(appLockSettingsPinInputProvider.notifier).state = '';
      return;
    }
    Navigator.pop(context, pin);
  }

  Widget _buildDot(int index, String pin) {
    final hasVal = index < pin.length;
    return Container(
      width: 16,
      height: 16,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hasVal ? const Color(0xFF429690) : Colors.grey[300],
        border: Border.all(
          color: hasVal ? const Color(0xFF429690) : Colors.grey[400]!,
          width: 1,
        ),
      ),
    );
  }

  Widget _buildKey(String val) {
    return InkWell(
      onTap: () => _onDigitPressed(val),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[100],
        ),
        child: Center(
          child: Text(
            val,
            style: GoogleFonts.manrope(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E2D2C),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.title,
            style: GoogleFonts.manrope(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A2332),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.message,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),

          // Dots indicator with shake
          AnimatedBuilder(
            animation: _shakeAnimation,
            builder: (context, child) {
              final dx = sin(_shakeAnimation.value * 2 * pi) * 8;
              return Transform.translate(
                offset: Offset(dx, 0),
                child: Consumer(
                  builder: (context, ref, _) {
                    final pin = ref.watch(appLockSettingsPinInputProvider);
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (index) => _buildDot(index, pin)),
                    );
                  },
                ),
              );
            },
          ),

          const SizedBox(height: 40),

          // 3x4 custom numeric keypad
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [_buildKey('1'), _buildKey('2'), _buildKey('3')],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [_buildKey('4'), _buildKey('5'), _buildKey('6')],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [_buildKey('7'), _buildKey('8'), _buildKey('9')],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  const SizedBox(width: 72),
                  _buildKey('0'),
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: IconButton(
                      onPressed: _onBackspace,
                      icon: const Icon(Icons.backspace_outlined, size: 24, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
