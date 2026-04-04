/// Range disk radii relative to **contact** radius — universal for every soldier (player + enemy).
/// Attack = contact × 3; detection = contact × (attack × 7 × **1.6**) → **60% larger** than base 21×.
const double kSoldierAttackRangeRadiusScale = 3;
const double kSoldierDetectionRangeRadiusScale =
    kSoldierAttackRangeRadiusScale * 7 * 1.6;
