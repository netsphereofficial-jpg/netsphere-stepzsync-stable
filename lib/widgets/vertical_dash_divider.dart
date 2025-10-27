import 'package:flutter/material.dart';

class VerticalDashedDivider extends StatelessWidget {
  final double dashHeight;
  final double dashSpacing;
  final double width;
  final Color color;

  const VerticalDashedDivider({
    Key? key,
    this.dashHeight = 4.0,
    this.dashSpacing = 4.0,
    this.width = 2.0,
    this.color = Colors.grey,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: CustomPaint(
        painter: VerticalDashedPainter(
          dashHeight: dashHeight,
          dashSpacing: dashSpacing,
          color: color,
        ),
        size: Size(width, double.infinity),
      ),
    );
  }
}

class VerticalDashedPainter extends CustomPainter {
  final double dashHeight;
  final double dashSpacing;
  final Color color;

  VerticalDashedPainter({
    required this.dashHeight,
    required this.dashSpacing,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = size.width;

    final double totalDashSpace = dashHeight + dashSpacing;
    final int dashCount = (size.height / totalDashSpace).floor();

    for (int i = 0; i < dashCount; i++) {
      final double startY = i * totalDashSpace;
      final double endY = startY + dashHeight;
      
      if (endY <= size.height) {
        canvas.drawLine(
          Offset(size.width / 2, startY),
          Offset(size.width / 2, endY),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}