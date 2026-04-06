import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

import '../models/cohort_models.dart';
import '../models/cohort_soldier.dart';
import '../models/soldier_design.dart';
import '../models/soldier_design_palette.dart';
import '../models/soldier_faction_color_theme.dart';
import '../models/soldier_attack.dart';
import '../models/soldier_range_scales.dart';
import '../widgets/multi_polygon_soldier_painter.dart';
import '../widgets/soldier_design_catalog.dart';
import '../widgets/triangle_soldier.dart';
import 'cohort_kinematics.dart';
import 'orange_field_debris.dart';
import 'soldier_contact_body.dart';

/// Detection radius for a [CohortSoldier] in **world units** (logical px).
/// Converts [kSoldierDetectionRadiusModelUnits] (200 model units) via the
/// soldier's fit scale. Falls back to a reasonable constant for plain triangles.
double soldierDetectionRadiusWorld(CohortSoldier s) {
  final SoldierDesign? d = s.model.design;
  if (d == null) {
    return kSoldierDetectionRadiusModelUnits * 0.57;
  }
  final Size sz = Size(s.model.paintSize, s.model.paintSize);
  final double fit = MultiPolygonSoldierPainter.layoutMetrics(
    parts: d.parts,
    soldierCanvasSize: sz,
    motionT: 0.25,
    attackCycleT: null,
  ).fitScale;
  return kSoldierDetectionRadiusModelUnits * fit;
}

/// Build a [SoldierContactBody] from a [SoldierContact]:
/// polygon hull when available, circle fallback otherwise.
SoldierContactBody _bodyFromContact(SoldierContact c, Vector2 position) {
  if (c.hasPolygon) {
    final List<Vector2> verts = c.hullVertices!
        .map((Offset o) => Vector2(o.dx, o.dy))
        .toList();
    return SoldierContactBody.polygon(
      worldVertices: verts,
      position: position,
    );
  }
  return SoldierContactBody.circle(radius: c.radius, position: position);
}

// ---------------------------------------------------------------------------
// Geometry helpers: attack zone world circle + polygon-circle overlap
// ---------------------------------------------------------------------------

/// Returns the hit zone as (center, radius) in **world** coordinates.
/// [attackCycleT] drives the crown position along the probe animation.
/// For [CrownVfxMode.scalingCrown] designs the radius scales with the
/// probe envelope (1x at rest → 3x at full extension).
({Vector2 center, double radius}) attackZoneWorldCircle(
  CohortSoldier s,
  Vector2 bodyPos,
  double angle,
  double? attackCycleT,
) {
  const double crownRadiusMul = 1.32;
  final SoldierDesign? d = s.model.design;
  if (d != null) {
    final Size sz = Size(s.model.paintSize, s.model.paintSize);
    final double fit = MultiPolygonSoldierPainter.layoutMetrics(
      parts: d.parts,
      soldierCanvasSize: sz,
      motionT: 0.25,
      attackCycleT: null,
    ).fitScale;
    final Offset anchor = MultiPolygonSoldierPainter.modelBboxCenter(
      parts: d.parts,
      motionT: 0.25,
      attackCycleT: null,
    );
    for (final SoldierShapePart p in d.parts) {
      if (p.stackRole != SoldierPartStackRole.attack) continue;
      if (p.motion != SoldierPartMotion.attackProbeExtend) continue;
      final List<Offset>? tv = MultiPolygonSoldierPainter.transformedFillVertices(
        p,
        0.25,
        attackCycleT,
      );
      if (tv == null || tv.length != 3) continue;
      double sx = 0, sy = 0;
      for (final Offset v in tv) {
        sx += v.dx;
        sy += v.dy;
      }
      final Offset cen = Offset(sx / 3, sy / 3);
      double best = 0;
      for (final Offset v in tv) {
        final double dd = (v - cen).distance;
        if (dd > best) best = dd;
      }
      double crownR = best * crownRadiusMul * fit;
      if (d.crownVfxMode == CrownVfxMode.scalingCrown) {
        final double envScale = attackCycleT != null
            ? 1.0 + 2.0 * MultiPolygonSoldierPainter.attackProbeEnvelope(attackCycleT)
            : 1.0;
        crownR *= envScale * 0.55;
      }
      final double mx = (cen.dx - anchor.dx) * fit;
      final double my = (cen.dy - anchor.dy) * fit;
      final double c = math.cos(angle);
      final double sn = math.sin(angle);
      return (
        center: Vector2(bodyPos.x + c * mx - sn * my, bodyPos.y + sn * mx + c * my),
        radius: crownR,
      );
    }
  }
  return (
    center: Vector2(bodyPos.x, bodyPos.y),
    radius: s.contact.radius * kSoldierAttackRangeRadiusScale,
  );
}

/// Contact zone vertices transformed to world space (rotated + translated).
List<Vector2>? contactZoneWorldVerts(SoldierContact contact, Vector2 bodyPos, double angle) {
  if (!contact.hasPolygon) return null;
  final double c = math.cos(angle);
  final double sn = math.sin(angle);
  return contact.hullVertices!.map((Offset o) {
    return Vector2(
      bodyPos.x + c * o.dx - sn * o.dy,
      bodyPos.y + sn * o.dx + c * o.dy,
    );
  }).toList();
}

/// Engagement zone vertices transformed to world space.
List<Vector2>? engagementZoneWorldVerts(SoldierContact contact, Vector2 bodyPos, double angle) {
  if (!contact.hasEngagement) return null;
  final double c = math.cos(angle);
  final double sn = math.sin(angle);
  return contact.engagementHullVertices!.map((Offset o) {
    return Vector2(
      bodyPos.x + c * o.dx - sn * o.dy,
      bodyPos.y + sn * o.dx + c * o.dy,
    );
  }).toList();
}

/// SAT overlap test for two convex polygons.
bool _convexPolysOverlap(List<Vector2> a, List<Vector2> b) {
  bool separated(List<Vector2> poly, List<Vector2> other) {
    for (int i = 0; i < poly.length; i++) {
      final int j = (i + 1) % poly.length;
      final double nx = poly[j].y - poly[i].y;
      final double ny = poly[i].x - poly[j].x;
      double minA = double.infinity, maxA = double.negativeInfinity;
      for (final Vector2 v in poly) {
        final double d = v.x * nx + v.y * ny;
        if (d < minA) minA = d;
        if (d > maxA) maxA = d;
      }
      double minB = double.infinity, maxB = double.negativeInfinity;
      for (final Vector2 v in other) {
        final double d = v.x * nx + v.y * ny;
        if (d < minB) minB = d;
        if (d > maxB) maxB = d;
      }
      if (maxA < minB || maxB < minA) return true;
    }
    return false;
  }
  return !separated(a, b) && !separated(b, a);
}

/// True when a contact zone (polygon or circle) overlaps an engagement zone polygon.
bool contactOverlapsEngagementPoly({
  required SoldierContact contact,
  required Vector2 contactBodyPos,
  required double contactAngle,
  required List<Vector2> engagementWorldVerts,
}) {
  final List<Vector2>? cVerts = contactZoneWorldVerts(contact, contactBodyPos, contactAngle);
  if (cVerts != null && cVerts.length >= 3) {
    return _convexPolysOverlap(cVerts, engagementWorldVerts);
  }
  // Circle fallback: check if circle overlaps convex polygon
  final double r = contact.radius;
  final double r2 = r * r;
  for (final Vector2 v in engagementWorldVerts) {
    if ((v - contactBodyPos).length2 <= r2) return true;
  }
  if (_pointInConvexPoly(contactBodyPos, engagementWorldVerts)) return true;
  for (int i = 0; i < engagementWorldVerts.length; i++) {
    final Vector2 a = engagementWorldVerts[i];
    final Vector2 b = engagementWorldVerts[(i + 1) % engagementWorldVerts.length];
    if (_segDistSq(a, b, contactBodyPos) <= r2) return true;
  }
  return false;
}

/// True when a contact zone (polygon or circle) overlaps an attack zone circle.
bool contactOverlapsAttackCircle({
  required SoldierContact contact,
  required Vector2 contactBodyPos,
  required double contactAngle,
  required Vector2 attackCenter,
  required double attackRadius,
}) {
  final double r2 = attackRadius * attackRadius;
  final List<Vector2>? verts = contactZoneWorldVerts(contact, contactBodyPos, contactAngle);
  if (verts != null && verts.length >= 3) {
    for (final Vector2 v in verts) {
      if ((v - attackCenter).length2 <= r2) return true;
    }
    if (_pointInConvexPoly(attackCenter, verts)) return true;
    for (int i = 0; i < verts.length; i++) {
      final Vector2 a = verts[i];
      final Vector2 b = verts[(i + 1) % verts.length];
      if (_segDistSq(a, b, attackCenter) <= r2) return true;
    }
    return false;
  }
  final double dist2 = (contactBodyPos - attackCenter).length2;
  final double sum = attackRadius + contact.radius;
  return dist2 <= sum * sum;
}

bool _pointInConvexPoly(Vector2 p, List<Vector2> poly) {
  bool allPos = true, allNeg = true;
  for (int i = 0; i < poly.length; i++) {
    final Vector2 a = poly[i];
    final Vector2 b = poly[(i + 1) % poly.length];
    final double cross = (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x);
    if (cross < 0) allPos = false;
    if (cross > 0) allNeg = false;
  }
  return allPos || allNeg;
}

double _segDistSq(Vector2 a, Vector2 b, Vector2 p) {
  final Vector2 ab = b - a;
  final double t = ((p - a).dot(ab) / ab.length2).clamp(0.0, 1.0);
  final Vector2 proj = a + ab * t;
  return (p - proj).length2;
}

// ---------------------------------------------------------------------------
// Combat constants
// ---------------------------------------------------------------------------

const int kGildedBastionMaxHp = 100;
const int kGildedBastionAttackDmg = 20;
const double kKnockbackSpeed = 350.0;
const double kKnockbackCooldown = 0.25;
const double kAttackCycleSeconds = SoldierAttackSpec.kPreviewCycleSeconds;

