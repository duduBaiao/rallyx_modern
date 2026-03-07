import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:rallyx_modern/game/rallyx_game.dart';
import 'package:rallyx_modern/game/ui/debug_overlay.dart';
import 'package:rallyx_modern/game/ui/game_over_overlay.dart';
import 'package:rallyx_modern/game/ui/hud_overlay.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RallyXApp());
}

class RallyXApp extends StatelessWidget {
  const RallyXApp({super.key});

  @override
  Widget build(BuildContext context) {
    final game = RallyXGame();

    return MaterialApp(
      title: 'Rally-X Modern',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: GameWidget<RallyXGame>(
          game: game,
          overlayBuilderMap: {
            HudOverlay.id: (context, game) => HudOverlay(game: game),
            GameOverOverlay.id: (context, game) => GameOverOverlay(game: game),
            DebugOverlay.id: (context, game) => DebugOverlay(game: game),
          },
          initialActiveOverlays: const [HudOverlay.id, GameOverOverlay.id],
        ),
      ),
    );
  }
}
