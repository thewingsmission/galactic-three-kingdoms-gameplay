import 'package:flame/extensions.dart';

import '../widgets/isosceles_triangle_vertices.dart';
import '../widgets/multi_polygon_soldier_painter.dart';
import 'cohort_models.dart';
import 'soldier_design.dart';
import 'soldier_design_palette.dart';

/// Visual layer: intrinsic shape only (no position, velocity, or animation vs the soldier).
/// Renders **rigidly** at the soldier origin; all motion is on [CohortSoldier.localOffset].
class SoldierModel {
  const SoldierModel({
    this.type = SoldierType.triangle,
    this.side = 40,
    this.paintSize = 56,
    this.isEnemy = false,
    this.design,
    this.displayPalette,
  });

  final SoldierType type;
  /// Leg length for isosceles triangle geometry.
  final double side;
  /// Canvas extent for [TriangleSoldierPainter] / [OrangeTrianglePainter].
  final double paintSize;
  final bool isEnemy;
  /// Player polygon sprite; null ⇒ triangle painter.
  final SoldierDesign? design;
  final SoldierDesignPalette? displayPalette;
}

/// Contact layer: polygon hull **or** circle (world units) for collision physics.
///
/// For designs with a `SoldierPartStackRole.contact` part, [hullVertices] holds the
/// polygon scaled by the fit factor (body-local / world space). [radius] is the
/// circumscribed radius of that polygon (still useful for attack-range scaling).
///
/// For plain triangles, [hullVertices] is null and [radius] is the old circle radius.
class SoldierContact {
  const SoldierContact({
    required this.radius,
    this.hullVertices,
    this.targetHullVertices,
    this.engagementHullVertices,
  });

  /// Circle fallback: radius = 27% of short side.
  factory SoldierContact.fromModel(SoldierModel model) {
    final double shortSide = isoscelesShortSideLength(model.side);
    return SoldierContact(radius: 0.45 * 0.6 * shortSide);
  }

  /// Build from a design's contact + engagement polygons, scaled by the fit
  /// factor so vertices are in the same coordinate space as the war scene.
  factory SoldierContact.fromDesign(SoldierDesign design, double paintSize) {
    final Size sz = Size(paintSize, paintSize);
    final double fit = MultiPolygonSoldierPainter.layoutMetrics(
      parts: design.parts,
      soldierCanvasSize: sz,
      motionT: 0.25,
      attackCycleT: null,
    ).fitScale;
    final Offset anchor = MultiPolygonSoldierPainter.modelBboxCenter(
      parts: design.parts,
      motionT: 0.25,
      attackCycleT: null,
    );

    List<Offset>? contactScaled;
    double maxR = 0;
    for (final SoldierShapePart p in design.parts) {
      if (p.stackRole != SoldierPartStackRole.contact) continue;
      final List<Offset>? hull =
          MultiPolygonSoldierPainter.transformedFillVertices(p, 0.25, null);
      if (hull == null || hull.length < 3) continue;
      contactScaled = <Offset>[];
      for (final Offset v in hull) {
        final double wx = (v.dx - anchor.dx) * fit;
        final double wy = (v.dy - anchor.dy) * fit;
        contactScaled.add(Offset(wx, wy));
        final double r = Offset(wx, wy).distance;
        if (r > maxR) maxR = r;
      }
      break;
    }

    List<Offset>? targetScaled;
    for (final SoldierShapePart p in design.parts) {
      if (p.stackRole != SoldierPartStackRole.target) continue;
      final List<Offset>? hull =
          MultiPolygonSoldierPainter.transformedFillVertices(p, 0.25, null);
      if (hull == null || hull.length < 3) continue;
      targetScaled = <Offset>[];
      for (final Offset v in hull) {
        final double wx = (v.dx - anchor.dx) * fit;
        final double wy = (v.dy - anchor.dy) * fit;
        targetScaled.add(Offset(wx, wy));
      }
      break;
    }

    List<Offset>? engScaled;
    for (final SoldierShapePart p in design.parts) {
      if (p.stackRole != SoldierPartStackRole.engagement) continue;
      final List<Offset>? hull =
          MultiPolygonSoldierPainter.transformedFillVertices(p, 0.25, null);
      if (hull == null || hull.length < 3) continue;
      engScaled = <Offset>[];
      for (final Offset v in hull) {
        final double wx = (v.dx - anchor.dx) * fit;
        final double wy = (v.dy - anchor.dy) * fit;
        engScaled.add(Offset(wx, wy));
      }
      break;
    }

    if (contactScaled != null) {
      return SoldierContact(
        radius: maxR,
        hullVertices: contactScaled,
        targetHullVertices: targetScaled,
        engagementHullVertices: engScaled,
      );
    }

    final double shortSide = isoscelesShortSideLength(40);
    return SoldierContact(radius: 0.45 * 0.6 * shortSide);
  }

  /// Circumscribed radius (world units) — used for hit zone range scaling.
  final double radius;

  /// Contact polygon vertices in **body-local** space (centered on body origin).
  /// Null for plain-triangle soldiers (use [radius] circle fallback).
  final List<Offset>? hullVertices;

  /// Target zone polygon in **body-local** space — contact hull × 1.5. Null when not defined.
  final List<Offset>? targetHullVertices;

  /// Engagement zone polygon in **body-local** space. Null when not defined.
  final List<Offset>? engagementHullVertices;

  bool get hasPolygon => hullVertices != null && hullVertices!.length >= 3;
  bool get hasTarget =>
      targetHullVertices != null && targetHullVertices!.length >= 3;
  bool get hasEngagement =>
      engagementHullVertices != null && engagementHullVertices!.length >= 3;
}

/// Middle layer: sole owner of motion relative to the cohort; [model] / [contact] fixed in this frame.
/// [CohortRuntime] moves [localOffset] toward formation targets at local soldier speed.
class CohortSoldier {
  CohortSoldier({
    required this.model,
    required this.canonicalSlot,
    SoldierContact? contact,
    Vector2? localOffset,
  })  : contact = contact ?? SoldierContact.fromModel(model),
        localOffset = localOffset ?? Vector2(canonicalSlot.x, canonicalSlot.y);

  final SoldierModel model;
  final SoldierContact contact;
  /// Formation slot in cohort space (unrotated canonical position).
  final Vector2 canonicalSlot;
  /// Current position of the soldier (and its model) relative to cohort center.
  Vector2 localOffset;
}
