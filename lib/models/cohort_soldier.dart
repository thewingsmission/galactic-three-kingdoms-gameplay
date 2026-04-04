import 'package:flame/extensions.dart';

import '../widgets/isosceles_triangle_vertices.dart';
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

/// Contact layer: circle radius (world units) derived from triangle short side; no motion vs soldier.
class SoldierContact {
  const SoldierContact({required this.radius});

  /// Radius = 60% of the prior factor (0.45) × short side = **0.27 × short side**.
  factory SoldierContact.fromModel(SoldierModel model) {
    final double shortSide = isoscelesShortSideLength(model.side);
    return SoldierContact(radius: 0.45 * 0.6 * shortSide);
  }

  final double radius;
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
