import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../widgets/multi_polygon_soldier_painter.dart';
import 'cohort_soldier.dart';
import 'soldier_design.dart';
import 'soldier_range_scales.dart';

/// Snapshot for design dialog copy (model units unless noted).
class SoldierDesignCombatSnapshot {
  const SoldierDesignCombatSnapshot({
    required this.contactZoneLabel,
    required this.contactZoneAreaModel,
    required this.attackZoneAreaModel,
    required this.attackZoneRadiusModel,
    required this.detectionZoneRadiusModel,
    required this.attacksPerSecond,
  });

  final String contactZoneLabel;
  /// Shoelace area of contact polygon, or πr² for disk fallback (model units²).
  final double contactZoneAreaModel;
  /// π × [attackZoneRadiusModel]² (model units²).
  final double attackZoneAreaModel;
  final double attackZoneRadiusModel;
  final double detectionZoneRadiusModel;
  final double attacksPerSecond;
}

double _polygonSignedArea(List<Offset> pts) {
  if (pts.length < 3) {
    return 0;
  }
  double s = 0;
  for (int i = 0; i < pts.length; i++) {
    final Offset a = pts[i];
    final Offset b = pts[(i + 1) % pts.length];
    s += a.dx * b.dy - b.dx * a.dy;
  }
  return s * 0.5;
}

Rect _axisAlignedBounds(Iterable<Offset> pts) {
  double minX = double.infinity;
  double maxX = double.negativeInfinity;
  double minY = double.infinity;
  double maxY = double.negativeInfinity;
  for (final Offset v in pts) {
    if (v.dx < minX) minX = v.dx;
    if (v.dx > maxX) maxX = v.dx;
    if (v.dy < minY) minY = v.dy;
    if (v.dy > maxY) maxY = v.dy;
  }
  return Rect.fromLTRB(minX, minY, maxX, maxY);
}

/// World-space radius used for attack/detection ring scaling (matches range painter intent).
double combatContactRadiusWorld(
  List<SoldierShapePart> parts, {
  double motionT = 0.25,
  double? attackCycleT,
}) {
  final double at =
      attackCycleT ?? MultiPolygonSoldierPainter.kAttackProbeBoundsPhase;
  final List<Offset>? hull = _contactHullVertices(parts, motionT, at);
  if (hull != null && hull.isNotEmpty) {
    final Offset? hub = _centerRoleHub(parts, motionT, at);
    if (hub != null) {
      double best = 0;
      for (final Offset v in hull) {
        best = math.max(best, (v - hub).distance);
      }
      return best;
    }
  }
  return SoldierContact.fromModel(const SoldierModel()).radius;
}

List<Offset>? _contactHullVertices(
  List<SoldierShapePart> parts,
  double motionT,
  double attackT,
) {
  for (final SoldierShapePart p in parts) {
    if (p.stackRole != SoldierPartStackRole.contact) {
      continue;
    }
    final List<Offset>? v =
        MultiPolygonSoldierPainter.transformedFillVertices(p, motionT, attackT);
    if (v != null && v.length >= 3) {
      return v;
    }
  }
  return null;
}

Offset? _centerRoleHub(
  List<SoldierShapePart> parts,
  double motionT,
  double attackT,
) {
  final List<Offset> buf = <Offset>[];
  for (final SoldierShapePart p in parts) {
    if (p.stackRole != SoldierPartStackRole.center) {
      continue;
    }
    final List<Offset>? fill =
        MultiPolygonSoldierPainter.transformedFillVertices(p, motionT, attackT);
    if (fill != null) {
      buf.addAll(fill);
    }
    final List<Offset>? stroke =
        MultiPolygonSoldierPainter.transformedStrokePolyline(p, motionT, attackT);
    if (stroke != null) {
      buf.addAll(stroke);
    }
  }
  if (buf.isEmpty) {
    return null;
  }
  double minX = buf.first.dx, maxX = buf.first.dx;
  double minY = buf.first.dy, maxY = buf.first.dy;
  for (final Offset v in buf) {
    if (v.dx < minX) minX = v.dx;
    if (v.dx > maxX) maxX = v.dx;
    if (v.dy < minY) minY = v.dy;
    if (v.dy > maxY) maxY = v.dy;
  }
  return Offset((minX + maxX) / 2, (minY + maxY) / 2);
}

const double _kCrownAttackRadiusMul = 1.32;

double? _crownAttackRadiusModel(
  List<SoldierShapePart> parts, {
  double motionT = 0.25,
  double? attackCycleT,
}) {
  final double at =
      attackCycleT ?? MultiPolygonSoldierPainter.kAttackProbeBoundsPhase;
  for (final SoldierShapePart p in parts) {
    if (p.stackRole != SoldierPartStackRole.attack) {
      continue;
    }
    if (p.motion != SoldierPartMotion.attackProbeExtend) {
      continue;
    }
    final List<Offset>? tv =
        MultiPolygonSoldierPainter.transformedFillVertices(p, motionT, at);
    if (tv == null || tv.length != 3) {
      continue;
    }
    double sx = 0, sy = 0;
    for (final Offset v in tv) {
      sx += v.dx;
      sy += v.dy;
    }
    final Offset cen = Offset(sx / 3, sy / 3);
    double best = 0;
    for (final Offset v in tv) {
      final double d = (v - cen).distance;
      if (d > best) {
        best = d;
      }
    }
    return best * _kCrownAttackRadiusMul;
  }
  return null;
}

/// Labels and radii for the design detail header.
SoldierDesignCombatSnapshot soldierDesignCombatSnapshot(SoldierDesign design) {
  final List<SoldierShapePart> parts = design.parts;
  final double motionT = 0.25;
  final double attackT = MultiPolygonSoldierPainter.kAttackProbeBoundsPhase;

  final double rContact = combatContactRadiusWorld(parts);
  final String contactLabel;
  final List<Offset>? hull =
      _contactHullVertices(parts, motionT, attackT);
  final double contactArea;
  if (hull != null && hull.length >= 3) {
    final Rect bb = _axisAlignedBounds(hull);
    contactArea = _polygonSignedArea(hull).abs();
    contactLabel =
        'trapezium · bbox ${bb.width.toStringAsFixed(0)}×${bb.height.toStringAsFixed(0)}';
  } else {
    contactArea = math.pi * rContact * rContact;
    contactLabel = 'disk · r ${rContact.toStringAsFixed(2)}';
  }

  final double? crownR = _crownAttackRadiusModel(parts);
  final double attackR = crownR ?? (rContact * kSoldierAttackRangeRadiusScale);
  final double detectR = rContact * kSoldierDetectionRangeRadiusScale;
  final double attackArea = math.pi * attackR * attackR;

  return SoldierDesignCombatSnapshot(
    contactZoneLabel: contactLabel,
    contactZoneAreaModel: contactArea,
    attackZoneAreaModel: attackArea,
    attackZoneRadiusModel: attackR,
    detectionZoneRadiusModel: detectR,
    attacksPerSecond: design.attack.displayAttacksPerSecond,
  );
}
