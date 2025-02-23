import 'package:flutter/material.dart';
import 'dart:math';

class AtomWidget extends StatelessWidget {
  final Color color;
  final bool shouldRotate;
  final int index;
  final int total;
  final double animationValue;

  const AtomWidget({
    super.key,
    required this.color,
    required this.shouldRotate,
    required this.index,
    required this.total,
    required this.animationValue,
  });

  // Helper method: determine orb size based on total count
  double _getOrbSize() {
    switch (total) {
      case 1:
      case 2:
      case 3:
        return 19.0;
      case 4:
        return 10.0;
      default:
        return 13.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final orbSize = _getOrbSize();

    if (!shouldRotate) {
      return Center(child: _buildAtom(orbSize));
    }

    final orbitalPhaseOffset = (2 * pi * index) / total;
    final orbitalAngle = animationValue + orbitalPhaseOffset;
    final orbitalRadius =
        total > 1 ? (0.95 * orbSize) / (2 * sin(pi / total)) : 0.0;

    double dx = cos(orbitalAngle) * orbitalRadius;
    double dy = sin(orbitalAngle) * orbitalRadius;

    return Transform.translate(
      offset: Offset(dx, dy),
      child: Transform.rotate(
        angle: animationValue,
        child: _buildAtom(orbSize),
      ),
    );
  }

  Widget _buildAtom(double orbSize) {
    return RepaintBoundary(
      child: Container(
        width: orbSize,
        height: orbSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: Alignment.center,
            colors: [
              color,
              color.withAlpha(179), // ~70% opacity
              color.withAlpha(77), // ~30% opacity
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
      ),
    );
  }
}
