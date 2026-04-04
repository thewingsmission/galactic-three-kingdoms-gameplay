import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/soldier_attack.dart';
import '../models/soldier_design.dart';
import '../models/soldier_design_palette.dart';
import '../models/soldier_faction_color_theme.dart';

/// Paints [SoldierShapePart]s: filled polygons, stroked polylines, or both — scaled to [size], upright (−Y).
///
/// [strokeWidth] is in **model units** (same space as part vertices); it is multiplied by the
/// fit [scale] so outline thickness stays proportional in **screen** space across small cards
/// and large popups. Final outline pixels are also multiplied by [kOutlineThicknessMul] (~half).
/// [motionT] ∈ [0,1) drives [SoldierPartMotion.wingFlap] / [SoldierPartMotion.earSwing].
/// [attackCycleT] ∈ [0,1) drives [SoldierPartMotion.attackProbeExtend] (omit for rest pose).
class MultiPolygonSoldierPainter extends CustomPainter {
  MultiPolygonSoldierPainter({
    required this.parts,
    required this.displayPalette,
    this.strokeWidth = 2.25,
    this.motionT = 0,
    this.attackCycleT,
    this.uniformWorldScale,
    this.fixedModelAnchor,
    this.paintCrownFlames = false,
  }) : assert(parts.isNotEmpty);

  /// Global multiplier on all outline / polyline stroke pixels (half thickness vs legacy).
  static const double kOutlineThicknessMul = 0.5;

  /// Cycle phase where [attackProbeEnvelope] is at full extension — use for layout / bbox so the
  /// attack strip does not clip during the probe hold.
  static const double kAttackProbeBoundsPhase = 0.05;

  final List<SoldierShapePart> parts;
  final SoldierDesignPalette displayPalette;
  /// Outline width in **model/world units** (scaled by internal fit scale → pixels).
  final double strokeWidth;
  /// Loop phase for part motion (e.g. wing flap).
  final double motionT;
  /// Attack loop phase for [SoldierPartMotion.attackProbeExtend]; null ⇒ probe retracted.
  final double? attackCycleT;
  /// When set, model units map to pixels with this factor (same for every design in idle grids).
  /// When null, scale is chosen so the whole soldier fits [size] (legacy).
  final double? uniformWorldScale;
  /// When set, maps this model-space point to the canvas center instead of the current frame’s
  /// bbox center (stable position during attack / flap animation).
  final Offset? fixedModelAnchor;
  /// Flame particles on the probe crown while [attackProbeEnvelope] > 0 ([SoldierDesign.paintCrownFlames]).
  final bool paintCrownFlames;

  /// Fully retracted tail of each cycle must last at least this many seconds (matches
  /// [SoldierAttackSpec.kPreviewCycleSeconds]).
  static const double kAttackProbeMinRestSeconds = 0.15;

  /// Normalized phase where return motion ends and [attackProbeEnvelope] stays at **0** until loop end.
  static double attackProbeReturnEndNormalized() {
    final double c = SoldierAttackSpec.kPreviewCycleSeconds;
    if (c <= 1e-9) return 0.92;
    return (1.0 - kAttackProbeMinRestSeconds / c).clamp(0.05, 0.995);
  }

  /// 0→1 attack cycle: very fast ease-out to full extension, short hold, long slow return.
  static double attackProbeEnvelope(double t) {
    double x = t % 1.0;
    if (x < 0) x += 1.0;
    const double tPop = 0.03;
    const double tHoldEnd = 0.07;
    final double tReturnEnd = attackProbeReturnEndNormalized();
    if (x < tPop) {
      return Curves.easeOutCubic.transform(x / tPop);
    }
    if (x < tHoldEnd) {
      return 1.0;
    }
    if (x < tReturnEnd) {
      final double u = (x - tHoldEnd) / (tReturnEnd - tHoldEnd);
      return 1.0 - Curves.easeInOutCubic.transform(u);
    }
    return 0.0;
  }

