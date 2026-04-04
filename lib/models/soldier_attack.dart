/// One attack **presentation** per soldier; the design gallery loops this upward (−Y).
enum SoldierAttackMode {
  railNeedle,
  twinRail,
  triSpread,
  pulseWave,
  plasmaBolt,
  sustainedBeam,
  burstShards,
  sweepBeam,
  helixBurst,
  lanceCharge,
  pelletStorm,
  sineWaver,
  overchargeCone,
  needleSalvo,
  /// Solid blade arc (fill + black outline), not a glow beam.
  swordSwipe,
  /// No upward VFX — attack read from soldier part motion only.
  none,
}

/// Describes how this soldier attacks (single mode); used in the design preview animation.
class SoldierAttackSpec {
  const SoldierAttackSpec({
    required this.mode,
    required this.label,
    this.nominalAttacksPerSecond,
  });

  /// Design-dialog preview loop length (seconds); matches default [AnimationController] duration.
  static const double kPreviewCycleSeconds = 1.4;

  final SoldierAttackMode mode;
  /// Short name shown under the card (e.g. "Twin rail").
  final String label;
  /// Reference strikes per second for UI (e.g. dialog). When null, uses `1 / [kPreviewCycleSeconds]`.
  final double? nominalAttacksPerSecond;

  double get displayAttacksPerSecond =>
      nominalAttacksPerSecond ?? (1.0 / kPreviewCycleSeconds);
}
