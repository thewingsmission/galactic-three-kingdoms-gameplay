import 'package:flutter/material.dart';

import '../models/soldier_design.dart';
import '../models/soldier_design_palette.dart';
import 'multi_polygon_soldier_painter.dart';
import 'triangle_soldier.dart';

/// Rounded square tile showing a Triangle soldier preview.
class SoldierInventoryTile extends StatelessWidget {
  const SoldierInventoryTile({
    super.key,
    required this.index,
    required this.selected,
    required this.onTap,
    this.rosterDesign,
    this.rosterPalette = SoldierDesignPalette.yellow,
  });

  final int index;
  final bool selected;
  final VoidCallback onTap;
  final SoldierDesign? rosterDesign;
  final SoldierDesignPalette rosterPalette;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Material(
      color: selected ? cs.primaryContainer.withValues(alpha: 0.55) : cs.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 88,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? cs.primary : Colors.white24,
              width: selected ? 3 : 1.5,
            ),
          ),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 72,
                height: 72,
                child: Center(
                  child: rosterDesign != null
                      ? CustomPaint(
                          size: const Size(56, 56),
                          painter: RosterMiniSoldierPainter(
                            design: rosterDesign!,
                            palette: rosterPalette,
                          ),
                        )
                      : const TriangleSoldier(size: 56, side: 40, angle: 0),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  rosterDesign != null
                      ? '${rosterDesign!.name} · #${index + 1}'
                      : 'Triangle #${index + 1}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: cs.primary, size: 26),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small idle preview for inventory / formation (no attack cycle).
class RosterMiniSoldierPainter extends CustomPainter {
  RosterMiniSoldierPainter({
    required this.design,
    required this.palette,
  });

  final SoldierDesign design;
  final SoldierDesignPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final List<SoldierShapePart> parts = design.parts;
    final double fit = MultiPolygonSoldierPainter.layoutMetrics(
      parts: parts,
      soldierCanvasSize: size,
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
      displayPalette: palette,
      strokeWidth: 2.25,
      motionT: 0.25,
      attackCycleT: null,
      uniformWorldScale: fit,
      fixedModelAnchor: anchor,
      paintCrownFlames: false,
    ).paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant RosterMiniSoldierPainter oldDelegate) {
    return oldDelegate.design != design || oldDelegate.palette != palette;
  }
}