/// War scene: first deployed soldier **is** the cohort anchor (joystick, formation origin); other
/// soldiers are contact bodies in that leader’s space. [CohortRuntime] drives formation via
/// **forces**; [localOffset] syncs from bodies relative to the leader soldier.
///
/// **Ranges (player soldier *i*, enemy center = enemy body position):**
/// - **Detection disk**: center = soldier *i* center, radius = [kSoldierDetectionRadiusModelUnits] (200) × fit scale → world units via [soldierDetectionRadiusWorld].
/// - **Attack disk**: center = soldier *i* center, radius = `contactRadius_i ×` [kSoldierAttackRangeRadiusScale].
///
/// **Neutral stick** (`!_playerCohortMoving()`, joystick inside dead zone) — per player soldier *i*
/// after `_updateRangeEntryMaps` (and using earliest detection/attack **entry time** when multiple
/// enemies qualify):
///
/// ```
/// if (no enemy center lies inside soldier i’s detection disk) {
///   apply formation PD toward leader + formationTargetLocal(i);
///   no chase from _applyChaseForces for i;
/// } else {
///   let E = chosen enemy (earliest detection entry among those in the disk);
///   do not apply formation PD to soldier i;
///   if (E’s center lies inside soldier i’s attack disk) {
///     no chase for i (hold — only physics damping / collisions);
///   } else {
///     chase: steer velocity toward cohortMaxSpeed along line to E’s center;
///   }
/// }
/// ```
///
/// **Moving stick** (player): formation PD applies (subject to per-soldier detection skip above only
/// when stick neutral); chase block above is skipped. Facing uses attack/detection/leader velocity
/// per `_playerSoldierFacingAngle`.
///
/// **Enemies**: no formation PD; chase when not “moving” by speed threshold and player in detection
/// but not attack (mirror logic via `_earliestPlayerInDetectionForEnemy`, etc.).
class CohortWarGame extends Forge2DGame {
  CohortWarGame({
    required CohortDeployment deployment,
    required this.playerPalette,
    required this.velocityHud,
    required this.soldier1PosHud,
  }) : _deployment = deployment,
       _enemyPalettes = SoldierDesignPalette.values
           .where((SoldierDesignPalette p) => p != playerPalette)
           .toList(),
       super(
         gravity: Vector2.zero(),
         zoom: 1.5,
       );

  final CohortDeployment _deployment;
  final SoldierDesignPalette playerPalette;
  final List<SoldierDesignPalette> _enemyPalettes;
  final ValueNotifier<Vector2> velocityHud;
  final ValueNotifier<Vector2> soldier1PosHud;
  final ValueNotifier<bool> gameOver = ValueNotifier<bool>(false);

  Vector2 stick = Vector2.zero();

  static const double cohortMaxSpeed = 220;
  static const double steeringGain = 7;
  /// Position gain k in e'' = k·e − c·v_rel (same units as acceleration per unit error).
  static const double soldierFormationGain = 12;
  /// Critically damped PD: **c = 2√k** (ζ = 1). Using **56%** of that.
  static final double soldierFormationVelDamp =
      2 * math.sqrt(soldierFormationGain) * 0.56;
  static const double _stickNeutral = 0.06;
  static const double _velocitySnap2 = 20 * 20;
  /// Ignore flip-detect when nearly still (avoids noise).
  static const double _neutralOppClampMinVel2 = 25;
  /// Enemy soldier treated as "moving" if its speed exceeds this (no joystick).
  static const double _enemySoldierMovingVel = 25;
  static final double _enemySoldierMovingVel2 =
      _enemySoldierMovingVel * _enemySoldierMovingVel;
  /// Aim / velocity magnitude² below this → use cohort aim instead of velocity direction.
  static const double _moveDirEpsilon2 = 4;
  /// Chase steering: drive soldier velocity toward [cohortMaxSpeed] along line to target (stationary cohort).
  static const double _chaseVelocitySteerGain = 8;

  late final CohortRuntime playerCohort;
  late final List<SoldierContactBody> playerSoldierBodies;
  late final List<Vector2> _soldierVelBefore;
  final Vector2 _leaderSoldierVelBefore = Vector2.zero();
  final List<EnemySoldier> enemySoldiers = <EnemySoldier>[];

  double _warTime = 0;
  late List<Map<String, double>> _playerAttackEntry;
  late List<Map<String, double>> _playerDetectionEntry;
  late List<double> _lastPlayerFacing;
  late List<Map<String, double>> _enemyAttackPlayerEntry;
  late List<Map<String, double>> _enemyDetectionPlayerEntry;
  late List<double> _lastEnemySoldierFacing;

  // --- Combat state ---
  late List<int> _playerHp;
  late List<int> _playerMaxHp;
  late List<double> _playerAttackCycleT;
  late List<String?> _playerLockedEnemy;
  late List<Set<String>> _playerDamagedThisPhase;
  late List<bool> _playerWasInAttackPhase;
  late List<bool> _playerAlive;
  late List<double> _playerKnockbackTimer;

  late List<int> _enemyHp;
  late List<int> _enemyMaxHp;
  late List<double> _enemyAttackCycleT;
  late List<String?> _enemyLockedPlayer;
  late List<Set<String>> _enemyDamagedThisPhase;
  late List<bool> _enemyWasInAttackPhase;
  late List<bool> _enemyAlive;
  late List<double> _enemyKnockbackTimer;

  void setStick(Offset normalized) {
    stick.setValues(normalized.dx, normalized.dy);
  }

  int get soldierCount => _deployment.soldiers.length;

  /// First deployed soldier: receives stick steering; formation anchor; camera target.
  Body get _leaderBody => playerSoldierBodies[0].body;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    velocityIterations = 12;
    positionIterations = 12;

    playerCohort = CohortRuntime.fromDeployment(_deployment);
    debugPrint('[CohortWarGame] playerCohort.soldierCount=${playerCohort.soldierCount}');

    final Vector2 start =
        size.x > 0 && size.y > 0 ? size / 2 : Vector2(400, 240);

    _enemyAttackPlayerEntry = <Map<String, double>>[];
    _enemyDetectionPlayerEntry = <Map<String, double>>[];
    _lastEnemySoldierFacing = <double>[];
    _enemyHp = <int>[];
    _enemyMaxHp = <int>[];
    _enemyAttackCycleT = <double>[];
    _enemyLockedPlayer = <String?>[];
    _enemyDamagedThisPhase = <Set<String>>[];
    _enemyWasInAttackPhase = <bool>[];
    _enemyAlive = <bool>[];
    _enemyKnockbackTimer = <double>[];

    _spawnEnemySoldiers(start);

    final List<SoldierContactBody> pb = <SoldierContactBody>[];
    for (int i = 0; i < playerCohort.soldierCount; i++) {
      final CohortSoldier s = playerCohort.soldier(i);
      final Vector2 pos = start + s.localOffset;
      final SoldierContactBody b = _bodyFromContact(s.contact, pos);
      pb.add(b);
    }
    playerSoldierBodies = pb;
    for (final SoldierContactBody b in playerSoldierBodies) {
      await world.add(b);
    }
    _soldierVelBefore = List<Vector2>.generate(
      playerSoldierBodies.length,
      (_) => Vector2.zero(),
    );

    _playerAttackEntry = List<Map<String, double>>.generate(
      playerCohort.soldierCount,
      (_) => <String, double>{},
    );
    _playerDetectionEntry = List<Map<String, double>>.generate(
      playerCohort.soldierCount,
      (_) => <String, double>{},
    );
    _lastPlayerFacing = List<double>.generate(
      playerCohort.soldierCount,
      (_) => playerCohort.visualAngle,
    );
    _playerHp = List<int>.filled(playerCohort.soldierCount, kGildedBastionMaxHp);
    _playerMaxHp = List<int>.filled(playerCohort.soldierCount, kGildedBastionMaxHp);
    _playerAttackCycleT = List<double>.filled(playerCohort.soldierCount, 0);
    _playerLockedEnemy = List<String?>.filled(playerCohort.soldierCount, null);
    _playerDamagedThisPhase = List<Set<String>>.generate(
      playerCohort.soldierCount,
      (_) => <String>{},
    );
    _playerWasInAttackPhase = List<bool>.filled(playerCohort.soldierCount, false);
    _playerAlive = List<bool>.filled(playerCohort.soldierCount, true);
    _playerKnockbackTimer = List<double>.filled(playerCohort.soldierCount, 0);

    final _SoldierAccessor playerAccessor = (
      count: () => playerCohort.soldierCount,
      soldier: (int i) => playerCohort.soldier(i),
      position: (int i) => playerSoldierBodies[i].body.position,
      angle: (int i) => _playerSoldierRenderAngle(i),
      alive: (int i) => _playerAlive[i],
    );
    final _SoldierAccessor enemyAccessor = (
      count: () => enemySoldiers.length,
      soldier: (int i) => enemySoldiers[i].soldier,
      position: (int i) => enemySoldiers[i].body.body.position,
      angle: (int i) => _enemySoldierRenderAngle(i),
      alive: (int i) => _enemyAlive[i],
    );

    await world.add(
      EnemySoldiersPainter(
        enemyCount: () => enemySoldiers.length,
        soldier: (int i) => enemySoldiers[i].soldier,
        soldierWorldPosition: (int i) => enemySoldiers[i].body.body.position,
        visualAngleForSoldier: _enemySoldierRenderAngle,
        attackCycleForSoldier: (int i) =>
            _enemyLockedPlayer[i] != null ? _enemyAttackCycleT[i] : null,
        isAlive: (int i) => _enemyAlive[i],
      ),
    );

    await world.add(
      PlayerFormationPainter(
        runtime: playerCohort,
        soldierWorldPosition: (int i) => playerSoldierBodies[i].body.position,
        visualAngleForSoldier: _playerSoldierRenderAngle,
        attackCycleForSoldier: (int i) =>
            _playerLockedEnemy[i] != null ? _playerAttackCycleT[i] : null,
        isAlive: (int i) => _playerAlive[i],
      ),
    );

    await world.add(_WarContactZoneLayer(player: playerAccessor, enemy: enemyAccessor));
    await world.add(_WarEngagementZoneLayer(player: playerAccessor, enemy: enemyAccessor));
    await world.add(_WarAttackZoneLayer(
      player: playerAccessor,
      enemy: enemyAccessor,
      playerAttackCycleT: (int i) =>
          _playerLockedEnemy[i] != null ? _playerAttackCycleT[i] : null,
      enemyAttackCycleT: (int i) =>
          _enemyLockedPlayer[i] != null ? _enemyAttackCycleT[i] : null,
    ));
    await world.add(_WarDetectionZoneLayer(player: playerAccessor, enemy: enemyAccessor));
    await world.add(_WarCenterDotLayer(player: playerAccessor, enemy: enemyAccessor));
    await world.add(_WarHpBarLayer(
      player: playerAccessor,
      enemy: enemyAccessor,
      playerHp: () => _playerHp,
      playerMaxHp: () => _playerMaxHp,
      enemyHp: () => _enemyHp,
      enemyMaxHp: () => _enemyMaxHp,
    ));

