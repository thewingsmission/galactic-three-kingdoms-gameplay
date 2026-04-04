import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Absolute **model** coordinates for rulers and tap readout: same frame as
/// [MultiPolygonSoldierPainter] with [fixedModelAnchor].
///
/// Plot pixel **p** (origin top-left of plot):  
/// `model = stableModelAnchor + (p - plotCenter) / sigma`.
@immutable
class ModelPlotRulerCoords {
  const ModelPlotRulerCoords({
    required this.plotCenter,
    required this.stableModelAnchor,
    required this.sigma,
  });

  final Offset plotCenter;
  final Offset stableModelAnchor;
  final double sigma;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModelPlotRulerCoords &&
          plotCenter == other.plotCenter &&
          stableModelAnchor == other.stableModelAnchor &&
          sigma == other.sigma;

  @override
  int get hashCode => Object.hash(plotCenter, stableModelAnchor, sigma);
}

/// L-shaped rulers: **Y** down the left, **X** along the bottom. Inset [child] so rings/soldier
/// align with ruler coordinates.
///
/// Prefer [modelPlotCoords] for the soldier Range panel: tick labels are **absolute** model
/// values (vertices / [SoldierDesign.rangePlotHubModel]).
///
/// Legacy: when [modelPlotCoords] is null and [labelOriginX] / [labelOriginY] are set:
/// - If [rulerSigma] is **null**, ticks are every 10 **screen pixels**.
/// - If [rulerSigma] is set, ticks are every 10 **model units** offset from that pixel origin.
class PixelRulersFrame extends StatelessWidget {
  const PixelRulersFrame({
    super.key,
    required this.child,
    this.thickness = kDefaultThickness,
    this.modelPlotCoords,
    this.labelOriginX,
    this.labelOriginY,
    this.rulerSigma,
  });

  /// Match this when sizing the plot area beside the frame (e.g. ring/soldier scale).
  static const double kDefaultThickness = 28;

