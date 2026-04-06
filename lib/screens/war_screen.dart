import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/cohort_war_game.dart';
import '../models/cohort_models.dart';
import '../models/soldier_design_palette.dart';
import '../models/soldier_faction_color_theme.dart';
import '../widgets/virtual_joystick.dart';

enum WarActionMode { attack, defense, target }

class WarScreen extends StatefulWidget {
  const WarScreen({
    super.key,
    required this.deployment,
    required this.playerPalette,
  });

  final CohortDeployment deployment;
  final SoldierDesignPalette playerPalette;

  @override
  State<WarScreen> createState() => _WarScreenState();
}

class _WarScreenState extends State<WarScreen> {
  final ValueNotifier<Vector2> _velocityHud =
      ValueNotifier<Vector2>(Vector2.zero());
  final ValueNotifier<Vector2> _soldier1PosHud =
      ValueNotifier<Vector2>(Vector2.zero());

  late CohortWarGame _game;
  Key _gameKey = UniqueKey();
  WarActionMode _actionMode = WarActionMode.defense;
  WarActionMode? _pressedButton;

  static const double _btnRadius = 44.8;
  static const double _btnDiameter = _btnRadius * 2;

  @override
  void initState() {
    super.initState();
    _game = _createGame();
  }

  CohortWarGame _createGame() {
    return CohortWarGame(
      deployment: widget.deployment.copy(),
      playerPalette: widget.playerPalette,
      velocityHud: _velocityHud,
      soldier1PosHud: _soldier1PosHud,
      onTargetAssigned: () {
        setState(() => _actionMode = WarActionMode.target);
      },
    );
  }

  void _restart() {
    setState(() {
      _game = _createGame();
      _gameKey = UniqueKey();
      _actionMode = WarActionMode.defense;
    });
  }

  @override
  void dispose() {
    _velocityHud.dispose();
    _soldier1PosHud.dispose();
    super.dispose();
  }

  static Color _paler(Color c) => Color.lerp(c, Colors.white, 0.65)!;

  Widget _buildActionButton({
    required WarActionMode mode,
    required String label,
    required String assetPath,
    required Color fillColor,
    required Color outlineColor,
    required double bottomOffset,
    required double rightOffset,
    double imageScale = 1.4,
    Offset imageOffset = Offset.zero,
  }) {
    final bool pressed = _pressedButton == mode;
    final bool selected = _actionMode == mode;
    final bool anotherPressed = _pressedButton != null && !pressed;
    final double scale = pressed ? 1.2 : (selected && !anotherPressed ? 1.2 : 1.0);
    final double size = _btnDiameter * scale;
    return Positioned(
      bottom: bottomOffset - (size - _btnDiameter) / 2 - 20,
      right: rightOffset - (size - _btnDiameter) / 2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          GestureDetector(
            onTapDown: (_) => setState(() => _pressedButton = mode),
            onTapUp: (_) => setState(() {
              _actionMode = mode;
              _pressedButton = null;
            }),
            onTapCancel: () => setState(() => _pressedButton = null),
            child: Container(
              width: size,
              height: size,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _paler(fillColor),
                border: Border.all(
                  color: outlineColor,
                  width: (scale > 1.0) ? 5.0 : 3.5,
                ),
              ),
              child: Transform.translate(
                offset: imageOffset,
                child: Transform.scale(
                  scale: imageScale,
                  child: Image.asset(assetPath, fit: BoxFit.contain),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          IgnorePointer(
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                color: outlineColor,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.5,
                shadows: <Shadow>[
                  Shadow(
                    color: outlineColor.withValues(alpha: 0.6),
                    blurRadius: 6,
                  ),
                  const Shadow(
                    color: Colors.black87,
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Color> redTier = kRedFactionComponentColors;
    final List<Color> yellowTier = kYellowFactionComponentColors;
    final List<Color> blueTier = kBlueFactionComponentColors;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: <Widget>[
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapUp: (TapUpDetails details) =>
                _game.handleScreenTap(details.localPosition),
            child: GameWidget<CohortWarGame>(key: _gameKey, game: _game),
          ),
          Positioned(
            left: 20,
            top: 16,
            child: SafeArea(
              child: IconButton.filledTonal(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
              ),
            ),
          ),
          Positioned(
            left: 24,
            bottom: 24,
            child: SafeArea(
              child: VirtualJoystick(
                outerRadius: 72,
                knobRadius: 28,
                onChanged: (Offset o) => _game.setStick(o),
              ),
            ),
          ),
          // Action buttons — bottom right
          _buildActionButton(
            mode: WarActionMode.attack,
            label: 'Attack',
            assetPath: 'image/button_attack.png',
            fillColor: redTier[4],
            outlineColor: redTier[1],
            bottomOffset: _btnRadius * 0.8,
            rightOffset: _btnRadius * 4.9,
            imageScale: 2.6845,
            imageOffset: Offset(0, _btnRadius * 0.15),
          ),
          _buildActionButton(
            mode: WarActionMode.defense,
            label: 'Defense',
            assetPath: 'image/button_defense.png',
            fillColor: yellowTier[4],
            outlineColor: yellowTier[1],
            bottomOffset: _btnRadius * 1.4,
            rightOffset: _btnRadius * 2.65,
            imageScale: 2.016,
            imageOffset: Offset(_btnRadius * 0.03, _btnRadius * 0.31),
          ),
          _buildActionButton(
            mode: WarActionMode.target,
            label: 'Target',
            assetPath: 'image/button_target.png',
            fillColor: blueTier[4],
            outlineColor: blueTier[1],
            bottomOffset: _btnRadius * 2.4,
            rightOffset: _btnRadius * 0.5,
            imageScale: 1.694,
            imageOffset: Offset(_btnRadius * 0.07, 0),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: _game.gameOver,
            builder: (BuildContext context, bool isOver, Widget? child) {
              if (!isOver) return const SizedBox.shrink();
              return Container(
                color: Colors.black.withValues(alpha: 0.72),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        'GAME OVER',
                        style:
                            Theme.of(context).textTheme.displaySmall?.copyWith(
                                  color: Colors.redAccent.shade100,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 6,
                                ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          FilledButton.icon(
                            onPressed: _restart,
                            icon: const Icon(Icons.refresh, size: 20),
                            label: const Text('Restart'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 14),
                              textStyle: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 16),
                          OutlinedButton.icon(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.home_outlined, size: 20),
                            label: const Text('Back to Menu'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white38),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 14),
                              textStyle: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
