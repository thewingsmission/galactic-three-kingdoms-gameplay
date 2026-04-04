import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/soldier_attack.dart';
import '../models/soldier_design.dart';
import '../models/soldier_design_palette.dart';
import 'multi_polygon_soldier_painter.dart';
import 'soldier_idle_uniform_scale.dart';
import 'upward_attack_painter.dart';

/// Attack column preview: optional VFX band + soldier; [SoldierAttackMode.none] uses full height.
/// Attack painter uses [MultiPolygonSoldierPainter.layoutMetrics] so effects match soldier size
/// in narrow columns (e.g. detail popup).
///
/// When [uniformIdleDesigns] is set, the soldier uses [soldierIdleUniformWorldToPixel] so all
/// designs share the same model→pixel scale in the soldier strip (draft / validated grid).
///
/// [layoutMetrics] uses a **fixed** wing phase and full probe extent so fit scale does not pulse
/// each frame while wings flap (soldier stays constant size in the attack column).
class SoldierAttackPreviewColumn extends StatelessWidget {
  const SoldierAttackPreviewColumn({
    super.key,
    required this.design,
    required this.palette,
    required this.motionT,
    this.strokeWidth = 2.25,
    this.uniformIdleDesigns,
    /// Caps soldier scale (e.g. match **Idle** column catalog σ); null = no extra cap.
    this.maxUniformWorldToPixel,
    /// Pins this model point to the soldier canvas center; null = bbox centroid.
    this.fixedModelAnchor,
    /// Vertical offset for the whole column (e.g. popup framing); 0 = none.
    this.verticalPaintNudge = 0,
  });

  final SoldierDesign design;
  final SoldierDesignPalette palette;
  final double motionT;
  final double strokeWidth;
  /// When non-null, soldier row uses uniform idle scale across this design set.
  final Iterable<SoldierDesign>? uniformIdleDesigns;
  final double? maxUniformWorldToPixel;
  final Offset? fixedModelAnchor;
  final double verticalPaintNudge;

  @override
  Widget build(BuildContext context) {
    final List<SoldierShapePart> parts = design.parts;
    final Color attackAccent = palette.attackAccent;
    final bool showAttackVfx = design.attack.mode != SoldierAttackMode.none;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final double h = c.maxHeight;
        final double w = c.maxWidth;
        final double attackH = showAttackVfx ? h * 0.34 : 0;
        final double soldierH = math.max(1.0, h - attackH);
        final metrics = MultiPolygonSoldierPainter.layoutMetrics(
          parts: parts,
          soldierCanvasSize: Size(w, soldierH),
          motionT: 0.25,
          attackCycleT: MultiPolygonSoldierPainter.kAttackProbeBoundsPhase,
        );
        double lockedWorldToPixel = uniformIdleDesigns != null
            ? soldierIdleUniformWorldToPixel(
                Size(w, soldierH),
                uniformIdleDesigns!,
              )
            : metrics.fitScale;
        if (maxUniformWorldToPixel != null) {
          lockedWorldToPixel =
              math.min(lockedWorldToPixel, maxUniformWorldToPixel!);
        }
        final Offset stableAnchor = fixedModelAnchor ??
            MultiPolygonSoldierPainter.modelBboxCenter(
              parts: parts,
              motionT: 0.25,
              attackCycleT: MultiPolygonSoldierPainter.kAttackProbeBoundsPhase,
            );

        Widget column = Column(
          mainAxisSize: MainAxisSize.max,
          children: <Widget>[
            if (attackH > 0)
              SizedBox(
                height: attackH,
                width: double.infinity,
                child: CustomPaint(
                  painter: UpwardAttackPainter(
                    mode: design.attack.mode,
                    t: motionT,
                    accentColor: attackAccent,
                    effectScale: lockedWorldToPixel,
                    soldierModelHeight: metrics.modelHeight,
                  ),
                ),
              ),
            Expanded(
              child: ClipRect(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 1),
                  child: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints inner) {
                      return CustomPaint(
                        size: Size(inner.maxWidth, inner.maxHeight),
                        painter: MultiPolygonSoldierPainter(
                          parts: parts,
                          displayPalette: palette,
                          strokeWidth: strokeWidth,
                          motionT: motionT,
                          attackCycleT: motionT,
                          uniformWorldScale: lockedWorldToPixel,
                          fixedModelAnchor: stableAnchor,
                          paintCrownFlames: design.paintCrownFlames,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        );
        if (verticalPaintNudge != 0) {
          column = Transform.translate(
            offset: Offset(0, verticalPaintNudge),
            child: column,
          );
        }
        return column;
      },
    );
  }
}
