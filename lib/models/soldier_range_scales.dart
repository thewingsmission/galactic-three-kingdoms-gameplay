/// Range disk radii relative to **contact** radius — same as [CohortWarGame] / triangle soldier.
/// Attack = contact × 3; detection = contact × 21 (attack × 7).
const double kSoldierAttackRangeRadiusScale = 3;
const double kSoldierDetectionRangeRadiusScale =
    kSoldierAttackRangeRadiusScale * 7;
