import 'package:flutter/material.dart';

class VerticalDashedDivider extends StatelessWidget {
  final double dashHeight;
  final double dashSpacing;
  final Color color;
  final double width;
  final bool isHorizontal;

  const VerticalDashedDivider({
    Key? key,
    this.dashHeight = 4.0,
    this.dashSpacing = 3.0,
    this.color = Colors.grey,
    this.width = 1.0,
    this.isHorizontal = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: DashedLinePainter(
        color: color,
        dashHeight: dashHeight,
        dashSpacing: dashSpacing,
        strokeWidth: width,
        isHorizontal: isHorizontal,
      ),
      child: isHorizontal
          ? Container(height: width, width: double.infinity)
          : Container(width: width, height: double.infinity),
    );
  }
}

class DashedLinePainter extends CustomPainter {
  final Color color;
  final double dashHeight;
  final double dashSpacing;
  final double strokeWidth;
  final bool isHorizontal;

  DashedLinePainter({
    required this.color,
    required this.dashHeight,
    required this.dashSpacing,
    required this.strokeWidth,
    required this.isHorizontal,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    if (isHorizontal) {
      // Draw horizontal dashed line
      double startX = 0;
      final y = size.height / 2;

      while (startX < size.width) {
        canvas.drawLine(
          Offset(startX, y),
          Offset(startX + dashHeight, y),
          paint,
        );
        startX += dashHeight + dashSpacing;
      }
    } else {
      // Draw vertical dashed line
      double startY = 0;
      final x = size.width / 2;

      while (startY < size.height) {
        canvas.drawLine(
          Offset(x, startY),
          Offset(x, startY + dashHeight),
          paint,
        );
        startY += dashHeight + dashSpacing;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate != this;
  }
}