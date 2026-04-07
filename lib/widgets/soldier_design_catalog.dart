import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/soldier_attack.dart';
import '../models/soldier_design.dart';
import '../models/soldier_explicit_palettes.dart';
import '../models/soldier_rarity.dart';
import 'isosceles_triangle_vertices.dart';

/// Centers all shape layers together (single centroid) — fills + strokes — upright (−Y).
List<SoldierShapePart> _centerParts(List<SoldierShapePart> parts) {
  final List<Offset> all = <Offset>[];
  for (final SoldierShapePart p in parts) {
    if (p.fillVertices != null) {
      all.addAll(p.fillVertices!);
    }
    if (p.strokePolyline != null) {
      all.addAll(p.strokePolyline!);
    }
  }
  if (all.isEmpty) return parts;
  double sx = 0, sy = 0;
  for (final Offset e in all) {
    sx += e.dx;
    sy += e.dy;
  }
  final double n = all.length.toDouble();
  final double cx = sx / n, cy = sy / n;
  return parts
      .map(
        (SoldierShapePart p) => SoldierShapePart(
          fillVertices: p.fillVertices
              ?.map((Offset v) => Offset(v.dx - cx, v.dy - cy))
              .toList(),
          strokePolyline: p.strokePolyline
              ?.map((Offset v) => Offset(v.dx - cx, v.dy - cy))
              .toList(),
          strokeClosed: p.strokeClosed,
          fillTier: p.fillTier,
          transparentFill: p.transparentFill,
          strokeWidth: p.strokeWidth,
          motion: p.motion,
          motionPivot: p.motionPivot != null
              ? Offset(p.motionPivot!.dx - cx, p.motionPivot!.dy - cy)
              : null,
          motionSign: p.motionSign,
          motionAmplitudeRad: p.motionAmplitudeRad,
          stackRole: p.stackRole,
        ),
      )
      .toList();
}

/// Uniformly scales all vertices so the overall **width** (x extent) equals [targetWidth].
List<SoldierShapePart> _scalePartsToWidth(
    List<SoldierShapePart> parts, double targetWidth) {
  double minX = double.infinity, maxX = double.negativeInfinity;
  for (final SoldierShapePart p in parts) {
    for (final Offset v in <Offset>[...?p.fillVertices, ...?p.strokePolyline]) {
      if (v.dx < minX) minX = v.dx;
      if (v.dx > maxX) maxX = v.dx;
    }
  }
  final double w = maxX - minX;
  if (w <= 0) return parts;
  final double s = targetWidth / w;
  return parts
      .map(
        (SoldierShapePart p) => SoldierShapePart(
          fillVertices: p.fillVertices
              ?.map((Offset v) => Offset(v.dx * s, v.dy * s))
              .toList(),
          strokePolyline: p.strokePolyline
              ?.map((Offset v) => Offset(v.dx * s, v.dy * s))
              .toList(),
          strokeClosed: p.strokeClosed,
          fillTier: p.fillTier,
          transparentFill: p.transparentFill,
          strokeWidth: p.strokeWidth,
          motion: p.motion,
          motionPivot: p.motionPivot != null
              ? Offset(p.motionPivot!.dx * s, p.motionPivot!.dy * s)
              : null,
          motionSign: p.motionSign,
          motionAmplitudeRad: p.motionAmplitudeRad,
          stackRole: p.stackRole,
        ),
      )
      .toList();
}

/// Circle vertices centred at origin with [n] segments.
List<Offset> _circleVerts(double r, int n) =>
    List<Offset>.generate(n, (int i) {
      final double a = -math.pi / 2 + i * 2 * math.pi / n;
      return Offset(r * math.cos(a), r * math.sin(a));
    });

/// Engagement annulus vertices — 6 inner + 6 outer, for min/max distance detection.
List<Offset> _engagementAnnulusVerts(double inner, double outer) {
  final List<Offset> v = <Offset>[];
  for (int k = 0; k < 6; k++) {
    final double a = k * math.pi / 3;
    v.add(Offset(inner * math.cos(a), inner * math.sin(a)));
  }
  for (int k = 0; k < 6; k++) {
    final double a = (k + 0.5) * math.pi / 3;
    v.add(Offset(outer * math.cos(a), outer * math.sin(a)));
  }
  return v;
}

/// Small upper fin — pairs with a main hull so silhouettes can always use **≥2** parts.
List<Offset> _upFin({
  double apexY = -33,
  double halfW = 6.5,
  double baseY = -24,
}) =>
    <Offset>[
      Offset(0, apexY),
      Offset(halfW, baseY),
      Offset(-halfW, baseY),
    ];

List<Offset> _octagon(Offset c, double r) {
  return List<Offset>.generate(8, (int i) {
    final double a = -math.pi / 2 + i * math.pi / 4;
    return Offset(
      c.dx + r * math.cos(a),
      c.dy + r * math.sin(a),
    );
  });
}

List<Offset> _star5Points(Offset c, double rOut, double rIn) {
  final List<Offset> v = <Offset>[];
  for (int i = 0; i < 5; i++) {
    final double a0 = -math.pi / 2 + i * 2 * math.pi / 5;
    final double a1 = a0 + math.pi / 5;
    v.add(Offset(c.dx + rOut * math.cos(a0), c.dy + rOut * math.sin(a0)));
    v.add(Offset(c.dx + rIn * math.cos(a1), c.dy + rIn * math.sin(a1)));
  }
  return v;
}

List<Offset> _hexVerts6(Offset c, double r) {
  return List<Offset>.generate(6, (int i) {
    final double a = -math.pi / 2 + i * math.pi / 3;
    return Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
  });
}

List<Offset> _arrowTriEast(double len, double halfW) {
  return <Offset>[
    Offset(len, 0),
    Offset(len * 0.38, -halfW),
    Offset(len * 0.38, halfW),
  ];
}

List<Offset> _rotPoly(List<Offset> poly, double radians) {
  final double c = math.cos(radians), s = math.sin(radians);
  return poly
      .map(
        (Offset p) => Offset(
          p.dx * c - p.dy * s,
          p.dx * s + p.dy * c,
        ),
      )
      .toList();
}

Color _radialRed(int variant) {
  return Color.lerp(
    const Color(0xFFB71C1C),
    const Color(0xFFFF5252),
    variant / 9.0,
  )!;
}

/// Ten new **legendary** radial sigils (crimson / neon-red emblem style, reference-inspired).
List<SoldierDesign> _buildTenRadialLegendaryDrafts() {
  const List<String> kNames = <String>[
    'Crimson Core',
    'Hex Nova',
    'Stellar Seal',
    'Ruby Mandala',
    'Scarlet Compass',
    'Ember Sigil',
    'Blood Star',
    'Radial Ward',
    'Vermillion Web',
    'Rune Flare',
  ];
  const List<SoldierAttackMode> kAtk = <SoldierAttackMode>[
    SoldierAttackMode.helixBurst,
    SoldierAttackMode.sweepBeam,
    SoldierAttackMode.swordSwipe,
    SoldierAttackMode.overchargeCone,
    SoldierAttackMode.sustainedBeam,
    SoldierAttackMode.plasmaBolt,
    SoldierAttackMode.burstShards,
    SoldierAttackMode.sineWaver,
    SoldierAttackMode.lanceCharge,
    SoldierAttackMode.needleSalvo,
  ];
  const List<String> kAtkLabel = <String>[
    'Helix burst',
    'Sweep beam',
    'Sword swipe',
    'Overcharge cone',
    'Sustained beam',
    'Plasma bolt',
    'Burst shards',
    'Sine waver',
    'Lance charge',
    'Needle salvo',
  ];

  final List<SoldierDesign> out = <SoldierDesign>[];

  for (int vi = 0; vi < 10; vi++) {
    final Color fill = _radialRed(vi);
    final List<SoldierShapePart> raw = <SoldierShapePart>[];

    // Per-design + per-layer tier variety (1–5) on the standard ramps; [fill] only drives transparency.
    const List<int> kCoreTierByVi = <int>[4, 2, 5, 3, 1, 4, 2, 5, 3, 1];
    final int coreTier = kCoreTierByVi[vi];

    raw.add(
      partRadialSigil(
        variant: vi,
        fillVertices: _star5Points(Offset.zero, 15, 6.2),
        fill: fill,
        fillTierOverride: coreTier,
        stroke: Colors.black,
        strokeWidth: 2.1,
      ),
    );

    // Six outward arrows (emblem rays).
    for (int k = 0; k < 6; k++) {
      final int rayTier = ((k + vi * 2) % 5) + 1;
      raw.add(
        partRadialSigil(
          variant: vi * 10 + k,
          fillVertices: _rotPoly(_arrowTriEast(26, 6.5), k * math.pi / 3),
          fill: fill.withValues(alpha: 0.94),
          fillTierOverride: rayTier,
          stroke: Colors.black,
          strokeWidth: 1.85,
        ),
      );
    }

    if (vi.isEven) {
      final int ringTier = ((vi ~/ 2) % 5) + 1;
      raw.add(
        partRadialSigil(
          variant: vi + 40,
          fillVertices: _hexVerts6(Offset.zero, 20),
          fill: fill.withValues(alpha: 0.35),
          fillTierOverride: ringTier,
          stroke: Colors.black,
          strokeWidth: 1.7,
        ),
      );
    } else {
      for (int k = 0; k < 6; k++) {
        final double a = k * math.pi / 3;
        final Offset hub = Offset(math.cos(a) * 19, math.sin(a) * 19);
        final int hubTier = ((k * 2 + vi + 1) % 5) + 1;
        raw.add(
          partRadialSigil(
            variant: vi * 20 + k,
            fillVertices: _star5Points(hub, 5.2, 2.1),
            fill: fill.withValues(alpha: 0.98),
            fillTierOverride: hubTier,
            stroke: Colors.black,
            strokeWidth: 1.5,
          ),
        );
      }
    }

    // Tiny "face" in the heart of the sigil (two eyes + mouth) — reference kawaii stars.
    raw.add(
      SoldierShapePart(
        fillVertices: <Offset>[
          Offset(-3.5, -1.5),
          Offset(-2.5, -1.5),
          Offset(-3, -0.5),
          Offset(-3.5, -1),
        ],
        fillTier: ((vi + 4) % 5) + 1,
        strokeWidth: 0.8,
      ),
    );
    raw.add(
      SoldierShapePart(
        fillVertices: <Offset>[
          Offset(2.5, -1.5),
          Offset(3.5, -1.5),
          Offset(3, -0.5),
          Offset(2.5, -1),
        ],
        fillTier: ((vi + 2) % 5) + 1,
        strokeWidth: 0.8,
      ),
    );
    raw.add(
      SoldierShapePart(
        strokePolyline: <Offset>[
          Offset(-3, 2.5),
          Offset(0, 4),
          Offset(3, 2.5),
        ],
        fillTier: 1,
        transparentFill: true,
        strokeWidth: 1.2,
      ),
    );

    out.add(
      SoldierDesign(
        id: 'radial_sigil_${(vi + 1).toString().padLeft(2, '0')}',
        name: kNames[vi],
        rarity: SoldierRarity.legendary,
        parts: _centerParts(raw),
        attack: SoldierAttackSpec(mode: kAtk[vi], label: kAtkLabel[vi]),
      ),
    );
  }

  return out;
}

