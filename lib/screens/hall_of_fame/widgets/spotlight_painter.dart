import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Custom painter for animated spotlight effects
class SpotlightPainter extends CustomPainter {
  final double animationValue; // 0.0 to 1.0
  final int spotlightCount;

  SpotlightPainter({
    required this.animationValue,
    this.spotlightCount = 3,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Create multiple spotlight beams
    for (int i = 0; i < spotlightCount; i++) {
      _drawSpotlight(
        canvas,
        size,
        i,
        spotlightCount,
      );
    }
  }

  void _drawSpotlight(Canvas canvas, Size size, int index, int total) {
    // Calculate spotlight position with animation
    final offsetX = (size.width / (total + 1)) * (index + 1);
    final sweepOffset = math.sin(animationValue * 2 * math.pi + index) * 50;

    // Spotlight gradient (cone shape)
    final spotlight = RadialGradient(
      center: Alignment.topCenter,
      radius: 1.5,
      colors: [
        Colors.amber.withOpacity(0.15),
        Colors.amber.withOpacity(0.08),
        Colors.amber.withOpacity(0.03),
        Colors.transparent,
      ],
      stops: const [0.0, 0.3, 0.6, 1.0],
    );

    final rect = Rect.fromLTWH(
      offsetX + sweepOffset - 100,
      -50,
      200,
      size.height + 100,
    );

    final paint = Paint()
      ..shader = spotlight.createShader(rect)
      ..style = PaintingStyle.fill;

    // Draw spotlight beam
    final path = Path();
    path.moveTo(offsetX + sweepOffset, 0);
    path.lineTo(offsetX + sweepOffset - 80, size.height);
    path.lineTo(offsetX + sweepOffset + 80, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(SpotlightPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

/// Glass reflection effect painter
class GlassReflectionPainter extends CustomPainter {
  final Color glassColor;

  GlassReflectionPainter({
    this.glassColor = Colors.white,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Top reflection (bright)
    final topReflection = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.center,
      colors: [
        glassColor.withOpacity(0.2),
        glassColor.withOpacity(0.05),
        Colors.transparent,
      ],
      stops: const [0.0, 0.5, 1.0],
    );

    final topRect = Rect.fromLTWH(0, 0, size.width, size.height * 0.3);
    final topPaint = Paint()
      ..shader = topReflection.createShader(topRect)
      ..style = PaintingStyle.fill;

    canvas.drawRect(topRect, topPaint);

    // Edge highlight
    final edgePath = Path();
    edgePath.moveTo(0, size.height * 0.1);
    edgePath.quadraticBezierTo(
      size.width * 0.5,
      size.height * 0.05,
      size.width,
      size.height * 0.1,
    );

    final edgePaint = Paint()
      ..color = glassColor.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawPath(edgePath, edgePaint);
  }

  @override
  bool shouldRepaint(GlassReflectionPainter oldDelegate) => false;
}

/// Trophy shine effect painter
class TrophyShinePainter extends CustomPainter {
  final double animationValue; // 0.0 to 1.0
  final Color shineColor;

  TrophyShinePainter({
    required this.animationValue,
    this.shineColor = const Color(0xFFFFD700),
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Animated shine sweep across the trophy
    final sweepX = size.width * animationValue;

    // Create shine gradient
    final shineGradient = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        Colors.transparent,
        shineColor.withOpacity(0.4),
        shineColor.withOpacity(0.6),
        shineColor.withOpacity(0.4),
        Colors.transparent,
      ],
      stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
    );

    final shineRect = Rect.fromLTWH(
      sweepX - 60,
      0,
      120,
      size.height,
    );

    final shinePaint = Paint()
      ..shader = shineGradient.createShader(shineRect)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);

    canvas.drawRect(shineRect, shinePaint);

    // Add sparkle points
    _drawSparkles(canvas, size, sweepX);
  }

  void _drawSparkles(Canvas canvas, Size size, double centerX) {
    final sparklePaint = Paint()
      ..color = shineColor.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    // Random sparkle positions relative to shine position
    final sparkles = [
      Offset(centerX - 20, size.height * 0.2),
      Offset(centerX + 10, size.height * 0.4),
      Offset(centerX - 5, size.height * 0.6),
      Offset(centerX + 25, size.height * 0.3),
    ];

    for (final sparkle in sparkles) {
      // Only draw sparkles that are visible
      if (sparkle.dx >= 0 && sparkle.dx <= size.width) {
        _drawStar(canvas, sparkle, 3, sparklePaint);
      }
    }
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    const points = 4; // 4-point star

    for (int i = 0; i < points * 2; i++) {
      final angle = (i * math.pi / points) - math.pi / 2;
      final r = i.isEven ? radius : radius / 2;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(TrophyShinePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

/// Animated background gradient painter
class MuseumBackgroundPainter extends CustomPainter {
  final double animationValue;

  MuseumBackgroundPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    // Animated radial gradient for dynamic background
    final gradient = RadialGradient(
      center: Alignment(
        math.sin(animationValue * 2 * math.pi) * 0.5,
        math.cos(animationValue * 2 * math.pi) * 0.5,
      ),
      radius: 1.5,
      colors: [
        const Color(0xFF1A1A2E),
        const Color(0xFF0F0F1E),
        const Color(0xFF0A0A0A),
      ],
      stops: const [0.0, 0.5, 1.0],
    );

    final paint = Paint()
      ..shader = gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Add subtle noise/texture effect
    _drawNoisePattern(canvas, size);
  }

  void _drawNoisePattern(Canvas canvas, Size size) {
    final noisePaint = Paint()
      ..color = Colors.white.withOpacity(0.02)
      ..style = PaintingStyle.fill;

    final random = math.Random(42); // Fixed seed for consistent pattern

    for (int i = 0; i < 100; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 2;

      canvas.drawCircle(Offset(x, y), radius, noisePaint);
    }
  }

  @override
  bool shouldRepaint(MuseumBackgroundPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
