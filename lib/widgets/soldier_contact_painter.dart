import 'package:flutter/material.dart';

/// Contact circle (100% transparent); drawn in soldier local space, centroid at canvas center.
/// Forge2D [SoldierContactBody] still defines actual collision.
class SoldierContactPainter extends CustomPainter {
  SoldierContactPainter({
    required this.radius,
    this.strokeWidth = 2,
  });

  final double radius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = Offset(size.width / 2, size.height / 2);
    final Paint fill = Paint()
      ..color = Colors.transparent
      ..style = PaintingStyle.fill;
    final Paint stroke = Paint()
      ..color = Colors.transparent
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(c, radius, fill);
    canvas.drawCircle(c, radius, stroke);
  }

  @override
  bool shouldRepaint(covariant SoldierContactPainter oldDelegate) {
    return oldDelegate.radius != radius || oldDelegate.strokeWidth != strokeWidth;
  }
}
