import 'dart:math';
import 'package:flutter/material.dart';

class GradientRingPainter extends CustomPainter {
  final double progress;
  final double gradientRotation;
  final double ballPosition;
  final bool isAnimating;

  GradientRingPainter({
    required this.progress,
    required this.gradientRotation,
    required this.ballPosition,
    required this.isAnimating,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    final strokeWidth = 10.0;

    // Background ring with subtle glow
    final backgroundPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    if (progress > 0) {
      // Enhanced gradient colors with more vibrant neon effects
      final gradientColors = [
        const Color(0xFFCDFF49), // Neon green
        const Color(0xFFFF6B35), // Orange
        const Color(0xFFFF1744), // Red
        const Color(0xFF9C27B0), // Purple
        const Color(0xFFFFEB3B), // Yellow
        const Color(0xFF00E5FF), // Electric blue
        const Color(0xFFE91E63), // Pink
        const Color(0xFFCDFF49), // Back to neon green
      ];

      // Calculate continuous rotation - multiple laps around the circle
      final sweepAngle = 2 * pi * progress;

      // Create main gradient paint
      final rect = Rect.fromCircle(center: center, radius: radius);
      // Enhanced color cycling - colors rotate continuously with progress
      final colorRotationOffset = progress * pi / 8; // Gradual color shift as progress increases

      final gradient = SweepGradient(
        colors: gradientColors,
        stops: const [0.0, 0.14, 0.28, 0.42, 0.56, 0.7, 0.84, 1.0],
        startAngle: gradientRotation + colorRotationOffset,
        endAngle: gradientRotation + colorRotationOffset + 2 * pi,
      );

      // Glow effect - outer glow
      if (isAnimating) {
        final glowPaint = Paint()
          ..shader = gradient.createShader(rect)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth + 4
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

        canvas.drawArc(
          rect,
          -pi / 2,
          sweepAngle,
          false,
          glowPaint,
        );
      }

      // Main gradient ring
      final gradientPaint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        rect,
        -pi / 2, // Start from top
        sweepAngle,
        false,
        gradientPaint,
      );

      // Inner glow effect
      if (isAnimating) {
        final innerGlowPaint = Paint()
          ..shader = gradient.createShader(rect)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth - 2
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

        canvas.drawArc(
          rect,
          -pi / 2,
          sweepAngle,
          false,
          innerGlowPaint,
        );
      }

      // Draw animated ball at the end of progress
      if (progress > 0.03) {
        final ballAngle = -pi / 2 + sweepAngle;
        final ballX = center.dx + radius * cos(ballAngle);
        final ballY = center.dy + radius * sin(ballAngle);
        final ballCenter = Offset(ballX, ballY);

        // Enhanced ball with pulsing effect
        final ballSize = isAnimating ? 6.0 + (sin(ballPosition * 4 * pi) * 1.5) : 6.0;

        // Ball outer glow
        if (isAnimating) {
          final ballGlowPaint = Paint()
            ..color = const Color(0xFFCDFF49).withValues(alpha: 0.6)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

          canvas.drawCircle(ballCenter, ballSize + 4, ballGlowPaint);
        }

        // Ball shadow
        final shadowPaint = Paint()
          ..color = Colors.black.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

        canvas.drawCircle(
          Offset(ballCenter.dx + 1, ballCenter.dy + 1),
          ballSize.toDouble(),
          shadowPaint,
        );

        // Ball gradient with animated colors
        final ballGradient = RadialGradient(
          colors: [
            Colors.white,
            const Color(0xFFCDFF49),
            isAnimating ? const Color(0xFFFF6B35) : const Color(0xFF9C27B0),
          ],
          stops: const [0.0, 0.6, 1.0],
        );

        final ballRect = Rect.fromCircle(center: ballCenter, radius: ballSize.toDouble());
        final ballPaint = Paint()
          ..shader = ballGradient.createShader(ballRect);

        canvas.drawCircle(ballCenter, ballSize.toDouble(), ballPaint);

        // Ball highlight with animation
        final highlightSize = isAnimating ? 2.0 + (sin(ballPosition * 6 * pi) * 0.5) : 2.0;
        final highlightPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.9);

        canvas.drawCircle(
          Offset(ballCenter.dx - 2, ballCenter.dy - 2),
          highlightSize.toDouble(),
          highlightPaint,
        );

        // Additional sparkle effect when animating
        if (isAnimating) {
          final sparklePaint = Paint()
            ..color = Colors.white.withValues(alpha: 0.8);

          // Small sparkles around the ball
          for (int i = 0; i < 3; i++) {
            final sparkleAngle = ballPosition * 8 * pi + (i * pi / 1.5);
            final sparkleRadius = 12 + (sin(sparkleAngle) * 3);
            final sparkleX = ballCenter.dx + sparkleRadius * cos(sparkleAngle);
            final sparkleY = ballCenter.dy + sparkleRadius * sin(sparkleAngle);

            canvas.drawCircle(
              Offset(sparkleX, sparkleY),
              (1.0 + (sin(ballPosition * 10 * pi + i) * 0.5)).toDouble(),
              sparklePaint,
            );
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant GradientRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.gradientRotation != gradientRotation ||
        oldDelegate.ballPosition != ballPosition ||
        oldDelegate.isAnimating != isAnimating;
  }
}