import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallyx_modern/game/config/game_config.dart';
import 'package:rallyx_modern/game/input/keyboard_input_source.dart';
import 'package:rallyx_modern/game/level/level_data.dart';
import 'package:rallyx_modern/game/level/level_provider.dart';
import 'package:rallyx_modern/game/rallyx_game.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'fuel depletion while moving triggers game over and restart clears state',
    (WidgetTester tester) async {
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

      game.playerCar!.body.linearVelocity = Vector2(1.2, 0);
      game.fuel = 0.01;
      await tester.pump(const Duration(milliseconds: 200));

      expect(game.isGameOver, isTrue);
      expect(game.gameOverReason, isNotEmpty);

      game.requestRestart();
      await tester.pump(const Duration(milliseconds: 700));

      expect(game.isGameOver, isFalse);
      expect(game.currentStage, 1);
      expect(game.fuel, greaterThan(0));
    },
  );

  testWidgets('fuel drains at reduced rate while player is idle', (
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
    final fuelBefore = game.fuel;

    await tester.pump(const Duration(milliseconds: 400));

    final expectedIdleDrain =
        GameConfig.fuelDrainPerSecond * GameConfig.idleFuelDrainFactor * 0.4;
    expect(game.fuel, closeTo(fuelBefore - expectedIdleDrain, 0.2));
  });

  testWidgets('moving drains more fuel than idling', (
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
    final fuelAtStart = game.fuel;

    await tester.pump(const Duration(milliseconds: 400));
    final fuelAfterIdle = game.fuel;
    final idleDrain = fuelAtStart - fuelAfterIdle;

    game.playerCar!.body.linearVelocity = Vector2(1.2, 0);
    await tester.pump(const Duration(milliseconds: 400));
    final movingDrain = fuelAfterIdle - game.fuel;

    expect(idleDrain, greaterThan(0));
    expect(movingDrain, greaterThan(idleDrain));
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

  testWidgets('mounted enemies are not pruned during runtime updates', (
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

    expect(game.currentStage, 1);
    expect(game.currentEnemySpawnCount, 2);

    await tester.pump(const Duration(seconds: 2));
    expect(game.currentStage, 1);
    expect(game.currentEnemySpawnCount, 2);
  });

  testWidgets('fills missing enemy spawns when provider returns one spawn', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final inputSource = KeyboardInputSource();
    final game = RallyXGame(
      inputSource: inputSource,
      levelProvider: _SingleSpawnLevelProvider(baseLevel: _buildOpenLevel()),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GameWidget<RallyXGame>(game: game)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));

    expect(game.currentStage, 1);
    expect(game.currentEnemySpawnCount, 2);
    expect(game.debugActiveEnemies.length, 2);
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

class _SingleSpawnLevelProvider implements LevelProvider {
  const _SingleSpawnLevelProvider({required this.baseLevel});

  final LevelData baseLevel;

  @override
  LevelData loadLevel({required int stage, required int seed}) {
    return LevelData(
      stage: stage,
      seed: seed,
      width: baseLevel.width,
      height: baseLevel.height,
      tiles: baseLevel.tiles
          .map((row) => List<TileKind>.from(row, growable: false))
          .toList(growable: false),
      playerSpawn: baseLevel.playerSpawn,
      enemySpawns: baseLevel.enemySpawns,
      flags: baseLevel.flags,
    );
  }
}

LevelData _buildOpenLevel() {
  const width = 41;
  const height = 41;
  final tiles = List<List<TileKind>>.generate(height, (y) {
    return List<TileKind>.generate(width, (x) {
      final border = x == 0 || y == 0 || x == width - 1 || y == height - 1;
      return border ? TileKind.wall : TileKind.road;
    });
  });

  return LevelData(
    stage: 1,
    seed: 0,
    width: width,
    height: height,
    tiles: tiles,
    playerSpawn: const TileCoordinate(5, 35),
    enemySpawns: const [TileCoordinate(35, 5)],
    flags: const [],
  );
}
