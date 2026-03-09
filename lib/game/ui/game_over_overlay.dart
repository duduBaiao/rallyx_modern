import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rallyx_modern/game/rallyx_game.dart';

class GameOverOverlay extends StatefulWidget {
  const GameOverOverlay({super.key, required this.game});

  static const String id = 'game_over_overlay';

  final RallyXGame game;

  @override
  State<GameOverOverlay> createState() => _GameOverOverlayState();
}

class _GameOverOverlayState extends State<GameOverOverlay> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
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
    if (!widget.game.isGameOver) {
      return const SizedBox.shrink();
    }

    return ColoredBox(
      color: const Color(0x9F000000),
      child: Center(
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            border: Border.all(color: const Color(0xFF3A4454)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'GAME OVER',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.game.gameOverReason,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 14),
              Text(
                'Survival: ${widget.game.survivalTime.toStringAsFixed(1)}s',
                style: const TextStyle(color: Colors.white),
              ),
              Text(
                'Score: ${widget.game.score.toStringAsFixed(1)}',
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Top 10 (Total Score)',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 6),
              ...widget.game.topScores.take(10).toList().asMap().entries.map((
                entry,
              ) {
                final rank = entry.key + 1;
                final score = entry.value;
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '$rank. ${score.totalScore.toStringAsFixed(1)} pts (Surv ${score.survivalSeconds.toStringAsFixed(1)}s, Stage ${score.stageReached})',
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              }),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: widget.game.requestRestart,
                child: const Text('Restart (R)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
