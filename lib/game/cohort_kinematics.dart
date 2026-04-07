import 'dart:math' as math;

import 'package:flame/extensions.dart';

import '../models/cohort_models.dart';
import '../models/cohort_soldier.dart';

/// Default radius used when placing the first soldier on the inventory ring (`(0,-1)*r`).
const double kCohortFormationRadius = 78;

/// Cohort space: **+y is upward** on screen (`(0,-1)` = forward from center).
///
/// Hierarchy: **cohort** (world center) → **[CohortSoldier]** (local offset, moved at
/// [localMoveSpeed]) → **[SoldierModel]** (triangle) + **[SoldierContact]** (disk), **no motion vs soldier**).
///
/// **Aim-driven formation (player):**
/// - **Orientation** `visualAngle = atan2(aim.x, -aim.y)` updates **immediately** each
///   frame (joystick from “up” toward “right” → sprite points right at once).
/// - **Target** local offset for each soldier is `R(visualAngle) * canonicalSlot` (e.g. one
///   soldier with canonical `(0,-1)*r` → target `(1,0)*r` when aim is right).
/// - **Soldier motion:** [localOffset] moves toward that target at [localMoveSpeed] when
///   [integratePositions] is true. In war with Forge2D, integration is off and physics + sync
///   own [localOffset].
class CohortRuntime {
  CohortRuntime({
    required List<CohortSoldier> soldiers,
    this.localMoveSpeed = 90,
    this.stickDeadZone = 0.06,
    this.aimDrivenFormation = true,
  })  : _soldiers = List<CohortSoldier>.from(soldiers),
        _lastAim = Vector2(0, -1);

  final List<CohortSoldier> _soldiers;

  /// Last non-zero aim (unit vector in screen space: x right, y up = negative dy).
  Vector2 _lastAim;

  final double localMoveSpeed;

  /// Normalized stick length below this uses [_lastAim] for targets/orientation.
  final double stickDeadZone;

  /// If false (e.g. enemies), soldiers stay at canonical slots and [visualAngle] is 0;
  /// [aim] is ignored. If true (player), aim rotates targets and sprites.
  final bool aimDrivenFormation;

  /// Radians; **instant** orientation for all models (joystick / aim direction).
  double visualAngle = 0;

  factory CohortRuntime.fromDeployment(CohortDeployment d) {
    final List<CohortSoldier> soldiers = d.soldiers.map((PlacedSoldier s) {
      final Vector2 slot = Vector2(s.localOffset.dx, s.localOffset.dy);
      final SoldierModel model = SoldierModel(
        type: s.type,
        side: s.soldierDesign?.side ?? 40,
        paintSize: s.soldierDesign?.paintSize ?? 56,
        isEnemy: false,
        design: s.soldierDesign,
        displayPalette: s.soldierDesign != null ? s.cohortPalette : null,
      );
      final SoldierContact? contactOverride = s.soldierDesign != null
          ? SoldierContact.fromDesign(s.soldierDesign!, model.paintSize)
          : null;
      return CohortSoldier(
        model: model,
        contact: contactOverride,
        canonicalSlot: slot,
        localOffset: Vector2(slot.x, slot.y),
      );
    }).toList();
    return CohortRuntime(soldiers: soldiers);
  }

  factory CohortRuntime.withSlots(
    List<Vector2> slots, {
    double localMoveSpeed = 90,
    double stickDeadZone = 0.06,
    bool aimDrivenFormation = false,
    SoldierModel model = const SoldierModel(
      side: 36,
      paintSize: 52,
      isEnemy: true,
    ),
  }) {
    final List<CohortSoldier> soldiers = slots.map((Vector2 slot) {
      return CohortSoldier(
        model: model,
        canonicalSlot: slot,
        localOffset: Vector2(slot.x, slot.y),
      );
    }).toList();
    return CohortRuntime(
      soldiers: soldiers,
      localMoveSpeed: localMoveSpeed,
      stickDeadZone: stickDeadZone,
      aimDrivenFormation: aimDrivenFormation,
    );
  }

  int get soldierCount => _soldiers.length;

  CohortSoldier soldier(int i) => _soldiers[i];

  /// Formation target in cohort space (rotated slot when aim-driven).
  Vector2 formationTargetLocal(int i) {
    final CohortSoldier s = _soldiers[i];
    if (!aimDrivenFormation) {
      return s.canonicalSlot;
    }
    return _rotate(s.canonicalSlot, visualAngle);
  }

  /// [aim] is raw joystick or direction vector (need not be unit). Uses cohort
  /// convention: forward = `(0,-1)` when aim is “up” on screen.
  void update(double dt, Vector2 aim, {bool integratePositions = true}) {
    final double step = localMoveSpeed * dt;

    if (!aimDrivenFormation) {
      visualAngle = 0;
      if (integratePositions) {
        for (final CohortSoldier s in _soldiers) {
          s.localOffset = _moveToward(s.localOffset, s.canonicalSlot, step);
        }
      }
      return;
    }

    if (aim.length2 > stickDeadZone * stickDeadZone) {
      final double inv = 1.0 / math.sqrt(aim.length2);
      _lastAim.setValues(aim.x * inv, aim.y * inv);
    }

    final Vector2 joy = _lastAim;
    visualAngle = math.atan2(joy.x, -joy.y);

    if (!integratePositions) {
      return;
    }

    for (final CohortSoldier s in _soldiers) {
      final Vector2 targetLocal = _rotate(s.canonicalSlot, visualAngle);
      s.localOffset = _moveToward(s.localOffset, targetLocal, step);
    }
  }

  /// World position = cohort center + soldier local offset (cohort axes = screen axes).
  Vector2 soldierWorldPosition(int i, Vector2 cohortWorldCenter) {
    return cohortWorldCenter + _soldiers[i].localOffset;
  }

  Vector2 _rotate(Vector2 p, double a) {
    final double c = math.cos(a);
    final double s = math.sin(a);
    return Vector2(p.x * c - p.y * s, p.x * s + p.y * c);
  }

  Vector2 _moveToward(Vector2 from, Vector2 to, double maxDist) {
    final Vector2 d = to - from;
    final double len = d.length;
    if (len <= maxDist || len < 1e-9) {
      return Vector2(to.x, to.y);
    }
    return Vector2(from.x + d.x * maxDist / len, from.y + d.y * maxDist / len);
  }
}
