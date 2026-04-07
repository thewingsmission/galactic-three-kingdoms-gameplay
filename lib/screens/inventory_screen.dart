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

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  static const int _inventorySize = 10;
  static const int _maxCohortSize = 10;

  /// Matches compact [SoldierInventoryTile] preview for cohort stack hit area.
  static const double _kFormationSoldierPx = 60;
  static const double _kFormationSoldierHalf = _kFormationSoldierPx / 2;

  /// Drag within this distance of the crosshair snaps to exact center (0, 0).
  static const double _centerSnapPx = 21;

  /// Ring radius for the 9 default placement slots around the center soldier.
  static const double _placementRadius = 49.14;

  /// 360° / 9 = 40° per slot for soldiers 2–10.
  static const int _ringSlots = 9;

  /// Per-slot roster: 10 × production Gilded Bastion.
  static final List<SoldierDesign> _kRoster = List<SoldierDesign>.unmodifiable(<SoldierDesign>[
    for (int i = 0; i < _inventorySize; i++) kProductionSoldierDesignCatalog.first,
  ]);

  SoldierDesignPalette _palette = SoldierDesignPalette.yellow;

  final List<bool> _selected = List<bool>.filled(_inventorySize, false);
  final Map<int, Offset> _offsets = <int, Offset>{};
  late final SoldierContact _soldierContact;

  /// Explicit leader — the soldier placed at center (first selected).
  int? _cohortLeaderIndex;

  /// Index of the soldier currently being dragged (null if idle).
  int? _dragIndex;

  late final AnimationController _idleMotionCtrl;
  double _lastIdleValue = 0;
  double _continuousMotionT = 0;

  void _accumulateMotionT() {
    final double curr = _idleMotionCtrl.value;
    double delta = curr - _lastIdleValue;
    if (delta < 0) delta += 1.0;
    _continuousMotionT += delta;
    _lastIdleValue = curr;
  }

  @override
  void initState() {
    super.initState();
    _soldierContact = SoldierContact.fromDesign(_kRoster.first, _kFormationSoldierPx);
    _idleMotionCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _idleMotionCtrl.addListener(_accumulateMotionT);
    _idleMotionCtrl.repeat();
  }

  @override
  void dispose() {
    _idleMotionCtrl.dispose();
    super.dispose();
  }

  /// The cohort leader — the soldier the user selected first (placed at center).
  int? _firstSelectedIndex() => _cohortLeaderIndex;

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
        final bool wasLeader = index == _cohortLeaderIndex;
        _selected[index] = false;
        _offsets.remove(index);
        if (wasLeader) {
          _cohortLeaderIndex = null;
          for (int i = 0; i < _inventorySize; i++) {
            if (_selected[i]) {
              _cohortLeaderIndex = i;
              _offsets[i] = Offset.zero;
              break;
            }
          }
        }
      } else {
        _selected[index] = true;
        if (_cohortLeaderIndex == null) {
          _cohortLeaderIndex = index;
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
    final double maxX = (half.dx - margin) * 0.7;
    final double maxY = (half.dy - margin) * 0.7;
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

  // ── Hit testing for drag (contact zone) ────────────────────────────

  /// Find the topmost (highest Y) selected soldier whose contact zone
  /// contains [touchLocal] (relative to panel center). Skips the leader.
  int? _hitTestSoldier(Offset touchLocal) {
    final int? leader = _firstSelectedIndex();
    final double r = _soldierContact.radius;
    int? best;
    double bestY = double.negativeInfinity;
    for (int i = 0; i < _inventorySize; i++) {
      if (!_selected[i]) continue;
      if (i == leader) continue;
      final Offset o = _offsets[i] ?? Offset.zero;
      final Offset local = touchLocal - o;
      final bool hit = _soldierContact.hullVertices != null
          ? _pointInPolygon(local, _soldierContact.hullVertices!)
          : local.distance <= r;
      if (hit && o.dy > bestY) {
        best = i;
        bestY = o.dy;
      }
    }
    return best;
  }

  static bool _pointInPolygon(Offset pt, List<Offset> hull) {
    bool inside = false;
    for (int i = 0, j = hull.length - 1; i < hull.length; j = i++) {
      final Offset a = hull[i], b = hull[j];
      if ((a.dy > pt.dy) != (b.dy > pt.dy) &&
          pt.dx < (b.dx - a.dx) * (pt.dy - a.dy) / (b.dy - a.dy) + a.dx) {
        inside = !inside;
      }
    }
    return inside;
  }

  void _onPanelPanStart(DragStartDetails details, Size panelSize) {
    final Offset origin = Offset(panelSize.width / 2, panelSize.height / 2);
    _dragIndex = _hitTestSoldier(details.localPosition - origin);
  }

  void _onPanelPanUpdate(DragUpdateDetails details, Size panelSize) {
    final int? di = _dragIndex;
    if (di == null) return;
    _onDragSoldier(di, details.delta, panelSize);
  }

  void _onPanelPanEnd(DragEndDetails _) {
    _dragIndex = null;
  }

  CohortDeployment _buildDeployment() {
    final List<PlacedSoldier> list = <PlacedSoldier>[];
    final int? leader = _cohortLeaderIndex;
    if (leader != null && _selected[leader]) {
      list.add(
        PlacedSoldier(
          inventoryIndex: leader,
          type: SoldierType.triangle,
          localOffset: _offsets[leader] ?? Offset.zero,
          soldierDesign: _kRoster[leader],
          cohortPalette: _palette,
        ),
      );
    }
    for (int i = 0; i < _inventorySize; i++) {
      if (!_selected[i] || i == leader) continue;
      list.add(
        PlacedSoldier(
          inventoryIndex: i,
          type: SoldierType.triangle,
          localOffset: _offsets[i] ?? Offset.zero,
          soldierDesign: _kRoster[i],
          cohortPalette: _palette,
        ),
      );
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

  Widget _buildPaletteSelector() {
    return SegmentedButton<SoldierDesignPalette>(
      style: SegmentedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
        minimumSize: const Size(24, 24),
        maximumSize: const Size(36, 28),
      ),
      showSelectedIcon: false,
      segments: const <ButtonSegment<SoldierDesignPalette>>[
        ButtonSegment<SoldierDesignPalette>(
          value: SoldierDesignPalette.red,
          tooltip: 'Red',
          icon: Icon(Icons.circle, size: 10, color: Color(0xFFE57373)),
        ),
        ButtonSegment<SoldierDesignPalette>(
          value: SoldierDesignPalette.yellow,
          tooltip: 'Yellow',
          icon: Icon(Icons.circle, size: 10, color: Color(0xFFFFC107)),
        ),
        ButtonSegment<SoldierDesignPalette>(
          value: SoldierDesignPalette.blue,
          tooltip: 'Blue',
          icon: Icon(Icons.circle, size: 10, color: Color(0xFF64B5F6)),
        ),
      ],
      selected: <SoldierDesignPalette>{_palette},
      onSelectionChanged: (Set<SoldierDesignPalette> next) {
        setState(() => _palette = next.first);
      },
      multiSelectionEnabled: false,
    );
  }

  static List<Color> _bgGradient(SoldierDesignPalette p) => switch (p) {
        SoldierDesignPalette.yellow => const <Color>[
          Color(0xFF0F0D08),
          Color(0xFF2A2314),
          Color(0xFF0C0B06),
        ],
        SoldierDesignPalette.red => const <Color>[
          Color(0xFF0F0808),
          Color(0xFF2A1414),
          Color(0xFF0C0606),
        ],
        SoldierDesignPalette.blue => const <Color>[
          Color(0xFF080B0F),
          Color(0xFF141E2A),
          Color(0xFF060A0C),
        ],
      };

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color paletteAccent = factionTierList(_palette)[0];
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _bgGradient(_palette),
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
                          Flexible(
                            child: Text(
                              'Soldier inventory',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildPaletteSelector(),
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
                              rosterDesign: _kRoster[i],
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
                              onPressed: () async {
                                final SoldierDesignPalette? result =
                                    await Navigator.of(context).push<SoldierDesignPalette>(
                                  MaterialPageRoute<SoldierDesignPalette>(
                                    builder: (BuildContext context) =>
                                        SoldierDesignScreen(initialPalette: _palette),
                                  ),
                                );
                                if (result != null && result != _palette) {
                                  setState(() => _palette = result);
                                }
                              },
                              icon: Icon(
                                Icons.category_outlined,
                                size: 18,
                                color: paletteAccent,
                              ),
                              label: Text(
                                'Designs',
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      color: paletteAccent,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: paletteAccent,
                                side: BorderSide(
                                  color: paletteAccent.withValues(alpha: 0.55),
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
                        color: paletteAccent.withValues(alpha: 0.42),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: LayoutBuilder(
                        builder: (BuildContext context, BoxConstraints c) {
                          final Size panelSize = Size(c.maxWidth, c.maxHeight);
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onPanStart: (DragStartDetails d) =>
                                _onPanelPanStart(d, panelSize),
                            onPanUpdate: (DragUpdateDetails d) =>
                                _onPanelPanUpdate(d, panelSize),
                            onPanEnd: _onPanelPanEnd,
                            child: AnimatedBuilder(
                              animation: _idleMotionCtrl,
                              builder: (BuildContext context, Widget? child) {
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
                                    ..._buildFormationSoldiers(panelSize, _continuousMotionT),
                                  ],
                                );
                              },
                            ),
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

  List<Widget> _buildFormationSoldiers(Size panelSize, double motionT) {
    final Offset origin = Offset(panelSize.width / 2, panelSize.height / 2);
    final List<int> indices = <int>[
      for (int i = 0; i < _inventorySize; i++)
        if (_selected[i]) i,
    ];
    indices.sort((int a, int b) {
      final double ya = (_offsets[a] ?? Offset.zero).dy;
      final double yb = (_offsets[b] ?? Offset.zero).dy;
      return ya.compareTo(yb);
    });
    return <Widget>[
      for (final int i in indices)
        Positioned(
          left: origin.dx + (_offsets[i] ?? Offset.zero).dx - _kFormationSoldierHalf,
          top: origin.dy + (_offsets[i] ?? Offset.zero).dy - _kFormationSoldierHalf,
          child: IgnorePointer(
            child: CustomPaint(
              size: const Size(_kFormationSoldierPx, _kFormationSoldierPx),
              painter: RosterMiniSoldierPainter(
                design: _kRoster[i],
                palette: _palette,
                motionT: motionT,
              ),
            ),
          ),
        ),
    ];
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


