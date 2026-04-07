import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/soldier_design.dart';
import '../models/soldier_range_scales.dart';
import 'multi_polygon_soldier_painter.dart';

/// War scene: simple circles. Detail dialog: pass [detailStableModelAnchor] matching
/// [MultiPolygonSoldierPainter.fixedModelAnchor] so dot / detection / attack rings track model
/// geometry instead of the shifting live bbox center. **Detection** radius =
/// [kSoldierDetectionRadiusModelUnits] (200 model units, universal player + enemy).
class SoldierRangeRingsPainter extends CustomPainter {
  SoldierRangeRingsPainter({
    required this.contactRadius,
    this.attackScale = kSoldierAttackRangeRadiusScale,
    this.detailParts,
    this.detailMotionT,
    this.detailAttackCycleT,
    this.detailUniformSigma,
    this.detailStableModelAnchor,
    this.detailRangePlotHubModel,
    this.crownVfxMode = CrownVfxMode.none,
  });

  /// World-space contact radius (e.g. from [SoldierContact.fromModel]).
  final double contactRadius;
  final double attackScale;
  final CrownVfxMode crownVfxMode;
  /// When set with [detailMotionT], [detailAttackCycleT], [detailUniformSigma], draws
  /// soldier-aligned contact + dynamic crown attack disc.
  final List<SoldierShapePart>? detailParts;
  final double? detailMotionT;
  final double? detailAttackCycleT;
  final double? detailUniformSigma;
  /// Same model point as [MultiPolygonSoldierPainter.fixedModelAnchor] — stable map origin so
  /// overlays don’t slide when the live bbox centroid shifts (wings / crown).
  final Offset? detailStableModelAnchor;
  /// When set, hub dot / detection center use this model point ([SoldierDesign.rangePlotHubModel]).
  final Offset? detailRangePlotHubModel;

  static const double _crownAttackRadiusMul = 1.32;
  /// Hide crown attack disk while [MultiPolygonSoldierPainter.attackProbeEnvelope] is near zero.
  static const double _kAttackDiskMinEnvelope = 0.02;

  bool get _useDetailOverlay =>
      detailParts != null &&
      detailParts!.isNotEmpty &&
      detailUniformSigma != null &&
      detailMotionT != null &&
      detailAttackCycleT != null;

  /// Pixels per world unit so the **attack** ring fits inside [size] (legacy / fallback).
  static double worldToPixelScale(
    Size size,
    double contactRadius, {
    double attackScale = kSoldierAttackRangeRadiusScale,
    double fitT = 0.90,
  }) {
    final double maxR = contactRadius * attackScale;
    final double fitR = math.min(size.width, size.height) / 2 * fitT;
    return fitR / maxR;
  }

  static void _accumulateVerts(
    List<Offset>? verts,
    void Function(Offset) add,
  ) {
    if (verts == null) return;
    for (final Offset v in verts) {
      add(v);
    }
  }

  static bool _collectRolePoints(
    List<SoldierShapePart> parts,
    Set<SoldierPartStackRole> roles,
    double motionT,
    double attackT,
    List<Offset> outPts,
  ) {
    outPts.clear();
    for (final SoldierShapePart p in parts) {
      if (!roles.contains(p.stackRole)) continue;
      _accumulateVerts(
        MultiPolygonSoldierPainter.transformedFillVertices(p, motionT, attackT),
        outPts.add,
      );
      _accumulateVerts(
        MultiPolygonSoldierPainter.transformedStrokePolyline(p, motionT, attackT),
        outPts.add,
      );
    }
    return outPts.isNotEmpty;
  }

  static bool _axisBounds(
    List<Offset> pts,
    void Function(double minX, double maxX, double minY, double maxY) out,
  ) {
    if (pts.isEmpty) return false;
    double minX = pts.first.dx, maxX = pts.first.dx;
    double minY = pts.first.dy, maxY = pts.first.dy;
    for (final Offset v in pts) {
      if (v.dx < minX) minX = v.dx;
      if (v.dx > maxX) maxX = v.dx;
      if (v.dy < minY) minY = v.dy;
      if (v.dy > maxY) maxY = v.dy;
    }
    out(minX, maxX, minY, maxY);
    return true;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (_useDetailOverlay) {
      _paintDetailOverlay(canvas, size);
    } else {
      _paintLegacyCircles(canvas, size);
    }
  }

