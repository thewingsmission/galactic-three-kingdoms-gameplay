import 'package:flutter/material.dart';

import '../models/soldier_design.dart';
import '../models/soldier_design_palette.dart';
import '../models/soldier_rarity.dart';
import 'soldier_attack_preview_column.dart';
import 'soldier_design_catalog.dart';

/// Larger silhouette + looping **upward** attack preview for the design gallery.
class SoldierDesignPreviewCard extends StatefulWidget {
  const SoldierDesignPreviewCard({
    super.key,
    required this.design,
    required this.rarity,
    this.palette = SoldierDesignPalette.yellow,
  });

  final SoldierDesign design;
  final SoldierRarity rarity;
  final SoldierDesignPalette palette;

  @override
  State<SoldierDesignPreviewCard> createState() => _SoldierDesignPreviewCardState();
}

class _SoldierDesignPreviewCardState extends State<SoldierDesignPreviewCard>
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
    final SoldierRarity r = widget.rarity;
    final Color accent = r.accentColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Expanded(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints c) {
              return Stack(
                clipBehavior: Clip.hardEdge,
                children: <Widget>[
                  AnimatedBuilder(
                    animation: _ctrl,
                    builder: (BuildContext context, Widget? child) {
                      return SoldierAttackPreviewColumn(
                        design: widget.design,
                        palette: widget.palette,
                        motionT: _continuousMotionT,
                        strokeWidth: 2.25,
                        uniformIdleDesigns: kSoldierDesignCatalog,
                      );
                    },
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        r.label,
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
                ],
              );
            },
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              widget.design.name,
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
    );
  }
}