    // Follow the cohort leader (first selected soldier), not a separate ghost body.
    camera.follow(playerSoldierBodies[0], snap: true, maxSpeed: double.infinity);
  }

  /// Cohort convention: [atan2(dx, -dy)] matches [CohortRuntime] aim / forward `(0,-1)`.
  static double _aimAngleToward(Vector2 delta) {
    return math.atan2(delta.x, -delta.y);
  }

  double _playerSoldierRenderAngle(int i) => _playerSoldierFacingAngle(i);

  double _enemySoldierRenderAngle(int enemyIndex) =>
      _enemySoldierFacingAngle(enemyIndex);

  bool _playerCohortMoving() =>
      stick.length2 > _stickNeutral * _stickNeutral;

  bool _enemySoldierMoving(int enemyIndex) {
    return enemySoldiers[enemyIndex].body.body.linearVelocity.length2 >
        _enemySoldierMovingVel2;
  }

  Vector2 _enemyWorldPosFromKey(String key) {
    final int ei = int.parse(key.substring(2));
    return enemySoldiers[ei].body.body.position;
  }

  Vector2 _playerWorldPosFromKey(String key) {
    final int j = int.parse(key.substring(2));
    return playerSoldierBodies[j].body.position;
  }

  /// Resolve any target key ('p-N' or 'e-N') to world position.
  Vector2 _targetWorldPos(String key) {
    if (key.startsWith('p-')) return _playerWorldPosFromKey(key);
    return _enemyWorldPosFromKey(key);
  }

  void _updateRangeEntryMaps() {
    for (int i = 0; i < playerSoldierBodies.length; i++) {
      if (!_playerAlive[i]) {
        _playerAttackEntry[i].clear();
        _playerDetectionEntry[i].clear();
        continue;
      }
      final Vector2 pos = playerSoldierBodies[i].body.position;
      final CohortSoldier ps = playerCohort.soldier(i);
      final double rD = soldierDetectionRadiusWorld(ps);
      final double rD2 = rD * rD;
      final Set<String> inA = <String>{};
      final Set<String> inD = <String>{};
      for (int ei = 0; ei < enemySoldiers.length; ei++) {
        if (!_enemyAlive[ei]) continue;
        final String k = 'e-$ei';
        final Vector2 c = enemySoldiers[ei].body.body.position;
        if ((c - pos).length2 <= rD2) inD.add(k);
        if (_enemyContactInPlayerEngagementZone(i, k)) inA.add(k);
      }
      _playerAttackEntry[i].removeWhere((String k, double _) => !inA.contains(k));
      for (final String k in inA) {
        _playerAttackEntry[i].putIfAbsent(k, () => _warTime);
      }
      _playerDetectionEntry[i].removeWhere((String k, double _) => !inD.contains(k));
      for (final String k in inD) {
        _playerDetectionEntry[i].putIfAbsent(k, () => _warTime);
      }
    }

    for (int ei = 0; ei < enemySoldiers.length; ei++) {
      if (!_enemyAlive[ei]) {
        _enemyAttackPlayerEntry[ei].clear();
        _enemyDetectionPlayerEntry[ei].clear();
        continue;
      }
      final EnemySoldier es = enemySoldiers[ei];
      final Vector2 pos = es.body.body.position;
      final double rD = soldierDetectionRadiusWorld(es.soldier);
      final double rD2 = rD * rD;
      final Set<String> inA = <String>{};
      final Set<String> inD = <String>{};
      for (int pj = 0; pj < playerSoldierBodies.length; pj++) {
        if (!_playerAlive[pj]) continue;
        final String k = 'p-$pj';
        final Vector2 c = playerSoldierBodies[pj].body.position;
        if ((c - pos).length2 <= rD2) inD.add(k);
        if (_playerContactInEnemyEngagementZone(ei, k)) inA.add(k);
      }
      for (int ej = 0; ej < enemySoldiers.length; ej++) {
        if (ej == ei || !_enemyAlive[ej]) continue;
        if (enemySoldiers[ej].palette == es.palette) continue;
        final String k = 'e-$ej';
        final Vector2 c = enemySoldiers[ej].body.body.position;
        if ((c - pos).length2 <= rD2) inD.add(k);
        if (_rivalContactInEnemyEngagementZone(ei, ej)) inA.add(k);
      }
      _enemyAttackPlayerEntry[ei]
          .removeWhere((String k, double _) => !inA.contains(k));
      for (final String k in inA) {
        _enemyAttackPlayerEntry[ei].putIfAbsent(k, () => _warTime);
      }
      _enemyDetectionPlayerEntry[ei]
          .removeWhere((String k, double _) => !inD.contains(k));
      for (final String k in inD) {
        _enemyDetectionPlayerEntry[ei].putIfAbsent(k, () => _warTime);
      }
    }
  }

  String? _earliestKeyInSet(Set<String> keys, Map<String, double> times) {
    String? best;
    double? bestT;
    for (final String k in keys) {
      final double? t = times[k];
      if (t == null) continue;
      if (bestT == null || t < bestT) {
        bestT = t;
        best = k;
      }
    }
    return best;
  }

  String? _earliestEnemyInEngagementForPlayer(int i) {
    final Set<String> inA = <String>{};
    for (int ei = 0; ei < enemySoldiers.length; ei++) {
      if (!_enemyAlive[ei]) continue;
      if (_enemyContactInPlayerEngagementZone(i, 'e-$ei')) {
        inA.add('e-$ei');
      }
    }
    return _earliestKeyInSet(inA, _playerAttackEntry[i]);
  }

  String? _earliestEnemyInDetectionForPlayer(int i) {
    final Vector2 pos = playerSoldierBodies[i].body.position;
    final double rD = soldierDetectionRadiusWorld(playerCohort.soldier(i));
    final double rD2 = rD * rD;
    final Set<String> inD = <String>{};
    for (int ei = 0; ei < enemySoldiers.length; ei++) {
      final Vector2 c = enemySoldiers[ei].body.body.position;
      if ((c - pos).length2 <= rD2) inD.add('e-$ei');
    }
    return _earliestKeyInSet(inD, _playerDetectionEntry[i]);
  }

  bool _enemyContactInPlayerAttackZone(int playerIndex, String enemyKey) {
    final int ei = int.parse(enemyKey.substring(2));
    final CohortSoldier ps = playerCohort.soldier(playerIndex);
    final Vector2 pPos = playerSoldierBodies[playerIndex].body.position;
    final double pAngle = _lastPlayerFacing[playerIndex];
    final double? aCycleT =
        _playerLockedEnemy[playerIndex] != null ? _playerAttackCycleT[playerIndex] : null;
    final ({Vector2 center, double radius}) az =
        attackZoneWorldCircle(ps, pPos, pAngle, aCycleT);
    final CohortSoldier es = enemySoldiers[ei].soldier;
    final Vector2 ePos = enemySoldiers[ei].body.body.position;
    final double eAngle = _lastEnemySoldierFacing[ei];
    return contactOverlapsAttackCircle(
      contact: es.contact,
      contactBodyPos: ePos,
      contactAngle: eAngle,
      attackCenter: az.center,
      attackRadius: az.radius,
    );
  }

  bool _rivalContactInEnemyAttackZone(int attackerEi, int targetEj) {
    final CohortSoldier attacker = enemySoldiers[attackerEi].soldier;
    final Vector2 aPos = enemySoldiers[attackerEi].body.body.position;
    final double aAngle = _lastEnemySoldierFacing[attackerEi];
    final double? aCycleT =
        _enemyLockedPlayer[attackerEi] != null ? _enemyAttackCycleT[attackerEi] : null;
    final ({Vector2 center, double radius}) az =
        attackZoneWorldCircle(attacker, aPos, aAngle, aCycleT);
    final CohortSoldier target = enemySoldiers[targetEj].soldier;
    final Vector2 tPos = enemySoldiers[targetEj].body.body.position;
    final double tAngle = _lastEnemySoldierFacing[targetEj];
    return contactOverlapsAttackCircle(
      contact: target.contact,
      contactBodyPos: tPos,
      contactAngle: tAngle,
      attackCenter: az.center,
      attackRadius: az.radius,
    );
  }

  bool _rivalContactInEnemyEngagementZone(int attackerEi, int targetEj) {
    final CohortSoldier attacker = enemySoldiers[attackerEi].soldier;
    final Vector2 aPos = enemySoldiers[attackerEi].body.body.position;
    final double aAngle = _lastEnemySoldierFacing[attackerEi];
    if (!attacker.contact.hasEngagement) return false;
    final List<Vector2>? engVerts =
        engagementZoneWorldVerts(attacker.contact, aPos, aAngle);
    if (engVerts == null) return false;
    final CohortSoldier target = enemySoldiers[targetEj].soldier;
    final Vector2 tPos = enemySoldiers[targetEj].body.body.position;
    final double tAngle = _lastEnemySoldierFacing[targetEj];
    return contactOverlapsEngagementPoly(
      contact: target.contact,
      contactBodyPos: tPos,
      contactAngle: tAngle,
      engagementWorldVerts: engVerts,
    );
  }

  String? _earliestTargetInEngagementForEnemy(int enemyIndex) {
    final Set<String> inA = <String>{};
    for (int pj = 0; pj < playerSoldierBodies.length; pj++) {
      if (!_playerAlive[pj]) continue;
      if (_playerContactInEnemyEngagementZone(enemyIndex, 'p-$pj')) {
        inA.add('p-$pj');
      }
    }
    for (int ej = 0; ej < enemySoldiers.length; ej++) {
      if (ej == enemyIndex || !_enemyAlive[ej]) continue;
      if (enemySoldiers[ej].palette == enemySoldiers[enemyIndex].palette) continue;
      if (_rivalContactInEnemyEngagementZone(enemyIndex, ej)) {
        inA.add('e-$ej');
      }
    }
    return _earliestKeyInSet(inA, _enemyAttackPlayerEntry[enemyIndex]);
  }

  String? _earliestTargetInDetectionForEnemy(int enemyIndex) {
    final EnemySoldier es = enemySoldiers[enemyIndex];
    final Vector2 pos = es.body.body.position;
    final double rD = soldierDetectionRadiusWorld(es.soldier);
    final double rD2 = rD * rD;
    final Set<String> inD = <String>{};
    for (int pj = 0; pj < playerSoldierBodies.length; pj++) {
      if (!_playerAlive[pj]) continue;
      final Vector2 c = playerSoldierBodies[pj].body.position;
      if ((c - pos).length2 <= rD2) inD.add('p-$pj');
    }
    for (int ej = 0; ej < enemySoldiers.length; ej++) {
      if (ej == enemyIndex || !_enemyAlive[ej]) continue;
      if (enemySoldiers[ej].palette == es.palette) continue;
      final Vector2 c = enemySoldiers[ej].body.body.position;
      if ((c - pos).length2 <= rD2) inD.add('e-$ej');
    }
    return _earliestKeyInSet(inD, _enemyDetectionPlayerEntry[enemyIndex]);
  }

  bool _playerContactInEnemyAttackZone(int enemyIndex, String playerKey) {
    final int pj = int.parse(playerKey.substring(2));
    final CohortSoldier es = enemySoldiers[enemyIndex].soldier;
    final Vector2 ePos = enemySoldiers[enemyIndex].body.body.position;
    final double eAngle = _lastEnemySoldierFacing[enemyIndex];
    final double? aCycleT =
        _enemyLockedPlayer[enemyIndex] != null ? _enemyAttackCycleT[enemyIndex] : null;
    final ({Vector2 center, double radius}) az =
        attackZoneWorldCircle(es, ePos, eAngle, aCycleT);
    final CohortSoldier ps = playerCohort.soldier(pj);
    final Vector2 pPos = playerSoldierBodies[pj].body.position;
    final double pAngle = _lastPlayerFacing[pj];
    return contactOverlapsAttackCircle(
      contact: ps.contact,
      contactBodyPos: pPos,
      contactAngle: pAngle,
      attackCenter: az.center,
      attackRadius: az.radius,
    );
  }

  // --- Engagement zone overlap (stop chase + trigger attack cycle) ---

  bool _enemyContactInPlayerEngagementZone(int playerIndex, String enemyKey) {
    final int ei = int.parse(enemyKey.substring(2));
    final CohortSoldier ps = playerCohort.soldier(playerIndex);
    final Vector2 pPos = playerSoldierBodies[playerIndex].body.position;
    final double pAngle = _lastPlayerFacing[playerIndex];
    final List<Vector2>? engVerts =
        engagementZoneWorldVerts(ps.contact, pPos, pAngle);
    if (engVerts == null || engVerts.length < 3) {
      return _enemyContactInPlayerAttackZone(playerIndex, enemyKey);
    }
    final CohortSoldier es = enemySoldiers[ei].soldier;
    final Vector2 ePos = enemySoldiers[ei].body.body.position;
    final double eAngle = _lastEnemySoldierFacing[ei];
    return contactOverlapsEngagementPoly(
      contact: es.contact,
      contactBodyPos: ePos,
      contactAngle: eAngle,
      engagementWorldVerts: engVerts,
    );
  }

  bool _playerContactInEnemyEngagementZone(int enemyIndex, String playerKey) {
    final int pj = int.parse(playerKey.substring(2));
    final CohortSoldier es = enemySoldiers[enemyIndex].soldier;
    final Vector2 ePos = enemySoldiers[enemyIndex].body.body.position;
    final double eAngle = _lastEnemySoldierFacing[enemyIndex];
    final List<Vector2>? engVerts =
        engagementZoneWorldVerts(es.contact, ePos, eAngle);
    if (engVerts == null || engVerts.length < 3) {
      return _playerContactInEnemyAttackZone(enemyIndex, playerKey);
    }
    final CohortSoldier ps = playerCohort.soldier(pj);
    final Vector2 pPos = playerSoldierBodies[pj].body.position;
    final double pAngle = _lastPlayerFacing[pj];
    return contactOverlapsEngagementPoly(
      contact: ps.contact,
      contactBodyPos: pPos,
      contactAngle: pAngle,
      engagementWorldVerts: engVerts,
    );
  }

  double _playerSoldierFacingAngle(int i) {
    final bool moving = _playerCohortMoving();
    final Vector2 p = playerSoldierBodies[i].body.position;
    double angle;

    if (moving) {
      final String? ea = _earliestEnemyInEngagementForPlayer(i);
      final String? target = ea ?? _earliestEnemyInDetectionForPlayer(i);
      if (target != null) {
        final Vector2 d = _enemyWorldPosFromKey(target) - p;
        angle = d.length2 < 1e-12 ? _lastPlayerFacing[i] : _aimAngleToward(d);
      } else {
        final Vector2 v = _leaderBody.linearVelocity;
        angle = v.length2 > _moveDirEpsilon2
            ? _aimAngleToward(v)
            : playerCohort.visualAngle;
      }
    } else {
      final String? ed = _earliestEnemyInDetectionForPlayer(i);
      if (ed != null) {
        final Vector2 d = _enemyWorldPosFromKey(ed) - p;
        angle = d.length2 < 1e-12 ? _lastPlayerFacing[i] : _aimAngleToward(d);
      } else {
        angle = _lastPlayerFacing[i];
      }
    }

    if (moving || _earliestEnemyInDetectionForPlayer(i) != null) {
      _lastPlayerFacing[i] = angle;
    }
    return angle;
  }

  double _enemySoldierFacingAngle(int enemyIndex) {
    final EnemySoldier es = enemySoldiers[enemyIndex];
    final bool moving = _enemySoldierMoving(enemyIndex);
    final Vector2 p = es.body.body.position;
    final String? pa = _earliestTargetInEngagementForEnemy(enemyIndex);
    final String? pd = _earliestTargetInDetectionForEnemy(enemyIndex);
    double angle;

    // Order: attack / detection first; avoids flicker when chase speed crosses [_enemySoldierMovingVel].
    if (pa != null) {
      final Vector2 d = _targetWorldPos(pa) - p;
      angle = d.length2 < 1e-12
          ? _lastEnemySoldierFacing[enemyIndex]
          : _aimAngleToward(d);
    } else if (pd != null) {
      final Vector2 d = _targetWorldPos(pd) - p;
      angle = d.length2 < 1e-12
          ? _lastEnemySoldierFacing[enemyIndex]
          : _aimAngleToward(d);
    } else if (moving) {
      final Vector2 v = es.body.body.linearVelocity;
      angle = v.length2 > _moveDirEpsilon2
          ? _aimAngleToward(v)
          : 0;
    } else {
      angle = _lastEnemySoldierFacing[enemyIndex];
    }

    if (moving || pa != null || pd != null) {
      _lastEnemySoldierFacing[enemyIndex] = angle;
    }
    return angle;
  }

  /// While cohort is stationary, chase uses velocity steering so |v| → [cohortMaxSpeed] (same as full-stick leader cap).
  void _applyChaseVelocityToward(Body b, Vector2 targetWorldPos) {
    final Vector2 to = targetWorldPos - b.position;
    if (to.length2 < 1e-10) return;
    final Vector2 dir = to.normalized();
    final Vector2 vWant = dir * cohortMaxSpeed;
    final Vector2 err = vWant - b.linearVelocity;
    b.applyForce(err * b.mass * _chaseVelocitySteerGain);
  }

  /// See class doc: neutral-stick chase applies only when an enemy center is in the soldier’s
  /// detection disk but outside their attack disk.
  void _tickKnockbackTimers(double dt) {
    for (int i = 0; i < _playerKnockbackTimer.length; i++) {
      if (_playerKnockbackTimer[i] > 0) {
        _playerKnockbackTimer[i] = (_playerKnockbackTimer[i] - dt).clamp(0.0, double.infinity);
      }
    }
    for (int i = 0; i < _enemyKnockbackTimer.length; i++) {
      if (_enemyKnockbackTimer[i] > 0) {
        _enemyKnockbackTimer[i] = (_enemyKnockbackTimer[i] - dt).clamp(0.0, double.infinity);
      }
    }
  }

  void _applyChaseForces() {
    if (!_playerCohortMoving()) {
      for (int i = 0; i < playerSoldierBodies.length; i++) {
        if (!_playerAlive[i]) continue;
        if (_playerKnockbackTimer[i] > 0) continue;
        final String? ed = _earliestEnemyInDetectionForPlayer(i);
        if (ed == null) continue;
        if (_enemyContactInPlayerEngagementZone(i, ed)) {
          playerSoldierBodies[i].body.linearVelocity.setZero();
          continue;
        }
        _applyChaseVelocityToward(
          playerSoldierBodies[i].body,
          _enemyWorldPosFromKey(ed),
        );
      }
    }

    for (int ei = 0; ei < enemySoldiers.length; ei++) {
      if (!_enemyAlive[ei]) continue;
      if (_enemyKnockbackTimer[ei] > 0) continue;
      if (_enemySoldierMoving(ei)) continue;
      final String? pd = _earliestTargetInDetectionForEnemy(ei);
      if (pd == null) continue;
      final bool engaged = pd.startsWith('p-')
          ? _playerContactInEnemyEngagementZone(ei, pd)
          : _rivalContactInEnemyEngagementZone(ei, int.parse(pd.substring(2)));
      if (engaged) {
        enemySoldiers[ei].body.body.linearVelocity.setZero();
        continue;
      }
      _applyChaseVelocityToward(
        enemySoldiers[ei].body.body,
        _targetWorldPos(pd),
      );
    }
  }

  // ── Enemy spawn config ──────────────────────────────────────────────
  static const int _initialEnemyCount = 24;
  static const double _waveIntervalSec = 2;
  static const int _waveSize = 10;
  static const int _maxAliveEnemies = 240;
  static const double _spawnRingMin = 200;
  static const double _spawnRingMax = 450;

  final math.Random _spawnRng = math.Random();
  double _nextWaveTime = _waveIntervalSec;
  int _waveNumber = 0;

  void _spawnEnemySoldiers(Vector2 center) {
    final math.Random rng = math.Random(21);
    final double detectionR =
        soldierDetectionRadiusWorld(playerCohort.soldier(0));
    final double minDist = detectionR + 60;

    for (int i = 0; i < _initialEnemyCount; i++) {
      final double angle = rng.nextDouble() * 2 * math.pi;
      final double r =
          minDist + rng.nextDouble() * (_spawnRingMax - minDist).clamp(0, 400);
      final Vector2 worldPos =
          center + Vector2(math.cos(angle) * r, math.sin(angle) * r);
      _addOneEnemy(worldPos);
    }
  }

  int _aliveEnemyCount() {
    int c = 0;
    for (int i = 0; i < _enemyAlive.length; i++) {
      if (_enemyAlive[i]) c++;
    }
    return c;
  }

  void _spawnEnemyWave() {
    _waveNumber++;
    final Vector2 playerCenter = _leaderBody.position;
    final int count = (_waveSize + (_waveNumber ~/ 3)).clamp(1, 10);
    for (int i = 0; i < count; i++) {
      if (_aliveEnemyCount() >= _maxAliveEnemies) return;
      final double angle = _spawnRng.nextDouble() * 2 * math.pi;
      final double r =
          _spawnRingMin + _spawnRng.nextDouble() * (_spawnRingMax - _spawnRingMin);
      final Vector2 worldPos =
          playerCenter + Vector2(math.cos(angle) * r, math.sin(angle) * r);
      _addOneEnemy(worldPos);
    }
  }

  void _addOneEnemy(Vector2 worldPos) {
    final SoldierDesignPalette enemyPalette =
        _enemyPalettes[_spawnRng.nextInt(_enemyPalettes.length)];
    final SoldierDesign enemyDesign = kProductionSoldierDesignCatalog.first;
    final SoldierModel enemyModel = SoldierModel(
      side: 40,
      paintSize: 56,
      isEnemy: true,
      design: enemyDesign,
      displayPalette: enemyPalette,
    );
    final SoldierContact enemyContact =
        SoldierContact.fromDesign(enemyDesign, enemyModel.paintSize);
    final CohortSoldier s = CohortSoldier(
      model: enemyModel,
      canonicalSlot: Vector2.zero(),
      localOffset: Vector2.zero(),
      contact: enemyContact,
    );
    final SoldierContactBody body = _bodyFromContact(enemyContact, worldPos);
    enemySoldiers.add(EnemySoldier(soldier: s, body: body, palette: enemyPalette));
    world.add(body);

    _enemyAttackPlayerEntry.add(<String, double>{});
    _enemyDetectionPlayerEntry.add(<String, double>{});
    _lastEnemySoldierFacing.add(0);
    _enemyHp.add(kGildedBastionMaxHp);
    _enemyMaxHp.add(kGildedBastionMaxHp);
    _enemyAttackCycleT.add(0);
    _enemyLockedPlayer.add(null);
    _enemyDamagedThisPhase.add(<String>{});
    _enemyWasInAttackPhase.add(false);
    _enemyAlive.add(true);
    _enemyKnockbackTimer.add(0);
  }

  void _steer() {
    final Vector2 v = _leaderBody.linearVelocity;
    if (stick.length2 <= _stickNeutral * _stickNeutral) {
      if (v.length2 <= _velocitySnap2) {
        _leaderBody.linearVelocity.setZero();
        return;
      }
    }
    final Vector2 target = stick * cohortMaxSpeed;
    final Vector2 err = target - v;
    _leaderBody.applyForce(err * _leaderBody.mass * steeringGain);
  }

  /// If neutral stick and some enemy center is in soldier *i*’s detection disk — skip formation
  /// for *i* (chase/hold handled in `_applyChaseForces`). Else formation PD for *i*.
  void _applySoldierFormationForces() {
    final Vector2 lc = _leaderBody.position;
    final Vector2 vLeader = _leaderBody.linearVelocity;
    final double c = soldierFormationVelDamp;

    for (int i = 0; i < playerSoldierBodies.length; i++) {
      if (!_playerAlive[i]) continue;
      if (_playerKnockbackTimer[i] > 0) continue;
      if (!_playerCohortMoving() &&
          _earliestEnemyInDetectionForPlayer(i) != null) {
        continue;
      }
      final Body b = playerSoldierBodies[i].body;
      final Vector2 target = lc + playerCohort.formationTargetLocal(i);
      final Vector2 err = target - b.position;
      final Vector2 relVel = b.linearVelocity - vLeader;
      final Vector2 accel = err * soldierFormationGain - relVel * c;
      b.applyForce(accel * b.mass);
    }
  }

  void _syncSoldierOffsetsFromBodies() {
    final Vector2 lc = _leaderBody.position;
    for (int i = 0; i < playerSoldierBodies.length; i++) {
      playerCohort.soldier(i).localOffset =
          playerSoldierBodies[i].body.position - lc;
    }
  }

  void _snapshotVelocitiesBeforeStep() {
    _leaderSoldierVelBefore.setFrom(_leaderBody.linearVelocity);
    for (int i = 0; i < playerSoldierBodies.length; i++) {
      _soldierVelBefore[i].setFrom(playerSoldierBodies[i].body.linearVelocity);
    }
  }

  /// With stick neutral, spring/damping can overshoot and briefly reverse velocity;
  /// zero it when the new velocity opposes the previous step's direction.
  void _neutralClampOppositeVelocities() {
    if (stick.length2 > _stickNeutral * _stickNeutral) return;

    void clampIfFlipped(Body body, Vector2 velBefore) {
      if (velBefore.length2 <= _neutralOppClampMinVel2) return;
      final Vector2 v = body.linearVelocity;
      if (v.dot(velBefore) < 0) {
        body.linearVelocity.setZero();
      }
    }

    clampIfFlipped(_leaderBody, _leaderSoldierVelBefore);
    for (int i = 0; i < playerSoldierBodies.length; i++) {
      clampIfFlipped(playerSoldierBodies[i].body, _soldierVelBefore[i]);
    }
  }

  @override
  void update(double dt) {
    if (gameOver.value) return;
    _tickKnockbackTimers(dt);
    _snapshotVelocitiesBeforeStep();
    _steer();
    playerCohort.update(dt, stick, integratePositions: false);
    _warTime += dt;
    _updateRangeEntryMaps();
    _applySoldierFormationForces();
    _applyChaseForces();
    super.update(dt);

    _neutralClampOppositeVelocities();

    _syncSoldierOffsetsFromBodies();

    _updateCombat(dt);

    if (_warTime >= _nextWaveTime && _aliveEnemyCount() < _maxAliveEnemies) {
      _spawnEnemyWave();
      _nextWaveTime = _warTime + _waveIntervalSec;
    }

    final Vector2 v = _leaderBody.linearVelocity;
    velocityHud.value = Vector2(v.x, v.y);

    if (playerSoldierBodies.isNotEmpty) {
      final Vector2 p = playerSoldierBodies[0].body.position;
      soldier1PosHud.value = Vector2(p.x, p.y);
    }
  }

  // ---------------------------------------------------------------------------
  // Attack cycle & damage
  // ---------------------------------------------------------------------------

  bool _isAttackPhase(double cycleT) {
    return MultiPolygonSoldierPainter.attackProbeEnvelope(cycleT) > 0;
  }

  void _updateCombat(double dt) {
    final double dtNorm = dt / kAttackCycleSeconds;

    // --- Player soldiers ---
    for (int i = 0; i < playerCohort.soldierCount; i++) {
      if (!_playerAlive[i]) continue;

      final String? detected = _earliestEnemyInDetectionForPlayer(i);
      if (detected == null) {
        _playerLockedEnemy[i] = null;
        _playerAttackCycleT[i] = 0;
        _playerDamagedThisPhase[i].clear();
        _playerWasInAttackPhase[i] = false;
        continue;
      }
      _playerLockedEnemy[i] ??= detected;
      if (!_playerDetectionEntry[i].containsKey(_playerLockedEnemy[i])) {
        _playerLockedEnemy[i] = detected;
        _playerAttackCycleT[i] = 0;
        _playerDamagedThisPhase[i].clear();
        _playerWasInAttackPhase[i] = false;
      }
      final String locked = _playerLockedEnemy[i]!;

      final int ei = int.parse(locked.substring(2));
      if (ei >= enemySoldiers.length || !_enemyAlive[ei]) {
        _playerLockedEnemy[i] = detected != locked ? detected : null;
        _playerAttackCycleT[i] = 0;
        _playerDamagedThisPhase[i].clear();
        _playerWasInAttackPhase[i] = false;
        continue;
      }

      final bool engaged = _enemyContactInPlayerEngagementZone(i, locked);
      if (!engaged) {
        _playerAttackCycleT[i] = 0;
        _playerDamagedThisPhase[i].clear();
        _playerWasInAttackPhase[i] = false;
        continue;
      }

      _playerAttackCycleT[i] = (_playerAttackCycleT[i] + dtNorm) % 1.0;
      final bool inAttack = _isAttackPhase(_playerAttackCycleT[i]);

      if (!_playerWasInAttackPhase[i] && inAttack) {
        _playerDamagedThisPhase[i].clear();
      }
      _playerWasInAttackPhase[i] = inAttack;

      if (inAttack) {
        final Vector2 attackerPos = playerSoldierBodies[i].body.position;
        for (int ej = 0; ej < enemySoldiers.length; ej++) {
          if (!_enemyAlive[ej]) continue;
          final String ek = 'e-$ej';
          if (_playerDamagedThisPhase[i].contains(ek)) continue;
          if (_enemyContactInPlayerAttackZone(i, ek)) {
            _playerDamagedThisPhase[i].add(ek);
            _enemyHp[ej] = (_enemyHp[ej] - kGildedBastionAttackDmg).clamp(0, _enemyMaxHp[ej]);
            final Vector2 targetPos = enemySoldiers[ej].body.body.position;
            final Vector2 dir = targetPos - attackerPos;
            if (dir.length2 > 0.01) {
              enemySoldiers[ej].body.body.linearVelocity.setFrom(
                dir.normalized() * kKnockbackSpeed,
              );
              _enemyKnockbackTimer[ej] = kKnockbackCooldown;
            }
            _spawnDamageText(targetPos, kGildedBastionAttackDmg, playerPalette);
            if (_enemyHp[ej] <= 0) {
              _killEnemy(ej);
            }
          }
        }
      }
    }

    // --- Enemy soldiers (target = player OR rival enemy) ---
    for (int ei = 0; ei < enemySoldiers.length; ei++) {
      if (!_enemyAlive[ei]) continue;

      final String? detected = _earliestTargetInDetectionForEnemy(ei);
      if (detected == null) {
        _enemyLockedPlayer[ei] = null;
        _enemyAttackCycleT[ei] = 0;
        _enemyDamagedThisPhase[ei].clear();
        _enemyWasInAttackPhase[ei] = false;
        continue;
      }
      _enemyLockedPlayer[ei] ??= detected;
      if (!_enemyDetectionPlayerEntry[ei].containsKey(_enemyLockedPlayer[ei])) {
        _enemyLockedPlayer[ei] = detected;
        _enemyAttackCycleT[ei] = 0;
        _enemyDamagedThisPhase[ei].clear();
        _enemyWasInAttackPhase[ei] = false;
      }
      final String locked = _enemyLockedPlayer[ei]!;

      final bool targetAlive = locked.startsWith('p-')
          ? (int.parse(locked.substring(2)) < playerCohort.soldierCount &&
              _playerAlive[int.parse(locked.substring(2))])
          : (int.parse(locked.substring(2)) < enemySoldiers.length &&
              _enemyAlive[int.parse(locked.substring(2))]);
      if (!targetAlive) {
        _enemyLockedPlayer[ei] = detected != locked ? detected : null;
        _enemyAttackCycleT[ei] = 0;
        _enemyDamagedThisPhase[ei].clear();
        _enemyWasInAttackPhase[ei] = false;
        continue;
      }

      final bool engaged = locked.startsWith('p-')
          ? _playerContactInEnemyEngagementZone(ei, locked)
          : _rivalContactInEnemyEngagementZone(
              ei, int.parse(locked.substring(2)));
      if (!engaged) {
        _enemyAttackCycleT[ei] = 0;
        _enemyDamagedThisPhase[ei].clear();
        _enemyWasInAttackPhase[ei] = false;
        continue;
      }

      _enemyAttackCycleT[ei] = (_enemyAttackCycleT[ei] + dtNorm) % 1.0;
      final bool inAttack = _isAttackPhase(_enemyAttackCycleT[ei]);

      if (!_enemyWasInAttackPhase[ei] && inAttack) {
        _enemyDamagedThisPhase[ei].clear();
      }
      _enemyWasInAttackPhase[ei] = inAttack;

      if (inAttack) {
        final Vector2 attackerPos = enemySoldiers[ei].body.body.position;
        final SoldierDesignPalette attackerPal = enemySoldiers[ei].palette;
        for (int pj = 0; pj < playerCohort.soldierCount; pj++) {
          if (!_playerAlive[pj]) continue;
          final String pk = 'p-$pj';
          if (_enemyDamagedThisPhase[ei].contains(pk)) continue;
          if (_playerContactInEnemyAttackZone(ei, pk)) {
            _enemyDamagedThisPhase[ei].add(pk);
            _playerHp[pj] = (_playerHp[pj] - kGildedBastionAttackDmg).clamp(0, _playerMaxHp[pj]);
            final Vector2 targetPos = playerSoldierBodies[pj].body.position;
            final Vector2 dir = targetPos - attackerPos;
            if (dir.length2 > 0.01) {
              playerSoldierBodies[pj].body.linearVelocity.setFrom(
                dir.normalized() * kKnockbackSpeed,
              );
              _playerKnockbackTimer[pj] = kKnockbackCooldown;
            }
            _spawnDamageText(targetPos, kGildedBastionAttackDmg, attackerPal);
            if (_playerHp[pj] <= 0) _killPlayer(pj);
          }
        }
        for (int ej = 0; ej < enemySoldiers.length; ej++) {
          if (ej == ei || !_enemyAlive[ej]) continue;
          final String ek = 'e-$ej';
          if (_enemyDamagedThisPhase[ei].contains(ek)) continue;
          if (_rivalContactInEnemyAttackZone(ei, ej)) {
            _enemyDamagedThisPhase[ei].add(ek);
            _enemyHp[ej] = (_enemyHp[ej] - kGildedBastionAttackDmg).clamp(0, _enemyMaxHp[ej]);
            final Vector2 targetPos = enemySoldiers[ej].body.body.position;
            final Vector2 dir = targetPos - attackerPos;
            if (dir.length2 > 0.01) {
              enemySoldiers[ej].body.body.linearVelocity.setFrom(
                dir.normalized() * kKnockbackSpeed,
              );
              _enemyKnockbackTimer[ej] = kKnockbackCooldown;
            }
            _spawnDamageText(targetPos, kGildedBastionAttackDmg, attackerPal);
            if (_enemyHp[ej] <= 0) _killEnemy(ej);
          }
        }
      }
    }
  }

  void _killEnemy(int ei) {
    _enemyAlive[ei] = false;
    final CohortSoldier s = enemySoldiers[ei].soldier;
    final Vector2 pos = enemySoldiers[ei].body.body.position;
    world.remove(enemySoldiers[ei].body);
    world.add(_DeathRemnant(
      worldPos: pos.clone(),
      model: s.model,
    ));
    _enemyLockedPlayer[ei] = null;
    _enemyAttackCycleT[ei] = 0;
    for (int i = 0; i < playerCohort.soldierCount; i++) {
      if (_playerLockedEnemy[i] == 'e-$ei') {
        _playerLockedEnemy[i] = null;
        _playerAttackCycleT[i] = 0;
        _playerDamagedThisPhase[i].clear();
        _playerWasInAttackPhase[i] = false;
      }
    }
    for (int ej = 0; ej < enemySoldiers.length; ej++) {
      if (_enemyLockedPlayer[ej] == 'e-$ei') {
        _enemyLockedPlayer[ej] = null;
        _enemyAttackCycleT[ej] = 0;
        _enemyDamagedThisPhase[ej].clear();
        _enemyWasInAttackPhase[ej] = false;
      }
    }
  }

  void _killPlayer(int pj) {
    _playerAlive[pj] = false;
    final CohortSoldier s = playerCohort.soldier(pj);
    final Vector2 pos = playerSoldierBodies[pj].body.position;
    world.remove(playerSoldierBodies[pj]);
    world.add(_DeathRemnant(
      worldPos: pos.clone(),
      model: s.model,
    ));
    _playerLockedEnemy[pj] = null;
    _playerAttackCycleT[pj] = 0;
    if (pj == 0) {
      gameOver.value = true;
    }
    for (int ei = 0; ei < enemySoldiers.length; ei++) {
      if (_enemyLockedPlayer[ei] == 'p-$pj') {
        _enemyLockedPlayer[ei] = null;
        _enemyAttackCycleT[ei] = 0;
        _enemyDamagedThisPhase[ei].clear();
        _enemyWasInAttackPhase[ei] = false;
      }
    }
  }

  void _spawnDamageText(Vector2 worldPos, int amount, SoldierDesignPalette attackerPalette) {
    world.add(_FloatingDamageText(
      worldPos: worldPos.clone(),
      amount: amount,
      color: factionTierList(attackerPalette)[0],
    ));
  }
}

