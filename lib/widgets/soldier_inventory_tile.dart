import 'package:flutter/material.dart';

import '../models/soldier_design.dart';
import '../models/soldier_design_palette.dart';
import '../models/soldier_rarity.dart';
import 'multi_polygon_soldier_painter.dart';
import 'soldier_attack_preview_column.dart';
import 'soldier_design_catalog.dart';
import 'triangle_soldier.dart';

/// Card-style inventory tile matching the production panel design.
class SoldierInventoryTile extends StatefulWidget {
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
  State<SoldierInventoryTile> createState() => _SoldierInventoryTileState();
}

class _SoldierInventoryTileState extends State<SoldierInventoryTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  double _lastCtrlValue = 0;
  double _continuousMotionT = 0;

  void _accumulateMotionT() {
    final double curr = _ctrl.value;
    double delta = curr - _lastCtrlValue;
    if (delta < 0) delta += 1.0;
    _continuousMotionT += delta;
    _lastCtrlValue = curr;
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _ctrl.addListener(_accumulateMotionT);
    _ctrl.repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final SoldierDesign? design = widget.rosterDesign;
    final SoldierRarity rarity =
        design != null ? design.rarity : SoldierRarity.common;
    final Color accent = rarity.accentColor;
    final Color borderColor = widget.selected
        ? accent
        : Colors.white.withValues(alpha: 0.18);
    final double borderWidth = widget.selected ? 2.5 : 1.25;

    return GestureDetector(
      onTap: widget.onTap,
      child: AspectRatio(
        aspectRatio: 0.78,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: widget.selected
                ? accent.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                bottom: 18,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                  child: design != null
                      ? AnimatedBuilder(
                          animation: _ctrl,
                          builder: (BuildContext context, Widget? child) {
                            return SoldierAttackPreviewColumn(
                              design: design,
                              palette: widget.rosterPalette,
                              motionT: _continuousMotionT,
                              strokeWidth: 2.25,
                              uniformIdleDesigns: kSoldierDesignCatalog,
                            );
                          },
                        )
                      : const Center(
                          child: TriangleSoldier(size: 40, side: 30, angle: 0),
                        ),
                ),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    rarity.label,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 8,
                      height: 1,
                    ),
                  ),
                ),
              ),
              if (widget.selected)
                Positioned(
                  top: 2,
                  left: 2,
                  child: Icon(Icons.check_circle, color: accent, size: 16),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 2,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    design?.name ?? 'Triangle',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
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
    this.motionT = 0.25,
  });

  final SoldierDesign design;
  final SoldierDesignPalette palette;
  final double motionT;

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
      motionT: motionT,
      attackCycleT: null,
      uniformWorldScale: fit,
      fixedModelAnchor: anchor,
      crownVfxMode: CrownVfxMode.none,
    ).paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant RosterMiniSoldierPainter oldDelegate) {
    return oldDelegate.design != design ||
        oldDelegate.palette != palette ||
        oldDelegate.motionT != motionT;
  }
}