  void _paintDetailOverlay(Canvas canvas, Size size) {
    final List<SoldierShapePart> parts = detailParts!;
    final double motionT = detailMotionT!;
    final double attackT = detailAttackCycleT!;
    final double sigma = detailUniformSigma!;

    final List<Offset> all = <Offset>[];
    for (final SoldierShapePart p in parts) {
      if (p.stackRole == SoldierPartStackRole.contact ||
          p.stackRole == SoldierPartStackRole.target ||
          p.stackRole == SoldierPartStackRole.engagement ||
          p.stackRole == SoldierPartStackRole.hitZone) {
        continue;
      }
      _accumulateVerts(
        MultiPolygonSoldierPainter.transformedFillVertices(p, motionT, attackT),
        all.add,
      );
      _accumulateVerts(
        MultiPolygonSoldierPainter.transformedStrokePolyline(p, motionT, attackT),
        all.add,
      );
    }

    if (all.isEmpty) {
      _paintLegacyCircles(canvas, size);
      return;
    }

    double minX = all.first.dx, maxX = all.first.dx;
    double minY = all.first.dy, maxY = all.first.dy;
    for (final Offset v in all) {
      if (v.dx < minX) minX = v.dx;
      if (v.dx > maxX) maxX = v.dx;
      if (v.dy < minY) minY = v.dy;
      if (v.dy > maxY) maxY = v.dy;
    }

    final Offset c = Offset(size.width / 2, size.height / 2);
    final double bx;
    final double by;
    if (detailStableModelAnchor != null) {
      bx = detailStableModelAnchor!.dx;
      by = detailStableModelAnchor!.dy;
    } else {
      bx = (minX + maxX) / 2;
      by = (minY + maxY) / 2;
    }

    Offset toScreen(Offset m) =>
        Offset(c.dx + (m.dx - bx) * sigma, c.dy + (m.dy - by) * sigma);

    final List<Offset> roleBuf = <Offset>[];

    double colMinX = 0, colMaxX = 0, colMinY = 0, colMaxY = 0;
    final bool hasCollisionHull = _collectRolePoints(
          parts,
          <SoldierPartStackRole>{
            SoldierPartStackRole.body,
            SoldierPartStackRole.center,
          },
          motionT,
          attackT,
          roleBuf,
        ) &&
        _axisBounds(roleBuf, (double a, double b, double d, double e) {
          colMinX = a;
          colMaxX = b;
          colMinY = d;
          colMaxY = e;
        });

    final double colCx = (colMinX + colMaxX) / 2;
    final double colCy = (colMinY + colMaxY) / 2;
    final double colMw = colMaxX - colMinX;
    final double colMh = colMaxY - colMinY;

    final Path trap;
    List<Offset>? explicitContact;
    for (final SoldierShapePart p in parts) {
      if (p.stackRole != SoldierPartStackRole.contact) {
        continue;
      }
      explicitContact =
          MultiPolygonSoldierPainter.transformedFillVertices(p, motionT, attackT);
      if (explicitContact != null && explicitContact.length >= 3) {
        break;
      }
    }
    if (explicitContact != null && explicitContact.length >= 3) {
      final List<Offset> hull = explicitContact;
      final Offset s0 = toScreen(hull.first);
      trap = Path()..moveTo(s0.dx, s0.dy);
      for (int i = 1; i < hull.length; i++) {
        final Offset s = toScreen(hull[i]);
        trap.lineTo(s.dx, s.dy);
      }
      trap.close();
    } else {
      double trapWb;
      double trapWt;
      double trapHh;
      if (hasCollisionHull) {
        trapWb = colMw * 0.46 * 0.5;
        trapWt = colMw * 0.24 * 0.5;
        trapHh = colMh * 0.38 * 0.5;
      } else {
        final double mw = maxX - minX;
        final double mh = maxY - minY;
        trapWb = mw * 0.46 * 0.5;
        trapWt = mw * 0.24 * 0.5;
        trapHh = mh * 0.38 * 0.5;
      }
      final double trapBx = hasCollisionHull ? colCx : (minX + maxX) / 2;
      final double trapBy = hasCollisionHull ? colCy : (minY + maxY) / 2;

      final Offset t0 = toScreen(Offset(trapBx - trapWb, trapBy + trapHh));
      final Offset t1 = toScreen(Offset(trapBx + trapWb, trapBy + trapHh));
      final Offset t2 = toScreen(Offset(trapBx + trapWt, trapBy - trapHh));
      final Offset t3 = toScreen(Offset(trapBx - trapWt, trapBy - trapHh));
      trap = Path()
        ..moveTo(t0.dx, t0.dy)
        ..lineTo(t1.dx, t1.dy)
        ..lineTo(t2.dx, t2.dy)
        ..lineTo(t3.dx, t3.dy)
        ..close();
    }

    final double conStroke = math.max(
      2.0,
      math.min(
        5.2,
        math.min(
              hasCollisionHull ? colMw : (maxX - minX),
              hasCollisionHull ? colMh : (maxY - minY),
            ) *
            sigma *
            0.08,
      ),
    );
    canvas.drawPath(
      trap,
      Paint()
        ..color = const Color(0xFF00C853).withValues(alpha: 0.92)
        ..style = PaintingStyle.stroke
        ..strokeWidth = conStroke
        ..strokeJoin = StrokeJoin.round,
    );

    // --- Target zone polygon (contact × 1.5) ---
    for (final SoldierShapePart p in parts) {
      if (p.stackRole != SoldierPartStackRole.target) continue;
      final List<Offset>? tv =
          MultiPolygonSoldierPainter.transformedFillVertices(p, motionT, attackT);
      if (tv == null || tv.length < 3) continue;
      final Path targetPath = Path();
      final Offset t0 = toScreen(tv.first);
      targetPath.moveTo(t0.dx, t0.dy);
      for (int i = 1; i < tv.length; i++) {
        final Offset ts = toScreen(tv[i]);
        targetPath.lineTo(ts.dx, ts.dy);
      }
      targetPath.close();
      final double targetStroke = math.max(1.5, conStroke * 0.75);
      canvas.drawPath(
        targetPath,
        Paint()
          ..color = const Color(0xFFFF6D00).withValues(alpha: 0.75)
          ..style = PaintingStyle.stroke
          ..strokeWidth = targetStroke
          ..strokeJoin = StrokeJoin.round,
      );
      break;
    }

    // --- Engagement zone annulus (two circles centered on hub) ---
    for (final SoldierShapePart p in parts) {
      if (p.stackRole != SoldierPartStackRole.engagement) continue;
      final List<Offset>? ev =
          MultiPolygonSoldierPainter.transformedFillVertices(p, motionT, attackT);
      if (ev == null || ev.length < 3) continue;
      final Offset hubModel = detailRangePlotHubModel ?? Offset(bx, by);
      double minDist = double.infinity;
      double maxDist = 0;
      for (final Offset v in ev) {
        final double d = (v - hubModel).distance;
        if (d < minDist) minDist = d;
        if (d > maxDist) maxDist = d;
      }
      final Offset hubScr = toScreen(hubModel);
      final double innerPx = minDist * sigma;
      final double outerPx = maxDist * sigma;
      final double engStroke = math.max(1.5, conStroke * 0.75);
      final Paint engPaint = Paint()
        ..color = const Color(0xFF9C27B0).withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = engStroke;
      canvas.drawCircle(hubScr, outerPx, engPaint);
      canvas.drawCircle(hubScr, innerPx, engPaint);
      break;
    }

    // --- Hit zone polygons ---
    for (final SoldierShapePart p in parts) {
      if (p.stackRole != SoldierPartStackRole.hitZone) continue;
      final List<Offset>? hv =
          MultiPolygonSoldierPainter.transformedFillVertices(p, motionT, attackT);
      if (hv == null || hv.length < 3) continue;
      final Path hitPath = Path();
      final Offset h0 = toScreen(hv.first);
      hitPath.moveTo(h0.dx, h0.dy);
      for (int i = 1; i < hv.length; i++) {
        final Offset hs = toScreen(hv[i]);
        hitPath.lineTo(hs.dx, hs.dy);
      }
      hitPath.close();
      final double hitStroke = math.max(1.5, conStroke * 0.65);
      canvas.drawPath(
        hitPath,
        Paint()
          ..color = const Color(0xFF1B5E20).withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = hitStroke
          ..strokeJoin = StrokeJoin.round,
      );
    }

    Offset? crownCentroid;
    double crownCircumR = 0;
    for (final SoldierShapePart p in parts) {
      if (p.stackRole != SoldierPartStackRole.attack) continue;
      if (p.motion != SoldierPartMotion.attackProbeExtend) continue;
      final List<Offset>? tv =
          MultiPolygonSoldierPainter.transformedFillVertices(p, motionT, attackT);
      if (tv == null || tv.length != 3) continue;
      double sx = 0, sy = 0;
      for (final Offset v in tv) {
        sx += v.dx;
        sy += v.dy;
      }
      final Offset cen = Offset(sx / 3, sy / 3);
      double best = 0;
      for (final Offset v in tv) {
        final double d = (v - cen).distance;
        if (d > best) best = d;
      }
      crownCentroid = cen;
      crownCircumR = best * _crownAttackRadiusMul;
      break;
    }

    final double attackEnv =
        MultiPolygonSoldierPainter.attackProbeEnvelope(attackT);

    if (crownCentroid != null && attackEnv > _kAttackDiskMinEnvelope) {
      final Offset ac = toScreen(crownCentroid);
      double ar = crownCircumR * sigma;
      if (crownVfxMode == CrownVfxMode.scalingCrown) {
        ar *= (1.0 + 2.0 * attackEnv) * 0.55;
      }
      final double atkStroke = math.max(2.0, math.min(5.0, ar * 0.18));
      canvas.drawCircle(
        ac,
        ar,
        Paint()
          ..color = const Color(0xFF1B5E20).withValues(alpha: 0.92)
          ..style = PaintingStyle.stroke
          ..strokeWidth = atkStroke,
      );
    }

    final double sWorld =
        worldToPixelScale(size, contactRadius, attackScale: attackScale);
    final double detectionPx =
        kSoldierDetectionRadiusModelUnits * sigma;

    Offset hubScreen = c;
    if (detailRangePlotHubModel != null) {
      hubScreen = toScreen(detailRangePlotHubModel!);
    } else if (_collectRolePoints(
      parts,
      <SoldierPartStackRole>{SoldierPartStackRole.center},
      motionT,
      attackT,
      roleBuf,
    )) {
      double cx0 = 0, cx1 = 0, cy0 = 0, cy1 = 0;
      _axisBounds(roleBuf, (double a, double b, double d, double e) {
        cx0 = a;
        cx1 = b;
        cy0 = d;
        cy1 = e;
      });
      final Offset hub = Offset((cx0 + cx1) / 2, (cy0 + cy1) / 2);
      hubScreen = toScreen(hub);
    }

    final double detStroke =
        math.max(1.8, math.min(4.5, detectionPx * 0.035));
    canvas.drawCircle(
      hubScreen,
      detectionPx,
      Paint()
        ..color = const Color(0xFF40C4FF).withValues(alpha: 0.88)
        ..style = PaintingStyle.stroke
        ..strokeWidth = detStroke,
    );

    final double dotR = math.max(1.2, contactRadius * sWorld * 0.22);
    canvas.drawCircle(
      hubScreen,
      dotR,
      Paint()..color = const Color(0xFFE91E63).withValues(alpha: 0.98),
    );
  }

