import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

import '../models/cohort_models.dart';
import '../models/cohort_soldier.dart';
import '../models/soldier_design.dart';
import '../models/soldier_range_scales.dart';
import '../widgets/multi_polygon_soldier_painter.dart';
import '../widgets/soldier_contact_painter.dart';
import '../widgets/triangle_soldier.dart';
import 'cohort_kinematics.dart';
import 'orange_field_debris.dart';
import 'soldier_contact_body.dart';

/// War scene: first deployed soldier **is** the cohort anchor (joystick, formation origin); other
/// soldiers are contact bodies in that leader’s space. [CohortRuntime] drives formation via
/// **forces**; [localOffset] syncs from bodies relative to the leader soldier.
///
/// **Ranges (player soldier *i*, enemy center = enemy body position):**
/// - **Detection disk**: center = soldier *i* center, radius = `contactRadius_i ×` [kSoldierDetectionRangeRadiusScale].
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
    required this.velocityHud,
  }) : _deployment = deployment,
       super(
         gravity: Vector2.zero(),
         zoom: 1,
       );

  final CohortDeployment _deployment;
  final ValueNotifier<Vector2> velocityHud;

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

  void setStick(Offset normalized) {
    stick.setValues(normalized.dx, normalized.dy);
  }

  int get soldierCount => _deployment.soldiers.length;

  /// First deployed soldier: receives stick steering; formation anchor; camera target.
  Body get _leaderBody => playerSoldierBodies[0].body;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Default 10/10: dense circles + formation can leave contacts under-resolved; a bit more solver work.
    velocityIterations = 12;
    positionIterations = 12;

    playerCohort = CohortRuntime.fromDeployment(_deployment);

    final Vector2 start =
        size.x > 0 && size.y > 0 ? size / 2 : Vector2(400, 240);

    _spawnEnemySoldiers(start);

    final List<SoldierContactBody> pb = <SoldierContactBody>[];
    for (int i = 0; i < playerCohort.soldierCount; i++) {
      final CohortSoldier s = playerCohort.soldier(i);
      final Vector2 pos = start + s.localOffset;
      final SoldierContactBody b = SoldierContactBody(
        contactRadius: s.contact.radius,
        position: pos,
      );
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
    _enemyAttackPlayerEntry = List<Map<String, double>>.generate(
      enemySoldiers.length,
      (_) => <String, double>{},
    );
    _enemyDetectionPlayerEntry = List<Map<String, double>>.generate(
      enemySoldiers.length,
      (_) => <String, double>{},
    );
    _lastEnemySoldierFacing = List<double>.filled(enemySoldiers.length, 0);

    for (final EnemySoldier e in enemySoldiers) {
      await world.add(e.body);
    }

    await world.add(
      _PlayerSoldierDetectionRangeLayer(
        runtime: playerCohort,
        soldierWorldPosition: (int i) => playerSoldierBodies[i].body.position,
      ),
    );
    await world.add(
      _PlayerSoldierAttackRangeLayer(
        runtime: playerCohort,
        soldierWorldPosition: (int i) => playerSoldierBodies[i].body.position,
      ),
    );

    await world.add(
      EnemySoldiersPainter(
        enemyCount: enemySoldiers.length,
        soldier: (int i) => enemySoldiers[i].soldier,
        soldierWorldPosition: (int i) => enemySoldiers[i].body.body.position,
        visualAngleForSoldier: _enemySoldierRenderAngle,
      ),
    );

    await world.add(
      PlayerFormationPainter(
        runtime: playerCohort,
        soldierWorldPosition: (int i) => playerSoldierBodies[i].body.position,
        visualAngleForSoldier: _playerSoldierRenderAngle,
      ),
    );

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
    // Keys: "e-0", "e-1", …
    final int ei = int.parse(key.substring(2));
    return enemySoldiers[ei].body.body.position;
  }

  Vector2 _playerWorldPosFromKey(String key) {
    final int j = int.parse(key.substring(2));
    return playerSoldierBodies[j].body.position;
  }

  void _updateRangeEntryMaps() {
    for (int i = 0; i < playerSoldierBodies.length; i++) {
      final Vector2 pos = playerSoldierBodies[i].body.position;
      final double cr = playerCohort.soldier(i).contact.radius;
      final double rA = cr * kSoldierAttackRangeRadiusScale;
      final double rD = cr * kSoldierDetectionRangeRadiusScale;
      final double rA2 = rA * rA;
      final double rD2 = rD * rD;
      final Set<String> inA = <String>{};
      final Set<String> inD = <String>{};
      for (int ei = 0; ei < enemySoldiers.length; ei++) {
        final Vector2 c = enemySoldiers[ei].body.body.position;
        final String k = 'e-$ei';
        final double d2 = (c - pos).length2;
        if (d2 <= rA2) inA.add(k);
        if (d2 <= rD2) inD.add(k);
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
      final EnemySoldier es = enemySoldiers[ei];
      final Vector2 pos = es.body.body.position;
      final double cr = es.soldier.contact.radius;
      final double rA = cr * kSoldierAttackRangeRadiusScale;
      final double rD = cr * kSoldierDetectionRangeRadiusScale;
      final double rA2 = rA * rA;
      final double rD2 = rD * rD;
      final Set<String> inA = <String>{};
      final Set<String> inD = <String>{};
      for (int pj = 0; pj < playerSoldierBodies.length; pj++) {
        final Vector2 c = playerSoldierBodies[pj].body.position;
        final String k = 'p-$pj';
        final double d2 = (c - pos).length2;
        if (d2 <= rA2) inA.add(k);
        if (d2 <= rD2) inD.add(k);
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

  String? _earliestEnemyInAttackForPlayer(int i) {
    final Vector2 pos = playerSoldierBodies[i].body.position;
    final double cr = playerCohort.soldier(i).contact.radius;
    final double rA = cr * kSoldierAttackRangeRadiusScale;
    final double rA2 = rA * rA;
    final Set<String> inA = <String>{};
    for (int ei = 0; ei < enemySoldiers.length; ei++) {
      final Vector2 c = enemySoldiers[ei].body.body.position;
      if ((c - pos).length2 <= rA2) inA.add('e-$ei');
    }
    return _earliestKeyInSet(inA, _playerAttackEntry[i]);
  }

  String? _earliestEnemyInDetectionForPlayer(int i) {
    final Vector2 pos = playerSoldierBodies[i].body.position;
    final double cr = playerCohort.soldier(i).contact.radius;
    final double rD = cr * kSoldierDetectionRangeRadiusScale;
    final double rD2 = rD * rD;
    final Set<String> inD = <String>{};
    for (int ei = 0; ei < enemySoldiers.length; ei++) {
      final Vector2 c = enemySoldiers[ei].body.body.position;
      if ((c - pos).length2 <= rD2) inD.add('e-$ei');
    }
    return _earliestKeyInSet(inD, _playerDetectionEntry[i]);
  }

  bool _enemyCenterInPlayerAttackRange(int playerIndex, String enemyKey) {
    final Vector2 pos = playerSoldierBodies[playerIndex].body.position;
    final double cr = playerCohort.soldier(playerIndex).contact.radius;
    final double rA = cr * kSoldierAttackRangeRadiusScale;
    final Vector2 c = _enemyWorldPosFromKey(enemyKey);
    return (c - pos).length2 <= rA * rA;
  }

  String? _earliestPlayerInAttackForEnemy(int enemyIndex) {
    final EnemySoldier es = enemySoldiers[enemyIndex];
    final Vector2 pos = es.body.body.position;
    final double cr = es.soldier.contact.radius;
    final double rA = cr * kSoldierAttackRangeRadiusScale;
    final double rA2 = rA * rA;
    final Set<String> inA = <String>{};
    for (int pj = 0; pj < playerSoldierBodies.length; pj++) {
      final Vector2 c = playerSoldierBodies[pj].body.position;
      if ((c - pos).length2 <= rA2) inA.add('p-$pj');
    }
    return _earliestKeyInSet(inA, _enemyAttackPlayerEntry[enemyIndex]);
  }

  String? _earliestPlayerInDetectionForEnemy(int enemyIndex) {
    final EnemySoldier es = enemySoldiers[enemyIndex];
    final Vector2 pos = es.body.body.position;
    final double cr = es.soldier.contact.radius;
    final double rD = cr * kSoldierDetectionRangeRadiusScale;
    final double rD2 = rD * rD;
    final Set<String> inD = <String>{};
    for (int pj = 0; pj < playerSoldierBodies.length; pj++) {
      final Vector2 c = playerSoldierBodies[pj].body.position;
      if ((c - pos).length2 <= rD2) inD.add('p-$pj');
    }
    return _earliestKeyInSet(inD, _enemyDetectionPlayerEntry[enemyIndex]);
  }

  bool _playerCenterInEnemyAttackRange(int enemyIndex, String playerKey) {
    final Vector2 pos = enemySoldiers[enemyIndex].body.body.position;
    final double cr = enemySoldiers[enemyIndex].soldier.contact.radius;
    final double rA = cr * kSoldierAttackRangeRadiusScale;
    final Vector2 c = _playerWorldPosFromKey(playerKey);
    return (c - pos).length2 <= rA * rA;
  }

  double _playerSoldierFacingAngle(int i) {
    final bool moving = _playerCohortMoving();
    final Vector2 p = playerSoldierBodies[i].body.position;
    double angle;

    if (moving) {
      final String? ea = _earliestEnemyInAttackForPlayer(i);
      if (ea != null) {
        final Vector2 d = _enemyWorldPosFromKey(ea) - p;
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
    final String? pa = _earliestPlayerInAttackForEnemy(enemyIndex);
    final String? pd = _earliestPlayerInDetectionForEnemy(enemyIndex);
    double angle;

    // Order: attack / detection first; avoids flicker when chase speed crosses [_enemySoldierMovingVel].
    if (pa != null) {
      final Vector2 d = _playerWorldPosFromKey(pa) - p;
      angle = d.length2 < 1e-12
          ? _lastEnemySoldierFacing[enemyIndex]
          : _aimAngleToward(d);
    } else if (pd != null) {
      final Vector2 d = _playerWorldPosFromKey(pd) - p;
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
    final Vector2 to = targetWorldPos - b.worldCenter;
    if (to.length2 < 1e-10) return;
    final Vector2 dir = to.normalized();
    final Vector2 vWant = dir * cohortMaxSpeed;
    final Vector2 err = vWant - b.linearVelocity;
    b.applyForce(err * b.mass * _chaseVelocitySteerGain);
  }

  /// See class doc: neutral-stick chase applies only when an enemy center is in the soldier’s
  /// detection disk but outside their attack disk.
  void _applyChaseForces() {
    if (!_playerCohortMoving()) {
      for (int i = 0; i < playerSoldierBodies.length; i++) {
        final String? ed = _earliestEnemyInDetectionForPlayer(i);
        if (ed == null) continue;
        if (_enemyCenterInPlayerAttackRange(i, ed)) continue;
        final Body b = playerSoldierBodies[i].body;
        _applyChaseVelocityToward(b, _enemyWorldPosFromKey(ed));
      }
    }

    for (int ei = 0; ei < enemySoldiers.length; ei++) {
      if (_enemySoldierMoving(ei)) continue;
      final String? pd = _earliestPlayerInDetectionForEnemy(ei);
      if (pd == null) continue;
      if (_playerCenterInEnemyAttackRange(ei, pd)) continue;
      final Body b = enemySoldiers[ei].body.body;
      _applyChaseVelocityToward(b, _playerWorldPosFromKey(pd));
    }
  }

  void _spawnEnemySoldiers(Vector2 center) {
    final math.Random rng = math.Random(21);
    const int enemyCount = 12;
    const double scatterHalfWidth = 450;
    const double scatterHalfHeight = 350;

    const SoldierModel enemyModel = SoldierModel(
      side: 36,
      paintSize: 52,
      isEnemy: true,
    );

    for (int i = 0; i < enemyCount; i++) {
      final Vector2 worldPos = center +
          Vector2(
            (rng.nextDouble() - 0.5) * 2 * scatterHalfWidth,
            (rng.nextDouble() - 0.5) * 2 * scatterHalfHeight,
          );
      final CohortSoldier s = CohortSoldier(
        model: enemyModel,
        canonicalSlot: Vector2.zero(),
        localOffset: Vector2.zero(),
      );
      enemySoldiers.add(
        EnemySoldier(
          soldier: s,
          body: SoldierContactBody(
            contactRadius: s.contact.radius,
            position: worldPos,
          ),
        ),
      );
    }
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
      if (!_playerCohortMoving() &&
          _earliestEnemyInDetectionForPlayer(i) != null) {
        continue;
      }
      final Body b = playerSoldierBodies[i].body;
      final Vector2 target = lc + playerCohort.formationTargetLocal(i);
      final Vector2 err = target - b.worldCenter;
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

    final Vector2 v = _leaderBody.linearVelocity;
    velocityHud.value = Vector2(v.x, v.y);
  }
}

/// One enemy unit: a single [CohortSoldier] (visual + contact) and its Forge2D body.
/// There is no enemy cohort—only independent soldiers.
class EnemySoldier {
  EnemySoldier({
    required this.soldier,
    required this.body,
  });

  final CohortSoldier soldier;
  final SoldierContactBody body;
}

/// **Detection** disk layer (100% transparent; radii use [kSoldierDetectionRangeRadiusScale]).
class _PlayerSoldierDetectionRangeLayer extends Component {
  _PlayerSoldierDetectionRangeLayer({
    required this.runtime,
    required this.soldierWorldPosition,
  });

  final CohortRuntime runtime;
  final Vector2 Function(int index) soldierWorldPosition;

  static final Paint _fill = Paint()..color = Colors.transparent;

  @override
  int get priority => -1001;

  @override
  void render(Canvas canvas) {
    for (int i = 0; i < runtime.soldierCount; i++) {
      final CohortSoldier s = runtime.soldier(i);
      final double r = s.contact.radius * kSoldierDetectionRangeRadiusScale;
      final Vector2 p = soldierWorldPosition(i);
      canvas.drawCircle(Offset(p.x, p.y), r, _fill);
    }
  }
}

/// **Attack** disk layer (100% transparent; radii use [kSoldierAttackRangeRadiusScale]).
class _PlayerSoldierAttackRangeLayer extends Component {
  _PlayerSoldierAttackRangeLayer({
    required this.runtime,
    required this.soldierWorldPosition,
  });

  final CohortRuntime runtime;
  final Vector2 Function(int index) soldierWorldPosition;

  static final Paint _fill = Paint()..color = Colors.transparent;

  @override
  int get priority => -1000;

  @override
  void render(Canvas canvas) {
    for (int i = 0; i < runtime.soldierCount; i++) {
      final CohortSoldier s = runtime.soldier(i);
      final double r = s.contact.radius * kSoldierAttackRangeRadiusScale;
      final Vector2 p = soldierWorldPosition(i);
      canvas.drawCircle(Offset(p.x, p.y), r, _fill);
    }
  }
}

class PlayerFormationPainter extends Component {
  PlayerFormationPainter({
    required this.runtime,
    required this.soldierWorldPosition,
    required this.visualAngleForSoldier,
  });

  final CohortRuntime runtime;
  final Vector2 Function(int index) soldierWorldPosition;
  final double Function(int index) visualAngleForSoldier;

  @override
  int get priority => 20;

  @override
  void render(Canvas canvas) {
    for (int i = 0; i < runtime.soldierCount; i++) {
      final CohortSoldier s = runtime.soldier(i);
      final SoldierModel m = s.model;
      final SoldierContact sc = s.contact;
      final Vector2 p = soldierWorldPosition(i);
      final double half = m.paintSize / 2;
      final double angle = visualAngleForSoldier(i);
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
          motionT: 0.25,
          attackCycleT: null,
          uniformWorldScale: fit,
          fixedModelAnchor: anchor,
          paintCrownFlames: m.design!.paintCrownFlames,
        ).paint(canvas, sz);
      } else {
        TriangleSoldierPainter(side: m.side).paint(canvas, sz);
      }
      SoldierContactPainter(radius: sc.radius, strokeWidth: 2.5).paint(
        canvas,
        sz,
      );
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
  });

  final int enemyCount;
  final CohortSoldier Function(int index) soldier;
  final Vector2 Function(int index) soldierWorldPosition;
  final double Function(int index) visualAngleForSoldier;

  @override
  int get priority => 5;

  @override
  void render(Canvas canvas) {
    for (int i = 0; i < enemyCount; i++) {
      final CohortSoldier s = soldier(i);
      final SoldierModel m = s.model;
      final SoldierContact sc = s.contact;
      final Vector2 p = soldierWorldPosition(i);
      final double half = m.paintSize / 2;
      final double angle = visualAngleForSoldier(i);
      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(angle);
      canvas.translate(-half, -half);
      OrangeTrianglePainter(side: m.side).paint(
        canvas,
        Size(m.paintSize, m.paintSize),
      );
      SoldierContactPainter(radius: sc.radius, strokeWidth: 2).paint(
        canvas,
        Size(m.paintSize, m.paintSize),
      );
      canvas.restore();
    }
  }
}
