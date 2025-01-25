import 'package:flutter/material.dart';
import 'dart:math';

class AtomWidget extends StatefulWidget {
  const AtomWidget({
    super.key,
    required this.color,
    this.shouldRotate = false,
    this.orbitRadius = 8.0,
    this.initialAngle = 0.0,
  });

  final Color color;
  final bool shouldRotate;
  final double orbitRadius;
  final double initialAngle;

  @override
  State<AtomWidget> createState() => _AtomWidgetState();
}

class _AtomWidgetState extends State<AtomWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.shouldRotate) {
      return _buildAtom();
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final angle = _controller.value * 2 * pi + widget.initialAngle;
        return Transform.translate(
          offset: Offset(
            widget.orbitRadius * cos(angle),
            widget.orbitRadius * sin(angle),
          ),
          child: _buildAtom(),
        );
      },
    );
  }

  Widget _buildAtom() {
    return RepaintBoundary(
      child: Container(
        width: 19,
        height: 19,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              widget.color,
              widget.color.withAlpha(179), // ~0.7 * 255
              widget.color.withAlpha(77), // ~0.3 * 255
            ],
            stops: const [0.0, 0.5, 1.0],
            center: const Alignment(-0.3, -0.3),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
