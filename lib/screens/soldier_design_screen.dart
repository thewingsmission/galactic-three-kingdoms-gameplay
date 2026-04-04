import 'package:flutter/material.dart';

import '../models/soldier_design.dart';
import '../models/soldier_design_palette.dart';
import '../models/soldier_rarity.dart';
import '../widgets/soldier_design_catalog.dart';
import '../widgets/soldier_design_detail_dialog.dart';
import '../widgets/soldier_design_preview_card.dart';
import 'color_theme_screen.dart';

/// Tabs: **Draft** → **Validated** → **Production**; detail popup (idle / attack / range disks).
class SoldierDesignScreen extends StatefulWidget {
  const SoldierDesignScreen({super.key});

  @override
  State<SoldierDesignScreen> createState() => _SoldierDesignScreenState();
}

class _SoldierDesignScreenState extends State<SoldierDesignScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  late List<SoldierDesign> _validatedPool;

  final List<SoldierDesign> _productionPool = <SoldierDesign>[];

  /// 1-based indices into [_validatedPool] tagged for production.
  final Set<int> _markProduction = <int>{};

  /// 1-based draft indices marked to move to validated.
  final Set<int> _markValidate = <int>{};

  /// 1-based draft indices marked for deletion.
  final Set<int> _markDelete = <int>{};

  /// Preview / detail tint: **yellow** = authored catalog colors.
  SoldierDesignPalette _palette = SoldierDesignPalette.yellow;

  @override
  void initState() {
    super.initState();
    _validatedPool = List<SoldierDesign>.from(kValidatedSoldierDesignCatalog);
    _productionPool
      ..clear()
      ..addAll(kProductionSoldierDesignCatalog);
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() {
      if (_tabs.indexIsChanging) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _toggleProductionTag(int validatedOneBased) {
    setState(() {
      if (_markProduction.contains(validatedOneBased)) {
        _markProduction.remove(validatedOneBased);
      } else {
        _markProduction.add(validatedOneBased);
      }
    });
  }

  void _confirmMoveToProduction() {
    if (_markProduction.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tag soldiers with the factory icon first.')),
      );
      return;
    }
    final List<int> order = _markProduction.toList()
      ..sort((int a, int b) => b.compareTo(a));
    int moved = 0;
    for (final int oneBased in order) {
      final int i = oneBased - 1;
      if (i >= 0 && i < _validatedPool.length) {
        _productionPool.add(_validatedPool[i]);
        _validatedPool.removeAt(i);
        moved++;
      }
    }
    _markProduction.clear();
    debugPrint(
      '[SoldierDesignScreen] Moved $moved soldier(s) to production. '
      'Validated=${_validatedPool.length}, production=${_productionPool.length}',
    );
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Moved $moved to Production tab.')),
    );
  }

  void _toggleValidate(int oneBased) {
    setState(() {
      if (_markValidate.contains(oneBased)) {
        _markValidate.remove(oneBased);
      } else {
        _markValidate.add(oneBased);
        _markDelete.remove(oneBased);
      }
    });
  }

  void _toggleDelete(int oneBased) {
    setState(() {
      if (_markDelete.contains(oneBased)) {
        _markDelete.remove(oneBased);
      } else {
        _markDelete.add(oneBased);
        _markValidate.remove(oneBased);
      }
    });
  }

  void _selectAllDraftForDelete() {
    setState(() {
      _markValidate.clear();
      _markDelete
        ..clear()
        ..addAll(
          List<int>.generate(
            kDraftSoldierDesignCatalog.length,
            (int i) => i + 1,
          ),
        );
    });
  }

  void _onDetailPaletteChange(SoldierDesignPalette palette) {
    setState(() => _palette = palette);
  }

  void _confirmDraftSelection() {
    final List<int> toVal = _markValidate.toList()..sort();
    final List<int> toDel = _markDelete.toList()..sort();
    debugPrint('[SoldierDesignScreen] Draft confirm — copy 1-based indices for Cursor:');
    debugPrint('  MOVE_TO_VALIDATED: ${toVal.isEmpty ? '(none)' : toVal.join(', ')}');
    debugPrint('  DELETE_FROM_DRAFT: ${toDel.isEmpty ? '(none)' : toDel.join(', ')}');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Logged: ${toVal.length} → validated, ${toDel.length} → delete (see debug console)',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFF0F0D08),
              Color(0xFF2A2314),
              Color(0xFF0C0B06),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                child: Row(
                  children: <Widget>[
                    IconButton.filledTonal(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Soldier designs',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Color theme table',
                      onPressed: () {
                        Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) =>
                                const ColorThemeScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.palette_outlined),
                      color: const Color(0xFFFFB74D),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Tooltip(
                      message: 'Color scheme',
                      child: SegmentedButton<SoldierDesignPalette>(
                        style: SegmentedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 2,
                            vertical: 0,
                          ),
                          minimumSize: const Size(24, 24),
                          maximumSize: const Size(36, 28),
                        ),
                        showSelectedIcon: false,
                        segments: const <ButtonSegment<SoldierDesignPalette>>[
                          ButtonSegment<SoldierDesignPalette>(
                            value: SoldierDesignPalette.red,
                            tooltip: 'Red',
                            icon: Icon(
                              Icons.circle,
                              size: 10,
                              color: Color(0xFFE57373),
                            ),
                          ),
                          ButtonSegment<SoldierDesignPalette>(
                            value: SoldierDesignPalette.yellow,
                            tooltip: 'Yellow',
                            icon: Icon(
                              Icons.circle,
                              size: 10,
                              color: Color(0xFFFFC107),
                            ),
                          ),
                          ButtonSegment<SoldierDesignPalette>(
                            value: SoldierDesignPalette.blue,
                            tooltip: 'Blue',
                            icon: Icon(
                              Icons.circle,
                              size: 10,
                              color: Color(0xFF64B5F6),
                            ),
                          ),
                        ],
                        selected: <SoldierDesignPalette>{_palette},
                        onSelectionChanged: (Set<SoldierDesignPalette> next) {
                          setState(() {
                            _palette = next.first;
                          });
                        },
                        multiSelectionEnabled: false,
                        emptySelectionAllowed: false,
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (_tabs.index == 1)
                      TextButton.icon(
                        onPressed: _confirmMoveToProduction,
                        icon: const Icon(
                          Icons.precision_manufacturing,
                          size: 18,
                          color: Color(0xFF26C6DA),
                        ),
                        label: Text(
                          'Move to Production',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: const Color(0xFF26C6DA),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF26C6DA),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                        ),
                      ),
                    if (_tabs.index == 0)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          TextButton.icon(
                            onPressed: _selectAllDraftForDelete,
                            icon: const Icon(
                              Icons.delete_sweep,
                              size: 18,
                              color: Color(0xFFE57373),
                            ),
                            label: Text(
                              'All delete',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: const Color(0xFFE57373),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFE57373),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _confirmDraftSelection,
                            icon: const Icon(
                              Icons.check_circle_outline,
                              size: 18,
                              color: Color(0xFFFFC107),
                            ),
                            label: Text(
                              'Confirm',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: const Color(0xFFFFC107),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFFFC107),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TabBar(
                  controller: _tabs,
                  indicatorColor: const Color(0xFFFFC107),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  tabs: <Widget>[
                    Tab(text: 'Draft (${kDraftSoldierDesignCatalog.length})'),
                    Tab(text: 'Validated (${_validatedPool.length})'),
                    Tab(text: 'Production (${_productionPool.length})'),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: <Widget>[
                    for (final SoldierRarity r in SoldierRarity.values)
                      Chip(
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 2,
                          vertical: 0,
                        ),
                        labelPadding: const EdgeInsets.only(left: 2, right: 6),
                        avatar: CircleAvatar(
                          backgroundColor: r.accentColor.withValues(alpha: 0.35),
                          radius: 5,
                          child: Text(
                            '${r.structureTier}',
                            style: TextStyle(
                              color: r.accentColor,
                              fontSize: 7,
                              fontWeight: FontWeight.bold,
                              height: 1,
                            ),
                          ),
                        ),
                        label: Text(
                          '${r.label} · ${r.powerTier}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white70,
                            fontSize: 9,
                            height: 1.1,
                          ),
                        ),
                        side: BorderSide(
                          color: r.accentColor.withValues(alpha: 0.5),
                        ),
                        backgroundColor: Colors.black.withValues(alpha: 0.35),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: <Widget>[
                    _buildDraftTab(theme),
                    _buildValidatedTab(theme),
                    _buildProductionTab(theme),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildValidatedTab(ThemeData theme) {
    if (_validatedPool.isEmpty) {
      return Center(
        child: Text(
          'No validated soldiers (all moved to Production or empty).',
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white54),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Text(
            'Tap a card for details. Factory icon tags for Production; Move to Production (top right).',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              mainAxisSpacing: 12,
              crossAxisSpacing: 10,
              childAspectRatio: 0.58,
            ),
            itemCount: _validatedPool.length,
            itemBuilder: (BuildContext context, int index) {
              final SoldierDesign d = _validatedPool[index];
              final SoldierRarity r = d.rarity;
              final int oneBased = index + 1;
              final bool tag = _markProduction.contains(oneBased);
              final Color border = tag
                  ? const Color(0xFF26C6DA)
                  : r.accentColor.withValues(alpha: 0.55);
              return Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.none,
                children: <Widget>[
                  GestureDetector(
                    onTap: () => showSoldierDesignDetailDialog(
                      context: context,
                      design: d,
                      rarity: r,
                      palette: _palette,
                      onPaletteChanged: _onDetailPaletteChange,
                    ),
                    child: _designCell(
                      theme: theme,
                      design: d,
                      rarity: r,
                      subtitle: '#$oneBased',
                      borderColor: border,
                      borderWidth: tag ? 2.5 : 1.5,
                    ),
                  ),
                  Positioned(
                    top: 2,
                    right: 4,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        onTap: () => _toggleProductionTag(oneBased),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.precision_manufacturing,
                            size: 18,
                            color: tag
                                ? const Color(0xFF26C6DA)
                                : Colors.white38,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDraftTab(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Text(
            'Tap ✓ / ✕ per cell, or All delete (top right). Confirm logs indices.',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              mainAxisSpacing: 12,
              crossAxisSpacing: 10,
              childAspectRatio: 0.58,
            ),
            itemCount: kDraftSoldierDesignCatalog.length,
            itemBuilder: (BuildContext context, int index) {
              final SoldierDesign d = kDraftSoldierDesignCatalog[index];
              final SoldierRarity r = d.rarity;
              final int oneBased = index + 1;
              final bool v = _markValidate.contains(oneBased);
              final bool del = _markDelete.contains(oneBased);
              final Color border = v
                  ? const Color(0xFF66BB6A)
                  : del
                      ? const Color(0xFFE57373)
                      : r.accentColor.withValues(alpha: 0.55);
              return Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.none,
                children: <Widget>[
                  GestureDetector(
                    onTap: () => showSoldierDesignDetailDialog(
                      context: context,
                      design: d,
                      rarity: r,
                      palette: _palette,
                      onPaletteChanged: _onDetailPaletteChange,
                    ),
                    child: _designCell(
                      theme: theme,
                      design: d,
                      rarity: r,
                      subtitle: '#$oneBased',
                      borderColor: border,
                      borderWidth: v || del ? 2.5 : 1.5,
                    ),
                  ),
                  Positioned(
                    top: 2,
                    right: 4,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          InkWell(
                            onTap: () => _toggleValidate(oneBased),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.verified_outlined,
                                size: 18,
                                color: v
                                    ? const Color(0xFF66BB6A)
                                    : Colors.white38,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => _toggleDelete(oneBased),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: del
                                    ? const Color(0xFFE57373)
                                    : Colors.white38,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProductionTab(ThemeData theme) {
    if (_productionPool.isEmpty) {
      return Center(
        child: Text(
          'Production is empty. Tag soldiers on Validated, then Move to Production.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white54),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Text(
            'Tap a card for idle / attack / range details.',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              mainAxisSpacing: 12,
              crossAxisSpacing: 10,
              childAspectRatio: 0.58,
            ),
            itemCount: _productionPool.length,
            itemBuilder: (BuildContext context, int index) {
              final SoldierDesign d = _productionPool[index];
              final SoldierRarity r = d.rarity;
              final int oneBased = index + 1;
              return GestureDetector(
                onTap: () => showSoldierDesignDetailDialog(
                  context: context,
                  design: d,
                  rarity: r,
                  palette: _palette,
                  onPaletteChanged: _onDetailPaletteChange,
                ),
                child: _designCell(
                  theme: theme,
                  design: d,
                  rarity: r,
                  subtitle: '#$oneBased',
                  borderColor: const Color(0xFF26C6DA).withValues(alpha: 0.75),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _designCell({
    required ThemeData theme,
    required SoldierDesign design,
    required SoldierRarity rarity,
    required String subtitle,
    required Color borderColor,
    double borderWidth = 1.5,
  }) {
    return Center(
      child: FractionallySizedBox(
        widthFactor: 0.92,
        heightFactor: 0.94,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    subtitle,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white54,
                      fontSize: 9,
                    ),
                  ),
                ),
                Expanded(
                  child: SoldierDesignPreviewCard(
                    design: design,
                    rarity: rarity,
                    palette: _palette,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
