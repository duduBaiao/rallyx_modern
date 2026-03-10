import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
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
    final fuelPercent = widget.game.fuelPercent;
    final fuelProgress = (fuelPercent / 100).clamp(0.0, 1.0);

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFF0A0E14),
        border: Border(left: BorderSide(color: Color(0xFF30394A))),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final minimapAspect = level == null
                ? 1.0
                : level.width / level.height;
            const headerHeight = 68.0;
            const gapBeforeMinimap = 12.0;
            final minimapMaxHeight = math.max(
              0.0,
              constraints.maxHeight - headerHeight - gapBeforeMinimap,
            );
            final minimapHeightForWidth = constraints.maxWidth / minimapAspect;
            final minimapHeight = math.min(
              minimapMaxHeight,
              minimapHeightForWidth,
            );
            final minimapWidth = minimapHeight * minimapAspect;

            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Fuel',
                        style: TextStyle(
                          color: Color(0xFFB8C2D1),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${fuelPercent.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Color(0xFFE6EDF7),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 8,
                      child: LinearProgressIndicator(
                        value: fuelProgress,
                        backgroundColor: const Color(0xFF253041),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _fuelColorForProgress(fuelProgress),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text(
                        'Survival',
                        style: TextStyle(
                          color: Color(0xFFB8C2D1),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              '${widget.game.survivalTime.toStringAsFixed(1)}s',
                              style: const TextStyle(
                                color: Color(0xFFE6EDF7),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: gapBeforeMinimap),
                  Align(
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: minimapWidth,
                      height: minimapHeight,
                      child: level == null
                          ? const SizedBox.shrink()
                          : CustomPaint(
                              painter: _MinimapPainter(
                                level: level,
                                player: widget.game.playerTile,
                                enemies: widget.game.enemyTiles,
                                flags: widget.game.remainingFlags,
                              ),
                              child: const SizedBox.expand(),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Color _fuelColorForProgress(double progress) {
    if (progress <= 0.2) {
      return const Color(0xFFE75A5A);
    }
    if (progress <= 0.5) {
      return const Color(0xFFF2C94C);
    }
    return const Color(0xFF46C67A);
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
  final Paint _specialFlagPaint = Paint()..color = const Color(0xFF46C67A);

  @override
  void paint(Canvas canvas, Size size) {
    final tileW = size.width / level.width;
    final tileH = size.height / level.height;
    final tileMin = tileW < tileH ? tileW : tileH;

    for (var y = 0; y < level.height; y++) {
      for (var x = 0; x < level.width; x++) {
        final kind = level.tileAt(x, y);
        final rect = Rect.fromLTWH(x * tileW, y * tileH, tileW, tileH);
        if (kind == TileKind.wall) {
          canvas.drawRect(rect, _wallPaint);
        } else if (kind == TileKind.rock) {
          canvas.drawOval(rect.deflate(tileMin * 0.2), _rockPaint);
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
      canvas.drawCircle(center, tileMin * 0.3, _enemyPaint);
    }

    final p = player;
    if (p != null) {
      final center = Offset((p.x + 0.5) * tileW, (p.y + 0.5) * tileH);
      canvas.drawCircle(center, tileMin * 0.35, _playerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MinimapPainter oldDelegate) => true;
}
