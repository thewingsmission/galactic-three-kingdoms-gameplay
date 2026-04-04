import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/soldier_attack.dart';
import '../models/soldier_design.dart';
import '../models/soldier_design_combat_metrics.dart';
import '../models/soldier_design_palette.dart';
import '../models/soldier_rarity.dart';
import 'multi_polygon_soldier_painter.dart';
import 'pixel_rulers_frame.dart';
import 'soldier_attack_preview_column.dart';
import 'soldier_design_catalog.dart';
import 'soldier_idle_uniform_scale.dart';
import 'soldier_range_rings_painter.dart';

/// Almost full-screen dialog: **left** idle · **middle** attack · **right** range rings.
Future<void> showSoldierDesignDetailDialog({
  required BuildContext context,
  required SoldierDesign design,
  required SoldierRarity rarity,
  required SoldierDesignPalette palette,
  ValueChanged<SoldierDesignPalette>? onPaletteChanged,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (BuildContext context) => _SoldierDesignDetailDialogBody(
      design: design,
      rarity: rarity,
      palette: palette,
      onPaletteChanged: onPaletteChanged,
    ),
  );
}

class _SoldierDesignDetailDialogBody extends StatefulWidget {
  const _SoldierDesignDetailDialogBody({
    required this.design,
    required this.rarity,
    required this.palette,
    this.onPaletteChanged,
  });

  final SoldierDesign design;
  final SoldierRarity rarity;
  final SoldierDesignPalette palette;
  final ValueChanged<SoldierDesignPalette>? onPaletteChanged;

  @override
  State<_SoldierDesignDetailDialogBody> createState() =>
      _SoldierDesignDetailDialogBodyState();
}

