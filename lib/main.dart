import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:rallyx_modern/game/input/keyboard_input_source.dart';
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
    final game = RallyXGame(inputSource: KeyboardInputSource());

    return MaterialApp(
      title: 'Rally-X Modern',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              Expanded(
                flex: 8,
                child: GameWidget<RallyXGame>(
                  game: game,
                  overlayBuilderMap: {
                    GameOverOverlay.id: (context, game) =>
                        GameOverOverlay(game: game),
                    DebugOverlay.id: (context, game) =>
                        DebugOverlay(game: game),
                  },
                  initialActiveOverlays: const [GameOverOverlay.id],
                ),
              ),
              Expanded(flex: 2, child: HudOverlay(game: game)),
            ],
          ),
        ),
      ),
    );
  }
}
