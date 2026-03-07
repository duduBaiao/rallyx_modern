import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:rallyx_modern/game/rallyx_game.dart';
import 'package:rallyx_modern/game/ui/debug_overlay.dart';

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
            DebugOverlay.id: (context, game) => DebugOverlay(game: game),
          },
        ),
      ),
    );
  }
}
