import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Custom painter for animated sync progress ring
///
/// Renders a glowing progress ring around the center circle during sync operations
/// Supports both indeterminate (connecting) and determinate (progress) modes
class SyncProgressRingPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final double animationValue; // For indeterminate animation
  final bool isIndeterminate; // True for connecting state
  final Color startColor;
  final Color endColor;
  final double strokeWidth;

  SyncProgressRingPainter({
    required this.progress,
    required this.animationValue,
    this.isIndeterminate = false,
    this.startColor = const Color(0xFF2759FF),
    this.endColor = const Color(0xFFCDFF49),
    this.strokeWidth = 6.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - (strokeWidth / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    if (isIndeterminate) {
      // Indeterminate mode: Rotating arc
      _paintIndeterminateArc(canvas, rect);
    } else {
      // Determinate mode: Progress arc with gradient
      _paintProgressArc(canvas, rect);
    }

    // Add glow effect
    _paintGlow(canvas, center, radius);
  }

  void _paintIndeterminateArc(Canvas canvas, Rect rect) {
    // Background circle (very subtle)
    final backgroundPaint = Paint()
      ..color = startColor.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(rect.center, rect.width / 2, backgroundPaint);

    // Rotating arc (120 degrees)
    final arcPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          startColor.withValues(alpha: 0.0),
          startColor,
          endColor,
          endColor.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.3, 0.7, 1.0],
        transform: GradientRotation(animationValue * 2 * math.pi),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Draw rotating arc
    const sweepAngle = math.pi * 2 / 3; // 120 degrees
    final startAngle = -math.pi / 2 + (animationValue * 2 * math.pi);

    canvas.drawArc(
      rect,
      startAngle,
      sweepAngle,
      false,
      arcPaint,
    );
  }

  void _paintProgressArc(Canvas canvas, Rect rect) {
    // Background circle
    final backgroundPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(rect.center, rect.width / 2, backgroundPaint);

    // Progress arc with gradient
    if (progress > 0) {
      final progressPaint = Paint()
        ..shader = SweepGradient(
          colors: [
            startColor,
            Color.lerp(startColor, endColor, 0.5)!,
            endColor,
          ],
          stops: const [0.0, 0.5, 1.0],
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      // Draw progress arc
      const startAngle = -math.pi / 2; // Start from top
      final sweepAngle = 2 * math.pi * progress;

      canvas.drawArc(
        rect,
        startAngle,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  void _paintGlow(Canvas canvas, Offset center, double radius) {
    // Only add glow effect when there's progress or animation
    if (progress > 0 || isIndeterminate) {
      final glowPaint = Paint()
        ..color = endColor.withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 1.5;

      canvas.drawCircle(center, radius, glowPaint);
    }
  }

  @override
  bool shouldRepaint(SyncProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.isIndeterminate != isIndeterminate;
  }
}
