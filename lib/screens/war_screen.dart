import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/cohort_war_game.dart';
import '../models/cohort_models.dart';
import '../models/soldier_design_palette.dart';
import '../models/soldier_faction_color_theme.dart';
import '../widgets/virtual_joystick.dart';

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

class _WarScreenState extends State<WarScreen>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<Vector2> _velocityHud =
      ValueNotifier<Vector2>(Vector2.zero());
  final ValueNotifier<Vector2> _soldier1PosHud =
      ValueNotifier<Vector2>(Vector2.zero());

  late CohortWarGame _game;
  Key _gameKey = UniqueKey();
  WarActionMode _actionMode = WarActionMode.defense;
  WarActionMode _preTargetMode = WarActionMode.defense;
  WarActionMode? _pressedButton;
  late final AnimationController _glowCtrl;

  static const double _btnRadius = 44.8;
  static const double _btnDiameter = _btnRadius * 2;

  void _selectMode(WarActionMode mode) {
    if (_actionMode == mode) return;
    if (mode == WarActionMode.target && _actionMode != WarActionMode.target) {
      _preTargetMode = _actionMode;
    }
    setState(() => _actionMode = mode);
    _game.setActionMode(mode);
  }

  void _revertFromTarget() {
    if (_actionMode != WarActionMode.target) return;
    setState(() => _actionMode = _preTargetMode);
    _game.setActionMode(_preTargetMode);
  }

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _glowCtrl.repeat();
    _game = _createGame();
  }

  CohortWarGame _createGame() {
    return CohortWarGame(
      deployment: widget.deployment.copy(),
      playerPalette: widget.playerPalette,
      velocityHud: _velocityHud,
      soldier1PosHud: _soldier1PosHud,
      onTargetAssigned: () => _selectMode(WarActionMode.target),
      onTargetCleared: () => _revertFromTarget(),
    );
  }

  void _restart() {
    setState(() {
      _game = _createGame();
      _game.setActionMode(WarActionMode.defense);
      _gameKey = UniqueKey();
      _actionMode = WarActionMode.defense;
      _preTargetMode = WarActionMode.defense;
    });
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
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
            onTapUp: (_) {
              setState(() => _pressedButton = null);
              _selectMode(mode);
            },
            onTapCancel: () => setState(() => _pressedButton = null),
            child: AnimatedBuilder(
              animation: _glowCtrl,
              builder: (BuildContext context, Widget? child) {
                final double rawT = _glowCtrl.value;
                final double pulseT = selected
                    ? (rawT < 0.5 ? rawT * 2 : 2.0 - rawT * 2)
                    : 0;
                final double glowOpacity = pulseT * 0.8;
                final double glowSpread = pulseT * 14;
                return CustomPaint(
                  painter: selected
                      ? _ButtonBurstPainter(
                          t: rawT,
                          color: outlineColor,
                          radius: size / 2,
                        )
                      : null,
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
                      boxShadow: glowOpacity > 0
                          ? <BoxShadow>[
                              BoxShadow(
                                color: outlineColor.withValues(alpha: glowOpacity * 0.95),
                                blurRadius: 16 + glowSpread,
                                spreadRadius: glowSpread,
                              ),
                            ]
                          : null,
                    ),
                    child: child,
                  ),
                );
              },
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
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: ValueListenableBuilder<int>(
                valueListenable: _game.killCountRevision,
                builder: (BuildContext context, int _, Widget? child) {
                  String fmt(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}k' : '$n';
                  final int r = _game.killCounts[SoldierDesignPalette.red] ?? 0;
                  final int y = _game.killCounts[SoldierDesignPalette.yellow] ?? 0;
                  final int b = _game.killCounts[SoldierDesignPalette.blue] ?? 0;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    color: Colors.black.withValues(alpha: 0.45),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text('Red: ${fmt(r)}',
                          style: TextStyle(color: kRedFactionComponentColors[0], fontSize: 14, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 32),
                        Text('Yellow: ${fmt(y)}',
                          style: TextStyle(color: kYellowFactionComponentColors[0], fontSize: 14, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 32),
                        Text('Blue: ${fmt(b)}',
                          style: TextStyle(color: kBlueFactionComponentColors[0], fontSize: 14, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: _game.playerEliminated,
            builder: (BuildContext context, bool eliminated, Widget? child) {
              return Positioned(
                left: 24,
                bottom: 24,
                child: SafeArea(
                  child: IgnorePointer(
                    ignoring: eliminated,
                    child: Opacity(
                      opacity: eliminated ? 0.35 : 1.0,
                      child: VirtualJoystick(
                        outerRadius: 72,
                        knobRadius: 28,
                        onChanged: (Offset o) => _game.setStick(o),
                        baseColor: eliminated ? const Color(0x22888888) : const Color(0x33FFFFFF),
                        ringColor: eliminated ? const Color(0x44888888) : const Color(0x88FFFFFF),
                        knobColor: eliminated ? const Color(0x66888888) : const Color(0xE6FFFFFF),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          ValueListenableBuilder<bool>(
            valueListenable: _game.playerEliminated,
            builder: (BuildContext context, bool eliminated, Widget? child) {
              return IgnorePointer(
                ignoring: eliminated,
                child: Opacity(
                  opacity: eliminated ? 0.35 : 1.0,
                  child: Stack(
                    children: <Widget>[
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
                    ],
                  ),
                ),
              );
            },
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

class _ButtonBurstPainter extends CustomPainter {
  _ButtonBurstPainter({
    required this.t,
    required this.color,
    required this.radius,
  });

  final double t;
  final Color color;
  final double radius;

  static const int _particleCount = 10;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double orbitR = radius + 8;

    for (int i = 0; i < _particleCount; i++) {
      final double baseAngle = (i / _particleCount) * 2 * math.pi;
      final double angle = baseAngle + t * 2 * math.pi;

      final double wobble = 1.0 + 0.15 * math.sin(t * 4 * math.pi + i * 1.3);
      final double dist = orbitR * wobble;

      final double px = center.dx + math.cos(angle) * dist;
      final double py = center.dy + math.sin(angle) * dist;

      final double pulse = 0.6 + 0.4 * math.sin(t * 2 * math.pi + i * 0.9);
      final double particleSize = (2.0 + 1.5 * ((i * 3) % 4)) * pulse;
      final double alpha = 0.4 + 0.4 * pulse;

      canvas.drawCircle(
        Offset(px, py),
        particleSize,
        Paint()..color = color.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(_ButtonBurstPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.color != color;
}