/// Legendary **#151** — gold castle-tower with feline face (reference-inspired): battlements, windows, side feet.
///
/// Authoring matches [document/soldier_structure.md] Gilded Bastion: **attack** pass draws probe rod (1) then crown (2);
/// crown flames / strike disk use the triangular attack part only (probe is a quad).
final List<SoldierShapePart> _kGildedBastionRawParts = <SoldierShapePart>[
    SoldierShapePart(
      fillVertices: <Offset>[
        Offset(-9, -32),
        Offset(9, -32),
        Offset(21, 8),
        Offset(-21, 8),
      ],
      fillTier: 2,
      strokeWidth: 2.2,
      stackRole: SoldierPartStackRole.body,
    ),
    SoldierShapePart(
      fillVertices: <Offset>[
        Offset(-22, 8),
        Offset(22, 8),
        Offset(22, 24),
        Offset(-22, 24),
      ],
      fillTier: 3,
      strokeWidth: 2.2,
      stackRole: SoldierPartStackRole.body,
    ),
    SoldierShapePart(
      fillVertices: <Offset>[
        Offset(-30, 10),
        Offset(-24, 10),
        Offset(-24, 24),
        Offset(-30, 24),
      ],
      fillTier: 4,
      strokeWidth: 2.0,
      motion: SoldierPartMotion.wingFlap,
      motionSign: -1.0,
      motionAmplitudeRad: 0.26,
      stackRole: SoldierPartStackRole.body,
    ),
    SoldierShapePart(
      fillVertices: <Offset>[
        Offset(24, 10),
        Offset(30, 10),
        Offset(30, 24),
        Offset(24, 24),
      ],
      fillTier: 4,
      strokeWidth: 2.0,
      motion: SoldierPartMotion.wingFlap,
      motionSign: 1.0,
      motionAmplitudeRad: 0.26,
      stackRole: SoldierPartStackRole.body,
    ),
    SoldierShapePart(
      fillVertices: _octagon(const Offset(0, -17), 4.4),
      fillTier: 5,
      strokeWidth: 1.8,
      stackRole: SoldierPartStackRole.center,
    ),
    SoldierShapePart(
      fillVertices: _octagon(const Offset(0, -1), 4.4),
      fillTier: 5,
      strokeWidth: 1.8,
      stackRole: SoldierPartStackRole.center,
    ),
    SoldierShapePart(
      fillVertices: <Offset>[
        Offset(-1.4, -22),
        Offset(1.4, -22),
        Offset(1.4, -32),
        Offset(-1.4, -32),
      ],
      fillTier: 1,
      strokeWidth: 1.6,
      motion: SoldierPartMotion.attackProbeExtend,
      motionSign: 1.0,
      motionAmplitudeRad: 60.0,
      stackRole: SoldierPartStackRole.underlay,
    ),
    SoldierShapePart(
      fillVertices: <Offset>[
        Offset(0, -46),
        Offset(8.5, -32),
        Offset(-8.5, -32),
      ],
      fillTier: 1,
      strokeWidth: 2.0,
      motion: SoldierPartMotion.attackProbeExtend,
      motionSign: 1.0,
      motionAmplitudeRad: 60.0,
      stackRole: SoldierPartStackRole.attack,
    ),
    SoldierShapePart(
      fillVertices: <Offset>[
        Offset(-17, -42),
        Offset(-11.5, -32),
        Offset(-22.5, -32),
      ],
      fillTier: 1,
      strokeWidth: 2.0,
      motion: SoldierPartMotion.earSwing,
      motionPivot: const Offset(-11.5, -32),
      motionSign: -1.0,
      motionAmplitudeRad: math.pi / 4,
      stackRole: SoldierPartStackRole.overlay,
    ),
    SoldierShapePart(
      fillVertices: <Offset>[
        Offset(17, -42),
        Offset(22.5, -32),
        Offset(11.5, -32),
      ],
      fillTier: 1,
      strokeWidth: 2.0,
      motion: SoldierPartMotion.earSwing,
      motionPivot: const Offset(11.5, -32),
      motionSign: 1.0,
      motionAmplitudeRad: math.pi / 4,
      stackRole: SoldierPartStackRole.overlay,
    ),
    SoldierShapePart(
      strokePolyline: <Offset>[
        Offset(0, -21.2),
        Offset(0, -12.8),
      ],
      fillTier: 1,
      transparentFill: true,
      strokeWidth: 1.4,
      stackRole: SoldierPartStackRole.overlay,
    ),
    SoldierShapePart(
      strokePolyline: <Offset>[
        Offset(-4, -17),
        Offset(4, -17),
      ],
      fillTier: 1,
      transparentFill: true,
      strokeWidth: 1.4,
      stackRole: SoldierPartStackRole.overlay,
    ),
    SoldierShapePart(
      strokePolyline: <Offset>[
        Offset(0, -5.2),
        Offset(0, 3.2),
      ],
      fillTier: 1,
      transparentFill: true,
      strokeWidth: 1.4,
      stackRole: SoldierPartStackRole.overlay,
    ),
    SoldierShapePart(
      strokePolyline: <Offset>[
        Offset(-4, -1),
        Offset(4, -1),
      ],
      fillTier: 1,
      transparentFill: true,
      strokeWidth: 1.4,
      stackRole: SoldierPartStackRole.overlay,
    ),
    SoldierShapePart(
      fillVertices: <Offset>[
        Offset(-11.2, 13.5),
        Offset(-9.8, 15),
        Offset(-11.2, 16.5),
        Offset(-12.4, 15),
      ],
      fillTier: 1,
      strokeWidth: 1.0,
      stackRole: SoldierPartStackRole.overlay,
    ),
    SoldierShapePart(
      fillVertices: <Offset>[
        Offset(11.2, 13.5),
        Offset(12.4, 15),
        Offset(11.2, 16.5),
        Offset(9.8, 15),
      ],
      fillTier: 1,
      strokeWidth: 1.0,
      stackRole: SoldierPartStackRole.overlay,
    ),
    SoldierShapePart(
      fillVertices: <Offset>[
        Offset(0, 12.5),
        Offset(-2.2, 16.2),
        Offset(2.2, 16.2),
      ],
      fillTier: 1,
      strokeWidth: 1.0,
      stackRole: SoldierPartStackRole.overlay,
    ),
    SoldierShapePart(
      strokePolyline: <Offset>[
        Offset(-9.5, 20),
        Offset(-5, 22),
        Offset(0, 20),
        Offset(5, 22),
        Offset(9.5, 20),
      ],
      fillTier: 1,
      transparentFill: true,
      strokeWidth: 1.5,
      stackRole: SoldierPartStackRole.overlay,
    ),
    SoldierShapePart(
      strokePolyline: <Offset>[
        Offset(-27, 13),
        Offset(-27, 21),
      ],
      fillTier: 1,
      transparentFill: true,
      strokeWidth: 1.2,
      stackRole: SoldierPartStackRole.overlay,
    ),
    SoldierShapePart(
      strokePolyline: <Offset>[
        Offset(27, 13),
        Offset(27, 21),
      ],
      fillTier: 1,
      transparentFill: true,
      strokeWidth: 1.2,
      stackRole: SoldierPartStackRole.overlay,
    ),
];

/// **Centered model space** — same frame as [_centerParts] output and Range ruler readout.
const List<Offset> _kGildedBastionContactHull = <Offset>[
  Offset(-7, -26),
  Offset(7, -26),
  Offset(18, 22),
  Offset(-18, 22),
];

/// Target zone = previous × 0.75 (scaled about centroid (0, −2)).
const List<Offset> _kGildedBastionTargetHull = <Offset>[
  Offset(-14.33, -51.14),
  Offset(14.33, -51.14),
  Offset(36.86, 47.14),
  Offset(-36.86, 47.14),
];