  final Widget child;
  final double thickness;
  /// When set, rulers use **absolute** model coordinates (see [ModelPlotRulerCoords]).
  final ModelPlotRulerCoords? modelPlotCoords;
  /// Plot X pixel where horizontal ruler reads **0**; null = left edge (legacy).
  final double? labelOriginX;
  /// Plot Y pixel (downward) where vertical ruler reads **0**; null = legacy top=0.
  final double? labelOriginY;
  /// When non-null with [labelOriginX]/[labelOriginY], tick spacing uses **model units**
  /// (same scale as soldier painting: screen delta = model delta × [rulerSigma]).
  final double? rulerSigma;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final double L = thickness;
        final double plotW = math.max(0, c.maxWidth - L);
        final double plotH = math.max(0, c.maxHeight - L);
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: <Widget>[
            Positioned(
              left: L,
              top: 0,
              width: plotW,
              height: plotH,
              child: child,
            ),
            Positioned(
              left: 0,
              top: 0,
              width: L,
              height: plotH,
              child: CustomPaint(
                painter: _VerticalRulerPainter(
                  extentPx: plotH,
                  modelPlotCoords: modelPlotCoords,
                  labelOriginY: labelOriginY,
                  rulerSigma: rulerSigma,
                ),
                size: Size(L, plotH),
              ),
            ),
            Positioned(
              left: L,
              bottom: 0,
              width: plotW,
              height: L,
              child: CustomPaint(
                painter: _HorizontalRulerPainter(
                  extentPx: plotW,
                  modelPlotCoords: modelPlotCoords,
                  labelOriginX: labelOriginX,
                  rulerSigma: rulerSigma,
                ),
                size: Size(plotW, L),
              ),
            ),
            Positioned(
              left: 0,
              bottom: 0,
              width: L,
              height: L,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  border: Border.all(color: Colors.white24),
                ),
                child: Center(
                  child: Text(
                    modelPlotCoords != null || rulerSigma != null ? 'm' : 'px',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 8,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

abstract class _RulerStyle {
  static const Color major = Color(0xFFB0B0B0);
  static const Color minor = Color(0xFF6E6E6E);
  static const Color label = Color(0xFF9E9E9E);
}

/// Horizontal: [modelPlotCoords] absolute model, legacy, or origin-centered.
class _HorizontalRulerPainter extends CustomPainter {
  _HorizontalRulerPainter({
    required this.extentPx,
    this.modelPlotCoords,
    this.labelOriginX,
    this.rulerSigma,
  });

  final double extentPx;
  final ModelPlotRulerCoords? modelPlotCoords;
  final double? labelOriginX;
  final double? rulerSigma;

  static const int _minorStep = 10;
  static const int _majorStep = 50;

  @override
  void paint(Canvas canvas, Size size) {
    final double h = size.height;
    final double w = size.width;
    final Paint minor = Paint()
      ..color = _RulerStyle.minor
      ..strokeWidth = 1;
    final Paint major = Paint()
      ..color = _RulerStyle.major
      ..strokeWidth = 1;

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.black.withValues(alpha: 0.4),
    );

    if (modelPlotCoords != null) {
      final ModelPlotRulerCoords mc = modelPlotCoords!;
      final double sig = mc.sigma;
      if (sig > 1e-9) {
        final double cx = mc.plotCenter.dx;
        final double ax = mc.stableModelAnchor.dx;
        final double mLow = ax + (0 - cx) / sig;
        final double mHigh = ax + (w - cx) / sig;
        final int mMin = (mLow / _minorStep).floor() * _minorStep;
        final int mMax = (mHigh / _minorStep).ceil() * _minorStep;
        for (int M = mMin; M <= mMax; M += _minorStep) {
          final double x = cx + (M - ax) * sig;
          if (x < -0.5 || x > w + 0.5) continue;
          final bool isMajor = M % _majorStep == 0;
          final double tickH = isMajor ? h * 0.55 : h * 0.28;
          canvas.drawLine(
            Offset(x, h),
            Offset(x, h - tickH),
            isMajor ? major : minor,
          );
          if (isMajor) {
            final TextPainter tp = TextPainter(
              text: TextSpan(
                text: '$M',
                style: const TextStyle(
                  color: _RulerStyle.label,
                  fontSize: 8,
                  height: 1,
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout();
            tp.paint(
              canvas,
              Offset(x - tp.width * 0.5, h - tickH - tp.height - 1),
            );
          }
        }
      }
    } else if (labelOriginX != null) {
      final double ox = labelOriginX!;
      final double? sig = rulerSigma;
      if (sig != null && sig > 1e-9) {
        final int mMin =
            (((0 - ox) / sig) / _minorStep).floor() * _minorStep;
        final int mMax =
            (((w - ox) / sig) / _minorStep).ceil() * _minorStep;
        for (int m = mMin; m <= mMax; m += _minorStep) {
          final double x = ox + m * sig;
          if (x < -0.5 || x > w + 0.5) continue;
          final bool isMajor = m % _majorStep == 0;
          final double tickH = isMajor ? h * 0.55 : h * 0.28;
          canvas.drawLine(
            Offset(x, h),
            Offset(x, h - tickH),
            isMajor ? major : minor,
          );
          if (isMajor) {
            final TextPainter tp = TextPainter(
              text: TextSpan(
                text: '$m',
                style: const TextStyle(
                  color: _RulerStyle.label,
                  fontSize: 8,
                  height: 1,
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout();
            tp.paint(
              canvas,
              Offset(x - tp.width * 0.5, h - tickH - tp.height - 1),
            );
          }
        }
      } else {
        final int kMin = ((0 - ox) / _minorStep).floor() * _minorStep;
        final int kMax = ((w - ox) / _minorStep).ceil() * _minorStep;
        for (int k = kMin; k <= kMax; k += _minorStep) {
          final double x = ox + k;
          if (x < -0.5 || x > w + 0.5) continue;
          final bool isMajor = k % _majorStep == 0;
          final double tickH = isMajor ? h * 0.55 : h * 0.28;
          canvas.drawLine(
            Offset(x, h),
            Offset(x, h - tickH),
            isMajor ? major : minor,
          );
          if (isMajor) {
            final TextPainter tp = TextPainter(
              text: TextSpan(
                text: '$k',
                style: const TextStyle(
                  color: _RulerStyle.label,
                  fontSize: 8,
                  height: 1,
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout();
            tp.paint(
              canvas,
              Offset(x - tp.width * 0.5, h - tickH - tp.height - 1),
            );
          }
        }
      }
    } else {
      for (int x = 0; x <= w.ceil(); x += _minorStep) {
        final bool isMajor = x % _majorStep == 0;
        final double tickH = isMajor ? h * 0.55 : h * 0.28;
        canvas.drawLine(
          Offset(x.toDouble(), h),
          Offset(x.toDouble(), h - tickH),
          isMajor ? major : minor,
        );
        if (isMajor && x > 0) {
          final TextPainter tp = TextPainter(
            text: TextSpan(
              text: '$x',
              style: const TextStyle(
                color: _RulerStyle.label,
                fontSize: 8,
                height: 1,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(
            canvas,
            Offset(x.toDouble() - tp.width * 0.5, h - tickH - tp.height - 1),
          );
        }
      }
      _drawSmallLabel(canvas, '0', const Offset(2, 2));
    }
    _drawAxisCaption(canvas, 'X →', Offset(w - 2, 2), right: true);
  }

  void _drawSmallLabel(Canvas canvas, String text, Offset pos) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: _RulerStyle.label,
          fontSize: 7,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos);
  }

  void _drawAxisCaption(Canvas canvas, String text, Offset pos, {bool right = false}) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.35),
          fontSize: 8,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(right ? pos.dx - tp.width : pos.dx, pos.dy));
  }

  @override
  bool shouldRepaint(covariant _HorizontalRulerPainter oldDelegate) {
    return oldDelegate.extentPx != extentPx ||
        oldDelegate.modelPlotCoords != modelPlotCoords ||
        oldDelegate.labelOriginX != labelOriginX ||
        oldDelegate.rulerSigma != rulerSigma;
  }
}

/// Vertical: [modelPlotCoords] absolute model, legacy, or origin-centered.
class _VerticalRulerPainter extends CustomPainter {
  _VerticalRulerPainter({
    required this.extentPx,
    this.modelPlotCoords,
    this.labelOriginY,
    this.rulerSigma,
  });

  final double extentPx;
  final ModelPlotRulerCoords? modelPlotCoords;
  final double? labelOriginY;
  final double? rulerSigma;

  static const int _minorStep = 10;
  static const int _majorStep = 50;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Paint minor = Paint()
      ..color = _RulerStyle.minor
      ..strokeWidth = 1;
    final Paint major = Paint()
      ..color = _RulerStyle.major
      ..strokeWidth = 1;

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.black.withValues(alpha: 0.4),
    );

    if (modelPlotCoords != null) {
      final ModelPlotRulerCoords mc = modelPlotCoords!;
      final double sig = mc.sigma;
      if (sig > 1e-9) {
        final double cy = mc.plotCenter.dy;
        final double ay = mc.stableModelAnchor.dy;
        final double mLow = ay + (0 - cy) / sig;
        final double mHigh = ay + (h - cy) / sig;
        final int mMin = (mLow / _minorStep).floor() * _minorStep;
        final int mMax = (mHigh / _minorStep).ceil() * _minorStep;
        for (int M = mMin; M <= mMax; M += _minorStep) {
          final double y = cy + (M - ay) * sig;
          if (y < -0.5 || y > h + 0.5) continue;
          final bool isMajor = M % _majorStep == 0;
          final double tickW = isMajor ? w * 0.55 : w * 0.28;
          canvas.drawLine(
            Offset(0, y),
            Offset(tickW, y),
            isMajor ? major : minor,
          );
          if (isMajor) {
            _drawRotatedLabel(canvas, '$M', Offset(tickW + 1, y));
          }
        }
      }
      _drawAxisCaptionVertical(canvas, 'Y ↓', Offset(2, h - 10));
    } else if (labelOriginY != null) {
      final double oy = labelOriginY!;
      final double? sig = rulerSigma;
      if (sig != null && sig > 1e-9) {
        final int mMin =
            (((-oy) / sig) / _minorStep).floor() * _minorStep;
        final int mMax =
            (((h - oy) / sig) / _minorStep).ceil() * _minorStep;
        for (int m = mMin; m <= mMax; m += _minorStep) {
          final double y = oy + m * sig;
          if (y < -0.5 || y > h + 0.5) continue;
          final bool isMajor = m % _majorStep == 0;
          final double tickW = isMajor ? w * 0.55 : w * 0.28;
          canvas.drawLine(
            Offset(0, y),
            Offset(tickW, y),
            isMajor ? major : minor,
          );
          if (isMajor) {
            _drawRotatedLabel(canvas, '$m', Offset(tickW + 1, y));
          }
        }
      } else {
        final int kMin = ((-oy) / _minorStep).floor() * _minorStep;
        final int kMax = ((h - oy) / _minorStep).ceil() * _minorStep;
        for (int k = kMin; k <= kMax; k += _minorStep) {
          final double y = oy + k;
          if (y < -0.5 || y > h + 0.5) continue;
          final bool isMajor = k % _majorStep == 0;
          final double tickW = isMajor ? w * 0.55 : w * 0.28;
          canvas.drawLine(
            Offset(0, y),
            Offset(tickW, y),
            isMajor ? major : minor,
          );
          if (isMajor) {
            _drawRotatedLabel(canvas, '$k', Offset(tickW + 1, y));
          }
        }
      }
      _drawAxisCaptionVertical(canvas, 'Y ↓', Offset(2, h - 10));
    } else {
      for (int y = 0; y <= h.ceil(); y += _minorStep) {
        final bool isMajor = y % _majorStep == 0;
        final double tickW = isMajor ? w * 0.55 : w * 0.28;
        canvas.drawLine(
          Offset(0, y.toDouble()),
          Offset(tickW, y.toDouble()),
          isMajor ? major : minor,
        );
        if (isMajor && y > 0) {
          _drawRotatedLabel(canvas, '$y', Offset(tickW + 1, y.toDouble()));
        }
      }
      _drawRotatedLabel(canvas, '0', const Offset(2, 6), small: true);
      _drawAxisCaptionVertical(canvas, 'Y ↓', Offset(2, h - 10));
    }
  }

  void _drawRotatedLabel(
    Canvas canvas,
    String text,
    Offset anchor, {
    bool small = false,
  }) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: _RulerStyle.label,
          fontSize: small ? 7 : 8,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(anchor.dx, anchor.dy);
    canvas.rotate(-math.pi / 2);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height));
    canvas.restore();
  }

  void _drawAxisCaptionVertical(Canvas canvas, String text, Offset pos) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.35),
          fontSize: 8,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(-math.pi / 2);
    tp.paint(canvas, Offset(0, 0));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _VerticalRulerPainter oldDelegate) {
    return oldDelegate.extentPx != extentPx ||
        oldDelegate.modelPlotCoords != modelPlotCoords ||
        oldDelegate.labelOriginY != labelOriginY ||
        oldDelegate.rulerSigma != rulerSigma;
  }
}