class _SoldierDesignDetailDialogBodyState extends State<_SoldierDesignDetailDialogBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _attackCtrl;
  late SoldierDesignPalette _palette;
  /// Range plot position in ruler coords (shown next to panel title on touch).
  String? _rangesPlotCoord;

  List<SoldierShapePart> get _parts => widget.design.parts;

  /// Idle motion (wings / ears) — [SoldierPartMotion.attackProbeExtend] is attack column only.
  bool get _hasIdlePartMotion => _parts.any(
        (SoldierShapePart p) =>
            p.motion == SoldierPartMotion.wingFlap ||
            p.motion == SoldierPartMotion.earSwing,
      );

  /// Same stable model point as [SoldierAttackPreviewColumn] (probe pose) for range rings.
  Offset get _rangeStableModelAnchor => MultiPolygonSoldierPainter.modelBboxCenter(
        parts: _parts,
        motionT: 0.25,
        attackCycleT: MultiPolygonSoldierPainter.kAttackProbeBoundsPhase,
      );

  @override
  void initState() {
    super.initState();
    _palette = widget.palette;
    _attackCtrl = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds:
            (SoldierAttackSpec.kPreviewCycleSeconds * 1000).round(),
      ),
    )..repeat();
  }

  @override
  void dispose() {
    _attackCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _SoldierDesignDetailDialogBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.palette != widget.palette) {
      _palette = widget.palette;
    }
  }

  void _setPalette(SoldierDesignPalette next) {
    if (_palette == next) return;
    setState(() => _palette = next);
    widget.onPaletteChanged?.call(next);
  }

  void _updateRangesPlotCoord(
    Offset local,
    double plotW,
    double plotH,
    Offset plotCenter,
    Offset stableModelAnchor,
    double sigma,
  ) {
    final double L = PixelRulersFrame.kDefaultThickness;
    if (local.dx < L ||
        local.dx >= L + plotW ||
        local.dy < 0 ||
        local.dy >= plotH) {
      return;
    }
    if (sigma <= 1e-9) return;
    final double px = local.dx - L;
    final double py = local.dy;
    final double mx =
        stableModelAnchor.dx + (px - plotCenter.dx) / sigma;
    final double my =
        stableModelAnchor.dy + (py - plotCenter.dy) / sigma;
    final String next =
        '(${mx.toStringAsFixed(1)}, ${my.toStringAsFixed(1)})';
    if (_rangesPlotCoord == next) return;
    setState(() => _rangesPlotCoord = next);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color accent = widget.rarity.accentColor;
    final double cr = combatContactRadiusWorld(_parts);
    final Size mq = MediaQuery.sizeOf(context);
    final ({double width, double height}) modelBb =
        MultiPolygonSoldierPainter.modelBoundingSize(
      parts: _parts,
      motionT: 0.25,
      attackCycleT: MultiPolygonSoldierPainter.kAttackProbeBoundsPhase,
    );
    final SoldierDesignCombatSnapshot combat =
        soldierDesignCombatSnapshot(widget.design);
    final TextStyle statsStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.45),
      fontSize: 9,
      height: 1.25,
    );
    final String statsInline =
        '${modelBb.width.toStringAsFixed(1)}×${modelBb.height.toStringAsFixed(1)} · '
        '${combat.contactZoneLabel} · '
        'contact area ${combat.contactZoneAreaModel.toStringAsFixed(0)} · '
        'attack area ${combat.attackZoneAreaModel.toStringAsFixed(0)} · '
        'atk r${combat.attackZoneRadiusModel.toStringAsFixed(1)} · '
        'det r${combat.detectionZoneRadiusModel.toStringAsFixed(1)} · '
        '${combat.attacksPerSecond.toStringAsFixed(2)}/s';

    return Dialog(
      insetPadding: const EdgeInsets.all(10),
      backgroundColor: const Color(0xFF121018),
      child: SizedBox(
        width: mq.width - 20,
        height: mq.height * 0.92,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 4, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              widget.design.name,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                statsInline,
                                style: statsStyle,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${widget.design.attack.label} · ${_paletteLabel(_palette)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: accent,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: SegmentedButton<SoldierDesignPalette>(
                            style: SegmentedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 4,
                              ),
                            ),
                            showSelectedIcon: false,
                            segments: const <ButtonSegment<SoldierDesignPalette>>[
                              ButtonSegment<SoldierDesignPalette>(
                                value: SoldierDesignPalette.red,
                                label: Text('Red', style: TextStyle(fontSize: 12)),
                                icon: Icon(Icons.circle, size: 10, color: Color(0xFFE57373)),
                              ),
                              ButtonSegment<SoldierDesignPalette>(
                                value: SoldierDesignPalette.yellow,
                                label: Text('Yellow', style: TextStyle(fontSize: 12)),
                                icon: Icon(Icons.circle, size: 10, color: Color(0xFFFFC107)),
                              ),
                              ButtonSegment<SoldierDesignPalette>(
                                value: SoldierDesignPalette.blue,
                                label: Text('Blue', style: TextStyle(fontSize: 12)),
                                icon: Icon(Icons.circle, size: 10, color: Color(0xFF64B5F6)),
                              ),
                            ],
                            selected: <SoldierDesignPalette>{_palette},
                            onSelectionChanged: (Set<SoldierDesignPalette> next) {
                              _setPalette(next.first);
                            },
                            multiSelectionEnabled: false,
                            emptySelectionAllowed: false,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white70, size: 28),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white24),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    flex: 4,
                    child: _panel(
                      theme,
                      title: 'Idle',
                      innerPadding:
                          const EdgeInsets.fromLTRB(10, 8, 10, 2),
                      child: LayoutBuilder(
                        builder:
                            (BuildContext context, BoxConstraints c) {
                          final double sigma =
                              soldierIdleUniformWorldToPixel(
                            Size(c.maxWidth, c.maxHeight),
                            kSoldierDesignCatalog,
                          );
                          final Offset idleAnchor = _rangeStableModelAnchor;
                          return ClipRect(
                            child: _hasIdlePartMotion
                                ? AnimatedBuilder(
                                    animation: _attackCtrl,
                                    builder: (BuildContext context,
                                        Widget? child) {
                                      return CustomPaint(
                                        painter: MultiPolygonSoldierPainter(
                                          parts: _parts,
                                          displayPalette: _palette,
                                          strokeWidth: 2.25,
                                          motionT: _attackCtrl.value,
                                          uniformWorldScale: sigma,
                                          fixedModelAnchor: idleAnchor,
                                          paintCrownFlames:
                                              widget.design.paintCrownFlames,
                                        ),
                                      );
                                    },
                                  )
                                : CustomPaint(
                                    painter: MultiPolygonSoldierPainter(
                                      parts: _parts,
                                      displayPalette: _palette,
                                      strokeWidth: 2.25,
                                      motionT: 0,
                                      uniformWorldScale: sigma,
                                      fixedModelAnchor: idleAnchor,
                                      paintCrownFlames:
                                          widget.design.paintCrownFlames,
                                    ),
                                  ),
                          );
                        },
                      ),
                    ),
                  ),
                  const VerticalDivider(width: 1, color: Colors.white24),
                  Expanded(
                    flex: 4,
                    child: _panel(
                      theme,
                      title: 'Attack',
                      innerPadding:
                          const EdgeInsets.fromLTRB(10, 8, 10, 2),
                      child: AnimatedBuilder(
                        animation: _attackCtrl,
                        builder: (BuildContext context, Widget? child) {
                          return SoldierAttackPreviewColumn(
                            design: widget.design,
                            palette: _palette,
                            motionT: _attackCtrl.value,
                            strokeWidth: 2.25,
                            uniformIdleDesigns: kSoldierDesignCatalog,
                          );
                        },
                      ),
                    ),
                  ),
                  const VerticalDivider(width: 1, color: Colors.white24),
                  Expanded(
                    flex: 5,
                    child: _panel(
                      theme,
                      title: 'Range',
                      innerPadding:
                          const EdgeInsets.fromLTRB(10, 8, 10, 2),
                      titleSuffix: _rangesPlotCoord == null
                          ? null
                          : Text(
                              _rangesPlotCoord!,
                              style: theme.textTheme.labelLarge
                                  ?.copyWith(
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'monospace',
                                fontSize: 13,
                              ),
                            ),
                      child: LayoutBuilder(
                        builder:
                            (BuildContext context, BoxConstraints c) {
                          final double rulerL =
                              PixelRulersFrame.kDefaultThickness;
                          final double plotW =
                              math.max(0, c.maxWidth - rulerL);
                          final double plotH =
                              math.max(0, c.maxHeight - rulerL);
                          final Size plotSz = Size(plotW, plotH);
                          final double sigma =
                              soldierIdleUniformWorldToPixel(
                            plotSz,
                            kSoldierDesignCatalog,
                          );
                          final Offset rangeStableAnchor =
                              _rangeStableModelAnchor;
                          final Offset rangePlotCenter =
                              Offset(plotW / 2, plotH / 2);
                          final ModelPlotRulerCoords rangeModelRuler =
                              ModelPlotRulerCoords(
                            plotCenter: rangePlotCenter,
                            stableModelAnchor: rangeStableAnchor,
                            sigma: sigma,
                          );
                          Widget rangeStack(double motionT, double attackT) {
                            return Stack(
                              fit: StackFit.expand,
                              clipBehavior: Clip.hardEdge,
                              children: <Widget>[
                                CustomPaint(
                                  painter: MultiPolygonSoldierPainter(
                                    parts: _parts,
                                    displayPalette: _palette,
                                    strokeWidth: 2.25,
                                    motionT: motionT,
                                    attackCycleT: attackT,
                                    uniformWorldScale: sigma,
                                    fixedModelAnchor: rangeStableAnchor,
                                    paintCrownFlames:
                                        widget.design.paintCrownFlames,
                                  ),
                                ),
                                CustomPaint(
                                  painter: SoldierRangeRingsPainter(
                                    contactRadius: cr,
                                    detailParts: _parts,
                                    detailMotionT: motionT,
                                    detailAttackCycleT: attackT,
                                    detailUniformSigma: sigma,
                                    detailStableModelAnchor:
                                        rangeStableAnchor,
                                    detailRangePlotHubModel:
                                        widget.design.rangePlotHubModel,
                                  ),
                                ),
                              ],
                            );
                          }

                          return AnimatedBuilder(
                            animation: _attackCtrl,
                            builder:
                                (BuildContext context, Widget? child) {
                              final double t = _attackCtrl.value;
                              return Listener(
                                behavior: HitTestBehavior.opaque,
                                onPointerDown: (PointerDownEvent e) {
                                  _updateRangesPlotCoord(
                                    e.localPosition,
                                    plotW,
                                    plotH,
                                    rangePlotCenter,
                                    rangeStableAnchor,
                                    sigma,
                                  );
                                },
                                onPointerMove: (PointerMoveEvent e) {
                                  _updateRangesPlotCoord(
                                    e.localPosition,
                                    plotW,
                                    plotH,
                                    rangePlotCenter,
                                    rangeStableAnchor,
                                    sigma,
                                  );
                                },
                                child: PixelRulersFrame(
                                  thickness: rulerL,
                                  modelPlotCoords: rangeModelRuler,
                                  child: rangeStack(t, t),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _panel(
    ThemeData theme, {
    required String title,
    Widget? titleSuffix,
    EdgeInsetsGeometry innerPadding = const EdgeInsets.all(10),
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                title,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: const Color(0xFFFFC107),
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (titleSuffix != null) ...<Widget>[
                const SizedBox(width: 10),
                Flexible(child: titleSuffix),
              ],
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: innerPadding,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: child,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _paletteLabel(SoldierDesignPalette p) {
    return switch (p) {
      SoldierDesignPalette.red => 'Red scheme',
      SoldierDesignPalette.yellow => 'Yellow scheme',
      SoldierDesignPalette.blue => 'Blue scheme',
    };
  }
}