final SoldierDesign _kLegendaryCastleCat = SoldierDesign(
  id: 'gilded_bastion_cat',
  name: 'Gilded Bastion',
  rarity: SoldierRarity.legendary,
  rangePlotHubModel: const Offset(0, 9.1),
  paintCrownFlames: true,
  parts: <SoldierShapePart>[
    ..._centerParts(_kGildedBastionRawParts),
    SoldierShapePart(
      fillVertices: _kGildedBastionContactHull.toList(),
      fillTier: 1,
      transparentFill: true,
      strokeWidth: 0,
      stackRole: SoldierPartStackRole.contact,
    ),
    SoldierShapePart(
      fillVertices: _kGildedBastionTargetHull.toList(),
      fillTier: 1,
      transparentFill: true,
      strokeWidth: 0,
      stackRole: SoldierPartStackRole.target,
    ),
    SoldierShapePart(
      fillVertices: const <Offset>[
        Offset(-6, -34),
        Offset(6, -34),
        Offset(6, -87),
        Offset(-6, -87),
      ],
      fillTier: 1,
      transparentFill: true,
      strokeWidth: 0,
      stackRole: SoldierPartStackRole.engagement,
    ),
  ],
  attack: const SoldierAttackSpec(
    mode: SoldierAttackMode.none,
    label: 'Crown strike',
  ),
);

