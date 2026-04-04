import 'package:flutter/material.dart';

/// Three preview / production options; each [SoldierShapePart] uses the same **tier index**
/// with [kRedFactionComponentColors] / yellow / blue (see soldier_faction_color_theme.dart).
enum SoldierDesignPalette {
  red,
  yellow,
  blue,
}

extension SoldierDesignPaletteX on SoldierDesignPalette {
  /// Accent for attack beams / UI that should follow the palette.
  Color get attackAccent => switch (this) {
        SoldierDesignPalette.red => const Color(0xFFE53935),
        SoldierDesignPalette.yellow => const Color(0xFFFFC107),
        SoldierDesignPalette.blue => const Color(0xFF42A5F5),
      };

  /// Crown flame VFX: bright core, mid body, deep ember ([MultiPolygonSoldierPainter]).
  ({Color bright, Color mid, Color deep}) get crownFlameColors =>
      switch (this) {
        SoldierDesignPalette.red => (
            bright: const Color(0xFFFF7043),
            mid: const Color(0xFFFFAB91),
            deep: const Color(0xFFC62828),
          ),
        SoldierDesignPalette.yellow => (
            bright: const Color(0xFFFFF176),
            mid: const Color(0xFFFFD54F),
            deep: const Color(0xFFE65100),
          ),
        SoldierDesignPalette.blue => (
            bright: const Color(0xFF84FFFF),
            mid: const Color(0xFF4FC3F7),
            deep: const Color(0xFF1565C0),
          ),
      };
}
