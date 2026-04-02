import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:know_your_expenses/features/constants/string_constants.dart';
import 'package:know_your_expenses/features/helper/utils.dart';
import 'package:know_your_expenses/features/login_signup/view_model/view_model_login_signup.dart';

// ─── Colours (same palette) ────────────────────────────────────────────────
const _kGreen = Color(0xFF2E8B57);
const _kLightGreen = Color(0xFF3EAF78);
const _kDeepGreen = Color(0xFF1A5C3A);
const _kBlue = Color(0xFF0461E5);
const _kRed = Color(0xFFEA3636);
const _kBorder = Color(0xFFE1ECFC);
const _kBg = Color(0xFFF5F9FF);

class ForgetPasswordPage extends ConsumerStatefulWidget {
  const ForgetPasswordPage({super.key});

  @override
  ConsumerState<ForgetPasswordPage> createState() => _ForgetPasswordPageState();
}

class _ForgetPasswordPageState extends ConsumerState<ForgetPasswordPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  late AnimationController _entranceController;
  late AnimationController _iconController;

  late Animation<Offset> _headerSlide;
  late Animation<double> _headerOpacity;
  late Animation<Offset> _formSlide;
  late Animation<double> _formOpacity;
  late Animation<double> _iconScale;
  late Animation<double> _iconRotate;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _iconController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _headerSlide = Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
          ),
        );

    _headerOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _formSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
          ),
        );

    _formOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.3, 0.8, curve: Curves.easeIn),
      ),
    );

    // Lock icon bouncy scale-in
    _iconScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 1.15,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.15,
          end: 0.9,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.9,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 20,
      ),
    ]).animate(_iconController);

    _iconRotate = Tween<double>(begin: -0.15, end: 0.0).animate(
      CurvedAnimation(parent: _iconController, curve: Curves.elasticOut),
    );

    _entranceController.forward();
    Future.delayed(
      const Duration(milliseconds: 200),
      () => _iconController.forward(),
    );
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _iconController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    if (!RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$').hasMatch(v)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final success = await ref
        .read(authControllerProvider.notifier)
        .resetPassword(_emailController.text.trim());

    if (!mounted) return;

    if (success) {
      Utils.showSuccessToast(
        context,
        title: 'Email Sent!',
        description: 'A password reset link has been sent to your email.',
      );
      Navigator.pop(context);
    } else {
      Utils.showErrorToast(
        context,
        title: ref.read(authControllerProvider).error ?? 'Reset Failed',
        description: 'Please check your email and try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authControllerProvider).isLoading;

    return Scaffold(
      backgroundColor: const Color(0xFFF0FAF4),
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          // ── Gradient Header ──────────────────────────────────────────────
          SlideTransition(
            position: _headerSlide,
            child: FadeTransition(
              opacity: _headerOpacity,
              child: _Header(iconScale: _iconScale, iconRotate: _iconRotate),
            ),
          ),

          // ── Scrollable Form ──────────────────────────────────────────────
          Expanded(
            child: SlideTransition(
              position: _formSlide,
              child: FadeTransition(
                opacity: _formOpacity,
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: 32,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          forgetPass,
                          style: GoogleFonts.manrope(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1E2D2C),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          forgetPassDesc,
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                            height: 1.6,
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Info card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _kGreen.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _kGreen.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _kGreen.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.info_outline_rounded,
                                  color: _kGreen,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'We\'ll send a reset link to your registered email address.',
                                  style: GoogleFonts.manrope(
                                    fontSize: 13,
                                    color: _kDeepGreen,
                                    fontWeight: FontWeight.w500,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Email field
                        _SmartField(
                          controller: _emailController,
                          label: 'Email Address',
                          hint: 'you@example.com',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: _validateEmail,
                        ),

                        const SizedBox(height: 32),

                        // Submit button
                        _SubmitButton(isLoading: isLoading, onPressed: _submit),

                        const SizedBox(height: 20),

                        // Back to Sign In
                        Center(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.arrow_back_rounded,
                                  size: 16,
                                  color: _kGreen,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Back to Sign In',
                                  style: GoogleFonts.manrope(
                                    color: _kGreen,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final Animation<double> iconScale;
  final Animation<double> iconRotate;

  const _Header({required this.iconScale, required this.iconRotate});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(44),
            bottomRight: Radius.circular(44),
          ),
          child: Container(
            height: 200,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_kDeepGreen, _kGreen, _kLightGreen],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -30,
                  right: -30,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.07),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -20,
                  left: 20,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.06),
                    ),
                  ),
                ),
                Positioned(
                  top: 20,
                  left: 60,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.08),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: SizedBox(
            height: 200,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated lock icon
                  AnimatedBuilder(
                    animation: iconScale,
                    builder: (_, __) => Transform.scale(
                      scale: iconScale.value,
                      child: Transform.rotate(
                        angle: iconRotate.value,
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.12),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                              BoxShadow(
                                color: _kLightGreen.withOpacity(0.3),
                                blurRadius: 24,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.lock_reset_rounded,
                            size: 34,
                            color: _kGreen,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Know Your Expenses',
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Password Recovery',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white60,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Smart Field ─────────────────────────────────────────────────────────────
class _SmartField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;

  const _SmartField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.validator,
    this.keyboardType,
  });

  @override
  State<_SmartField> createState() => _SmartFieldState();
}

class _SmartFieldState extends State<_SmartField>
    with SingleTickerProviderStateMixin {
  final FocusNode _focusNode = FocusNode();
  late AnimationController _shakeController;
  late Animation<double> _shakeAnim;

  bool _isDirty = false;
  bool _hasError = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -6.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: -4.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -4.0, end: 4.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 4.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.linear));

    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    if (!_isDirty) setState(() => _isDirty = true);
    final err = widget.validator?.call(value);
    setState(() {
      _hasError = err != null;
      _errorText = err;
    });
  }

  String? _validate(String? value) {
    final err = widget.validator?.call(value);
    setState(() {
      _isDirty = true;
      _hasError = err != null;
      _errorText = err;
    });
    if (err != null) _shakeController.forward(from: 0);
    return err;
  }

  Color get _borderColor {
    if (_isDirty && _hasError) return _kRed;
    if (_isDirty && !_hasError) return _kBlue;
    if (_focusNode.hasFocus) return _kBlue.withOpacity(0.6);
    return _kBorder;
  }

  double get _borderWidth {
    if (_isDirty) return 1.8;
    if (_focusNode.hasFocus) return 1.5;
    return 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final bool isValid = _isDirty && !_hasError;

    return AnimatedBuilder(
      animation: _shakeAnim,
      builder: (_, child) => Transform.translate(
        offset: Offset(_shakeAnim.value, 0),
        child: child,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Row(
              children: [
                Text(
                  widget.label,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _isDirty && _hasError
                        ? _kRed
                        : isValid
                        ? _kGreen
                        : const Color(0xFF3A4A48),
                  ),
                ),
                if (isValid) ...[
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 14,
                    color: _kGreen,
                  ),
                ],
              ],
            ),
          ),

          // Input container
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: _isDirty && _hasError
                  ? _kRed.withOpacity(0.04)
                  : isValid
                  ? _kBlue.withOpacity(0.03)
                  : _kBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _borderColor, width: _borderWidth),
              boxShadow: (_focusNode.hasFocus || isValid)
                  ? [
                      BoxShadow(
                        color: (isValid && !_hasError ? _kBlue : _kBorder)
                            .withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                Icon(
                  widget.icon,
                  size: 20,
                  color: _isDirty && _hasError
                      ? _kRed.withOpacity(0.7)
                      : isValid
                      ? _kGreen
                      : Colors.grey.shade400,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    keyboardType: widget.keyboardType,
                    onChanged: _onChanged,
                    validator: _validate,
                    autovalidateMode: AutovalidateMode.disabled,
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF1E2D2C),
                    ),
                    decoration: InputDecoration(
                      hintText: widget.hint,
                      hintStyle: GoogleFonts.manrope(
                        fontSize: 14,
                        color: Colors.grey.shade400,
                        fontWeight: FontWeight.w400,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      errorStyle: const TextStyle(fontSize: 0, height: 0),
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                    ),
                  ),
                ),
                if (isValid)
                  const Padding(
                    padding: EdgeInsets.only(right: 14),
                    child: Icon(Icons.check_rounded, color: _kGreen, size: 18),
                  )
                else
                  const SizedBox(width: 14),
              ],
            ),
          ),

          // Error message
          AnimatedCrossFade(
            firstChild: const SizedBox(height: 0),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 13,
                    color: _kRed,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      _errorText ?? '',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: _kRed,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            crossFadeState: _hasError && _isDirty
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

// ─── Submit Button ────────────────────────────────────────────────────────────
class _SubmitButton extends StatefulWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _SubmitButton({required this.isLoading, required this.onPressed});

  @override
  State<_SubmitButton> createState() => _SubmitButtonState();
}

class _SubmitButtonState extends State<_SubmitButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, child) => Transform.scale(
        scale: widget.isLoading ? 1.0 : _pulseAnim.value,
        child: child,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: widget.isLoading ? null : widget.onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: Ink(
            decoration: BoxDecoration(
              gradient: widget.isLoading
                  ? null
                  : const LinearGradient(
                      colors: [_kDeepGreen, _kGreen, _kLightGreen],
                    ),
              color: widget.isLoading ? Colors.grey.shade300 : null,
              borderRadius: BorderRadius.circular(18),
              boxShadow: widget.isLoading
                  ? null
                  : [
                      BoxShadow(
                        color: _kGreen.withOpacity(0.4),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
            ),
            child: Container(
              alignment: Alignment.center,
              child: widget.isLoading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Send Reset Link',
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
