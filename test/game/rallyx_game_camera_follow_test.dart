import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallyx_modern/game/input/keyboard_input_source.dart';
import 'package:rallyx_modern/game/rallyx_game.dart';
import 'package:rallyx_modern/game/ui/hud_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('camera position follows player in 80/20 layout', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final game = RallyXGame(inputSource: KeyboardInputSource());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                Expanded(flex: 8, child: GameWidget<RallyXGame>(game: game)),
                Expanded(flex: 2, child: HudOverlay(game: game)),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 900));

    final player = game.playerCar;
    expect(player, isNotNull);

    final initialDelta =
        (game.camera.viewfinder.position - player!.body.position).length;
    expect(initialDelta, lessThan(0.25));

    player.body.setTransform(
      player.body.position + Vector2(2.0, 1.5),
      player.body.angle,
    );
    await tester.pump(const Duration(milliseconds: 200));

    final movedDelta =
        (game.camera.viewfinder.position - player.body.position).length;
    expect(movedDelta, lessThan(0.25));
  });
}
