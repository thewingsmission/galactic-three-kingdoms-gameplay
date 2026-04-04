import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/soldier_attack.dart';

/// Draws one looping **upward** attack visualization (−Y in canvas = toward top of this rect).
///
/// When [effectScale] and [soldierModelHeight] are set (from [MultiPolygonSoldierPainter.layoutMetrics]),
/// stroke offsets match the soldier’s on-screen fit scale and sword-like attacks cap length so
/// wide popups match the draft grid card.
/// Otherwise sizes follow [min(width,height)] (legacy).
/// [t] ∈ [0,1) advances over time; call from repeating animation.
class UpwardAttackPainter extends CustomPainter {
  UpwardAttackPainter({
    required this.mode,
    required this.t,
    required this.accentColor,
    this.effectScale,
    this.soldierModelHeight,
  });

  final SoldierAttackMode mode;
  final double t;
  final Color accentColor;
  /// Pixels-per-model-unit for VFX; aligns with soldier [MultiPolygonSoldierPainter] fit scale.
  final double? effectScale;
  /// Model-space height of soldier bbox (for capping blade length vs width-limited fit).
  final double? soldierModelHeight;

  static final Paint _glow = Paint()..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double cx = w / 2;
    final double originY = h * 0.92;
    final double topY = h * 0.06;
    final double phase = t * math.pi * 2;

    final double layoutScale = effectScale != null
        ? effectScale!.clamp(0.22, 2.15)
        : (math.min(w, h) / 110.0).clamp(0.48, 2.05);
    double sc(double v) => v * layoutScale;

