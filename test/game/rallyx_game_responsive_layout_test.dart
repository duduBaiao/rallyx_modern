import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallyx_modern/game/config/game_config.dart';
import 'package:rallyx_modern/game/input/keyboard_input_source.dart';
import 'package:rallyx_modern/game/rallyx_game.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('larger viewport scales procedural playfield dimensions', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(3200, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final game = RallyXGame(inputSource: KeyboardInputSource());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GameWidget<RallyXGame>(game: game)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 900));

    final level = game.currentLevel;
    expect(level, isNotNull);
    expect(level!.width, greaterThan(GameConfig.playfieldTilesWide));
    expect(level.height, greaterThan(GameConfig.playfieldTilesHigh));
    expect(
      (level.width - GameConfig.proceduralDimensionOffset) %
          GameConfig.proceduralDimensionStep,
      0,
    );
    expect(
      (level.height - GameConfig.proceduralDimensionOffset) %
          GameConfig.proceduralDimensionStep,
      0,
    );
  });

  testWidgets('smaller viewport keeps baseline procedural dimensions', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final game = RallyXGame(inputSource: KeyboardInputSource());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GameWidget<RallyXGame>(game: game)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 900));

    final level = game.currentLevel;
    expect(level, isNotNull);
    expect(level!.width, GameConfig.playfieldTilesWide);
    expect(level.height, GameConfig.playfieldTilesHigh);
  });
}
