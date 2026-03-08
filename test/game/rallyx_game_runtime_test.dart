import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallyx_modern/game/input/keyboard_input_source.dart';
import 'package:rallyx_modern/game/rallyx_game.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('fuel depletion triggers game over and restart clears state', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final inputSource = KeyboardInputSource();
    final game = RallyXGame(inputSource: inputSource);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GameWidget<RallyXGame>(game: game)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(game.playerCar, isNotNull);
    expect(game.isGameOver, isFalse);

    game.fuel = 0.01;
    await tester.pump(const Duration(milliseconds: 200));

    expect(game.isGameOver, isTrue);
    expect(game.gameOverReason, isNotEmpty);

    game.requestRestart();
    await tester.pump(const Duration(milliseconds: 700));

    expect(game.isGameOver, isFalse);
    expect(game.currentStage, 1);
    expect(game.fuel, greaterThan(0));
  });

  testWidgets('debugCollectAllFlags advances stage and refills fuel', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final inputSource = KeyboardInputSource();
    final game = RallyXGame(inputSource: inputSource);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GameWidget<RallyXGame>(game: game)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    final initialStage = game.currentStage;
    game.fuel = 1.0;

    await game.debugCollectAllFlags();
    await tester.pump(const Duration(milliseconds: 700));

    expect(game.currentStage, initialStage + 1);
    expect(game.fuel, greaterThan(50));
    expect(game.isGameOver, isFalse);
  });

  testWidgets('enemy count scales with stage and caps at spawn count', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final inputSource = KeyboardInputSource();
    final game = RallyXGame(inputSource: inputSource);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GameWidget<RallyXGame>(game: game)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(game.currentStage, 1);
    expect(game.currentEnemySpawnCount, 2);

    await game.debugSkipStage();
    await tester.pump(const Duration(milliseconds: 600));
    expect(game.currentStage, 2);
    expect(game.currentEnemySpawnCount, 3);

    await game.debugSkipStage();
    await tester.pump(const Duration(milliseconds: 600));
    expect(game.currentStage, 3);
    expect(game.currentEnemySpawnCount, 4);

    await game.debugSkipStage();
    await tester.pump(const Duration(milliseconds: 600));
    expect(game.currentStage, 4);
    expect(game.currentEnemySpawnCount, 4);
  });

  testWidgets('debug enemy override forces active enemy count', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final inputSource = KeyboardInputSource();
    final game = RallyXGame(
      inputSource: inputSource,
      debugEnemyCountOverride: 1,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GameWidget<RallyXGame>(game: game)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(game.currentEnemySpawnCount, 1);

    await game.debugSkipStage();
    await tester.pump(const Duration(milliseconds: 600));
    expect(game.currentStage, 2);
    expect(game.currentEnemySpawnCount, 1);
  });

  testWidgets('player does not rotate while stopped', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final inputSource = KeyboardInputSource();
    final game = RallyXGame(inputSource: inputSource);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GameWidget<RallyXGame>(game: game)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));

    final player = game.playerCar;
    expect(player, isNotNull);
    final initialAngle = player!.body.angle;

    inputSource.handleKeyEvent(
      const KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.arrowLeft,
        logicalKey: LogicalKeyboardKey.arrowLeft,
        timeStamp: Duration.zero,
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));

    final stoppedAngleDelta = (player.body.angle - initialAngle).abs();
    expect(stoppedAngleDelta, lessThan(0.02));

    inputSource.clear();
  });

  testWidgets('player speed is capped at tuned lower top speed', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final inputSource = KeyboardInputSource();
    final game = RallyXGame(inputSource: inputSource);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GameWidget<RallyXGame>(game: game)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));

    inputSource.handleKeyEvent(
      const KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.arrowUp,
        logicalKey: LogicalKeyboardKey.arrowUp,
        timeStamp: Duration.zero,
      ),
    );
    await tester.pump(const Duration(milliseconds: 2200));

    expect(game.playerCar, isNotNull);
    expect(game.playerCar!.speed, lessThanOrEqualTo(4.3));

    inputSource.clear();
  });
}
