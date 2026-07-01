import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:know_your_expenses/features/home/view/widget/widget_floating_icon.dart';
import 'package:know_your_expenses/features/common_widgets/common_widgets_png.dart';
import 'package:know_your_expenses/features/transaction/view/page_expense_transaction.dart';
import 'package:know_your_expenses/features/common_widgets/closable_banner_ad.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _shimmerController;

  late Animation<Offset> _heroSlide;
  late Animation<double> _heroOpacity;
  late Animation<Offset> _cardSlide;
  late Animation<double> _cardOpacity;
  late Animation<Offset> _btnSlide;
  late Animation<double> _btnOpacity;

  late List<IconData> randomIcons;
  late List<Color> randomColors;

  static const _green = Color(0xFF2E8B57);
  static const _lightGreen = Color(0xFF3EAF78);
  static const _darkGreen = Color(0xFF1A5C3A);

  @override
  void initState() {
    super.initState();

    randomIcons = _getRandomIcons();
    randomColors = _getRandomColors();

    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _shimmerController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    // Hero image slides up from bottom
    _heroSlide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
          ),
        );

    _heroOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    // Feature cards slide up
    _cardSlide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: const Interval(0.35, 0.75, curve: Curves.easeOut),
          ),
        );

    _cardOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.35, 0.65, curve: Curves.easeIn),
      ),
    );

    // Button slides up last
    _btnSlide = Tween<Offset>(begin: const Offset(0, 0.6), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
          ),
        );

    _btnOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.6, 0.9, curve: Curves.easeIn),
      ),
    );

    _entranceController.forward();
  }

  List<IconData> _getRandomIcons() {
    final icons = [
      Icons.rocket_launch_rounded,
      Icons.auto_awesome_rounded,
      Icons.local_fire_department_rounded,
      Icons.bolt_rounded,
      Icons.diamond_rounded,
      Icons.workspace_premium_rounded,
      Icons.stars_rounded,
      Icons.whatshot_rounded,
    ];
    icons.shuffle();
    return icons.take(2).toList();
  }

  List<Color> _getRandomColors() {
    final colors = [
      const Color(0xFF6366F1),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFFF59E0B),
      const Color(0xFF10B981),
    ];
    colors.shuffle();
    return colors.take(2).toList();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF0FAF4),
      body: Stack(
        children: [
          // Background gradient blobs
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _green.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            bottom: 160,
            left: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _lightGreen.withOpacity(0.08),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ─── Hero Section ───
                Expanded(
                  flex: 6,
                  child: SlideTransition(
                    position: _heroSlide,
                    child: FadeTransition(
                      opacity: _heroOpacity,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Curved green background
                          ClipPath(
                            clipper: _WaveClipper(),
                            child: Container(
                              width: double.infinity,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [_darkGreen, _green, _lightGreen],
                                ),
                              ),
                              child: Stack(
                                children: [
                                  // Subtle pattern circles inside header
                                  Positioned(
                                    top: 10,
                                    left: -30,
                                    child: Container(
                                      width: 160,
                                      height: 160,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white.withOpacity(0.05),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: -40,
                                    right: 40,
                                    child: Container(
                                      width: 100,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white.withOpacity(0.06),
                                      ),
                                    ),
                                  ),
                                  // Background home image
                                  Align(
                                    alignment: Alignment.topCenter,
                                    child: Image.asset(
                                      PngImages.homePageBackPng,
                                      fit: BoxFit.fitWidth,
                                      width: size.width,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Man image (foreground)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: -10,
                            child: Image.asset(
                              PngImages.homePageManPng,
                              height: size.height * 0.42,
                              fit: BoxFit.contain,
                            ),
                          ),

                          // Floating icon left
                          Positioned(
                            left: 24,
                            top: 0,
                            bottom: 120,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FloatingIconBubble(
                                icon: randomIcons[0],
                                color: randomColors[0],
                                floatOffset: 16,
                                duration: const Duration(milliseconds: 2200),
                              ),
                            ),
                          ),

                          // Floating icon right
                          Positioned(
                            right: 24,
                            top: 0,
                            bottom: 60,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: FloatingIconBubble(
                                icon: randomIcons[1],
                                color: randomColors[1],
                                floatOffset: 12,
                                duration: const Duration(milliseconds: 1800),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ─── Bottom Content ───
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Heading
                        SlideTransition(
                          position: _cardSlide,
                          child: FadeTransition(
                            opacity: _cardOpacity,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Spend Smarter,',
                                  style: GoogleFonts.manrope(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF1E1E1E),
                                    height: 1.2,
                                  ),
                                ),
                                ShaderMask(
                                  shaderCallback: (bounds) =>
                                      const LinearGradient(
                                        colors: [_green, _lightGreen],
                                      ).createShader(bounds),
                                  child: Text(
                                    'Save More! 💰',
                                    style: GoogleFonts.manrope(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Track every rupee, build better habits,\nand reach your financial goals.',
                                  style: GoogleFonts.manrope(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade600,
                                    height: 1.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Feature chips
                        SlideTransition(
                          position: _cardSlide,
                          child: FadeTransition(
                            opacity: _cardOpacity,
                            child: Row(
                              children: [
                                _FeatureChip(
                                  icon: Icons.track_changes_rounded,
                                  label: 'Track',
                                  color: const Color(0xFF6366F1),
                                ),
                                const SizedBox(width: 10),
                                _FeatureChip(
                                  icon: Icons.insights_rounded,
                                  label: 'Analyse',
                                  color: _green,
                                ),
                                const SizedBox(width: 10),
                                _FeatureChip(
                                  icon: Icons.savings_rounded,
                                  label: 'Save',
                                  color: const Color(0xFFF59E0B),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      // ─── Bottom Button ───
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ClosableBannerAd(),
          SlideTransition(
            position: _btnSlide,
            child: FadeTransition(
              opacity: _btnOpacity,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
                child: _GetStartedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddExpensePageHomePage(),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Wave Clipper ───
class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 40);
    path.quadraticBezierTo(
      size.width * 0.25,
      size.height + 20,
      size.width * 0.5,
      size.height - 10,
    );
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height - 40,
      size.width,
      size.height - 10,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

// ─── Feature Chip ───
class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _FeatureChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Get Started Button ───
class _GetStartedButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _GetStartedButton({required this.onPressed});

  @override
  State<_GetStartedButton> createState() => _GetStartedButtonState();
}

class _GetStartedButtonState extends State<_GetStartedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(
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
      animation: _pulseAnimation,
      builder: (_, child) =>
          Transform.scale(scale: _pulseAnimation.value, child: child),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40),
            gradient: const LinearGradient(
              colors: [Color(0xFF1A5C3A), Color(0xFF2E8B57), Color(0xFF3EAF78)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2E8B57).withOpacity(0.45),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Get Started',
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
