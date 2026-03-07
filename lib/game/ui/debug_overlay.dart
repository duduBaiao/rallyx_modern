import 'package:flutter/material.dart';
import 'package:rallyx_modern/game/config/game_config.dart';
import 'package:rallyx_modern/game/rallyx_game.dart';

class DebugOverlay extends StatelessWidget {
  const DebugOverlay({super.key, required this.game});

  static const String id = 'debug_overlay';

  final RallyXGame game;

  @override
  Widget build(BuildContext context) {
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
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Debug Overlay (Scaffold)'),
                Text('Toggle: F3'),
                SizedBox(height: 8),
                Text('Target FPS: ${GameConfig.targetFps}'),
                Text('Physics step: 1/60 s fixed'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
