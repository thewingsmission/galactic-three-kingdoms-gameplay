import 'package:flutter/material.dart';

import 'soldier_design.dart';
import 'soldier_design_palette.dart';

/// Five palette slots per faction used when painting soldier components.
///
/// **Design indices are 1–5** (darkest → lightest). In Dart each list is 0-based:
/// design index `n` → `list[n - 1]`.
///
/// **Yellow** and **blue** ramps are **HSL-mapped from the red ramp**: same saturation &
/// lightness per tier, hue set to the former authored **tier 3** yellow / blue hue
/// (`#FCD87E` / `#66ACF1`).
const List<Color> kRedFactionComponentColors = <Color>[
  Color(0xFFFF000D), // 1 — (255, 0, 13)
  Color(0xFFFF333D), // 2 — (255, 51, 61)
  Color(0xFFFF666E), // 3 — (255, 102, 110)
  Color(0xFFFF999E), // 4 — (255, 153, 158)
  Color(0xFFFFCCCF), // 5 — (255, 204, 207)
];

const List<Color> kYellowFactionComponentColors = <Color>[
  Color(0xFFFFB600), // 1 — from red 1 via HSL hue → yellow tier-3 hue
  Color(0xFFFFC533), // 2
  Color(0xFFFFD366), // 3
  Color(0xFFFFE299), // 4
  Color(0xFFFFF0CC), // 5
];

const List<Color> kBlueFactionComponentColors = <Color>[
  Color(0xFF0080FF), // 1 — from red 1 via HSL hue → blue tier-3 hue
  Color(0xFF339AFF), // 2
  Color(0xFF66B3FF), // 3
  Color(0xFF99CCFF), // 4
  Color(0xFFCCE6FF), // 5
];

/// Active faction list for [SoldierDesignPalette] (tiers **1–5** → index `tier - 1`).
List<Color> factionTierList(SoldierDesignPalette p) => switch (p) {
      SoldierDesignPalette.red => kRedFactionComponentColors,
      SoldierDesignPalette.yellow => kYellowFactionComponentColors,
      SoldierDesignPalette.blue => kBlueFactionComponentColors,
    };

/// Design tier **1–5** → color from [factionTierList].
Color factionTierColor(SoldierDesignPalette p, int tier) {
  assert(tier >= 1 && tier <= 5);
  return factionTierList(p)[tier - 1];
}

extension SoldierShapePartFactionColors on SoldierShapePart {
  /// Fill from standard ramp for [p]; **stroke is always black** for all three themes.
  SoldierPartColorPair colorsForPalette(SoldierDesignPalette p) {
    final List<Color> list = factionTierList(p);
    return SoldierPartColorPair(
      fill: transparentFill ? Colors.transparent : list[fillTier - 1],
      stroke: Colors.black,
    );
  }
}
