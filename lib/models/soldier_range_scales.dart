/// Range disk radii relative to **contact** radius (fallback for soldiers without a design).
/// Attack = contact × 3.
const double kSoldierAttackRangeRadiusScale = 3;

/// Universal detection radius in **model units** — same for every soldier regardless of design.
/// The war scene converts this to world units via the soldier's fit scale.
const double kSoldierDetectionRadiusModelUnits = 400;

/// Target zone radius = detection radius × this scale.
const double kSoldierTargetZoneScale = 1.5;
