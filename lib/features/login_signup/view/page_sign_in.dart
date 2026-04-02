import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:know_your_expenses/features/common_widgets/common_navigation.dart';
import 'package:know_your_expenses/features/common_widgets/common_widgets_png.dart';
import 'package:know_your_expenses/features/constants/string_constants.dart';
import 'package:know_your_expenses/features/helper/utils.dart';
import 'package:know_your_expenses/features/home/view/page_home.dart';
import 'package:know_your_expenses/features/login_signup/view/page_forget_password.dart';
import 'package:know_your_expenses/features/login_signup/view/page_sign_up.dart';
import 'package:know_your_expenses/features/login_signup/view_model/view_model_login_signup.dart';
import 'package:know_your_expenses/features/transaction/view_model/view_model_transaction.dart';

// ─── Colours (same palette as Sign Up) ────────────────────────────────────
const _kGreen = Color(0xFF2E8B57);
const _kLightGreen = Color(0xFF3EAF78);
const _kDeepGreen = Color(0xFF1A5C3A);
const _kBlue = Color(0xFF0461E5);
const _kRed = Color(0xFFEA3636);
const _kBorder = Color(0xFFE1ECFC);
const _kBg = Color(0xFFF5F9FF);

class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;

  late AnimationController _entranceController;
  late Animation<Offset> _headerSlide;
  late Animation<double> _headerOpacity;
  late Animation<Offset> _formSlide;
  late Animation<double> _formOpacity;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 1000),
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

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    if (!RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$').hasMatch(v)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 6) return 'Minimum 6 characters required';
    return null;
  }

  Future<void> _signInWithGoogle() async {
    final success = await ref
        .read(authControllerProvider.notifier)
        .signInWithGoogle();

    if (!mounted) return;

    ref.read(bottomNavIndexProvider.notifier).state = 0;

    if (success) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
    } else {
      final error = ref.read(authControllerProvider).error;
      if (error != null) {
        Utils.showErrorToast(context, title: error);
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref
        .read(authControllerProvider.notifier)
        .signIn(_emailController.text.trim(), _passwordController.text.trim());

    if (!mounted) return;

    ref.read(bottomNavIndexProvider.notifier).state = 0;

    if (success) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
    } else {
      Utils.showErrorToast(
        context,
        title: ref.read(authControllerProvider).error,
        description: 'Please check your credentials and try again.',
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
              child: const _Header(),
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
                    top: 28,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          'Welcome Back 👋',
                          style: GoogleFonts.manrope(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1E2D2C),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sign in to continue tracking your expenses.',
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Google button
                        _GoogleButton(onTap: _signInWithGoogle),

                        const SizedBox(height: 24),

                        // Divider
                        Row(
                          children: [
                            Expanded(
                              child: Divider(color: Colors.grey.shade300),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(
                                'or',
                                style: GoogleFonts.manrope(
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(color: Colors.grey.shade300),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Email field
                        _SmartField(
                          controller: _emailController,
                          label: 'Email Address',
                          hint: 'you@example.com',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: _validateEmail,
                        ),

                        const SizedBox(height: 14),

                        // Password field
                        _SmartField(
                          controller: _passwordController,
                          label: 'Password',
                          hint: 'Your password',
                          icon: Icons.lock_outline_rounded,
                          obscureText: _obscurePassword,
                          validator: _validatePassword,
                          suffixWidget: GestureDetector(
                            onTap: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            child: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: Colors.grey.shade400,
                              size: 20,
                            ),
                          ),
                        ),

                        // Forgot password
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => CustomNavigation.to(
                              context,
                              ForgetPasswordPage(),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 8,
                              ),
                            ),
                            child: Text(
                              forgetPassword,
                              style: GoogleFonts.manrope(
                                color: _kGreen,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Submit button
                        _SubmitButton(isLoading: isLoading, onPressed: _submit),

                        const SizedBox(height: 20),

                        // Sign up link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Don't have an account? ",
                              style: GoogleFonts.manrope(
                                color: Colors.grey.shade500,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => CustomNavigation.to(
                                context,
                                const SignUpPage(),
                              ),
                              child: Text(
                                signUp,
                                style: GoogleFonts.manrope(
                                  color: _kGreen,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
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
  const _Header();

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
                  Container(
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
                      ],
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 34,
                      color: _kGreen,
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
                    'Spend Smarter • Save More',
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

// ─── Google Button ────────────────────────────────────────────────────────────
class _GoogleButton extends ConsumerWidget {
  final VoidCallback onTap;

  const _GoogleButton({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(authControllerProvider).isLoading;

    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(PngImages.googlePng, width: 22),
            const SizedBox(width: 12),
            Text(
              'Continue with Google',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E2D2C),
              ),
            ),
          ],
        ),
      ),
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
  final bool obscureText;
  final Widget? suffixWidget;
  const _SmartField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.suffixWidget,
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
    if (_isDirty && (_hasError || !_hasError)) return 1.8;
    if (_focusNode.hasFocus) return 2;
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
                        color: (isValid && !_hasError ? _kBlue : _kBorder).withOpacity(0.15),
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
                    obscureText: widget.obscureText,
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
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w400,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      counter: const SizedBox.shrink(),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      errorStyle: const TextStyle(fontSize: 0, height: 0),
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                    ),
                  ),
                ),
                if (widget.suffixWidget != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: widget.suffixWidget!,
                  )
                else if (isValid)
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
                          logIn,
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
                            Icons.arrow_forward_rounded,
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
