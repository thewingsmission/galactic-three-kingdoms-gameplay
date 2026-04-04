import 'package:flutter/material.dart';

import '../widgets/isosceles_triangle_vertices.dart';

/// Orange enemy triangle (same geometry as yellow); used by [EnemySoldiersPainter].
/// Drawn fixed in **soldier local space** (no motion vs soldier origin).
class OrangeTrianglePainter extends CustomPainter {
  OrangeTrianglePainter({
    this.side = 36,
  });

  final double side;

  static const Color _fill = Color(0xFFFF9800);
  static const Color _stroke = Colors.black;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = Offset(size.width / 2, size.height / 2);
    final List<Offset> verts = isoscelesTriangleVerticesCentroid(legLength: side);

    final Path path = Path()
      ..moveTo(c.dx + verts[0].dx, c.dy + verts[0].dy)
      ..lineTo(c.dx + verts[1].dx, c.dy + verts[1].dy)
      ..lineTo(c.dx + verts[2].dx, c.dy + verts[2].dy)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = _fill
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = _stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant OrangeTrianglePainter oldDelegate) {
    return oldDelegate.side != side;
  }
}