/// Hand-tuned soldiers (33). Full [kSoldierDesignCatalog] adds procedural units to **150**, same rarity ratio.
final List<SoldierDesign> _kHandCraftedSoldiers = <SoldierDesign>[
  // —— Common (fills + strokes; multi-part OK) ——
  SoldierDesign(
    id: 'saber',
    name: 'Saber',
    rarity: SoldierRarity.common,
    parts: _centerParts(<SoldierShapePart>[
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(0, -28),
          const Offset(5, -26),
          const Offset(4, 14),
          const Offset(-4, 14),
          const Offset(-5, -26),
        ],
        fill: const Color(0xFFFFF8E1),
        stroke: const Color(0xFF4A3800),
      ),
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(-14, 12),
          const Offset(14, 12),
          const Offset(14, 18),
          const Offset(-14, 18),
        ],
        fill: const Color(0xFFFFB300),
      ),
      partGoldFaction(
        strokePolyline: <Offset>[
          const Offset(0, 18),
          const Offset(0, 30),
        ],
        fill: Colors.transparent,
        stroke: const Color(0xFF5D4500),
        strokeWidth: 5,
      ),
    ]),
    attack: const SoldierAttackSpec(
      mode: SoldierAttackMode.swordSwipe,
      label: 'Sword swipe',
    ),
  ),
  SoldierDesign(
    id: 'longbow',
    name: 'Longbow',
    rarity: SoldierRarity.common,
    parts: _centerParts(<SoldierShapePart>[
      partGoldFaction(
        strokePolyline: <Offset>[
          const Offset(-18, -20),
          const Offset(-24, -6),
          const Offset(-24, 6),
          const Offset(-18, 20),
        ],
        fill: Colors.transparent,
        stroke: const Color(0xFF5D4500),
        strokeWidth: 4,
      ),
      partGoldFaction(
        strokePolyline: const <Offset>[
          Offset(16, -20),
          Offset(16, 20),
        ],
        fill: Colors.transparent,
        stroke: const Color(0xFFC4A050),
        strokeWidth: 1.2,
      ),
      partGoldFaction(
        fillVertices: const <Offset>[
          Offset(4, -28),
          Offset(10, -22),
          Offset(-2, -20),
        ],
        fill: const Color(0xFFFFECB3),
      ),
    ]),
    attack: const SoldierAttackSpec(
      mode: SoldierAttackMode.needleSalvo,
      label: 'Needle salvo',
    ),
  ),
  SoldierDesign(
    id: 'onager',
    name: 'Onager',
    rarity: SoldierRarity.common,
    parts: _centerParts(<SoldierShapePart>[
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(-26, 18),
          const Offset(26, 18),
          const Offset(22, 26),
          const Offset(-22, 26),
        ],
        fill: const Color(0xFFFFA726),
      ),
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(-8, -8),
          const Offset(-4, -8),
          const Offset(-4, 18),
          const Offset(-8, 18),
        ],
        fill: const Color(0xFFFF9800),
      ),
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(8, -8),
          const Offset(12, -8),
          const Offset(12, 18),
          const Offset(8, 18),
        ],
        fill: const Color(0xFFFF9800),
      ),
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(-6, -22),
          const Offset(8, -18),
          const Offset(10, -14),
          const Offset(-8, -10),
        ],
        fill: const Color(0xFFFFB74D),
      ),
    ]),
    attack: const SoldierAttackSpec(
      mode: SoldierAttackMode.burstShards,
      label: 'Burst shards',
    ),
  ),
  SoldierDesign(
    id: 'sentinel',
    name: 'Sentinel',
    parts: _centerParts(<SoldierShapePart>[
      partGoldFaction(
        fillVertices: isoscelesTriangleVerticesCentroid(legLength: 36),
        fill: const Color(0xFFFFEB3B),
      ),
      partGoldFaction(
        fillVertices: _upFin(apexY: -36, halfW: 7, baseY: -26),
        fill: const Color(0xFFFFD54F),
      ),
    ]),
    attack: const SoldierAttackSpec(
      mode: SoldierAttackMode.railNeedle,
      label: 'Rail needle',
    ),
  ),
  SoldierDesign(
    id: 'razor',
    name: 'Razor',
    parts: _centerParts(<SoldierShapePart>[
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(0, -22),
          const Offset(-16, 14),
          const Offset(20, 10),
        ],
        fill: const Color(0xFFFFD54F),
      ),
      partGoldFaction(
        fillVertices: _upFin(apexY: -34, halfW: 6, baseY: -25),
        fill: const Color(0xFFFFCA28),
      ),
    ]),
    attack: const SoldierAttackSpec(
      mode: SoldierAttackMode.twinRail,
      label: 'Twin rail',
    ),
  ),
  SoldierDesign(
    id: 'bastion',
    name: 'Bastion',
    parts: _centerParts(<SoldierShapePart>[
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(-22, -6),
          const Offset(22, -6),
          const Offset(0, 20),
        ],
        fill: const Color(0xFFFFF176),
      ),
      partGoldFaction(
        fillVertices: _upFin(apexY: -32, halfW: 8, baseY: -22),
        fill: const Color(0xFFFFD54F),
      ),
    ]),
    attack: const SoldierAttackSpec(
      mode: SoldierAttackMode.triSpread,
      label: 'Tri spread',
    ),
  ),
  SoldierDesign(
    id: 'dagger',
    name: 'Dagger',
    parts: _centerParts(<SoldierShapePart>[
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(0, -26),
          const Offset(-8, 18),
          const Offset(10, 16),
        ],
        fill: const Color(0xFFFFF9C4),
      ),
      partGoldFaction(
        fillVertices: _upFin(apexY: -35, halfW: 5.5, baseY: -26),
        fill: const Color(0xFFFFE082),
      ),
    ]),
    attack: const SoldierAttackSpec(mode: SoldierAttackMode.pulseWave, label: 'Pulse wave'),
  ),
  SoldierDesign(
    id: 'spike',
    name: 'Spike',
    parts: _centerParts(<SoldierShapePart>[
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(0, -22),
          const Offset(-18, 8),
          const Offset(16, 12),
        ],
        fill: const Color(0xFFFFFDE7),
      ),
      partGoldFaction(
        fillVertices: _upFin(apexY: -33, halfW: 6, baseY: -24),
        fill: const Color(0xFFFFF9C4),
      ),
    ]),
    attack: const SoldierAttackSpec(mode: SoldierAttackMode.plasmaBolt, label: 'Plasma bolt'),
  ),
  SoldierDesign(
    id: 'delta',
    name: 'Delta',
    parts: _centerParts(<SoldierShapePart>[
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(0, -20),
          const Offset(-20, 12),
          const Offset(20, 12),
        ],
        fill: const Color(0xFFFFECB3),
      ),
      partGoldFaction(
        fillVertices: _upFin(apexY: -34, halfW: 7, baseY: -24),
        fill: const Color(0xFFFFE082),
      ),
    ]),
    attack: const SoldierAttackSpec(mode: SoldierAttackMode.sustainedBeam, label: 'Sustained beam'),
  ),
  SoldierDesign(
    id: 'wedge',
    name: 'Wedge',
    parts: _centerParts(<SoldierShapePart>[
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(4, -24),
          const Offset(-14, 14),
          const Offset(12, 10),
        ],
        fill: const Color(0xFFFFE082),
      ),
      partGoldFaction(
        fillVertices: _upFin(apexY: -36, halfW: 5, baseY: -27),
        fill: const Color(0xFFFFD54F),
      ),
    ]),
    attack: const SoldierAttackSpec(mode: SoldierAttackMode.burstShards, label: 'Burst shards'),
  ),
  SoldierDesign(
    id: 'dart',
    name: 'Dart',
    parts: _centerParts(<SoldierShapePart>[
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(-4, -22),
          const Offset(18, 6),
          const Offset(-10, 16),
        ],
        fill: const Color(0xFFFFD54F),
      ),
      partGoldFaction(
        fillVertices: _upFin(apexY: -33, halfW: 6.5, baseY: -24),
        fill: const Color(0xFFFFCA28),
      ),
    ]),
    attack: const SoldierAttackSpec(mode: SoldierAttackMode.sweepBeam, label: 'Sweep beam'),
  ),
  SoldierDesign(
    id: 'crest',
    name: 'Crest',
    parts: _centerParts(<SoldierShapePart>[
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(0, -18),
          const Offset(16, -4),
          const Offset(12, 16),
          const Offset(-14, 14),
        ],
        fill: const Color(0xFFFFF8E1),
      ),
      partGoldFaction(
        fillVertices: _upFin(apexY: -32, halfW: 6, baseY: -23),
        fill: const Color(0xFFFFE57F),
      ),
    ]),
    attack: const SoldierAttackSpec(mode: SoldierAttackMode.helixBurst, label: 'Helix burst'),
  ),
  SoldierDesign(
    id: 'bolt',
    name: 'Bolt',
    parts: _centerParts(<SoldierShapePart>[
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(0, -24),
          const Offset(-12, 4),
          const Offset(-6, 18),
          const Offset(14, 8),
        ],
        fill: const Color(0xFFFFE57F),
      ),
      partGoldFaction(
        fillVertices: _upFin(apexY: -35, halfW: 5.5, baseY: -26),
        fill: const Color(0xFFFFCA28),
      ),
    ]),
    attack: const SoldierAttackSpec(mode: SoldierAttackMode.lanceCharge, label: 'Lance charge'),
  ),
  SoldierDesign(
    id: 'veer',
    name: 'Veer',
    parts: _centerParts(<SoldierShapePart>[
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(-6, -20),
          const Offset(14, -12),
          const Offset(8, 18),
          const Offset(-16, 10),
        ],
        fill: const Color(0xFFFFF3E0),
      ),
      partGoldFaction(
        fillVertices: _upFin(apexY: -34, halfW: 6, baseY: -24),
        fill: const Color(0xFFFFE0B2),
      ),
    ]),
    attack: const SoldierAttackSpec(mode: SoldierAttackMode.pelletStorm, label: 'Pellet storm'),
  ),
  SoldierDesign(
    id: 'nimbus',
    name: 'Nimbus',
    parts: _centerParts(<SoldierShapePart>[
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(0, -16),
          const Offset(14, -8),
          const Offset(18, 8),
          const Offset(0, 18),
          const Offset(-18, 6),
        ],
        fill: const Color(0xFFFFE0B2),
      ),
      partGoldFaction(
        fillVertices: _upFin(apexY: -31, halfW: 7, baseY: -21),
        fill: const Color(0xFFFFCA28),
      ),
    ]),
    attack: const SoldierAttackSpec(mode: SoldierAttackMode.sineWaver, label: 'Sine waver'),
  ),

  // —— Uncommon (2 polygons) ——
  SoldierDesign(
    id: 'shard',
    name: 'Shard',
    parts: _centerParts(<SoldierShapePart>[
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(-6, -18),
          const Offset(18, -10),
          const Offset(14, 14),
          const Offset(-16, 12),
        ],
        fill: const Color(0xFFFFCA28),
      ),
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(0, -26),
          const Offset(8, -18),
          const Offset(-8, -18),
        ],
        fill: const Color(0xFFFFE082),
      ),
    ]),
    attack: const SoldierAttackSpec(
      mode: SoldierAttackMode.pulseWave,
      label: 'Pulse wave',
    ),
  ),
  SoldierDesign(
    id: 'kite',
    name: 'Kite',
    parts: _centerParts(<SoldierShapePart>[
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(0, -24),
          const Offset(16, 0),
          const Offset(0, 18),
          const Offset(-20, 2),
        ],
        fill: const Color(0xFFFFB74D),
      ),
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(0, -10),
          const Offset(8, 2),
          const Offset(-8, 2),
        ],
        fill: const Color(0xFFFFE0B2),
      ),
    ]),
    attack: const SoldierAttackSpec(
      mode: SoldierAttackMode.plasmaBolt,
      label: 'Plasma bolt',
    ),
  ),
  SoldierDesign(
    id: 'pentek',
    name: 'Pentek',
    parts: _centerParts(<SoldierShapePart>[
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(0, -22),
          const Offset(-18, 12),
          const Offset(18, 10),
        ],
        fill: const Color(0xFFFFA726),
      ),
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(-10, 12),
          const Offset(10, 12),
          const Offset(0, 22),
        ],
        fill: const Color(0xFFFFCC80),
      ),
    ]),
    attack: const SoldierAttackSpec(
      mode: SoldierAttackMode.sustainedBeam,
      label: 'Sustained beam',
    ),
  ),
  SoldierDesign(
    id: 'striker',
    name: 'Striker',
    parts: _centerParts(<SoldierShapePart>[
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(-4, -20),
          const Offset(16, -6),
          const Offset(12, 14),
          const Offset(-14, 12),
        ],
        fill: const Color(0xFFFFCC80),
      ),
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(0, -28),
          const Offset(6, -22),
          const Offset(-6, -22),
        ],
        fill: const Color(0xFFFFE0B2),
      ),
    ]),
    attack: const SoldierAttackSpec(mode: SoldierAttackMode.railNeedle, label: 'Rail needle'),
  ),
  SoldierDesign(
    id: 'halo',
    name: 'Halo',
    parts: _centerParts(<SoldierShapePart>[
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(0, -14),
          const Offset(12, 2),
          const Offset(0, 16),
          const Offset(-14, 4),
        ],
        fill: const Color(0xFFFFB74D),
      ),
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(-18, -8),
          const Offset(-8, 2),
          const Offset(-16, 10),
        ],
        fill: const Color(0xFFFFE0B2),
      ),
    ]),
    attack: const SoldierAttackSpec(mode: SoldierAttackMode.twinRail, label: 'Twin rail'),
  ),
  SoldierDesign(
    id: 'picket',
    name: 'Picket',
    parts: _centerParts(<SoldierShapePart>[
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(0, -22),
          const Offset(10, 8),
          const Offset(-12, 12),
        ],
        fill: const Color(0xFFFFA726),
      ),
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(8, -12),
          const Offset(18, -4),
          const Offset(12, 6),
        ],
        fill: const Color(0xFFFFCC80),
      ),
    ]),
    attack: const SoldierAttackSpec(mode: SoldierAttackMode.triSpread, label: 'Tri spread'),
  ),
  SoldierDesign(
    id: 'rook',
    name: 'Rook',
    parts: _centerParts(<SoldierShapePart>[
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(-10, -18),
          const Offset(10, -18),
          const Offset(12, 10),
          const Offset(-12, 10),
        ],
        fill: const Color(0xFFFFB74D),
      ),
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(0, -26),
          const Offset(8, -18),
          const Offset(-8, -18),
        ],
        fill: const Color(0xFFFFE0B2),
      ),
    ]),
    attack: const SoldierAttackSpec(mode: SoldierAttackMode.pulseWave, label: 'Pulse wave'),
  ),
  SoldierDesign(
    id: 'vex',
    name: 'Vex',
    parts: _centerParts(<SoldierShapePart>[
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(0, -20),
          const Offset(16, 4),
          const Offset(-6, 16),
          const Offset(-18, 0),
        ],
        fill: const Color(0xFFFF9800),
      ),
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(4, 6),
          const Offset(14, 14),
          const Offset(0, 20),
        ],
        fill: const Color(0xFFFFE0B2),
      ),
    ]),
    attack: const SoldierAttackSpec(mode: SoldierAttackMode.plasmaBolt, label: 'Plasma bolt'),
  ),

  // —— Rare (3 polygons) ——
  SoldierDesign(
    id: 'cinder',
    name: 'Cinder',
    parts: _centerParts(<SoldierShapePart>[
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(0, -18),
          const Offset(14, -8),
          const Offset(16, 8),
          const Offset(0, 16),
          const Offset(-16, 4),
        ],
        fill: const Color(0xFFFF9800),
      ),
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(-22, -4),
          const Offset(-10, 4),
          const Offset(-18, 12),
        ],
        fill: const Color(0xFFFFB74D),
      ),
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(22, -4),
          const Offset(10, 4),
          const Offset(18, 12),
        ],
        fill: const Color(0xFFFFB74D),
      ),
    ]),
    attack: const SoldierAttackSpec(
      mode: SoldierAttackMode.burstShards,
      label: 'Burst shards',
    ),
  ),
  SoldierDesign(
    id: 'hexline',
    name: 'Hexline',
    parts: _centerParts(<SoldierShapePart>[
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(0, -18),
          const Offset(16, -8),
          const Offset(18, 6),
          const Offset(8, 16),
          const Offset(-8, 16),
          const Offset(-18, 2),
        ],
        fill: const Color(0xFFFFE082),
      ),
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(-24, 2),
          const Offset(-14, 10),
          const Offset(-20, 14),
        ],
        fill: const Color(0xFFFFF9C4),
        motion: SoldierPartMotion.wingFlap,
        motionSign: -1.0,
      ),
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(24, 2),
          const Offset(14, 10),
          const Offset(20, 14),
        ],
        fill: const Color(0xFFFFF9C4),
        motion: SoldierPartMotion.wingFlap,
        motionSign: 1.0,
      ),
    ]),
    attack: const SoldierAttackSpec(
      mode: SoldierAttackMode.sweepBeam,
      label: 'Sweep beam',
    ),
  ),
  SoldierDesign(
    id: 'fortress',
    name: 'Fortress',
    parts: _centerParts(<SoldierShapePart>[
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(-8, -16),
          const Offset(10, -16),
          const Offset(14, 8),
          const Offset(-12, 8),
        ],
        fill: const Color(0xFFFFD54F),
      ),
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(-20, -6),
          const Offset(-8, 2),
          const Offset(-14, 12),
        ],
        fill: const Color(0xFFFFE082),
      ),
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(20, -6),
          const Offset(8, 2),
          const Offset(14, 12),
        ],
        fill: const Color(0xFFFFE082),
      ),
    ]),
    attack: const SoldierAttackSpec(
      mode: SoldierAttackMode.helixBurst,
      label: 'Helix burst',
    ),
  ),
  SoldierDesign(
    id: 'titan',
    name: 'Titan',
    parts: _centerParts(<SoldierShapePart>[
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(0, -16),
          const Offset(14, -4),
          const Offset(12, 12),
          const Offset(-10, 14),
          const Offset(-14, -2),
        ],
        fill: const Color(0xFFFFE082),
      ),
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(-22, 2),
          const Offset(-12, 10),
          const Offset(-18, 16),
        ],
        fill: const Color(0xFFFFECB3),
      ),
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(22, 2),
          const Offset(12, 10),
          const Offset(18, 16),
        ],
        fill: const Color(0xFFFFECB3),
      ),
    ]),
    attack: const SoldierAttackSpec(mode: SoldierAttackMode.overchargeCone, label: 'Overcharge cone'),
  ),
  SoldierDesign(
    id: 'aegis',
    name: 'Aegis',
    parts: _centerParts(<SoldierShapePart>[
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(-8, -14),
          const Offset(8, -14),
          const Offset(16, 6),
          const Offset(0, 16),
          const Offset(-16, 6),
        ],
        fill: const Color(0xFFFFCA28),
      ),
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(-20, -6),
          const Offset(-10, 4),
          const Offset(-16, 12),
        ],
        fill: const Color(0xFFFFE082),
      ),
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(20, -6),
          const Offset(10, 4),
          const Offset(16, 12),
        ],
        fill: const Color(0xFFFFE082),
      ),
    ]),
    attack: const SoldierAttackSpec(mode: SoldierAttackMode.sustainedBeam, label: 'Sustained beam'),
  ),

  // —— Epic (4 polygons) ——
  SoldierDesign(
    id: 'septor',
    name: 'Septor',
    parts: _centerParts(<SoldierShapePart>[
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(-6, -8),
          const Offset(8, -8),
          const Offset(10, 10),
          const Offset(-8, 10),
        ],
        fill: const Color(0xFFFFE082),
      ),
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(0, -22),
          const Offset(8, -10),
          const Offset(-8, -10),
        ],
        fill: const Color(0xFFFFF9C4),
      ),
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(-18, -4),
          const Offset(-8, 4),
          const Offset(-14, 14),
        ],
        fill: const Color(0xFFFFF9C4),
      ),
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(18, -4),
          const Offset(8, 4),
          const Offset(14, 14),
        ],
        fill: const Color(0xFFFFF9C4),
      ),
    ]),
    attack: const SoldierAttackSpec(
      mode: SoldierAttackMode.lanceCharge,
      label: 'Lance charge',
    ),
  ),
  SoldierDesign(
    id: 'nova',
    name: 'Nova',
    parts: _centerParts(<SoldierShapePart>[
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(0, -6),
          const Offset(8, 0),
          const Offset(0, 8),
          const Offset(-8, 0),
        ],
        fill: const Color(0xFFFFB300),
      ),
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(0, -20),
          const Offset(6, -10),
          const Offset(-6, -10),
        ],
        fill: const Color(0xFFFFE57F),
      ),
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(-18, 4),
          const Offset(-10, 10),
          const Offset(-14, 16),
        ],
        fill: const Color(0xFFFFE57F),
      ),
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(18, 4),
          const Offset(10, 10),
          const Offset(14, 16),
        ],
        fill: const Color(0xFFFFE57F),
      ),
    ]),
    attack: const SoldierAttackSpec(
      mode: SoldierAttackMode.pelletStorm,
      label: 'Pellet storm',
    ),
  ),
  SoldierDesign(
    id: 'octave',
    name: 'Octave',
    parts: _centerParts(<SoldierShapePart>[
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(0, -14),
          const Offset(12, -6),
          const Offset(14, 6),
          const Offset(0, 14),
          const Offset(-14, 6),
        ],
        fill: const Color(0xFFFFCC80),
      ),
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(-20, -10),
          const Offset(-10, -4),
          const Offset(-16, 6),
        ],
        fill: const Color(0xFFFFE0B2),
      ),
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(20, -10),
          const Offset(10, -4),
          const Offset(16, 6),
        ],
        fill: const Color(0xFFFFE0B2),
      ),
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(-6, 14),
          const Offset(6, 14),
          const Offset(0, 22),
        ],
        fill: const Color(0xFFFFE0B2),
      ),
    ]),
    attack: const SoldierAttackSpec(
      mode: SoldierAttackMode.sineWaver,
      label: 'Sine waver',
    ),
  ),

  // —— Legendary (5 polygons) ——
  SoldierDesign(
    id: 'prism',
    name: 'Prism',
    parts: _centerParts(<SoldierShapePart>[
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(0, -12),
          const Offset(12, -6),
          const Offset(12, 6),
          const Offset(0, 12),
          const Offset(-12, 6),
          const Offset(-12, -6),
        ],
        fill: const Color(0xFFFFB74D),
      ),
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(0, -24),
          const Offset(8, -14),
          const Offset(-8, -14),
        ],
        fill: const Color(0xFFFFE0B2),
      ),
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(22, -6),
          const Offset(14, 4),
          const Offset(24, 8),
        ],
        fill: const Color(0xFFFFE0B2),
        motion: SoldierPartMotion.wingFlap,
        motionSign: 1.0,
        motionAmplitudeRad: 0.38,
      ),
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(-22, -6),
          const Offset(-14, 4),
          const Offset(-24, 8),
        ],
        fill: const Color(0xFFFFE0B2),
        motion: SoldierPartMotion.wingFlap,
        motionSign: -1.0,
        motionAmplitudeRad: 0.38,
      ),
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(-8, 16),
          const Offset(8, 16),
          const Offset(0, 24),
        ],
        fill: const Color(0xFFFFE0B2),
      ),
    ]),
    attack: const SoldierAttackSpec(
      mode: SoldierAttackMode.overchargeCone,
      label: 'Overcharge cone',
    ),
  ),
  SoldierDesign(
    id: 'gladius',
    name: 'Gladius',
    parts: _centerParts(<SoldierShapePart>[
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(0, -28),
          const Offset(-8, 14),
          const Offset(8, 12),
        ],
        fill: const Color(0xFFFFE57F),
      ),
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(-10, -4),
          const Offset(-4, 4),
          const Offset(-12, 8),
        ],
        fill: const Color(0xFFFFFDE7),
      ),
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(10, -4),
          const Offset(4, 4),
          const Offset(12, 8),
        ],
        fill: const Color(0xFFFFFDE7),
      ),
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(-6, 10),
          const Offset(2, 16),
          const Offset(-10, 18),
        ],
        fill: const Color(0xFFFFFDE7),
      ),
      partGoldFaction(
        fillVertices: <Offset>[
          const Offset(6, 10),
          const Offset(-2, 16),
          const Offset(10, 18),
        ],
        fill: const Color(0xFFFFFDE7),
      ),
    ]),
    attack: const SoldierAttackSpec(
      mode: SoldierAttackMode.needleSalvo,
      label: 'Needle salvo',
    ),
  ),
];

