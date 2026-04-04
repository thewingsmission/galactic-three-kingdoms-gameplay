import 'package:flutter/material.dart';

import 'soldier_design.dart';
import 'soldier_design_palette.dart';

/// Single soldier type for the warm-up.
enum SoldierType { triangle }

/// One deployed unit with formation offset in cohort space (screen coords: +x right, +y down).
/// Default cohort forward is `(0, -1)` (up on screen); rotation is applied around cohort center.
class PlacedSoldier {
  PlacedSoldier({
    required this.inventoryIndex,
    required this.type,
    required this.localOffset,
    this.soldierDesign,
    this.cohortPalette = SoldierDesignPalette.yellow,
  });

  final int inventoryIndex;
  final SoldierType type;
  Offset localOffset;
  /// When set, war + inventory use this [SoldierDesign] (polygon + contact hull).
  final SoldierDesign? soldierDesign;
  final SoldierDesignPalette cohortPalette;

  PlacedSoldier copyWith({Offset? localOffset}) {
    return PlacedSoldier(
      inventoryIndex: inventoryIndex,
      type: type,
      localOffset: localOffset ?? this.localOffset,
      soldierDesign: soldierDesign,
      cohortPalette: cohortPalette,
    );
  }
}

/// Snapshot passed into the war scene.
///
/// [soldiers] is ordered by inventory slot: **index 0 is the cohort** — the leader body the
/// camera follows and that receives joystick steering. Remaining entries are formation children
/// positioned in that leader’s local space ([PlacedSoldier.localOffset] relative to the leader).
class CohortDeployment {
  CohortDeployment({required this.soldiers});

  final List<PlacedSoldier> soldiers;

  /// First selected soldier; defines the cohort anchor in the war scene.
  PlacedSoldier? get leader => soldiers.isEmpty ? null : soldiers.first;

  CohortDeployment copy() {
    return CohortDeployment(
      soldiers: soldiers
          .map((PlacedSoldier s) => s.copyWith(localOffset: s.localOffset))
          .toList(),
    );
  }
}
