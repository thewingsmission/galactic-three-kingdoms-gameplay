import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/cohort_models.dart';
import '../models/soldier_design.dart';
import '../models/soldier_design_palette.dart';
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

  /// Drag within this distance of the crosshair snaps to exact center (0, 0).
  static const double _centerSnapPx = 14;

  /// Default war roster: production **Gilded Bastion** ×5 on landing.
  static final SoldierDesign _kDefaultRosterUnit =
      kProductionSoldierDesignCatalog.first;
  static const SoldierDesignPalette _kDefaultRosterPalette =
      SoldierDesignPalette.yellow;

  final List<bool> _selected = List<bool>.filled(_inventorySize, false);
  final Map<int, Offset> _offsets = <int, Offset>{};

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 5; i++) {
      _selected[i] = true;
    }
    _recomputeOffsetsFromSelection();
  }

  /// Lowest inventory index among selected soldiers (cohort order); that unit stays on the crosshair.
  int? _firstSelectedIndex() {
    for (int i = 0; i < _inventorySize; i++) {
      if (_selected[i]) return i;
    }
    return null;
  }

  void _recomputeOffsetsFromSelection() {
    _offsets.clear();
    final List<int> sel = <int>[];
    for (int i = 0; i < _inventorySize; i++) {
      if (_selected[i]) sel.add(i);
    }
    const double r = 78;
    for (int k = 0; k < sel.length; k++) {
      final int idx = sel[k];
      if (k == 0) {
        _offsets[idx] = Offset.zero;
      } else {
        final double a = -math.pi / 2 + k * 0.65;
        _offsets[idx] = Offset(math.cos(a) * r, math.sin(a) * r);
      }
    }
  }

  void _toggleSlot(int index) {
    setState(() {
      _selected[index] = !_selected[index];
      _recomputeOffsetsFromSelection();
    });
  }

  void _onDragSoldier(int index, Offset delta, Size panelSize) {
    if (index == _firstSelectedIndex()) {
      return;
    }
    final Offset half = Offset(panelSize.width / 2, panelSize.height / 2);
    const double margin = 36;
    final double maxX = half.dx - margin;
    final double maxY = half.dy - margin;
    setState(() {
      final Offset o = (_offsets[index] ?? Offset.zero) + delta;
      Offset next = Offset(
        o.dx.clamp(-maxX, maxX),
        o.dy.clamp(-maxY, maxY),
      );
      if (next.distance <= _centerSnapPx) {
        next = Offset.zero;
      }
      _offsets[index] = next;
    });
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
            cohortPalette: _kDefaultRosterPalette,
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
        builder: (BuildContext context) => WarScreen(deployment: d.copy()),
      ),
    );
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
                      Text(
                        'Soldier inventory',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to add or remove units. Landing default: five ${_kDefaultRosterUnit.name} (production). The lowest selected slot is the cohort anchor on the crosshair (not draggable).',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white70,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.separated(
                          itemCount: _inventorySize,
                          separatorBuilder: (BuildContext _, int index) {
                            assert(index >= 0);
                            return const SizedBox(height: 10);
                          },
                          itemBuilder: (BuildContext context, int i) {
                            return SoldierInventoryTile(
                              index: i,
                              selected: _selected[i],
                              onTap: () => _toggleSlot(i),
                              rosterDesign: _kDefaultRosterUnit,
                              rosterPalette: _kDefaultRosterPalette,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (BuildContext context) =>
                                  const SoldierDesignScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.category_outlined),
                        label: const Text('Soldier designs'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: cs.primary,
                          side: BorderSide(color: cs.primary.withValues(alpha: 0.55)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      FilledButton(
                        onPressed: _goToWar,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Go to War',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
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
                              Positioned(
                                left: 16,
                                top: 40,
                                right: 16,
                                child: Text(
                                  'Drag other soldiers relative to the crosshair. The first selected soldier stays fixed on the crosshair.',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Colors.white60,
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
          left: origin.dx + o.dx - 28,
          top: origin.dy + o.dy - 28,
            child: GestureDetector(
            onPanUpdate: (DragUpdateDetails d) => _onDragSoldier(i, d.delta, panelSize),
            child: CustomPaint(
              size: const Size(56, 56),
              painter: RosterMiniSoldierPainter(
                design: _kDefaultRosterUnit,
                palette: _kDefaultRosterPalette,
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
