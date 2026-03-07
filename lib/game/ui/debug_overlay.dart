import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rallyx_modern/game/config/game_config.dart';
import 'package:rallyx_modern/game/rallyx_game.dart';

class DebugOverlay extends StatefulWidget {
  const DebugOverlay({super.key, required this.game});

  static const String id = 'debug_overlay';

  final RallyXGame game;

  @override
  State<DebugOverlay> createState() => _DebugOverlayState();
}

class _DebugOverlayState extends State<DebugOverlay> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cmd = widget.game.currentCommand;

    final textStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: Colors.white);

    return SafeArea(
      child: Align(
        alignment: Alignment.topLeft,
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(12),
          color: const Color(0xCC000000),
          child: DefaultTextStyle(
            style: textStyle ?? const TextStyle(color: Colors.white),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Debug Overlay'),
                const Text('Toggle: F3'),
                const SizedBox(height: 8),
                const Text('Controls: Arrow keys + Space(smoke)'),
                const Text('Debug keys: R(restart), N(skip), G(game over)'),
                Text('Target FPS: ${GameConfig.targetFps}'),
                Text('FPS: ${widget.game.fps.toStringAsFixed(1)}'),
                const Text('Physics step: 1/60 s fixed'),
                const SizedBox(height: 8),
                Text('State: ${widget.game.runState}'),
                Text('Stage: ${widget.game.currentStage}'),
                Text('Seed: ${widget.game.currentSeed}'),
                Text('Flags: ${widget.game.currentFlagCount}'),
                Text('Remaining flags: ${widget.game.remainingFlagCount}'),
                Text('Enemy spawns: ${widget.game.currentEnemySpawnCount}'),
                const SizedBox(height: 8),
                Text('Fuel: ${widget.game.fuelPercent.toStringAsFixed(1)}%'),
                Text(
                  'Survival: ${widget.game.survivalTime.toStringAsFixed(1)}s',
                ),
                Text('Score: ${widget.game.score.toStringAsFixed(1)}'),
                const SizedBox(height: 8),
                Text('Speed: ${widget.game.playerSpeed.toStringAsFixed(2)}'),
                Text('Throttle: ${cmd.throttle.toStringAsFixed(2)}'),
                Text('Brake: ${cmd.brake.toStringAsFixed(2)}'),
                Text('Steering: ${cmd.steering.toStringAsFixed(2)}'),
                Text('Smoke: ${cmd.smoke ? 'ON' : 'OFF'}'),
                if (widget.game.isGameOver)
                  Text('Game over: ${widget.game.gameOverReason}'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