  /// Axis-aligned bounding size of all transformed geometry in **model units**.
  static ({double width, double height}) modelBoundingSize({
    required List<SoldierShapePart> parts,
    double motionT = 0,
    double? attackCycleT,
  }) {
    if (parts.isEmpty) {
      return (width: 1.0, height: 1.0);
    }
    final List<List<Offset>?> fillX = <List<Offset>?>[];
    final List<List<Offset>?> strokeX = <List<Offset>?>[];
    for (final SoldierShapePart p in parts) {
      if (p.stackRole == SoldierPartStackRole.contact) {
        fillX.add(null);
        strokeX.add(null);
        continue;
      }
      fillX.add(_transformVerts(p, p.fillVertices, motionT, attackCycleT));
      strokeX.add(_transformVerts(p, p.strokePolyline, motionT, attackCycleT));
    }
    final List<Offset> all = <Offset>[];
    for (int i = 0; i < parts.length; i++) {
      _collectBounds(fillX[i], all.add);
      _collectBounds(strokeX[i], all.add);
    }
    if (all.isEmpty) {
      return (width: 1.0, height: 1.0);
    }
    double minX = all.first.dx, maxX = all.first.dx;
    double minY = all.first.dy, maxY = all.first.dy;
    for (final Offset v in all) {
      if (v.dx < minX) minX = v.dx;
      if (v.dx > maxX) maxX = v.dx;
      if (v.dy < minY) minY = v.dy;
      if (v.dy > maxY) maxY = v.dy;
    }
    final double mw = (maxX - minX).clamp(1e-6, double.infinity);
    final double mh = (maxY - minY).clamp(1e-6, double.infinity);
    return (width: mw, height: mh);
  }

  /// Center of the axis-aligned bbox of all transformed parts (model units).
  static Offset modelBboxCenter({
    required List<SoldierShapePart> parts,
    double motionT = 0,
    double? attackCycleT,
  }) {
    if (parts.isEmpty) {
      return Offset.zero;
    }
    final List<List<Offset>?> fillX = <List<Offset>?>[];
    final List<List<Offset>?> strokeX = <List<Offset>?>[];
    for (final SoldierShapePart p in parts) {
      if (p.stackRole == SoldierPartStackRole.contact) {
        fillX.add(null);
        strokeX.add(null);
        continue;
      }
      fillX.add(_transformVerts(p, p.fillVertices, motionT, attackCycleT));
      strokeX.add(_transformVerts(p, p.strokePolyline, motionT, attackCycleT));
    }
    final List<Offset> all = <Offset>[];
    for (int i = 0; i < parts.length; i++) {
      _collectBounds(fillX[i], all.add);
      _collectBounds(strokeX[i], all.add);
    }
    if (all.isEmpty) {
      return Offset.zero;
    }
    double minX = all.first.dx, maxX = all.first.dx;
    double minY = all.first.dy, maxY = all.first.dy;
    for (final Offset v in all) {
      if (v.dx < minX) minX = v.dx;
      if (v.dx > maxX) maxX = v.dx;
      if (v.dy < minY) minY = v.dy;
      if (v.dy > maxY) maxY = v.dy;
    }
    return Offset((minX + maxX) / 2, (minY + maxY) / 2);
  }

  /// Fit scale and model bbox span for [parts] in [soldierCanvasSize] (same math as [paint]).
  /// Use with [UpwardAttackPainter.effectScale] so attack VFX match soldier size when width-limited.
  static ({double fitScale, double modelWidth, double modelHeight}) layoutMetrics({
    required List<SoldierShapePart> parts,
    required Size soldierCanvasSize,
    double motionT = 0,
    double? attackCycleT,
    double pad = 8,
  }) {
    final ({double width, double height}) bbox =
        modelBoundingSize(parts: parts, motionT: motionT, attackCycleT: attackCycleT);
    final double mw = bbox.width;
    final double mh = bbox.height;
    final double sx = (soldierCanvasSize.width - 2 * pad) / mw;
    final double sy = (soldierCanvasSize.height - 2 * pad) / mh;
    final double fit = sx < sy ? sx : sy;
    return (fitScale: fit, modelWidth: mw, modelHeight: mh);
  }

  static void _collectBounds(List<Offset>? verts, void Function(Offset) add) {
    if (verts == null) return;
    for (final Offset v in verts) {
      add(v);
    }
  }