/// Procedural silhouettes: **117** units, ratio Common:Uncommon:Rare:Epic:Legendary = 45:32:20:12:8
/// (same 12:8:5:3:2 per 30 as hand-crafted set). Uses deterministic seeds for stable shapes.
List<SoldierDesign> _generateProceduralSoldiers() {
  final List<SoldierDesign> out = <SoldierDesign>[];
  int n = 34;

  String attackLabel(SoldierAttackMode m) {
    return switch (m) {
      SoldierAttackMode.railNeedle => 'Rail needle',
      SoldierAttackMode.twinRail => 'Twin rail',
      SoldierAttackMode.triSpread => 'Tri spread',
      SoldierAttackMode.pulseWave => 'Pulse wave',
      SoldierAttackMode.plasmaBolt => 'Plasma bolt',
      SoldierAttackMode.sustainedBeam => 'Sustained beam',
      SoldierAttackMode.burstShards => 'Burst shards',
      SoldierAttackMode.sweepBeam => 'Sweep beam',
      SoldierAttackMode.helixBurst => 'Helix burst',
      SoldierAttackMode.lanceCharge => 'Lance charge',
      SoldierAttackMode.pelletStorm => 'Pellet storm',
      SoldierAttackMode.sineWaver => 'Sine waver',
      SoldierAttackMode.overchargeCone => 'Overcharge cone',
      SoldierAttackMode.needleSalvo => 'Needle salvo',
      SoldierAttackMode.swordSwipe => 'Sword swipe',
      SoldierAttackMode.none => 'None',
    };
  }

  List<Offset> centerOffsets(List<Offset> raw) {
    double sx = 0, sy = 0;
    for (final Offset e in raw) {
      sx += e.dx;
      sy += e.dy;
    }
    final double k = raw.length.toDouble();
    final double cx = sx / k, cy = sy / k;
    return raw.map((Offset v) => Offset(v.dx - cx, v.dy - cy)).toList();
  }

  List<Offset> irregularPoly(math.Random rng, int sides, double radius) {
    final List<Offset> raw = <Offset>[];
    for (int i = 0; i < sides; i++) {
      final double base = -math.pi / 2 + 2 * math.pi * i / math.max(sides, 1);
      final double jitter = (rng.nextDouble() - 0.5) * 0.42;
      final double rad = radius * (0.72 + rng.nextDouble() * 0.48);
      final double a = base + jitter;
      raw.add(Offset(math.cos(a) * rad, math.sin(a) * rad));
    }
    return centerOffsets(raw);
  }

  for (int i = 0; i < 45; i++) {
    final int seed = 91000 + i * 7919;
    final math.Random rng = math.Random(seed);
    final int sides = 3 + rng.nextInt(4);
    final SoldierAttackMode mode =
        SoldierAttackMode.values[seed % SoldierAttackMode.values.length];
    final List<Offset> hull = irregularPoly(rng, sides, 20);
    final math.Random rChip = math.Random(seed + 401);
    final List<Offset> chip = irregularPoly(rChip, 3, 6.5);
    final Offset chipShift = Offset(rng.nextDouble() * 6 - 3, -15 + rng.nextDouble() * 4);
    out.add(
      SoldierDesign(
        id: 'gen_c_${n.toString().padLeft(3, '0')}',
        name: 'Scout $n',
        parts: _centerParts(<SoldierShapePart>[
          partProceduralHull(
            fillVertices: hull,
            seed: seed,
            tierBand: 0,
          ),
          partProceduralHullAlpha(
            fillVertices: chip
                .map((Offset v) => Offset(v.dx + chipShift.dx, v.dy + chipShift.dy))
                .toList(),
            seed: seed + 11,
            tierBand: 0,
            alpha: 0.94,
          ),
        ]),
        rarity: SoldierRarity.common,
        attack: SoldierAttackSpec(mode: mode, label: attackLabel(mode)),
      ),
    );
    n++;
  }

  for (int i = 0; i < 32; i++) {
    final int seed = 82000 + i * 6151;
    final math.Random rng = math.Random(seed);
    final SoldierAttackMode mode =
        SoldierAttackMode.values[(seed + 3) % SoldierAttackMode.values.length];
    final List<Offset> main = irregularPoly(rng, 3 + rng.nextInt(3), 21);
    final math.Random r2 = math.Random(seed + 17);
    final List<Offset> fin = irregularPoly(r2, 3, 9);
    final Offset finShift = Offset(rng.nextDouble() * 10 - 5, -17 + rng.nextDouble() * 5);
    out.add(
      SoldierDesign(
        id: 'gen_u_${n.toString().padLeft(3, '0')}',
        name: 'Striker $n',
        parts: _centerParts(<SoldierShapePart>[
          partProceduralHull(
            fillVertices: main,
            seed: seed,
            tierBand: 1,
          ),
          partProceduralHullAlpha(
            fillVertices: fin
                .map((Offset v) => Offset(v.dx + finShift.dx, v.dy + finShift.dy))
                .toList(),
            seed: seed + 1,
            tierBand: 1,
            alpha: 0.92,
          ),
        ]),
        rarity: SoldierRarity.rare,
        attack: SoldierAttackSpec(mode: mode, label: attackLabel(mode)),
      ),
    );
    n++;
  }

  for (int i = 0; i < 20; i++) {
    final int seed = 73000 + i * 4337;
    final math.Random rng = math.Random(seed);
    final SoldierAttackMode mode =
        SoldierAttackMode.values[(seed + 5) % SoldierAttackMode.values.length];
    out.add(
      SoldierDesign(
        id: 'gen_r_${n.toString().padLeft(3, '0')}',
        name: 'Vanguard $n',
        parts: _centerParts(<SoldierShapePart>[
          partProceduralHull(
            fillVertices: irregularPoly(rng, 4 + rng.nextInt(2), 19),
            seed: seed,
            tierBand: 2,
          ),
          partProceduralHull(
            fillVertices: irregularPoly(math.Random(seed + 3), 3, 10)
                .map((Offset v) => Offset(v.dx - 20, v.dy + 2))
                .toList(),
            seed: seed + 2,
            tierBand: 2,
          ),
          partProceduralHull(
            fillVertices: irregularPoly(math.Random(seed + 7), 3, 10)
                .map((Offset v) => Offset(v.dx + 20, v.dy + 2))
                .toList(),
            seed: seed + 4,
            tierBand: 2,
          ),
        ]),
        rarity: SoldierRarity.rare,
        attack: SoldierAttackSpec(mode: mode, label: attackLabel(mode)),
      ),
    );
    n++;
  }

  for (int i = 0; i < 12; i++) {
    final int seed = 64000 + i * 2749;
    final math.Random rng = math.Random(seed);
    final SoldierAttackMode mode =
        SoldierAttackMode.values[(seed + 7) % SoldierAttackMode.values.length];
    out.add(
      SoldierDesign(
        id: 'gen_e_${n.toString().padLeft(3, '0')}',
        name: 'Warden $n',
        parts: _centerParts(<SoldierShapePart>[
          partProceduralHull(
            fillVertices: irregularPoly(rng, 4, 14),
            seed: seed,
            tierBand: 3,
          ),
          partProceduralHull(
            fillVertices: irregularPoly(math.Random(seed + 1), 3, 8)
                .map((Offset v) => Offset(v.dx, v.dy - 20))
                .toList(),
            seed: seed + 1,
            tierBand: 3,
          ),
          partProceduralHull(
            fillVertices: irregularPoly(math.Random(seed + 2), 3, 8)
                .map((Offset v) => Offset(v.dx - 16, v.dy + 4))
                .toList(),
            seed: seed + 2,
            tierBand: 3,
          ),
          partProceduralHull(
            fillVertices: irregularPoly(math.Random(seed + 4), 3, 8)
                .map((Offset v) => Offset(v.dx + 16, v.dy + 4))
                .toList(),
            seed: seed + 3,
            tierBand: 3,
          ),
        ]),
        rarity: SoldierRarity.epic,
        attack: SoldierAttackSpec(mode: mode, label: attackLabel(mode)),
      ),
    );
    n++;
  }

  for (int i = 0; i < 8; i++) {
    final int seed = 55000 + i * 9973;
    final math.Random rng = math.Random(seed);
    final SoldierAttackMode mode =
        SoldierAttackMode.values[(seed + 11) % SoldierAttackMode.values.length];
    out.add(
      SoldierDesign(
        id: 'gen_l_${n.toString().padLeft(3, '0')}',
        name: 'Apex $n',
        parts: _centerParts(<SoldierShapePart>[
          partProceduralHull(
            fillVertices: irregularPoly(rng, 6, 13),
            seed: seed,
            tierBand: 4,
          ),
          partProceduralHull(
            fillVertices: irregularPoly(math.Random(seed + 1), 3, 7)
                .map((Offset v) => Offset(v.dx, v.dy - 22))
                .toList(),
            seed: seed + 1,
            tierBand: 4,
          ),
          partProceduralHull(
            fillVertices: irregularPoly(math.Random(seed + 3), 3, 7)
                .map((Offset v) => Offset(v.dx - 20, v.dy + 2))
                .toList(),
            seed: seed + 2,
            tierBand: 4,
          ),
          partProceduralHull(
            fillVertices: irregularPoly(math.Random(seed + 5), 3, 7)
                .map((Offset v) => Offset(v.dx + 20, v.dy + 2))
                .toList(),
            seed: seed + 3,
            tierBand: 4,
          ),
          partProceduralHull(
            fillVertices: irregularPoly(math.Random(seed + 7), 3, 7)
                .map((Offset v) => Offset(v.dx, v.dy + 18))
                .toList(),
            seed: seed + 4,
            tierBand: 4,
          ),
        ]),
        rarity: SoldierRarity.legendary,
        attack: SoldierAttackSpec(mode: mode, label: attackLabel(mode)),
      ),
    );
    n++;
  }

  return out;
}