  void _paintLegacyCircles(Canvas canvas, Size size) {
    final Offset c = Offset(size.width / 2, size.height / 2);
    final double s = worldToPixelScale(size, contactRadius, attackScale: attackScale);

    void drawRing(double worldR, Color color, double strokeMin) {
      final double px = worldR * s;
      final double stroke = math.max(strokeMin, math.min(5.0, px * 0.20));
      canvas.drawCircle(
        c,
        px,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke,
      );
    }

    drawRing(
      contactRadius * attackScale,
      const Color(0xFF1B5E20).withValues(alpha: 0.92),
      2.0,
    );
    drawRing(
      contactRadius,
      const Color(0xFF00C853).withValues(alpha: 0.92),
      2.2,
    );
    final double dotR = math.max(1.2, contactRadius * s * 0.22);
    canvas.drawCircle(
      c,
      dotR,
      Paint()..color = const Color(0xFFB9F6CA).withValues(alpha: 0.96),
    );
  }

  @override
  bool shouldRepaint(covariant SoldierRangeRingsPainter oldDelegate) {
    if (oldDelegate.contactRadius != contactRadius ||
        oldDelegate.attackScale != attackScale ||
        oldDelegate.crownVfxMode != crownVfxMode ||
        oldDelegate.detailParts != detailParts ||
        oldDelegate.detailMotionT != detailMotionT ||
        oldDelegate.detailAttackCycleT != detailAttackCycleT ||
        oldDelegate.detailUniformSigma != detailUniformSigma ||
        oldDelegate.detailStableModelAnchor != detailStableModelAnchor ||
        oldDelegate.detailRangePlotHubModel != detailRangePlotHubModel) {
      return true;
    }
    final List<SoldierShapePart>? a = oldDelegate.detailParts;
    final List<SoldierShapePart>? b = detailParts;
    if (a == null && b == null) return false;
    if (a == null || b == null || a.length != b.length) return true;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return true;
    }
    return false;
  }
}
