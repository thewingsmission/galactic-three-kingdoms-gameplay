import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/soldier_design.dart';
import 'multi_polygon_soldier_painter.dart';

/// Largest [uniformWorldToPixel] such that **every** design in [designs] fits in [panel]
/// with padding [pad] — same world→px for all soldiers so relative model sizes match on screen.
double soldierIdleUniformWorldToPixel(
  Size panel,
  Iterable<SoldierDesign> designs, {
  double pad = 8,
}) {
  final List<SoldierDesign> list = designs is List<SoldierDesign>
      ? designs
      : designs.toList();
  if (list.isEmpty) {
    return 1.0;
  }
  final double aw = math.max(1e-6, panel.width - 2 * pad);
  final double ah = math.max(1e-6, panel.height - 2 * pad);
  double sigma = double.infinity;
  for (final SoldierDesign d in list) {
    final ({double width, double height}) b =
        MultiPolygonSoldierPainter.modelBoundingSize(
      parts: d.parts,
      motionT: 0.25,
      attackCycleT: MultiPolygonSoldierPainter.kAttackProbeBoundsPhase,
    );
    final double s = math.min(aw / b.width, ah / b.height);
    if (s < sigma) {
      sigma = s;
    }
  }
  return sigma.isFinite ? sigma : 1.0;
}