  static Offset _sCentroid(List<Offset> pts) {
    double sx = 0, sy = 0;
    for (final Offset e in pts) {
      sx += e.dx;
      sy += e.dy;
    }
    final double n = pts.length.toDouble();
    return Offset(sx / n, sy / n);
  }

  static Offset _sPivot(SoldierShapePart part) {
    if (part.motionPivot != null) return part.motionPivot!;
    final List<Offset> pts = <Offset>[];
    if (part.fillVertices != null && part.fillVertices!.length >= 3) {
      pts.addAll(part.fillVertices!);
    } else if (part.strokePolyline != null) {
      pts.addAll(part.strokePolyline!);
    }
    if (pts.isEmpty) return Offset.zero;
    return _sCentroid(pts);
  }

  static Offset _sRotateAround(Offset v, Offset pivot, double rad) {
    final double s = math.sin(rad), c = math.cos(rad);
    final double x = v.dx - pivot.dx, y = v.dy - pivot.dy;
    return Offset(
      pivot.dx + c * x - s * y,
      pivot.dy + s * x + c * y,
    );
  }

  static double _sTheta(SoldierShapePart part, double motionT) {
    if (part.motion != SoldierPartMotion.wingFlap &&
        part.motion != SoldierPartMotion.earSwing) {
      return 0;
    }
    final double phase = motionT * math.pi * 2;
    return part.motionSign * part.motionAmplitudeRad * math.sin(phase);
  }

  static List<Offset>? _transformVerts(
    SoldierShapePart part,
    List<Offset>? raw,
    double motionT,
    double? attackCycleT,
  ) {
    if (raw == null) return null;
    final double th = _sTheta(part, motionT);
    final List<Offset> afterWing = th == 0
        ? raw
        : raw.map((Offset v) => _sRotateAround(v, _sPivot(part), th)).toList();

    final double e = attackCycleT != null &&
            part.motion == SoldierPartMotion.attackProbeExtend
        ? attackProbeEnvelope(attackCycleT)
        : 0.0;
    if (e == 0) {
      if (th == 0) return raw;
      return afterWing;
    }

    final List<Offset> base =
        th == 0 ? List<Offset>.from(raw) : afterWing;
    return _applyAttackProbe(part, base, e);
  }

  static List<Offset> _applyAttackProbe(
    SoldierShapePart part,
    List<Offset> verts,
    double e,
  ) {
    final double dist = part.motionSign * part.motionAmplitudeRad * e;
    final Offset delta = Offset(0, -dist);
    if (verts.length == 2) {
      return <Offset>[verts[0], verts[1] + delta];
    }
    // Filled rod: bottom edge (larger model Y, toward feet) stays fixed; crown-facing edge moves.
    if (verts.length == 4 &&
        part.motion == SoldierPartMotion.attackProbeExtend) {
      double minY = verts.first.dy;
      double maxY = verts.first.dy;
      for (final Offset v in verts) {
        if (v.dy < minY) minY = v.dy;
        if (v.dy > maxY) maxY = v.dy;
      }
      if ((maxY - minY) > 1e-6) {
        // Move crown-facing edge (smallest model Y); body edge (largest Y) stays put.
        return verts
            .map(
              (Offset v) => v.dy <= minY + 1e-3 ? v + delta : v,
            )
            .toList();
      }
    }
    return verts.map((Offset v) => v + delta).toList();
  }

  /// Transformed fill vertices (same motion as [paint]); for overlays (e.g. range preview).
  static List<Offset>? transformedFillVertices(
    SoldierShapePart part,
    double motionT,
    double? attackCycleT,
  ) =>
      _transformVerts(part, part.fillVertices, motionT, attackCycleT);

  /// Transformed stroke polyline (same motion as [paint]).
  static List<Offset>? transformedStrokePolyline(
    SoldierShapePart part,
    double motionT,
    double? attackCycleT,
  ) =>
      _transformVerts(part, part.strokePolyline, motionT, attackCycleT);

  /// Match [SoldierRangeRingsPainter] attack-disk visibility.
  static const double _kCrownFlameMinEnvelope = 0.02;