/// Full legacy pool (**151**) — used only to extract user-promoted draft rows; not shown as a single list in UI.
final List<SoldierDesign> _kLegacyFullCatalog = List<SoldierDesign>.unmodifiable(
  <SoldierDesign>[
    ..._kHandCraftedSoldiers,
    ..._generateProceduralSoldiers(),
    _kLegendaryCastleCat,
  ],
);

/// Old **draft 1-based** indices moved to Validated (user curation).
const List<int> _kPromotedDraftOneBased = <int>[
  7, 8, 9, 24, 26, 27, 29, 31, 32, 33, 36,
];

List<SoldierDesign> _legacyPromotedAsLegendary() {
  return _kPromotedDraftOneBased.map((int i) {
    final SoldierDesign d = _kLegacyFullCatalog[i - 1];
    return SoldierDesign(
      id: d.id,
      name: d.name,
      parts: d.parts,
      attack: d.attack,
      rarity: SoldierRarity.legendary,
      rangePlotHubModel: d.rangePlotHubModel,
      crownVfxMode: d.crownVfxMode,
    );
  }).toList();
}

final List<SoldierDesign> _kRadialLegendaryDrafts =
    List<SoldierDesign>.unmodifiable(_buildTenRadialLegendaryDrafts());

/// Box Grin production — square body with happy smiley face.
List<SoldierShapePart> _boxGrinProdParts() {
  List<Offset> roundEye(double cx, double cy, [double r = 3.5]) =>
      List<Offset>.generate(14, (int i) {
        final double a = i * 2 * math.pi / 14;
        return Offset(cx + r * math.cos(a), cy + r * math.sin(a));
      });

  List<Offset> smileArc(double cx, double my, double w, double drop, int segs) {
    final List<Offset> pts = <Offset>[];
    for (int i = 0; i <= segs; i++) {
      final double t = i / segs;
      pts.add(Offset(cx - w / 2 + w * t, my + drop * math.sin(math.pi * t)));
    }
    return pts;
  }

  return _centerParts(<SoldierShapePart>[
    SoldierShapePart(
      fillVertices: const <Offset>[
        Offset(-18, -18), Offset(18, -18), Offset(18, 18), Offset(-18, 18),
      ],
      fillTier: 2, strokeWidth: 2.2, stackRole: SoldierPartStackRole.attack,
    ),
    SoldierShapePart(fillVertices: roundEye(-6.5, -4, 1.8375), fillTier: 0, strokeWidth: 0, stackRole: SoldierPartStackRole.attack),
    SoldierShapePart(fillVertices: roundEye(6.5, -4, 1.8375), fillTier: 0, strokeWidth: 0, stackRole: SoldierPartStackRole.attack),
    SoldierShapePart(
      strokePolyline: smileArc(0, 5, 16, 4.5, 12),
      fillTier: 1, transparentFill: true, strokeWidth: 4.86,
      motion: SoldierPartMotion.pulseScale,
      motionAmplitudeRad: 0.3,
      stackRole: SoldierPartStackRole.attack,
    ),
  ]);
}

