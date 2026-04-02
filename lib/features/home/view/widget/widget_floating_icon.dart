import 'package:flutter/material.dart';

class FloatingIconBubble extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double floatOffset;
  final Duration duration;

  const FloatingIconBubble({
    required this.icon,
    required this.color,
    this.floatOffset = 14.0,
    this.duration = const Duration(milliseconds: 2000),
    super.key,
  });

  @override
  State<FloatingIconBubble> createState() => _FloatingIconBubbleState();
}

class _FloatingIconBubbleState extends State<FloatingIconBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _floatAnimation;
  late Animation<double> _shadowAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(duration: widget.duration, vsync: this)
      ..repeat(reverse: true);

    _floatAnimation = Tween<double>(
      begin: 0,
      end: -widget.floatOffset,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _shadowAnimation = Tween<double>(
      begin: 0.35,
      end: 0.15,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _floatAnimation.value),
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withOpacity(_shadowAnimation.value),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: Offset(0, 8 + _floatAnimation.value.abs() * 0.3),
                ),
              ],
            ),
            child: Icon(widget.icon, size: 40, color: Colors.white),
          ),
        );
      },
    );
  }
}
