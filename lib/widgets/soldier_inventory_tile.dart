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
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? cs.primary : Colors.white24,
              width: selected ? 2.5 : 1.25,
            ),
          ),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: rosterDesign != null
                      ? CustomPaint(
                          size: const Size(40, 40),
                          painter: RosterMiniSoldierPainter(
                            design: rosterDesign!,
                            palette: rosterPalette,
                          ),
                        )
                      : const TriangleSoldier(size: 40, side: 30, angle: 0),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  rosterDesign != null
                      ? '${rosterDesign!.name} · #${index + 1}'
                      : 'Triangle #${index + 1}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                        height: 1.15,
                      ),
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: cs.primary, size: 20),
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
