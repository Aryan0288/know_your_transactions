import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../model/version_config_model.dart';

class ForceUpdatePage extends StatefulWidget {
  final VersionConfigModel config;

  const ForceUpdatePage({super.key, required this.config});

  @override
  State<ForceUpdatePage> createState() => _ForceUpdatePageState();
}

class _ForceUpdatePageState extends State<ForceUpdatePage>
    with TickerProviderStateMixin {
  late AnimationController _particleController;
  late AnimationController _ringController;
  late AnimationController _cardController;
  late AnimationController _buttonController;

  late Animation<double> _ringScale;
  late Animation<double> _ringOpacity;
  late Animation<double> _cardScale;
  late Animation<double> _cardOpacity;
  late Animation<Offset> _cardSlide;
  late Animation<double> _buttonScale;


  @override
  void initState() {
    super.initState();

    _particleController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _ringController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat();

    _cardController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _ringScale = Tween<double>(begin: 0.8, end: 2.5).animate(
      CurvedAnimation(parent: _ringController, curve: Curves.easeOut),
    );

    _ringOpacity = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(parent: _ringController, curve: Curves.easeOut),
    );

    _cardScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _cardController, curve: Curves.elasticOut),
    );

    _cardOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _cardController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _cardSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _cardController, curve: Curves.easeOut),
    );

    _buttonScale = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeInOut),
    );

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _cardController.forward();
    });
  }

  @override
  void dispose() {
    _particleController.dispose();
    _ringController.dispose();
    _cardController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  Future<void> _launchPlayStore() async {
    await _buttonController.forward();
    await _buttonController.reverse();

    final uri = Uri.parse(widget.config.playStoreUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildParticle(int index, Size size) {
    final random = Random(index * 17);
    final startX = random.nextDouble() * size.width;
    final startY = random.nextDouble() * size.height;
    final radius = 3.0 + random.nextDouble() * 5;
    final speed = 0.3 + random.nextDouble() * 0.7;
    final phase = random.nextDouble();

    return AnimatedBuilder(
      animation: _particleController,
      builder: (_, _) {
        final t = (_particleController.value + phase) % 1.0;
        final dy = -60 * t * speed;
        final opacity = (1.0 - t).clamp(0.0, 1.0) * 0.4;
        return Positioned(
          left: startX,
          top: startY + dy,
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: radius,
              height: radius,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return PopScope(
      canPop: false, // Block Android back button
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1A5C3A),
                Color(0xFF2E8B57),
                Color(0xFF3EAF78),
                Color(0xFF52C98A),
              ],
              stops: [0.0, 0.35, 0.70, 1.0],
            ),
          ),
          child: Stack(
            children: [
              // Floating particles (same as splash)
              ...List.generate(12, (i) => _buildParticle(i, size)),

              // Decorative circle — top right
              Positioned(
                top: -60,
                right: -60,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
              Positioned(
                top: -20,
                right: -20,
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),

              // Decorative circle — bottom left
              Positioned(
                bottom: -80,
                left: -80,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),

              // Main content
              Center(
                child: AnimatedBuilder(
                  animation: _cardController,
                  builder: (_, child) => Opacity(
                    opacity: _cardOpacity.value,
                    child: Transform.scale(
                      scale: _cardScale.value,
                      child: SlideTransition(
                        position: _cardSlide,
                        child: child,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 36,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        color: Colors.white.withValues(alpha: 0.13),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 40,
                            spreadRadius: 0,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Pulsing icon
                          SizedBox(
                            width: 130,
                            height: 130,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                AnimatedBuilder(
                                  animation: _ringController,
                                  builder: (_, _) => Transform.scale(
                                    scale: _ringScale.value,
                                    child: Container(
                                      width: 90,
                                      height: 90,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: _ringOpacity.value,
                                          ),
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.12),
                                        blurRadius: 30,
                                        spreadRadius: 4,
                                        offset: const Offset(0, 8),
                                      ),
                                      BoxShadow(
                                        color: const Color(
                                          0xFF52C98A,
                                        ).withValues(alpha: 0.5),
                                        blurRadius: 40,
                                        spreadRadius: 8,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.system_update_rounded,
                                    size: 52,
                                    color: Color(0xFF2E8B57),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 28),

                          // Title
                          Text(
                            'Update Available',
                            style: GoogleFonts.manrope(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 8),

                          // Subtitle badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: Colors.white.withValues(alpha: 0.18),
                            ),
                            child: Text(
                              'A newer version is ready for you',
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.9),
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Divider
                          Container(
                            height: 1,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Colors.white.withValues(alpha: 0.3),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Update message from Firestore
                          Text(
                            widget.config.updateMessage,
                            style: GoogleFonts.manrope(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withValues(alpha: 0.85),
                              height: 1.6,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 32),

                          // Update Now button
                          AnimatedBuilder(
                            animation: _buttonController,
                            builder: (_, child) => Transform.scale(
                              scale: _buttonScale.value,
                              child: child,
                            ),
                            child: GestureDetector(
                              onTap: _launchPlayStore,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF1A5C3A,
                                      ).withValues(alpha: 0.35),
                                      blurRadius: 20,
                                      spreadRadius: 0,
                                      offset: const Offset(0, 8),
                                    ),
                                    BoxShadow(
                                      color: Colors.white.withValues(alpha: 0.5),
                                      blurRadius: 10,
                                      spreadRadius: -4,
                                      offset: const Offset(0, -2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.rocket_launch_rounded,
                                      color: Color(0xFF1A5C3A),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Update Now',
                                      style: GoogleFonts.manrope(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF1A5C3A),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Fine print
                          Text(
                            'You must update to continue using the app',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withValues(alpha: 0.55),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
