import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/cohort_war_game.dart';
import '../models/cohort_models.dart';
import '../models/soldier_design_palette.dart';
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

class _WarScreenState extends State<WarScreen> {
  final ValueNotifier<Vector2> _velocityHud =
      ValueNotifier<Vector2>(Vector2.zero());
  final ValueNotifier<Vector2> _soldier1PosHud =
      ValueNotifier<Vector2>(Vector2.zero());

  late CohortWarGame _game;
  Key _gameKey = UniqueKey();

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
    );
  }

  void _restart() {
    setState(() {
      _game = _createGame();
      _gameKey = UniqueKey();
    });
  }

  @override
  void dispose() {
    _velocityHud.dispose();
    _soldier1PosHud.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: <Widget>[
          GameWidget<CohortWarGame>(key: _gameKey, game: _game),
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
