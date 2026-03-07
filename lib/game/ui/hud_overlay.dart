import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rallyx_modern/game/config/game_config.dart';
import 'package:rallyx_modern/game/level/level_data.dart';
import 'package:rallyx_modern/game/rallyx_game.dart';

class HudOverlay extends StatefulWidget {
  const HudOverlay({super.key, required this.game});

  static const String id = 'hud_overlay';

  final RallyXGame game;

  @override
  State<HudOverlay> createState() => _HudOverlayState();
}

class _HudOverlayState extends State<HudOverlay> {
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
    final level = widget.game.currentLevel;
    final fuelRatio = (widget.game.fuel / GameConfig.maxFuel).clamp(0, 1);

    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Container(
          width: 250,
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xCC0B0D12),
            border: Border.all(color: const Color(0xFF30394A)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'RALLY-X MODERN',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 10),
              _valueLine('Stage', '${widget.game.currentStage}'),
              _valueLine('State', widget.game.runState),
              _valueLine(
                'Survival',
                '${widget.game.survivalTime.toStringAsFixed(1)}s',
              ),
              _valueLine('Score', widget.game.score.toStringAsFixed(1)),
              _valueLine('Flags Left', '${widget.game.remainingFlagCount}'),
              const SizedBox(height: 10),
              const Text('Fuel', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  minHeight: 10,
                  value: fuelRatio.toDouble(),
                  backgroundColor: const Color(0xFF232A36),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    fuelRatio > 0.35
                        ? const Color(0xFF58D66B)
                        : const Color(0xFFEA5D5D),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Minimap', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 6),
              AspectRatio(
                aspectRatio: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0E14),
                    border: Border.all(color: const Color(0xFF30394A)),
                  ),
                  child: level == null
                      ? const SizedBox.shrink()
                      : CustomPaint(
                          painter: _MinimapPainter(
                            level: level,
                            player: widget.game.playerTile,
                            enemies: widget.game.enemyTiles,
                            flags: widget.game.remainingFlags,
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

  Widget _valueLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text.rich(
        TextSpan(
          text: '$label: ',
          style: const TextStyle(color: Colors.white70),
          children: [
            TextSpan(
              text: value,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _MinimapPainter extends CustomPainter {
  _MinimapPainter({
    required this.level,
    required this.player,
    required this.enemies,
    required this.flags,
  });

  final LevelData level;
  final TileCoordinate? player;
  final List<TileCoordinate> enemies;
  final List<FlagSpawn> flags;

  final Paint _wallPaint = Paint()..color = const Color(0xFF313A49);
  final Paint _rockPaint = Paint()..color = const Color(0xFF6A7382);
  final Paint _playerPaint = Paint()..color = const Color(0xFF3CA0FF);
  final Paint _enemyPaint = Paint()..color = const Color(0xFFE76565);
  final Paint _flagPaint = Paint()..color = const Color(0xFFF2E85A);
  final Paint _specialFlagPaint = Paint()..color = const Color(0xFFFC6A6A);

  @override
  void paint(Canvas canvas, Size size) {
    final tileW = size.width / level.width;
    final tileH = size.height / level.height;

    for (var y = 0; y < level.height; y++) {
      for (var x = 0; x < level.width; x++) {
        final kind = level.tileAt(x, y);
        final rect = Rect.fromLTWH(x * tileW, y * tileH, tileW, tileH);
        if (kind == TileKind.wall) {
          canvas.drawRect(rect, _wallPaint);
        } else if (kind == TileKind.rock) {
          canvas.drawOval(rect.deflate(tileW * 0.2), _rockPaint);
        }
      }
    }

    for (final flag in flags) {
      final rect = Rect.fromLTWH(
        flag.tile.x * tileW + tileW * 0.2,
        flag.tile.y * tileH + tileH * 0.2,
        tileW * 0.6,
        tileH * 0.6,
      );
      canvas.drawRect(rect, flag.isSpecial ? _specialFlagPaint : _flagPaint);
    }

    for (final enemy in enemies) {
      final center = Offset((enemy.x + 0.5) * tileW, (enemy.y + 0.5) * tileH);
      canvas.drawCircle(center, tileW * 0.3, _enemyPaint);
    }

    final p = player;
    if (p != null) {
      final center = Offset((p.x + 0.5) * tileW, (p.y + 0.5) * tileH);
      canvas.drawCircle(center, tileW * 0.35, _playerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MinimapPainter oldDelegate) => true;
}