    void beamLine(double x0, double x1, double width, double opacity) {
      final double sw = sc(width);
      _glow
        ..color = accentColor.withValues(alpha: opacity)
        ..strokeWidth = sw
        ..style = PaintingStyle.stroke
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, sw * 0.35);
      canvas.drawLine(Offset(x0, originY), Offset(x1, topY), _glow);
      _glow.maskFilter = null;
      _glow.strokeWidth = math.max(sc(1), sw * 0.45);
      _glow.color = Colors.white.withValues(alpha: opacity * 0.85);
      canvas.drawLine(Offset(x0, originY), Offset(x1, topY), _glow);
    }

    switch (mode) {
      case SoldierAttackMode.railNeedle:
        final double pulse = 0.45 + 0.55 * (0.5 + 0.5 * math.sin(phase));
        beamLine(cx, cx, 2.2, pulse);
        break;

      case SoldierAttackMode.twinRail:
        final double o = 0.5 + 0.5 * math.sin(phase * 1.3);
        final double off = sc(7);
        beamLine(cx - off, cx - off, 2, o);
        beamLine(cx + off, cx + off, 2, o);
        break;

      case SoldierAttackMode.triSpread:
        final double spread = 0.08 * math.sin(phase);
        for (final double dx in <double>[-10 + spread * 60, 0, 10 - spread * 60]) {
          beamLine(cx + sc(dx), cx + sc(dx * 0.85), 1.6, 0.55);
        }
        break;

      case SoldierAttackMode.pulseWave:
        for (int i = 0; i < 3; i++) {
          final double u = (t + i / 3) % 1.0;
          final double y = originY - u * (originY - topY);
          final double op = (1 - u) * 0.55;
          final Paint p = Paint()
            ..color = accentColor.withValues(alpha: op)
            ..style = PaintingStyle.stroke
            ..strokeWidth = sc(3);
          canvas.drawLine(Offset(cx - sc(18), y), Offset(cx + sc(18), y), p);
        }
        break;

      case SoldierAttackMode.plasmaBolt:
        final double u = t;
        final double y = originY - u * (originY - topY);
        final Paint p = Paint()..color = accentColor.withValues(alpha: 0.75);
        canvas.drawCircle(Offset(cx, y), sc(5 + 3 * math.sin(phase * 3)), p);
        canvas.drawCircle(
          Offset(cx, y),
          sc(9),
          Paint()
            ..color = accentColor.withValues(alpha: 0.25)
            ..style = PaintingStyle.stroke
            ..strokeWidth = sc(2),
        );
        break;

      case SoldierAttackMode.sustainedBeam:
        beamLine(cx, cx, 5 + 4 * math.sin(phase), 0.55);
        break;

      case SoldierAttackMode.burstShards:
        for (int i = 0; i < 5; i++) {
          final double u = (t * 1.4 + i * 0.18) % 1.0;
          final double y = originY - u * (originY - topY);
          final double x = cx + sc((i - 2) * 5.0);
          final Paint p = Paint()..color = accentColor.withValues(alpha: 0.7 * (1 - u));
          canvas.drawRect(
            Rect.fromCenter(center: Offset(x, y), width: sc(3), height: sc(8)),
            p,
          );
        }
        break;

      case SoldierAttackMode.sweepBeam:
        final double sweep = sc(14 * math.sin(phase * 0.8));
        beamLine(cx + sweep, cx + sweep * 0.9, 3, 0.5);
        break;

      case SoldierAttackMode.helixBurst:
        for (int i = 0; i < 6; i++) {
          final double u = (t + i / 6) % 1.0;
          final double y = originY - u * (originY - topY);
          final double x = cx + sc(10 * math.sin(phase + i));
          canvas.drawCircle(
            Offset(x, y),
            sc(2.5),
            Paint()..color = accentColor.withValues(alpha: 0.65 * (1 - u * 0.5)),
          );
        }
        break;

      case SoldierAttackMode.lanceCharge:
        final double len = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(phase * 1.7));
        final double y1 = originY - len * (originY - topY);
        _glow
          ..color = accentColor.withValues(alpha: 0.75)
          ..strokeWidth = sc(4)
          ..style = PaintingStyle.stroke;
        canvas.drawLine(Offset(cx, originY), Offset(cx, y1), _glow);
        break;

      case SoldierAttackMode.pelletStorm:
        for (int i = 0; i < 12; i++) {
          final double u = (t * 1.2 + i * 0.07) % 1.0;
          final double y = originY - u * (originY - topY);
          final double x = cx + sc(18 * math.sin(phase * 1.1 + i * 0.9));
          canvas.drawCircle(
            Offset(x, y),
            sc(1.8),
            Paint()..color = accentColor.withValues(alpha: 0.55 * (1 - u)),
          );
        }
        break;

      case SoldierAttackMode.sineWaver:
        final Path path = Path()..moveTo(cx, originY);
        final double step = math.max(2.0, sc(4));
        for (double y = originY; y >= topY; y -= step) {
          final double x = cx + sc(12 * math.sin((originY - y) * 0.08 + phase * 2));
          path.lineTo(x, y);
        }
        canvas.drawPath(
          path,
          Paint()
            ..color = accentColor.withValues(alpha: 0.65)
            ..style = PaintingStyle.stroke
            ..strokeWidth = sc(2.5),
        );
        break;

      case SoldierAttackMode.overchargeCone:
        final double halfW = sc(22);
        final Path cone = Path()
          ..moveTo(cx - halfW, originY)
          ..lineTo(cx, topY)
          ..lineTo(cx + halfW, originY)
          ..close();
        canvas.drawPath(
          cone,
          Paint()
            ..color = accentColor.withValues(alpha: 0.18 + 0.12 * math.sin(phase))
            ..style = PaintingStyle.fill,
        );
        beamLine(cx, cx, 4, 0.45);
        break;

      case SoldierAttackMode.needleSalvo:
        for (int i = 0; i < 8; i++) {
          final double u = (t * 2.2 + i * 0.11) % 1.0;
          final double y = originY - u * (originY - topY);
          final double x = cx + sc((i - 3.5) * 4);
          canvas.drawLine(
            Offset(x, y + sc(6)),
            Offset(x, y - sc(2)),
            Paint()
              ..color = accentColor.withValues(alpha: 0.75 * (1 - u))
              ..strokeWidth = sc(1.5),
          );
        }
        break;

      case SoldierAttackMode.none:
        break;

      case SoldierAttackMode.swordSwipe:
        final double rawBlade = (originY - topY) * 0.52;
        final double capLen = (effectScale != null && soldierModelHeight != null)
            ? effectScale! * soldierModelHeight! * 0.42
            : double.infinity;
        final double bladeLen = math.min(rawBlade, capLen);
        final double swing = math.sin(phase * 1.12);
        final double angle = -math.pi * 0.38 + swing * math.pi * 0.5;
        final double hw = sc(5.5);
        final double tip = sc(4.5);
        canvas.save();
        canvas.translate(cx, originY - sc(2));
        canvas.rotate(angle);
        final Path blade = Path()
          ..moveTo(-hw, sc(2))
          ..lineTo(hw, sc(2))
          ..lineTo(tip, -bladeLen)
          ..lineTo(-tip, -bladeLen)
          ..close();
        final Paint fill = Paint()
          ..color = accentColor.withValues(alpha: 0.96)
          ..style = PaintingStyle.fill;
        final Paint outline = Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = sc(1.3)
          ..strokeJoin = StrokeJoin.round;
        canvas.drawPath(blade, fill);
        canvas.drawPath(blade, outline);
        canvas.restore();
        break;
    }
  }

  @override
  bool shouldRepaint(covariant UpwardAttackPainter oldDelegate) {
    return oldDelegate.mode != mode ||
        oldDelegate.t != t ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.effectScale != effectScale ||
        oldDelegate.soldierModelHeight != soldierModelHeight;
  }
}