/// Draft soldiers (currently empty — all promoted to production).
List<SoldierDesign> _buildFacialGeometricDrafts() => <SoldierDesign>[];

/// Validated tab: **11** promoted legacy drafts — all **legendary**.
final List<SoldierDesign> kValidatedSoldierDesignCatalog =
    List<SoldierDesign>.unmodifiable(_legacyPromotedAsLegendary());

final SoldierDesign _kProductionGildedBastion = SoldierDesign(
  id: 'helm_tower_prod',
  name: 'Helm Tower',
  rarity: SoldierRarity.epic,
  rangePlotHubModel: _kLegendaryCastleCat.rangePlotHubModel,
  crownVfxMode: CrownVfxMode.scalingCrown,
  parts: _kLegendaryCastleCat.parts,
  attack: _kLegendaryCastleCat.attack,
);

/// Ember Sigil production parts — conforms to [soldier_structure.md].
///
/// Source layout (vi=5, odd):
///   0      – core star5
///   1‒6    – 6 arrow triangles
///   7‒12   – 6 hub stars
///   13‒15  – face features (left eye, right eye, mouth)
///
/// Output structure:
///   Core body  : center star (body), face (body)
///   Attack body: 6 components, each = arrow (static) + hub star (orbitSpin CW)
///                + hit zone image (invisible triangle, same shape as arrow)
///   Zones      : contact hexagon (rotated 30° CW), target (×2.16, rotated 30° CW),
///                engagement annulus (inner 33.6 / outer 54)
List<SoldierShapePart> _emberSigilProdParts() {
  final List<SoldierShapePart> scaled =
      _scalePartsToWidth(_kRadialLegendaryDrafts[5].parts, 75);

  Offset cen(List<Offset> pts) {
    double sx = 0, sy = 0;
    for (final Offset v in pts) {
      sx += v.dx;
      sy += v.dy;
    }
    return Offset(sx / pts.length, sy / pts.length);
  }

  final List<SoldierShapePart> out = <SoldierShapePart>[];

  // ── Core body: center star (index 0) ──
  out.add(scaled[0]);

  // ── Attack body: 6 components, each = arrow + hub star + hit zone ──
  // During attack all three thrust radially outward by 40 model units, then retract.
  const double kThrustDist = 40;
  for (int k = 0; k < 6; k++) {
    final SoldierShapePart arrow = scaled[1 + k];
    final SoldierShapePart star = scaled[7 + k];

    // Arrow triangle — radial probe only (no idle motion), scales to 1.8× at max extension
    out.add(SoldierShapePart(
      fillVertices: arrow.fillVertices,
      fillTier: arrow.fillTier,
      transparentFill: arrow.transparentFill,
      strokeWidth: arrow.strokeWidth,
      motion: SoldierPartMotion.radialProbe,
      motionAmplitudeRad: kThrustDist,
      motionProbeScale: 1.8,
      stackRole: SoldierPartStackRole.attack,
    ));

    // Hub star — idle CW spin + radial probe during attack, scales with arrow
    out.add(SoldierShapePart(
      fillVertices: star.fillVertices,
      fillTier: star.fillTier,
      transparentFill: star.transparentFill,
      strokeWidth: star.strokeWidth,
      motion: SoldierPartMotion.orbitSpinRadialProbe,
      motionPivot: cen(star.fillVertices!),
      motionAmplitudeRad: math.pi * 0.3,
      motionSign: -1.0,
      motionProbeDistance: kThrustDist,
      motionProbeScale: 1.8,
      stackRole: SoldierPartStackRole.attack,
    ));

    // Hit zone image (same shape/position as arrow) — radial probe tracks arrow, same scale
    out.add(SoldierShapePart(
      fillVertices: arrow.fillVertices,
      fillTier: 1,
      transparentFill: true,
      strokeWidth: 0,
      motion: SoldierPartMotion.radialProbe,
      motionAmplitudeRad: kThrustDist,
      motionProbeScale: 1.8,
      stackRole: SoldierPartStackRole.hitZone,
    ));
  }

  // ── Core body: face features (13, 14, 15) ──
  out.add(scaled[13]);
  out.add(scaled[14]);
  out.add(scaled[15]);

  // ── Contact zone: hexagon from arrow-triangle base midpoints, rotated 30° CW ──
  Offset rot30cw(Offset v) {
    const double c = 0.8660254037844387; // cos(-π/6)
    const double s = -0.4999999999999999; // sin(-π/6)
    return Offset(v.dx * c - v.dy * s, v.dx * s + v.dy * c);
  }

  final List<Offset> contactHexRaw = <Offset>[];
  for (int k = 0; k < 6; k++) {
    final List<Offset> av = scaled[1 + k].fillVertices!;
    int tipIdx = 0;
    double maxD = 0;
    for (int j = 0; j < av.length; j++) {
      final double d = av[j].distance;
      if (d > maxD) {
        maxD = d;
        tipIdx = j;
      }
    }
    double bx = 0, by = 0;
    int cnt = 0;
    for (int j = 0; j < av.length; j++) {
      if (j == tipIdx) continue;
      bx += av[j].dx;
      by += av[j].dy;
      cnt++;
    }
    contactHexRaw.add(Offset(bx / cnt, by / cnt));
  }
  final List<Offset> contactHex =
      contactHexRaw.map(rot30cw).toList();
  out.add(SoldierShapePart(
    fillVertices: contactHex,
    fillTier: 1,
    transparentFill: true,
    strokeWidth: 0,
    stackRole: SoldierPartStackRole.contact,
  ));

  // ── Target zone: contact × 2.592 (previous ×2.16 enlarged 20%) ──
  out.add(SoldierShapePart(
    fillVertices: contactHex.map((Offset v) => v * 2.592).toList(),
    fillTier: 1,
    transparentFill: true,
    strokeWidth: 0,
    stackRole: SoldierPartStackRole.target,
  ));

  // ── Engagement zone: annulus inner r=33.6, outer r=54 (model units) ──
  final List<Offset> engVerts = <Offset>[];
  for (int k = 0; k < 6; k++) {
    final double a = k * math.pi / 3;
    engVerts.add(Offset(33.6 * math.cos(a), 33.6 * math.sin(a)));
  }
  for (int k = 0; k < 6; k++) {
    final double a = (k + 0.5) * math.pi / 3;
    engVerts.add(Offset(54 * math.cos(a), 54 * math.sin(a)));
  }
  out.add(SoldierShapePart(
    fillVertices: engVerts,
    fillTier: 1,
    transparentFill: true,
    strokeWidth: 0,
    stackRole: SoldierPartStackRole.engagement,
  ));

  return out;
}

final SoldierDesign _kProductionEmberSigil = SoldierDesign(
  id: 'starry_hex_prod',
  name: 'Starry Hex',
  rarity: SoldierRarity.epic,
  rangePlotHubModel: Offset.zero,
  crownVfxMode: CrownVfxMode.none,
  parts: _emberSigilProdParts(),
  attack: const SoldierAttackSpec(mode: SoldierAttackMode.none, label: 'Sigil thrust'),
  maxHp: 150,
  attackDamage: 35,
  knockbackSpeed: 262.5,
);

final SoldierDesign _kProductionBloodStar = SoldierDesign(
  id: 'blood_star_prod',
  name: 'Blood Star',
  rarity: _kRadialLegendaryDrafts[6].rarity,
  crownVfxMode: CrownVfxMode.flames,
  parts: _scalePartsToWidth(_kRadialLegendaryDrafts[6].parts, 55),
  attack: _kRadialLegendaryDrafts[6].attack,
);

final SoldierDesign _kProductionBoxGrin = SoldierDesign(
  id: 'mild_square_prod',
  name: 'Mild Square',
  rarity: SoldierRarity.common,
  crownVfxMode: CrownVfxMode.punchBurst,
  paintSize: 42,
  side: 30,
  parts: <SoldierShapePart>[
    ..._scalePartsToWidth(_boxGrinProdParts(), 45),
    SoldierShapePart(
      fillVertices: const <Offset>[
        Offset(-19.125, -19.125), Offset(19.125, -19.125),
        Offset(19.125, 19.125), Offset(-19.125, 19.125),
      ],
      fillTier: 1, transparentFill: true, strokeWidth: 0,
      stackRole: SoldierPartStackRole.contact,
    ),
    SoldierShapePart(
      fillVertices: const <Offset>[
        Offset(-27.731, -27.731), Offset(27.731, -27.731),
        Offset(27.731, 27.731), Offset(-27.731, 27.731),
      ],
      fillTier: 1, transparentFill: true, strokeWidth: 0,
      stackRole: SoldierPartStackRole.target,
    ),
    SoldierShapePart(
      fillVertices: _engagementAnnulusVerts(26.25, 42.24),
      fillTier: 1, transparentFill: true, strokeWidth: 0,
      stackRole: SoldierPartStackRole.engagement,
    ),
    SoldierShapePart(
      fillVertices: const <Offset>[
        Offset(-24.75, -24.75), Offset(24.75, -24.75),
        Offset(24.75, 24.75), Offset(-24.75, 24.75),
      ],
      fillTier: 1, transparentFill: true, strokeWidth: 0,
      stackRole: SoldierPartStackRole.hitZone,
    ),
  ],
  attack: const SoldierAttackSpec(mode: SoldierAttackMode.none, label: 'Punch', nominalAttacksPerSecond: 0.4286),
  maxHp: 30,
  attackDamage: 1,
);

