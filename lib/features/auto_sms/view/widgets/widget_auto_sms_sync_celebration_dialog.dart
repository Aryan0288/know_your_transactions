import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Non-blocking floating celebration toast + confetti particle burst for Auto-SMS sync.
/// Celebrates successful 30-day SMS sync without interrupting user dashboard interactions.
class WidgetAutoSmsCelebrationOverlay {
  static OverlayEntry? _activeEntry;

  /// Shows an animated, non-modal floating celebration banner with confetti particle burst.
  /// Automatically dismisses after ~2.8s without blocking the user.
  static void show(
    BuildContext context, {
    required int addedCount,
    required int skippedCount,
    required double totalIncome,
    required double totalExpense,
  }) {
    try {
      HapticFeedback.mediumImpact();
      _activeEntry?.remove();
      _activeEntry = null;

      final overlayState = Overlay.of(context, rootOverlay: true);

      late OverlayEntry entry;
      entry = OverlayEntry(
        builder: (ctx) => _CelebrationOverlayView(
          addedCount: addedCount,
          skippedCount: skippedCount,
          totalIncome: totalIncome,
          totalExpense: totalExpense,
          onDismiss: () {
            try {
              entry.remove();
            } catch (_) {}
            if (_activeEntry == entry) {
              _activeEntry = null;
            }
          },
        ),
      );

      _activeEntry = entry;
      overlayState.insert(entry);
    } catch (e) {
      debugPrint('[WidgetAutoSmsCelebrationOverlay] Error displaying celebration overlay: $e');
    }
  }
}

/// Backward-compatible alias for existing call sites.
class WidgetAutoSmsSyncCelebrationDialog {
  static void show(
    BuildContext context, {
    required int addedCount,
    required int skippedCount,
    required double totalIncome,
    required double totalExpense,
  }) {
    WidgetAutoSmsCelebrationOverlay.show(
      context,
      addedCount: addedCount,
      skippedCount: skippedCount,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
    );
  }
}

class _CelebrationOverlayView extends StatefulWidget {
  final int addedCount;
  final int skippedCount;
  final double totalIncome;
  final double totalExpense;
  final VoidCallback onDismiss;

  const _CelebrationOverlayView({
    required this.addedCount,
    required this.skippedCount,
    required this.totalIncome,
    required this.totalExpense,
    required this.onDismiss,
  });

  @override
  State<_CelebrationOverlayView> createState() => _CelebrationOverlayViewState();
}

class _CelebrationOverlayViewState extends State<_CelebrationOverlayView>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _confettiController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  Timer? _autoDismissTimer;

  final List<_ConfettiParticle> _particles = [];
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();

    // 1. Entrance & Exit animation for the center celebration banner
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      reverseDuration: const Duration(milliseconds: 250),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInBack,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );

    // 2. Confetti Particle Animation
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..forward();

    _initConfetti();
    _entranceController.forward();

    // 3. Auto-dismiss after 2.8s
    _autoDismissTimer = Timer(const Duration(milliseconds: 2800), () {
      _dismiss();
    });
  }

  void _initConfetti() {
    final colors = [
      const Color(0xFF429690),
      const Color(0xFF2E8B57),
      const Color(0xFFFFB300),
      const Color(0xFFFF7043),
      const Color(0xFF42A5F5),
      const Color(0xFFAB47BC),
      const Color(0xFF26A69A),
    ];

    for (int i = 0; i < 70; i++) {
      final angle = -pi / 2 + (_rng.nextDouble() - 0.5) * (pi * 1.1);
      final speed = 260 + _rng.nextDouble() * 380;
      _particles.add(
        _ConfettiParticle(
          x: 0,
          y: 0,
          vx: cos(angle) * speed,
          vy: sin(angle) * speed,
          color: colors[_rng.nextInt(colors.length)],
          size: 6 + _rng.nextDouble() * 6,
          rotation: _rng.nextDouble() * 2 * pi,
          rotationSpeed: (_rng.nextDouble() - 0.5) * 8,
          isCircle: _rng.nextBool(),
        ),
      );
    }
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    _autoDismissTimer?.cancel();
    try {
      await _entranceController.reverse();
    } catch (_) {}
    if (mounted) {
      widget.onDismiss();
    }
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _entranceController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: amount % 1 == 0 ? 0 : 2,
    );
    return formatter.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final hasNew = widget.addedCount > 0;

    return SafeArea(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Confetti Layer (Non-blocking)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _confettiController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _ConfettiPainter(
                      particles: _particles,
                      progress: _confettiController.value,
                    ),
                  );
                },
              ),
            ),
          ),

          // 2. Floating Center Celebration Card
          Align(
            alignment: const Alignment(0, -0.15),
            child: GestureDetector(
              onTap: _dismiss,
              child: AnimatedBuilder(
                animation: _entranceController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: child,
                    ),
                  );
                },
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                    constraints: const BoxConstraints(maxWidth: 360),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFF429690).withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF429690).withValues(alpha: 0.22),
                          blurRadius: 28,
                          offset: const Offset(0, 10),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Icon + Header Row
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF429690), Color(0xFF2E8B57)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF429690).withValues(alpha: 0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.auto_awesome_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Congratulations! 🎉',
                                    style: GoogleFonts.manrope(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF1A2332),
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    hasNew
                                        ? 'Your transactions fetched successfully!'
                                        : 'Your transactions are already up to date!',
                                    style: GoogleFonts.manrope(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF429690),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Inflow / Outflow Pill (only if there are new transactions)
                        if (hasNew && (widget.totalIncome > 0 || widget.totalExpense > 0)) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                if (widget.totalIncome > 0)
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.arrow_downward_rounded,
                                        color: Color(0xFF2E7D32),
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Inflow: ${_formatCurrency(widget.totalIncome)}',
                                        style: GoogleFonts.manrope(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF2E7D32),
                                        ),
                                      ),
                                    ],
                                  ),
                                if (widget.totalIncome > 0 && widget.totalExpense > 0)
                                  Container(
                                    width: 1,
                                    height: 14,
                                    color: Colors.grey[300],
                                  ),
                                if (widget.totalExpense > 0)
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.arrow_upward_rounded,
                                        color: Color(0xFFC62828),
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Outflow: ${_formatCurrency(widget.totalExpense)}',
                                        style: GoogleFonts.manrope(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFFC62828),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ],
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

class _ConfettiParticle {
  double x;
  double y;
  double vx;
  double vy;
  final Color color;
  final double size;
  double rotation;
  final double rotationSpeed;
  final bool isCircle;

  _ConfettiParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.size,
    required this.rotation,
    required this.rotationSpeed,
    required this.isCircle,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;

  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0 || progress == 1) return;

    final origin = Offset(size.width / 2, size.height * 0.4);
    final dt = progress;
    final gravity = 420.0;

    for (final p in particles) {
      final currentX = origin.dx + p.vx * dt;
      final currentY = origin.dy + p.vy * dt + 0.5 * gravity * dt * dt;
      final currentRot = p.rotation + p.rotationSpeed * dt;
      final alpha = (1.0 - dt * 0.9).clamp(0.0, 1.0);

      final particlePaint = Paint()
        ..style = PaintingStyle.fill
        ..color = p.color.withValues(alpha: alpha);

      canvas.save();
      canvas.translate(currentX, currentY);
      canvas.rotate(currentRot);

      if (p.isCircle) {
        canvas.drawCircle(Offset.zero, p.size / 2, particlePaint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
          particlePaint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}
