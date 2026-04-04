import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'soldier_design.dart';
import 'soldier_faction_color_theme.dart';

/// Legacy catalog default stroke (ignored for paint — outlines are always black).
const Color kSoldierDefaultStroke = Color(0xFF3A2F00);

double _channelDist2(Color a, Color b) {
  final double dr = (a.r - b.r) * 255.0;
  final double dg = (a.g - b.g) * 255.0;
  final double db = (a.b - b.b) * 255.0;
  return dr * dr + dg * dg + db * db;
}

/// Closest standard tier **1–5** to [sample] on [reference] ramp.
int nearestTier1Based(Color sample, List<Color> reference) {
  assert(reference.length == 5);
  int best = 1;
  double bestD = 1e18;
  for (int i = 0; i < 5; i++) {
    final double d = _channelDist2(sample, reference[i]);
    if (d < bestD) {
      bestD = d;
      best = i + 1;
    }
  }
  return best;
}

/// Gold-era catalog parts: infer [fillTier] from yellow ramp (stroke arg ignored for painting).
SoldierShapePart partGoldFaction({
  List<Offset>? fillVertices,
  List<Offset>? strokePolyline,
  bool strokeClosed = false,
  required Color fill,
  Color stroke = kSoldierDefaultStroke,
  double strokeWidth = 2.25,
  SoldierPartMotion motion = SoldierPartMotion.none,
  Offset? motionPivot,
  double motionSign = 1.0,
  double motionAmplitudeRad = 0.42,
}) {
  final int ft = nearestTier1Based(fill, kYellowFactionComponentColors);
  return SoldierShapePart(
    fillVertices: fillVertices,
    strokePolyline: strokePolyline,
    strokeClosed: strokeClosed,
    fillTier: ft,
    transparentFill: fill.a < 0.04,
    strokeWidth: strokeWidth,
    motion: motion,
    motionPivot: motionPivot,
    motionSign: motionSign,
    motionAmplitudeRad: motionAmplitudeRad,
  );
}

/// Crimson radial sigils: use [fillTierOverride] **1–5** when set (per-layer variety); else [fill] → nearest red ramp tier.
/// [variant] ignored (kept for callsites).
SoldierShapePart partRadialSigil({
  required int variant,
  List<Offset>? fillVertices,
  List<Offset>? strokePolyline,
  bool strokeClosed = false,
  required Color fill,
  int? fillTierOverride,
  Color stroke = Colors.black,
  double strokeWidth = 2.25,
  SoldierPartMotion motion = SoldierPartMotion.none,
  Offset? motionPivot,
  double motionSign = 1.0,
  double motionAmplitudeRad = 0.42,
}) {
  assert(
    fillTierOverride == null ||
        (fillTierOverride >= 1 && fillTierOverride <= 5),
  );
  final int ft =
      fillTierOverride ?? nearestTier1Based(fill, kRedFactionComponentColors);
  return SoldierShapePart(
    fillVertices: fillVertices,
    strokePolyline: strokePolyline,
    strokeClosed: strokeClosed,
    fillTier: ft,
    transparentFill: fill.a < 0.04,
    strokeWidth: strokeWidth,
    motion: motion,
    motionPivot: motionPivot,
    motionSign: motionSign,
    motionAmplitudeRad: motionAmplitudeRad,
  );
}

/// Procedural hull: tier from [seed] so shapes differ; same index for red/yellow/blue.
SoldierShapePart partProceduralHull({
  required List<Offset> fillVertices,
  required int seed,
  required int tierBand,
  double strokeWidth = 2.25,
}) {
  final int t = ((seed.abs() + tierBand * 17) % 5) + 1;
  return SoldierShapePart(
    fillVertices: fillVertices,
    fillTier: t,
    strokeWidth: strokeWidth,
  );
}

SoldierShapePart partProceduralHullAlpha({
  required List<Offset> fillVertices,
  required int seed,
  required int tierBand,
  required double alpha,
  double strokeWidth = 2.25,
}) {
  final int base = ((seed.abs() + tierBand * 17) % 5) + 1;
  final int t = alpha < 0.98 ? math.min(5, base + 1) : base;
  return SoldierShapePart(
    fillVertices: fillVertices,
    fillTier: t,
    strokeWidth: strokeWidth,
  );
}
