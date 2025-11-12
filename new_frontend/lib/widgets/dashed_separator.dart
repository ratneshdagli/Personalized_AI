import 'package:flutter/material.dart';

// Horizontal dashed separator to match Figma dashed timeline rows.
class DashedSeparator extends StatelessWidget {
  final Color color;
  final double dashWidth;
  final double dashGap;
  final double thickness;
  const DashedSeparator({super.key, this.color = const Color(0x33FFFFFF), this.dashWidth = 6, this.dashGap = 6, this.thickness = 1});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedPainter(color, dashWidth, dashGap, thickness),
      size: const Size(double.infinity, 1),
    );
  }
}

class _DashedPainter extends CustomPainter {
  final Color color;
  final double dashWidth;
  final double dashGap;
  final double thickness;
  _DashedPainter(this.color, this.dashWidth, this.dashGap, this.thickness);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness;
    double x = 0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(x + dashWidth, y), paint);
      x += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
