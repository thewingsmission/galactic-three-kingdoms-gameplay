import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/cohort_models.dart';
import '../models/cohort_soldier.dart';
import '../models/soldier_design.dart';
import '../models/soldier_design_palette.dart';
import '../models/soldier_faction_color_theme.dart';
import '../widgets/soldier_design_catalog.dart';
import '../widgets/soldier_inventory_tile.dart';
import 'soldier_design_screen.dart';
import 'war_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  static const int _inventorySize = 11;
  static const int _maxCohortSize = 10;

  /// Matches compact [SoldierInventoryTile] preview for cohort stack hit area.
  static const double _kFormationSoldierPx = 40;
  static const double _kFormationSoldierHalf = _kFormationSoldierPx / 2;

  /// Drag within this distance of the crosshair snaps to exact center (0, 0).
  static const double _centerSnapPx = 14;

  /// Ring radius for the 9 default placement slots around the center soldier.
  static const double _placementRadius = 46.8;

  /// 360° / 9 = 40° per slot for soldiers 2–10.
  static const int _ringSlots = 9;

  /// Default war roster: production **Gilded Bastion**.
  static final SoldierDesign _kDefaultRosterUnit =
      kProductionSoldierDesignCatalog.first;

  SoldierDesignPalette _palette = SoldierDesignPalette.red;

  final List<bool> _selected = List<bool>.filled(_inventorySize, false);
  final Map<int, Offset> _offsets = <int, Offset>{};
  late final SoldierContact _soldierContact;

  @override
  void initState() {
    super.initState();
    _soldierContact = SoldierContact.fromDesign(_kDefaultRosterUnit, 56);
  }

  /// Lowest inventory index among selected soldiers (cohort order); that unit stays on the crosshair.
  int? _firstSelectedIndex() {
    for (int i = 0; i < _inventorySize; i++) {
      if (_selected[i]) return i;
    }
    return null;
  }

  int _selectedCount() {
    int c = 0;
    for (int i = 0; i < _inventorySize; i++) {
      if (_selected[i]) c++;
    }
    return c;
  }

  // ── Placement helpers ──────────────────────────────────────────────

  /// Try the 9 ring slots (40° each, 12 o'clock first, clockwise).
  /// Falls back to a random valid position if every slot overlaps.
  Offset _findValidPosition(int forIndex) {
    const double step = 2 * math.pi / _ringSlots;
    for (int s = 0; s < _ringSlots; s++) {
      final double angle = -math.pi / 2 + s * step;
      final Offset candidate = Offset(
        math.cos(angle) * _placementRadius,
        math.sin(angle) * _placementRadius,
      );
      if (!_wouldOverlapAny(candidate, forIndex)) return candidate;
    }
    return _findRandomValidPosition(forIndex);
  }

  Offset _findRandomValidPosition(int forIndex) {
    final math.Random rng = math.Random();
    for (int attempt = 0; attempt < 200; attempt++) {
      final double angle = rng.nextDouble() * 2 * math.pi;
      final double r =
          _soldierContact.radius * 2.5 + rng.nextDouble() * _placementRadius;
      final Offset candidate = Offset(math.cos(angle) * r, math.sin(angle) * r);
      if (!_wouldOverlapAny(candidate, forIndex)) return candidate;
    }
    return Offset(_placementRadius, 0);
  }

  // ── Contact-zone overlap detection ─────────────────────────────────

  bool _wouldOverlapAny(Offset candidate, int excludeIndex) {
    for (final MapEntry<int, Offset> entry in _offsets.entries) {
      if (entry.key == excludeIndex) continue;
      if (_contactsOverlap(candidate, entry.value)) return true;
    }
    return false;
  }

  bool _contactsOverlap(Offset posA, Offset posB) {
    final List<Offset>? hull = _soldierContact.hullVertices;
    if (hull != null && hull.length >= 3) {
      final List<Offset> polyA = hull.map((Offset v) => v + posA).toList();
      final List<Offset> polyB = hull.map((Offset v) => v + posB).toList();
      return _convexPolygonsOverlap(polyA, polyB);
    }
    return (posA - posB).distance < 2 * _soldierContact.radius;
  }

  /// Separating Axis Theorem for two convex polygons.
  static bool _convexPolygonsOverlap(List<Offset> a, List<Offset> b) {
    for (final List<Offset> poly in <List<Offset>>[a, b]) {
      for (int i = 0; i < poly.length; i++) {
        final Offset edge = poly[(i + 1) % poly.length] - poly[i];
        final double nx = -edge.dy, ny = edge.dx;
        double minA = double.infinity, maxA = double.negativeInfinity;
        double minB = double.infinity, maxB = double.negativeInfinity;
        for (final Offset v in a) {
          final double p = v.dx * nx + v.dy * ny;
          if (p < minA) minA = p;
          if (p > maxA) maxA = p;
        }
        for (final Offset v in b) {
          final double p = v.dx * nx + v.dy * ny;
          if (p < minB) minB = p;
          if (p > maxB) maxB = p;
        }
        if (maxA <= minB || maxB <= minA) return false;
      }
    }
    return true;
  }

  void _toggleSlot(int index) {
    if (!_selected[index] && _selectedCount() >= _maxCohortSize) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cohort is full (max 10 soldiers).')),
      );
      return;
    }
    setState(() {
      if (_selected[index]) {
        final int? currentLeader = _firstSelectedIndex();
        final bool wasLeader = index == currentLeader;
        _selected[index] = false;
        _offsets.remove(index);
        if (wasLeader) {
          final int? newLeader = _firstSelectedIndex();
          if (newLeader != null) {
            _offsets[newLeader] = Offset.zero;
          }
        }
      } else {
        _selected[index] = true;
        if (_selectedCount() == 1) {
          _offsets[index] = Offset.zero;
        } else {
          _offsets[index] = _findValidPosition(index);
        }
      }
    });
  }

  void _onDragSoldier(int index, Offset delta, Size panelSize) {
    if (index == _firstSelectedIndex()) return;
    final Offset half = Offset(panelSize.width / 2, panelSize.height / 2);
    const double margin = 36;
    final double maxX = half.dx - margin;
    final double maxY = half.dy - margin;
    final Offset o = (_offsets[index] ?? Offset.zero) + delta;
    Offset next = Offset(
      o.dx.clamp(-maxX, maxX),
      o.dy.clamp(-maxY, maxY),
    );
    if (next.distance <= _centerSnapPx) {
      next = Offset.zero;
    }
    if (!_wouldOverlapAny(next, index)) {
      setState(() {
        _offsets[index] = next;
      });
    }
  }

  CohortDeployment _buildDeployment() {
    final List<PlacedSoldier> list = <PlacedSoldier>[];
    for (int i = 0; i < _inventorySize; i++) {
      if (_selected[i]) {
        list.add(
          PlacedSoldier(
            inventoryIndex: i,
            type: SoldierType.triangle,
            localOffset: _offsets[i] ?? Offset.zero,
            soldierDesign: _kDefaultRosterUnit,
            cohortPalette: _palette,
          ),
        );
      }
    }
    return CohortDeployment(soldiers: list);
  }

  void _goToWar() {
    final CohortDeployment d = _buildDeployment();
    if (d.soldiers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one soldier.')),
      );
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => WarScreen(
          deployment: d.copy(),
          playerPalette: _palette,
        ),
      ),
    );
  }

  List<Widget> _buildPaletteChips() {
    return SoldierDesignPalette.values.map((SoldierDesignPalette p) {
      final bool active = p == _palette;
      final Color color = factionTierList(p)[0];
      return Padding(
        padding: const EdgeInsets.only(left: 4),
        child: GestureDetector(
          onTap: () => setState(() => _palette = p),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: active ? color : color.withValues(alpha: 0.25),
              shape: BoxShape.circle,
              border: Border.all(
                color: active ? Colors.white : Colors.white24,
                width: active ? 2.5 : 1.25,
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: const <Color>[
              Color(0xFF0F0D08),
              Color(0xFF2A2314),
              Color(0xFF0C0B06),
            ],
          ),
        ),
        child: SafeArea(
          child: Row(
            children: <Widget>[
              Expanded(
                flex: 42,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Text(
                            'Soldier inventory',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const Spacer(),
                          ..._buildPaletteChips(),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: GridView.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 6,
                            crossAxisSpacing: 6,
                            childAspectRatio: 0.78,
                          ),
                          itemCount: _inventorySize,
                          itemBuilder: (BuildContext context, int i) {
                            return SoldierInventoryTile(
                              index: i,
                              selected: _selected[i],
                              onTap: () => _toggleSlot(i),
                              rosterDesign: _kDefaultRosterUnit,
                              rosterPalette: _palette,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(context).push<void>(
                                  MaterialPageRoute<void>(
                                    builder: (BuildContext context) =>
                                        const SoldierDesignScreen(),
                                  ),
                                );
                              },
                              icon: Icon(
                                Icons.category_outlined,
                                size: 18,
                                color: cs.primary,
                              ),
                              label: Text(
                                'Designs',
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      color: cs.primary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: cs.primary,
                                side: BorderSide(
                                  color: cs.primary.withValues(alpha: 0.55),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _goToWar,
                              icon: const Icon(Icons.shield_moon_outlined, size: 18),
                              label: Text(
                                'Go to War',
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: cs.onPrimary,
                                    ),
                              ),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 58,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 16, 16),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: cs.primary.withValues(alpha: 0.42),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: LayoutBuilder(
                        builder: (BuildContext context, BoxConstraints c) {
                          final Size panelSize = Size(c.maxWidth, c.maxHeight);
                          return Stack(
                            clipBehavior: Clip.none,
                            children: <Widget>[
                              Positioned(
                                left: 16,
                                top: 12,
                                child: Text(
                                  'Cohort formation',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                              Center(
                                child: CustomPaint(
                                  size: panelSize,
                                  painter: _CrosshairPainter(),
                                ),
                              ),
                              ..._buildDraggableSoldiers(panelSize),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDraggableSoldiers(Size panelSize) {
    final List<Widget> out = <Widget>[];
    final Offset origin = Offset(panelSize.width / 2, panelSize.height / 2);
    for (int i = 0; i < _inventorySize; i++) {
      if (!_selected[i]) continue;
      final Offset o = _offsets[i] ?? Offset.zero;
      out.add(
        Positioned(
          left: origin.dx + o.dx - _kFormationSoldierHalf,
          top: origin.dy + o.dy - _kFormationSoldierHalf,
          child: GestureDetector(
            onPanUpdate: (DragUpdateDetails d) => _onDragSoldier(i, d.delta, panelSize),
            child: CustomPaint(
              size: const Size(_kFormationSoldierPx, _kFormationSoldierPx),
              painter: RosterMiniSoldierPainter(
                design: _kDefaultRosterUnit,
                palette: _palette,
              ),
            ),
          ),
        ),
      );
    }
    return out;
  }
}

class _CrosshairPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = Offset(size.width / 2, size.height / 2);
    final Paint p = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(c.dx - 14, c.dy), Offset(c.dx + 14, c.dy), p);
    canvas.drawLine(Offset(c.dx, c.dy - 14), Offset(c.dx, c.dy + 14), p);
    canvas.drawCircle(c, 5, Paint()..color = Colors.white24);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