  /// Uniform random point inside triangle (via sqrt trick), deterministic from [u01],[v01] ∈ (0,1).
  static Offset _triangleBarycentricPoint(
    Offset a,
    Offset b,
    Offset c,
    double u01,
    double v01,
  ) {
    final double r1 = u01.clamp(1e-6, 1.0 - 1e-6);
    final double r2 = v01.clamp(1e-6, 1.0 - 1e-6);
    final double sr = math.sqrt(r1);
    final double u = 1.0 - sr;
    final double v = sr * (1.0 - r2);
    final double w = sr * r2;
    return Offset(
      u * a.dx + v * b.dx + w * c.dx,
      u * a.dy + v * b.dy + w * c.dy,
    );
  }

  static void _paintCrownFlameParticles(
    Canvas canvas,
    List<Offset> triScreen,
    double envelope,
    double attackT,
    double motionT,
    double pixelScale,
    SoldierDesignPalette palette,
  ) {
    if (triScreen.length != 3) return;
    double minSy = triScreen[0].dy;
    int tipI = 0;
    for (int i = 1; i < 3; i++) {
      if (triScreen[i].dy < minSy) {
        minSy = triScreen[i].dy;
        tipI = i;
      }
    }
    final Offset tip = triScreen[tipI];
    final Offset centroid = Offset(
      (triScreen[0].dx + triScreen[1].dx + triScreen[2].dx) / 3.0,
      (triScreen[0].dy + triScreen[1].dy + triScreen[2].dy) / 3.0,
    );
    double minTx = triScreen[0].dx;
    double maxTx = triScreen[0].dx;
    for (final Offset p in triScreen) {
      if (p.dx < minTx) minTx = p.dx;
      if (p.dx > maxTx) maxTx = p.dx;
    }
    final double crownWidthPx = math.max(maxTx - minTx, 1e-6);
    double minTy = triScreen[0].dy;
    double maxTy = triScreen[0].dy;
    for (final Offset p in triScreen) {
      if (p.dy < minTy) minTy = p.dy;
      if (p.dy > maxTy) maxTy = p.dy;
    }
    final double crownHeightPx = math.max(maxTy - minTy, 1e-6);
    // Main lobe: sin ∈ [-1,1] → total horizontal span ≈ 1.2 × crown width.
    final double xAmpMain = crownWidthPx * 0.6;
    final double xAmpWobble = crownWidthPx * 0.12;
    final double phase = attackT * math.pi * 2 * 3 + motionT * math.pi * 2;
    final double e = envelope.clamp(0.0, 1.0);
    const double kFlameVerticalMul = 1.6;

    final ({Color bright, Color mid, Color deep}) fc = palette.crownFlameColors;
    final Color glowPaint =
        Color.lerp(fc.mid, fc.deep, 0.38) ?? fc.mid;

    final double triSpan =
        math.max(crownWidthPx, crownHeightPx);
    final double glowR = pixelScale * 8.2 * (0.5 + 0.5 * e) + triSpan * 0.14;
    canvas.drawCircle(
      centroid,
      glowR,
      Paint()
        ..color = glowPaint.withValues(alpha: 0.19 * e)
        ..style = PaintingStyle.fill,
    );

    final Offset a = triScreen[0];
    final Offset b = triScreen[1];
    final Offset c = triScreen[2];

    const int n = 22;
    for (int k = 0; k < n; k++) {
      final double t = k / (n - 1).clamp(1, 999);
      final double flicker =
          0.55 + 0.45 * math.sin(phase * 2.3 + k * 0.77);
      final double u01 =
          (0.5 + 0.5 * math.sin(phase * 2.11 + k * 3.37 + 0.2)).clamp(0.02, 0.98);
      final double v01 =
          (0.5 + 0.5 * math.sin(phase * 2.83 + k * 5.09 + 0.7)).clamp(0.02, 0.98);
      Offset base = _triangleBarycentricPoint(a, b, c, u01, v01);
      // Bias some particles toward tip so plume stays dense at apex.
      base = Offset.lerp(base, tip, t * 0.22 * e) ?? base;

      final Offset toTip = tip - base;
      final double lenTip = toTip.distance;
      final double ntx = lenTip > 1e-6 ? toTip.dx / lenTip : 0.0;
      final double nty = lenTip > 1e-6 ? toTip.dy / lenTip : -1.0;

      final double xJitter = math.sin(phase * 4.1 + k * 1.9) * xAmpMain +
          math.cos(phase * 5.5 + k * 2.8) * xAmpWobble;
      final double billow = math.sin(phase * 3.3 + k * 2.7).abs() *
          pixelScale *
          5.4 *
          kFlameVerticalMul *
          (0.35 + 0.65 * e);
      final double plumeMag = pixelScale *
          (2.4 + 4.2 * flicker * e) *
          kFlameVerticalMul *
          (0.55 + 0.25 * crownHeightPx / math.max(pixelScale * 14, 1e-6));

      Offset o = base.translate(
        xJitter + ntx * plumeMag,
        nty * plumeMag - billow,
      );
      final double rr = pixelScale *
          (2.05 + 4.1 * flicker * e) *
          (0.75 + 0.25 * math.sin(phase * 5 + k));
      final double tone =
          ((k % 5) / 5.0 + 0.12 * math.sin(phase * 2.1 + k * 0.9))
              .clamp(0.0, 1.0);
      final Color col = Color.lerp(
        Color.lerp(fc.bright, fc.mid, 0.45)!,
        fc.deep,
        tone,
      )!;
      canvas.drawCircle(
        o,
        rr,
        Paint()
          ..color = col.withValues(
            alpha: (0.2 + 0.38 * e * flicker).clamp(0.0, 1.0),
          )
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (parts.isEmpty) return;

    final List<List<Offset>?> fillX = <List<Offset>?>[];
    final List<List<Offset>?> strokeX = <List<Offset>?>[];
    for (final SoldierShapePart p in parts) {
      fillX.add(_transformVerts(p, p.fillVertices, motionT, attackCycleT));
      strokeX.add(_transformVerts(p, p.strokePolyline, motionT, attackCycleT));
    }

    final List<Offset> all = <Offset>[];
    for (int i = 0; i < parts.length; i++) {
      _collectBounds(fillX[i], all.add);
      _collectBounds(strokeX[i], all.add);
    }
    if (all.isEmpty) return;

    double minX = all.first.dx, maxX = all.first.dx;
    double minY = all.first.dy, maxY = all.first.dy;
    for (final Offset v in all) {
      if (v.dx < minX) minX = v.dx;
      if (v.dx > maxX) maxX = v.dx;
      if (v.dy < minY) minY = v.dy;
      if (v.dy > maxY) maxY = v.dy;
    }
    final double w = (maxX - minX).clamp(1e-6, double.infinity);
    final double h = (maxY - minY).clamp(1e-6, double.infinity);
    const double pad = 8;
    final double sx = (size.width - 2 * pad) / w;
    final double sy = (size.height - 2 * pad) / h;
    final double scale = uniformWorldScale ?? (sx < sy ? sx : sy);
    final double outlinePx =
        (strokeWidth * scale * kOutlineThicknessMul).clamp(0.18, 7.0);

    final Offset c = Offset(size.width / 2, size.height / 2);
    final double bx;
    final double by;
    if (fixedModelAnchor != null) {
      bx = fixedModelAnchor!.dx;
      by = fixedModelAnchor!.dy;
    } else {
      bx = (minX + maxX) / 2;
      by = (minY + maxY) / 2;
    }

    Offset map(Offset p) =>
        Offset(c.dx + (p.dx - bx) * scale, c.dy + (p.dy - by) * scale);

    void paintPartsForRole(SoldierPartStackRole role) {
      for (int i = 0; i < parts.length; i++) {
        if (parts[i].stackRole != role) continue;
        final SoldierShapePart part = parts[i];
        final SoldierPartColorPair pair = part.colorsForPalette(displayPalette);
        final List<Offset>? fv = fillX[i];
        if (fv != null && fv.length >= 3) {
          final Path path = Path();
          for (int j = 0; j < fv.length; j++) {
            final Offset q = map(fv[j]);
            if (j == 0) {
              path.moveTo(q.dx, q.dy);
            } else {
              path.lineTo(q.dx, q.dy);
            }
          }
          path.close();
          if (pair.fill.a > 0) {
            canvas.drawPath(path, Paint()..color = pair.fill..style = PaintingStyle.fill);
          }
          canvas.drawPath(
            path,
            Paint()
              ..color = pair.stroke
              ..style = PaintingStyle.stroke
              ..strokeWidth = outlinePx
              ..strokeJoin = StrokeJoin.round,
          );
        }

        final List<Offset>? sv = strokeX[i];
        if (sv != null && sv.length >= 2) {
          final Path line = Path();
          for (int j = 0; j < sv.length; j++) {
            final Offset q = map(sv[j]);
            if (j == 0) {
              line.moveTo(q.dx, q.dy);
            } else {
              line.lineTo(q.dx, q.dy);
            }
          }
          if (part.strokeClosed) {
            line.close();
            if (pair.fill.a > 0 && (fv == null || fv.length < 3)) {
              canvas.drawPath(line, Paint()..color = pair.fill..style = PaintingStyle.fill);
            }
          }
          final double linePx =
              (part.strokeWidth * scale * kOutlineThicknessMul).clamp(0.15, 6.0);
          canvas.drawPath(
            line,
            Paint()
              ..color = pair.stroke
              ..style = PaintingStyle.stroke
              ..strokeWidth = linePx
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round,
          );
        }
      }
    }

    const List<SoldierPartStackRole> kBeforeFlames = <SoldierPartStackRole>[
      SoldierPartStackRole.underlay,
      SoldierPartStackRole.body,
      SoldierPartStackRole.center,
      SoldierPartStackRole.attack,
    ];
    for (final SoldierPartStackRole role in kBeforeFlames) {
      paintPartsForRole(role);
    }

    if (paintCrownFlames && attackCycleT != null) {
      final double env = attackProbeEnvelope(attackCycleT!);
      if (env > _kCrownFlameMinEnvelope) {
        for (int i = 0; i < parts.length; i++) {
          final SoldierShapePart p = parts[i];
          if (p.stackRole != SoldierPartStackRole.attack) continue;
          if (p.motion != SoldierPartMotion.attackProbeExtend) continue;
          final List<Offset>? fv = fillX[i];
          if (fv == null || fv.length != 3) continue;
          final List<Offset> triScreen =
              fv.map((Offset m) => map(m)).toList(growable: false);
          _paintCrownFlameParticles(
            canvas,
            triScreen,
            env,
            attackCycleT!,
            motionT,
            scale,
            displayPalette,
          );
          break;
        }
      }
    }

    paintPartsForRole(SoldierPartStackRole.overlay);
  }

  @override
  bool shouldRepaint(covariant MultiPolygonSoldierPainter oldDelegate) {
    if (oldDelegate.motionT != motionT ||
        oldDelegate.attackCycleT != attackCycleT ||
        oldDelegate.displayPalette != displayPalette ||
        oldDelegate.parts.length != parts.length ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.uniformWorldScale != uniformWorldScale ||
        oldDelegate.fixedModelAnchor != fixedModelAnchor ||
        oldDelegate.paintCrownFlames != paintCrownFlames) {
      return true;
    }
    for (int i = 0; i < parts.length; i++) {
      final SoldierShapePart a = oldDelegate.parts[i];
      final SoldierShapePart b = parts[i];
      if (!listEquals(a.fillVertices, b.fillVertices) ||
          !listEquals(a.strokePolyline, b.strokePolyline) ||
          a.strokeClosed != b.strokeClosed ||
          a.fillTier != b.fillTier ||
          a.transparentFill != b.transparentFill ||
          a.strokeWidth != b.strokeWidth ||
          a.motion != b.motion ||
          a.motionPivot != b.motionPivot ||
          a.motionSign != b.motionSign ||
          a.motionAmplitudeRad != b.motionAmplitudeRad ||
          a.stackRole != b.stackRole) {
        return true;
      }
    }
    return false;
  }
}
