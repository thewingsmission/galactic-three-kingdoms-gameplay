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
      stackRole: SoldierPartStackRole.attack,
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
        rarity: SoldierRarity.uncommon,
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

/// Validated tab: **11** promoted legacy drafts — all **legendary**.
final List<SoldierDesign> kValidatedSoldierDesignCatalog =
    List<SoldierDesign>.unmodifiable(_legacyPromotedAsLegendary());

final SoldierDesign _kProductionGildedBastion = SoldierDesign(
  id: 'gilded_bastion_prod',
  name: 'Gilded Bastion',
  rarity: _kLegendaryCastleCat.rarity,
  rangePlotHubModel: _kLegendaryCastleCat.rangePlotHubModel,
  crownVfxMode: CrownVfxMode.scalingCrown,
  parts: _kLegendaryCastleCat.parts,
  attack: _kLegendaryCastleCat.attack,
);

/// Production tab / war roster: single **Gilded Bastion** with scalingCrown VFX.
final List<SoldierDesign> kProductionSoldierDesignCatalog =
    List<SoldierDesign>.unmodifiable(<SoldierDesign>[
      _kProductionGildedBastion,
    ]);

/// Draft tab: **10** new crimson radial sigils (legendary).
final List<SoldierDesign> kDraftSoldierDesignCatalog = _kRadialLegendaryDrafts;

/// Combined list for tooling (**11** validated + **1** production + **10** draft).
final List<SoldierDesign> kSoldierDesignCatalog = List<SoldierDesign>.unmodifiable(
  <SoldierDesign>[
    ...kValidatedSoldierDesignCatalog,
    ...kProductionSoldierDesignCatalog,
    ...kDraftSoldierDesignCatalog,
  ],
);
