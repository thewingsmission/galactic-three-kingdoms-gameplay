import 'package:flutter/material.dart';

import 'soldier_attack.dart';
import 'soldier_rarity.dart';

/// Draw / logical grouping: [underlay] first, then [body] + [center], then [attack], then [overlay].
/// Optional [contact] is **not** painted on the sprite; it defines an explicit contact hull for range UI.
/// Range preview uses [body]/[center] for collision hull, [center] for detection ring, [attack] for crown range.
enum SoldierPartStackRole {
  underlay,
  body,
  center,
  /// Logical footprint (polygon). Omitted from [MultiPolygonSoldierPainter] paint order.
  contact,
  attack,
  overlay,
}

/// Optional motion for a single layer (e.g. small wings on complex hulls).
enum SoldierPartMotion {
  none,
  /// Rotate around [motionPivot], or part centroid if null — flapping loop driven by painter [motionT].
  wingFlap,
  /// Hinge swing (e.g. ears): rotate around [motionPivot] (required). [motionAmplitudeRad] = peak |angle|;
  /// angle = [motionSign] × amplitude × sin(2π·[motionT]) (same phase as [wingFlap]).
  earSwing,
  /// Attack cycle: snaps forward along −Y, then slow return. [motionAmplitudeRad] = max extension in **model units**
  /// (not radians). Filled polygons translate; 2-point open polylines extend the **second** vertex along −Y.
  /// Driven by painter [attackCycleT] ∈ [0,1); omit [attackCycleT] for rest pose.
  attackProbeExtend,
}

/// Resolved fill + stroke for one paint pass.
class SoldierPartColorPair {
  const SoldierPartColorPair({required this.fill, required this.stroke});

  final Color fill;
  final Color stroke;

  @override
  bool operator ==(Object other) {
    return other is SoldierPartColorPair &&
        other.fill == fill &&
        other.stroke == stroke;
  }

  @override
  int get hashCode => Object.hash(fill, stroke);
}

/// One layer: filled polygon and/or stroked polyline — swords, bows, catapults, hulls, etc.
///
/// [fillTier] is **design index 1–5** (dark → light). The painter picks
/// `kRedFactionComponentColors[tier-1]` / yellow / blue for fill; **outlines are always black**.
class SoldierShapePart {
  const SoldierShapePart({
    this.fillVertices,
    this.strokePolyline,
    this.strokeClosed = false,
    required this.fillTier,
    this.transparentFill = false,
    this.strokeWidth = 2.25,
    this.motion = SoldierPartMotion.none,
    this.motionPivot,
    this.motionSign = 1.0,
    this.motionAmplitudeRad = 0.42,
    this.stackRole = SoldierPartStackRole.body,
  })  : assert(fillTier >= 1 && fillTier <= 5),
        assert(
          (fillVertices != null && fillVertices.length >= 3) ||
              (strokePolyline != null && strokePolyline.length >= 2),
        );

  final List<Offset>? fillVertices;
  final List<Offset>? strokePolyline;
  final bool strokeClosed;

  /// Standard ramp index **1–5** (darkest → lightest) for filled regions.
  final int fillTier;

  /// When true, fill is not painted; [fillTier] is ignored for fill.
  final bool transparentFill;

  final double strokeWidth;

  final SoldierPartMotion motion;
  /// Same coords as vertices; centroid used when null.
  final Offset? motionPivot;
  /// +1 / −1 to mirror left/right wings.
  final double motionSign;
  /// For [SoldierPartMotion.wingFlap] / [SoldierPartMotion.earSwing]: peak |rotation| in radians.
  /// For [SoldierPartMotion.attackProbeExtend]: forward slide distance in model units.
  final double motionAmplitudeRad;

  /// Z-order / parent grouping for paint and range overlays (see [SoldierPartStackRole]).
  final SoldierPartStackRole stackRole;
}

/// Unit design. [rarity] optional: if set, defines tier; else inferred from part count (legacy curve).
class SoldierDesign {
  SoldierDesign({
    required this.id,
    required this.name,
    required this.parts,
    required this.attack,
    SoldierRarity? rarity,
    /// Range column only: model point for hub dot / ruler (0,0) / detection disk center.
    /// Soldier rendering still uses the normal stable bbox anchor — set so dot can move without
    /// shifting the figure.
    this.rangePlotHubModel,
    /// When true, [MultiPolygonSoldierPainter] draws flame particles on the crown triangle
    /// during the attack probe window ([attackProbeEnvelope] > 0).
    this.paintCrownFlames = false,
  })  : _rarityOverride = rarity,
        assert(parts.isNotEmpty),
        assert(parts.length >= 2);

  final String id;
  final String name;
  final List<SoldierShapePart> parts;
  final SoldierAttackSpec attack;
  final Offset? rangePlotHubModel;
  final bool paintCrownFlames;

  final SoldierRarity? _rarityOverride;

  /// Effective tier (explicit or inferred from how many shape layers the design uses).
  SoldierRarity get rarity =>
      _rarityOverride ?? SoldierRarity.fromPartCount(parts.length);

  int get shapeLayerCount => parts.length;
}