/// Tri Fury production — triangle body with vertical ellipse eyes + brow lines + arrogant smirk.
List<SoldierShapePart> _triFuryProdParts() {
  // Vertical ellipse eye (rx < ry).
  List<Offset> ellipseEye(double cx, double cy, double rx, double ry) =>
      List<Offset>.generate(14, (int i) {
        final double a = i * 2 * math.pi / 14;
        return Offset(cx + rx * math.cos(a), cy + ry * math.sin(a));
      });

  final double triH = 40 * math.sqrt(3) / 2;
  final List<Offset> triBody = <Offset>[
    Offset(0, -triH * 2 / 3),
    Offset(20, triH / 3),
    Offset(-20, triH / 3),
  ];

  return _centerParts(<SoldierShapePart>[
    SoldierShapePart(
      fillVertices: triBody, fillTier: 2, strokeWidth: 2.2,
      stackRole: SoldierPartStackRole.attack,
    ),
    SoldierShapePart(fillVertices: ellipseEye(-6, -1, 1.47, 2.66), fillTier: 0, strokeWidth: 0, stackRole: SoldierPartStackRole.attack),
    SoldierShapePart(fillVertices: ellipseEye(6, -1, 1.47, 2.66), fillTier: 0, strokeWidth: 0, stackRole: SoldierPartStackRole.attack),
    SoldierShapePart(
      strokePolyline: const <Offset>[Offset(-8, -6.5), Offset(-3.5, -5)],
      fillTier: 1, transparentFill: true, strokeWidth: 5.4,
      motion: SoldierPartMotion.verticalBob,
      motionSign: -1.0,
      motionAmplitudeRad: 2.5,
      stackRole: SoldierPartStackRole.attack,
    ),
    SoldierShapePart(
      strokePolyline: const <Offset>[Offset(3.5, -5), Offset(8, -6.5)],
      fillTier: 1, transparentFill: true, strokeWidth: 5.4,
      motion: SoldierPartMotion.verticalBob,
      motionSign: -1.0,
      motionAmplitudeRad: 2.5,
      stackRole: SoldierPartStackRole.attack,
    ),
    SoldierShapePart(
      strokePolyline: const <Offset>[Offset(-7, 8), Offset(7, 6)],
      fillTier: 1, transparentFill: true, strokeWidth: 5.4,
      stackRole: SoldierPartStackRole.attack,
    ),
  ]);
}

final SoldierDesign _kProductionTriFury = SoldierDesign(
  id: 'smug_triangle_prod',
  name: 'Smug Triangle',
  rarity: SoldierRarity.common,
  crownVfxMode: CrownVfxMode.punchBurst,
  paintSize: 49.896,
  side: 35.64,
  parts: <SoldierShapePart>[
    ..._scalePartsToWidth(_triFuryProdParts(), 53.46),
    SoldierShapePart(
      fillVertices: const <Offset>[
        Offset(0, -26.235), Offset(22.721, 13.119), Offset(-22.721, 13.119),
      ],
      fillTier: 1, transparentFill: true, strokeWidth: 0,
      stackRole: SoldierPartStackRole.contact,
    ),
    SoldierShapePart(
      fillVertices: const <Offset>[
        Offset(0, -38.041), Offset(32.945, 19.021), Offset(-32.945, 19.021),
      ],
      fillTier: 1, transparentFill: true, strokeWidth: 0,
      stackRole: SoldierPartStackRole.target,
    ),
    SoldierShapePart(
      fillVertices: _engagementAnnulusVerts(31.185, 31.724),
      fillTier: 1, transparentFill: true, strokeWidth: 0,
      stackRole: SoldierPartStackRole.engagement,
    ),
    SoldierShapePart(
      fillVertices: const <Offset>[
        Offset(0, -33.952), Offset(29.403, 16.976), Offset(-29.403, 16.976),
      ],
      fillTier: 1, transparentFill: true, strokeWidth: 0,
      stackRole: SoldierPartStackRole.hitZone,
    ),
  ],
  attack: const SoldierAttackSpec(mode: SoldierAttackMode.none, label: 'Punch', nominalAttacksPerSecond: 0.4286),
  maxHp: 30,
  attackDamage: 1,
);

/// Orb Joy production — circle body with arc eyes + open mouth.
List<SoldierShapePart> _orbJoyProdParts() {
  List<Offset> arcEye(double cx, double cy, double w, double rise, int segs) {
    final List<Offset> pts = <Offset>[];
    for (int i = 0; i <= segs; i++) {
      final double t = i / segs;
      pts.add(Offset(cx - w / 2 + w * t, cy - rise * math.sin(math.pi * t)));
    }
    return pts;
  }

  List<Offset> openMouth(double cx, double cy, double rx, double ry, int segs) {
    final List<Offset> pts = <Offset>[Offset(cx - rx, cy)];
    for (int i = 1; i < segs; i++) {
      final double a = math.pi * i / segs;
      pts.add(Offset(cx - rx * math.cos(a), cy + ry * math.sin(a)));
    }
    pts.add(Offset(cx + rx, cy));
    return pts;
  }

  final List<Offset> circBody = List<Offset>.generate(20, (int i) {
    final double a = -math.pi / 2 + i * 2 * math.pi / 20;
    return Offset(18 * math.cos(a), 18 * math.sin(a));
  });

  return _centerParts(<SoldierShapePart>[
    SoldierShapePart(
      fillVertices: circBody, fillTier: 2, strokeWidth: 2.2,
      stackRole: SoldierPartStackRole.attack,
    ),
    SoldierShapePart(
      strokePolyline: arcEye(-7.5, -3, 8, 4, 10),
      fillTier: 1, transparentFill: true, strokeWidth: 4.32,
      stackRole: SoldierPartStackRole.attack,
    ),
    SoldierShapePart(
      strokePolyline: arcEye(7.5, -3, 8, 4, 10),
      fillTier: 1, transparentFill: true, strokeWidth: 4.32,
      stackRole: SoldierPartStackRole.attack,
    ),
    SoldierShapePart(
      fillVertices: openMouth(0, 5, 9, 7, 12),
      fillTier: 6, strokeWidth: 2.0,
      motion: SoldierPartMotion.pulseScale,
      motionAmplitudeRad: 0.3,
      stackRole: SoldierPartStackRole.attack,
    ),
  ]);
}

final SoldierDesign _kProductionOrbJoy = SoldierDesign(
  id: 'jolly_circle_prod',
  name: 'Jolly Circle',
  rarity: SoldierRarity.common,
  crownVfxMode: CrownVfxMode.punchBurst,
  paintSize: 42,
  side: 30,
  parts: <SoldierShapePart>[
    ..._scalePartsToWidth(_orbJoyProdParts(), 45),
    SoldierShapePart(
      fillVertices: _circleVerts(19.125, 20),
      fillTier: 1, transparentFill: true, strokeWidth: 0,
      stackRole: SoldierPartStackRole.contact,
    ),
    SoldierShapePart(
      fillVertices: _circleVerts(27.731, 20),
      fillTier: 1, transparentFill: true, strokeWidth: 0,
      stackRole: SoldierPartStackRole.target,
    ),
    SoldierShapePart(
      fillVertices: _engagementAnnulusVerts(26.25, 36.96),
      fillTier: 1, transparentFill: true, strokeWidth: 0,
      stackRole: SoldierPartStackRole.engagement,
    ),
    SoldierShapePart(
      fillVertices: _circleVerts(24.75, 20),
      fillTier: 1, transparentFill: true, strokeWidth: 0,
      stackRole: SoldierPartStackRole.hitZone,
    ),
  ],
  attack: const SoldierAttackSpec(mode: SoldierAttackMode.none, label: 'Punch', nominalAttacksPerSecond: 0.4286),
  maxHp: 30,
  attackDamage: 1,
);

/// Production tab / war roster.
final List<SoldierDesign> kProductionSoldierDesignCatalog =
    List<SoldierDesign>.unmodifiable(<SoldierDesign>[
      _kProductionGildedBastion,
      _kProductionEmberSigil,
      _kProductionBloodStar,
      _kProductionBoxGrin,
      _kProductionTriFury,
      _kProductionOrbJoy,
    ]);

/// Draft tab: currently empty (all promoted to production).
final List<SoldierDesign> kDraftSoldierDesignCatalog =
    List<SoldierDesign>.unmodifiable(_buildFacialGeometricDrafts());

/// Combined list for tooling (**11** validated + **6** production + **0** draft).
final List<SoldierDesign> kSoldierDesignCatalog = List<SoldierDesign>.unmodifiable(
  <SoldierDesign>[
    ...kValidatedSoldierDesignCatalog,
    ...kProductionSoldierDesignCatalog,
    ...kDraftSoldierDesignCatalog,
  ],
);