/// One enemy unit: a single [CohortSoldier] (visual + contact) and its Forge2D body.
/// There is no enemy cohort—only independent soldiers.
class EnemySoldier {
  EnemySoldier({
    required this.soldier,
    required this.body,
    required this.palette,
  });

  final CohortSoldier soldier;
  final SoldierContactBody body;
  final SoldierDesignPalette palette;
}

/// Floating damage number that drifts upward and fades out.
class _FloatingDamageText extends Component {
  _FloatingDamageText({
    required this.worldPos,
    required this.amount,
    required this.color,
  });

  final Vector2 worldPos;
  final int amount;
  final Color color;

  static const double _lifetime = 1.2;
  static const double _riseSpeed = 40.0;
  double _elapsed = 0;

  @override
  int get priority => 100;

  @override
  void update(double dt) {
    _elapsed += dt;
    worldPos.y -= _riseSpeed * dt;
    if (_elapsed >= _lifetime) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final double t = (_elapsed / _lifetime).clamp(0.0, 1.0);
    final double alpha = t < 0.6 ? 1.0 : 1.0 - ((t - 0.6) / 0.4);
    final double scale = t < 0.1 ? 0.5 + 5.0 * t : 1.0;
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: '$amount',
        style: TextStyle(
          color: color.withValues(alpha: alpha),
          fontSize: 12 * scale,
          fontWeight: FontWeight.w900,
          shadows: <Shadow>[
            Shadow(
              color: Colors.black.withValues(alpha: alpha * 0.85),
              blurRadius: 3,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(worldPos.x - tp.width / 2, worldPos.y - tp.height / 2));
    tp.dispose();
  }
}

/// Dead soldier remnant: top-down paint splatter that expands, lingers, then fades.
class _DeathRemnant extends Component {
  _DeathRemnant({
    required this.worldPos,
    required this.model,
  }) : _rng = math.Random(worldPos.x.hashCode ^ worldPos.y.hashCode);

  final Vector2 worldPos;
  final SoldierModel model;
  final math.Random _rng;

  static const double _expandDuration = 0.15;
  static const double _lingerDuration = 2.5;
  static const double _fadeDuration = 0.6;
  static const double _totalLifetime =
      _expandDuration + _lingerDuration + _fadeDuration;

  static const int _lobeCount = 10;
  static const int _subDrops = 5;

  double _elapsed = 0;

  late final double _baseRadius;
  late final List<double> _lobeRadii;
  late final List<double> _lobeAngles;
  late final List<_SplatDrop> _drops;
  late final Color _coreColor;
  late final Color _rimColor;

  bool _generated = false;

  void _ensureGenerated() {
    if (_generated) return;
    _generated = true;
    _baseRadius = model.paintSize * 0.35;
    _lobeRadii = List<double>.generate(
      _lobeCount,
      (_) => _baseRadius * (0.7 + _rng.nextDouble() * 0.6),
    );
    _lobeAngles = List<double>.generate(
      _lobeCount,
      (i) => (i / _lobeCount) * 2 * math.pi + (_rng.nextDouble() - 0.5) * 0.3,
    );
    _drops = List<_SplatDrop>.generate(_subDrops, (_) {
      final double a = _rng.nextDouble() * 2 * math.pi;
      final double dist = _baseRadius * (1.0 + _rng.nextDouble() * 0.8);
      return _SplatDrop(
        offset: Offset(math.cos(a) * dist, math.sin(a) * dist),
        radius: _baseRadius * (0.12 + _rng.nextDouble() * 0.18),
      );
    });

    final List<Color> tier = factionTierList(model.displayPalette!);
    _coreColor = Color.lerp(tier[0], Colors.black, 0.35)!;
    _rimColor = Color.lerp(tier.length > 1 ? tier[1] : tier[0], Colors.black, 0.5)!;
  }

  @override
  int get priority => 1;

  @override
  void update(double dt) {
    _elapsed += dt;
    if (_elapsed >= _totalLifetime) {
      removeFromParent();
    }
  }

  Path _buildSplatPath(double scale) {
    final Path path = Path();
    for (int i = 0; i <= _lobeCount; i++) {
      final int idx = i % _lobeCount;
      final int next = (i + 1) % _lobeCount;
      final double a = _lobeAngles[idx];
      final double r = _lobeRadii[idx] * scale;
      final double x = math.cos(a) * r;
      final double y = math.sin(a) * r;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final double aMid = (a + _lobeAngles[next]) / 2;
        final double rMid = (_lobeRadii[idx] + _lobeRadii[next]) / 2 * scale * 0.75;
        path.quadraticBezierTo(
          math.cos(aMid) * rMid,
          math.sin(aMid) * rMid,
          x,
          y,
        );
      }
    }
    path.close();
    return path;
  }

  @override
  void render(Canvas canvas) {
    if (model.displayPalette == null) return;
    _ensureGenerated();

    final double t = _elapsed;
    final double scale;
    final double alpha;
    if (t < _expandDuration) {
      scale = 0.3 + 0.7 * (t / _expandDuration);
      alpha = 1.0;
    } else if (t < _expandDuration + _lingerDuration) {
      scale = 1.0;
      alpha = 1.0;
    } else {
      scale = 1.0;
      final double fadeT =
          ((t - _expandDuration - _lingerDuration) / _fadeDuration)
              .clamp(0.0, 1.0);
      alpha = 1.0 - fadeT;
    }

    canvas.save();
    canvas.translate(worldPos.x, worldPos.y);

    final Path mainBlob = _buildSplatPath(scale);
    final Paint corePaint = Paint()
      ..color = _coreColor.withValues(alpha: alpha * 0.85)
      ..style = PaintingStyle.fill;
    final Paint rimPaint = Paint()
      ..color = _rimColor.withValues(alpha: alpha * 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 * scale;

    canvas.drawPath(mainBlob, corePaint);
    canvas.drawPath(mainBlob, rimPaint);

    final Paint dropPaint = Paint()
      ..color = _coreColor.withValues(alpha: alpha * 0.7)
      ..style = PaintingStyle.fill;
    for (final _SplatDrop drop in _drops) {
      canvas.drawCircle(
        drop.offset * scale,
        drop.radius * scale,
        dropPaint,
      );
    }

    canvas.restore();
  }
}

class _SplatDrop {
  const _SplatDrop({required this.offset, required this.radius});
  final Offset offset;
  final double radius;
}

/// Draws zone overlays per soldier following [soldier_structure.md] hierarchy:
///   Core body (sprites) → **Contact zone** → Attack (sprites) → **Attack zone** → **Detection zone** → Center dot.
///
/// Split into layers by [priority] so each zone sits at the correct z relative to sprite painters:
///   • [_WarContactZoneLayer] (priority 21) — above core+attack sprites (PlayerFormation=20).
///   • [_WarAttackZoneLayer] (priority 22) — above contact.
///   • [_WarDetectionZoneLayer] (priority 23) — above attack zone.

typedef _SoldierAccessor = ({
  int Function() count,
  CohortSoldier Function(int) soldier,
  Vector2 Function(int) position,
  double Function(int) angle,
  bool Function(int) alive,
});

/// **Contact zone** — polygon from design, or fallback circle.
class _WarContactZoneLayer extends Component {
  _WarContactZoneLayer({required this.player, required this.enemy});
  final _SoldierAccessor player;
  final _SoldierAccessor enemy;

  static bool visible = false;

  static final Paint _stroke = Paint()
    ..color = const Color(0xFF00C853).withValues(alpha: 0.7)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  @override
  int get priority => 21;

  static void _paint(Canvas canvas, CohortSoldier s, Vector2 pos, double angle) {
    final SoldierDesign? d = s.model.design;
    if (d == null) {
      canvas.drawCircle(Offset(pos.x, pos.y), s.contact.radius, _stroke);
      return;
    }
    final Size sz = Size(s.model.paintSize, s.model.paintSize);
    final double fit = MultiPolygonSoldierPainter.layoutMetrics(
      parts: d.parts, soldierCanvasSize: sz, motionT: 0.25, attackCycleT: null,
    ).fitScale;
    final Offset anchor = MultiPolygonSoldierPainter.modelBboxCenter(
      parts: d.parts, motionT: 0.25, attackCycleT: null,
    );
    for (final SoldierShapePart p in d.parts) {
      if (p.stackRole != SoldierPartStackRole.contact) continue;
      final List<Offset>? hull =
          MultiPolygonSoldierPainter.transformedFillVertices(p, 0.25, null);
      if (hull == null || hull.length < 3) continue;
      final double c = math.cos(angle);
      final double sn = math.sin(angle);
      final Path path = Path();
      for (int i = 0; i < hull.length; i++) {
        final double mx = (hull[i].dx - anchor.dx) * fit;
        final double my = (hull[i].dy - anchor.dy) * fit;
        final double wx = pos.x + c * mx - sn * my;
        final double wy = pos.y + sn * mx + c * my;
        if (i == 0) { path.moveTo(wx, wy); } else { path.lineTo(wx, wy); }
      }
      path.close();
      canvas.drawPath(path, _stroke);
      return;
    }
    canvas.drawCircle(Offset(pos.x, pos.y), s.contact.radius, _stroke);
  }

  @override
  void render(Canvas canvas) {
    if (!visible) return;
    for (int i = 0; i < player.count(); i++) {
      if (!player.alive(i)) continue;
      _paint(canvas, player.soldier(i), player.position(i), player.angle(i));
    }
    for (int i = 0; i < enemy.count(); i++) {
      if (!enemy.alive(i)) continue;
      _paint(canvas, enemy.soldier(i), enemy.position(i), enemy.angle(i));
    }
  }
}

/// **Engagement zone** — polygon from [SoldierPartStackRole.engagement] transformed to world space.
class _WarEngagementZoneLayer extends Component {
  _WarEngagementZoneLayer({required this.player, required this.enemy});
  final _SoldierAccessor player;
  final _SoldierAccessor enemy;

  static bool visible = false;

  static final Paint _stroke = Paint()
    ..color = const Color(0xFF2E7D32).withValues(alpha: 0.7)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  @override
  int get priority => 21;

  static void _paint(Canvas canvas, CohortSoldier s, Vector2 pos, double angle) {
    if (!s.contact.hasEngagement) return;
    final List<Vector2>? verts =
        engagementZoneWorldVerts(s.contact, pos, angle);
    if (verts == null || verts.length < 3) return;
    final Path path = Path();
    for (int i = 0; i < verts.length; i++) {
      if (i == 0) {
        path.moveTo(verts[i].x, verts[i].y);
      } else {
        path.lineTo(verts[i].x, verts[i].y);
      }
    }
    path.close();
    canvas.drawPath(path, _stroke);
  }

  @override
  void render(Canvas canvas) {
    if (!visible) return;
    for (int i = 0; i < player.count(); i++) {
      if (!player.alive(i)) continue;
      _paint(canvas, player.soldier(i), player.position(i), player.angle(i));
    }
    for (int i = 0; i < enemy.count(); i++) {
      if (!enemy.alive(i)) continue;
      _paint(canvas, enemy.soldier(i), enemy.position(i), enemy.angle(i));
    }
  }
}

/// **Hit zone** (formerly "Attack zone") — crown-based disk (same as design scene [SoldierRangeRingsPainter]):
/// finds the **triangular** attack part with [attackProbeExtend], computes its circumradius × 1.32,
/// and centers on the crown centroid in world space. Falls back to `contact × attack scale` only
/// when no crown triangle exists.
class _WarAttackZoneLayer extends Component {
  _WarAttackZoneLayer({
    required this.player,
    required this.enemy,
    required this.playerAttackCycleT,
    required this.enemyAttackCycleT,
  });
  final _SoldierAccessor player;
  final _SoldierAccessor enemy;
  final double? Function(int) playerAttackCycleT;
  final double? Function(int) enemyAttackCycleT;

  static bool visible = false;

  static const double _crownRadiusMul = 1.32;

  static final Paint _stroke = Paint()
    ..color = const Color(0xFF1B5E20).withValues(alpha: 0.7)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  @override
  int get priority => 22;

  static void _draw(Canvas canvas, CohortSoldier s, Vector2 bodyPos, double angleRad, double? aCycleT) {
    final SoldierDesign? d = s.model.design;
    if (d != null) {
      final Size sz = Size(s.model.paintSize, s.model.paintSize);
      final double fit = MultiPolygonSoldierPainter.layoutMetrics(
        parts: d.parts, soldierCanvasSize: sz, motionT: 0.25,
        attackCycleT: null,
      ).fitScale;
      final Offset anchor = MultiPolygonSoldierPainter.modelBboxCenter(
        parts: d.parts, motionT: 0.25,
        attackCycleT: null,
      );

      for (final SoldierShapePart p in d.parts) {
        if (p.stackRole != SoldierPartStackRole.attack) continue;
        if (p.motion != SoldierPartMotion.attackProbeExtend) continue;
        final List<Offset>? tv = MultiPolygonSoldierPainter.transformedFillVertices(
          p, 0.25, aCycleT,
        );
        if (tv == null || tv.length != 3) continue;

        double sx = 0, sy = 0;
        for (final Offset v in tv) { sx += v.dx; sy += v.dy; }
        final Offset cen = Offset(sx / 3, sy / 3);
        double best = 0;
        for (final Offset v in tv) {
          final double dd = (v - cen).distance;
          if (dd > best) best = dd;
        }
        double crownR = best * _crownRadiusMul * fit;
        if (d.crownVfxMode == CrownVfxMode.scalingCrown) {
          final double envScale = aCycleT != null
              ? 1.0 + 2.0 * MultiPolygonSoldierPainter.attackProbeEnvelope(aCycleT)
              : 1.0;
          crownR *= envScale * 0.55;
        }

        final double mx = (cen.dx - anchor.dx) * fit;
        final double my = (cen.dy - anchor.dy) * fit;
        final double c = math.cos(angleRad);
        final double sn = math.sin(angleRad);
        final double wx = bodyPos.x + c * mx - sn * my;
        final double wy = bodyPos.y + sn * mx + c * my;

        canvas.drawCircle(Offset(wx, wy), crownR, _stroke);
        return;
      }
    }

    canvas.drawCircle(
      Offset(bodyPos.x, bodyPos.y),
      s.contact.radius * kSoldierAttackRangeRadiusScale,
      _stroke,
    );
  }

  @override
  void render(Canvas canvas) {
    if (!visible) return;
    for (int i = 0; i < player.count(); i++) {
      if (!player.alive(i)) continue;
      _draw(canvas, player.soldier(i), player.position(i), player.angle(i), playerAttackCycleT(i));
    }
    for (int i = 0; i < enemy.count(); i++) {
      if (!enemy.alive(i)) continue;
      _draw(canvas, enemy.soldier(i), enemy.position(i), enemy.angle(i), enemyAttackCycleT(i));
    }
  }
}

/// **Detection zone** — circle at body center, radius = [kSoldierDetectionRadiusModelUnits] × fit scale.
class _WarDetectionZoneLayer extends Component {
  _WarDetectionZoneLayer({required this.player, required this.enemy});
  final _SoldierAccessor player;
  final _SoldierAccessor enemy;

  static bool visible = false;

  static final Paint _stroke = Paint()
    ..color = const Color(0xFF40C4FF).withValues(alpha: 0.55)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  @override
  int get priority => 23;

  @override
  void render(Canvas canvas) {
    if (!visible) return;
    void draw(CohortSoldier s, Vector2 p) {
      canvas.drawCircle(
        Offset(p.x, p.y),
        soldierDetectionRadiusWorld(s),
        _stroke,
      );
    }
    for (int i = 0; i < player.count(); i++) {
      if (!player.alive(i)) continue;
      draw(player.soldier(i), player.position(i));
    }
    for (int i = 0; i < enemy.count(); i++) {
      if (!enemy.alive(i)) continue;
      draw(enemy.soldier(i), enemy.position(i));
    }
  }
}

class PlayerFormationPainter extends Component {
  PlayerFormationPainter({
    required this.runtime,
    required this.soldierWorldPosition,
    required this.visualAngleForSoldier,
    required this.attackCycleForSoldier,
    required this.isAlive,
  });

  final CohortRuntime runtime;
  final Vector2 Function(int index) soldierWorldPosition;
  final double Function(int index) visualAngleForSoldier;
  final double? Function(int index) attackCycleForSoldier;
  final bool Function(int index) isAlive;

  static const double _idleCycleSec = 1.4;
  double _motionT = 0;

  @override
  int get priority => 20;

  @override
  void update(double dt) {
    _motionT = (_motionT + dt / _idleCycleSec) % 1.0;
  }

  @override
  void render(Canvas canvas) {
    for (int i = 0; i < runtime.soldierCount; i++) {
      if (!isAlive(i)) continue;
      final CohortSoldier s = runtime.soldier(i);
      final SoldierModel m = s.model;
      final Vector2 p = soldierWorldPosition(i);
      final double half = m.paintSize / 2;
      final double angle = visualAngleForSoldier(i);
      final double? aCycleT = attackCycleForSoldier(i);
      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(angle);
      canvas.translate(-half, -half);
      final Size sz = Size(m.paintSize, m.paintSize);
      if (m.design != null && m.displayPalette != null) {
        final List<SoldierShapePart> parts = m.design!.parts;
        final double fit = MultiPolygonSoldierPainter.layoutMetrics(
          parts: parts,
          soldierCanvasSize: sz,
          motionT: 0.25,
          attackCycleT: null,
        ).fitScale;
        final Offset anchor = MultiPolygonSoldierPainter.modelBboxCenter(
          parts: parts,
          motionT: 0.25,
          attackCycleT: null,
        );
        MultiPolygonSoldierPainter(
          parts: parts,
          displayPalette: m.displayPalette!,
          strokeWidth: 2.25,
          motionT: _motionT,
          attackCycleT: aCycleT,
          uniformWorldScale: fit,
          fixedModelAnchor: anchor,
          crownVfxMode: m.design!.crownVfxMode,
        ).paint(canvas, sz);
      } else {
        TriangleSoldierPainter(side: m.side).paint(canvas, sz);
      }
      canvas.restore();
    }
  }
}

class EnemySoldiersPainter extends Component {
  EnemySoldiersPainter({
    required this.enemyCount,
    required this.soldier,
    required this.soldierWorldPosition,
    required this.visualAngleForSoldier,
    required this.attackCycleForSoldier,
    required this.isAlive,
  });

  final int Function() enemyCount;
  final CohortSoldier Function(int index) soldier;
  final Vector2 Function(int index) soldierWorldPosition;
  final double Function(int index) visualAngleForSoldier;
  final double? Function(int index) attackCycleForSoldier;
  final bool Function(int index) isAlive;

  static const double _idleCycleSec = 1.4;
  double _motionT = 0;

  @override
  int get priority => 5;

  @override
  void update(double dt) {
    _motionT = (_motionT + dt / _idleCycleSec) % 1.0;
  }

  @override
  void render(Canvas canvas) {
    for (int i = 0; i < enemyCount(); i++) {
      if (!isAlive(i)) continue;
      final CohortSoldier s = soldier(i);
      final SoldierModel m = s.model;
      final Vector2 p = soldierWorldPosition(i);
      final double half = m.paintSize / 2;
      final double angle = visualAngleForSoldier(i);
      final double? aCycleT = attackCycleForSoldier(i);
      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(angle);
      canvas.translate(-half, -half);
      final Size sz = Size(m.paintSize, m.paintSize);
      if (m.design != null && m.displayPalette != null) {
        final List<SoldierShapePart> parts = m.design!.parts;
        final double fit = MultiPolygonSoldierPainter.layoutMetrics(
          parts: parts,
          soldierCanvasSize: sz,
          motionT: 0.25,
          attackCycleT: null,
        ).fitScale;
        final Offset anchor = MultiPolygonSoldierPainter.modelBboxCenter(
          parts: parts,
          motionT: 0.25,
          attackCycleT: null,
        );
        MultiPolygonSoldierPainter(
          parts: parts,
          displayPalette: m.displayPalette!,
          strokeWidth: 2.25,
          motionT: _motionT,
          attackCycleT: aCycleT,
          uniformWorldScale: fit,
          fixedModelAnchor: anchor,
          crownVfxMode: m.design!.crownVfxMode,
        ).paint(canvas, sz);
      } else {
        OrangeTrianglePainter(side: m.side).paint(
          canvas,
          sz,
        );
      }
      canvas.restore();
    }
  }
}

/// **Center dot** — small green filled circle at the soldier's body position (rotation pivot).
class _WarCenterDotLayer extends Component {
  _WarCenterDotLayer({required this.player, required this.enemy});
  final _SoldierAccessor player;
  final _SoldierAccessor enemy;

  static bool visible = false;

  static final Paint _fill = Paint()..color = const Color(0xFF14532D).withValues(alpha: 0.98);
  static const double _dotR = 2.5;

  @override
  int get priority => 24;

  @override
  void render(Canvas canvas) {
    if (!visible) return;
    for (int i = 0; i < player.count(); i++) {
      if (!player.alive(i)) continue;
      final Vector2 p = player.position(i);
      canvas.drawCircle(Offset(p.x, p.y), _dotR, _fill);
    }
    for (int i = 0; i < enemy.count(); i++) {
      if (!enemy.alive(i)) continue;
      final Vector2 p = enemy.position(i);
      canvas.drawCircle(Offset(p.x, p.y), _dotR, _fill);
    }
  }
}

/// **HP bar** — thin horizontal bar above each soldier, partitioned into 5 equal
/// segments colored by the soldier's faction tier palette (index 1 for the highest
/// HP segment through index 5 for the lowest).
class _WarHpBarLayer extends Component {
  _WarHpBarLayer({
    required this.player,
    required this.enemy,
    required this.playerHp,
    required this.playerMaxHp,
    required this.enemyHp,
    required this.enemyMaxHp,
  });

  final _SoldierAccessor player;
  final _SoldierAccessor enemy;
  final List<int> Function() playerHp;
  final List<int> Function() playerMaxHp;
  final List<int> Function() enemyHp;
  final List<int> Function() enemyMaxHp;

  static const double _barWidth = 34;
  static const double _barHeight = 4;
  static const double _yOffset = -32;
  static const int _segments = 5;

  static final Paint _bgPaint = Paint()..color = const Color(0xAA000000);
  static final Paint _borderPaint = Paint()
    ..color = const Color(0xBBFFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.5;
  static final Paint _segPaint = Paint();

  @override
  int get priority => 25;

  static void _drawBar(
    Canvas canvas,
    Vector2 pos,
    int hp,
    int maxHp,
    List<Color> tierColors,
  ) {
    if (maxHp <= 0) return;
    final double left = pos.x - _barWidth / 2;
    final double top = pos.y + _yOffset;
    final Rect bg = Rect.fromLTWH(left, top, _barWidth, _barHeight);
    canvas.drawRect(bg, _bgPaint);

    final double ratio = (hp / maxHp).clamp(0.0, 1.0);
    final double fillW = _barWidth * ratio;
    final double segW = _barWidth / _segments;
    for (int s = 0; s < _segments; s++) {
      final double segLeft = left + s * segW;
      final double segRight = segLeft + segW;
      if (segLeft >= left + fillW) break;
      final double clippedW = (left + fillW - segLeft).clamp(0.0, segW);
      final int tierIndex = _segments - s;
      _segPaint.color = tierColors[tierIndex - 1];
      canvas.drawRect(
        Rect.fromLTWH(segLeft, top, clippedW, _barHeight),
        _segPaint,
      );
    }

    canvas.drawRect(bg, _borderPaint);
  }

  @override
  void render(Canvas canvas) {
    final List<int> pHp = playerHp();
    final List<int> pMax = playerMaxHp();
    for (int i = 0; i < player.count(); i++) {
      if (!player.alive(i)) continue;
      final SoldierDesignPalette? pal = player.soldier(i).model.displayPalette;
      final List<Color> colors =
          pal != null ? factionTierList(pal) : kBlueFactionComponentColors;
      _drawBar(canvas, player.position(i), pHp[i], pMax[i], colors);
    }
    final List<int> eHp = enemyHp();
    final List<int> eMax = enemyMaxHp();
    for (int i = 0; i < enemy.count(); i++) {
      if (!enemy.alive(i)) continue;
      final SoldierDesignPalette? pal = enemy.soldier(i).model.displayPalette;
      final List<Color> colors =
          pal != null ? factionTierList(pal) : kRedFactionComponentColors;
      _drawBar(canvas, enemy.position(i), eHp[i], eMax[i], colors);
    }
  }
}
