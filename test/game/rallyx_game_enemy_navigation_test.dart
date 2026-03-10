import 'package:flame/game.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallyx_modern/game/input/keyboard_input_source.dart';
import 'package:rallyx_modern/game/level/level_data.dart';
import 'package:rallyx_modern/game/level/level_provider.dart';
import 'package:rallyx_modern/game/rallyx_game.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('enemy traverses many tiles and avoids long stuck periods', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final inputSource = KeyboardInputSource();
    final game = RallyXGame(
      inputSource: inputSource,
      levelProvider: _StaticLevelProvider(
        baseLevel: _buildOpenLevel(
          playerSpawn: const TileCoordinate(4, 60),
          enemySpawns: const [TileCoordinate(60, 4)],
        ),
      ),
      debugEnemyCountOverride: 1,
      initialSeed: 7,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GameWidget<RallyXGame>(game: game)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 900));

    expect(game.currentEnemySpawnCount, 1);
    final uniqueTiles = <TileCoordinate>{};
    TileCoordinate? previousTile;
    var sameTileSeconds = 0.0;
    var maxSameTileSeconds = 0.0;

    for (var i = 0; i < 40; i++) {
      expect(game.isGameOver, isFalse);
      final enemies = game.enemyTiles;
      expect(enemies, isNotEmpty);
      final tile = enemies.first;
      uniqueTiles.add(tile);

      if (previousTile != null && previousTile == tile) {
        sameTileSeconds += 0.2;
      } else {
        sameTileSeconds = 0;
        previousTile = tile;
      }
      if (sameTileSeconds > maxSameTileSeconds) {
        maxSameTileSeconds = sameTileSeconds;
      }

      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(uniqueTiles.length, greaterThanOrEqualTo(12));
    expect(maxSameTileSeconds, lessThan(1.8));
  });

  testWidgets('smoke still stuns enemies', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final inputSource = KeyboardInputSource();
    final game = RallyXGame(
      inputSource: inputSource,
      levelProvider: _StaticLevelProvider(baseLevel: _buildOpenLevel()),
      debugEnemyCountOverride: 1,
      initialSeed: 11,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GameWidget<RallyXGame>(game: game)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 900));

    expect(game.playerCar, isNotNull);
    final enemies = game.debugActiveEnemies;
    expect(enemies, isNotEmpty);
    final enemy = enemies.first;

    final fuelBeforeSmoke = game.fuel;
    game.debugDeploySmoke();
    await tester.pump(const Duration(milliseconds: 40));
    expect(game.fuel, lessThan(fuelBeforeSmoke));

    var cloudVisible = false;
    for (var i = 0; i < 8; i++) {
      if (game.debugSmokeCloudPositions.isNotEmpty) {
        cloudVisible = true;
        break;
      }
      await tester.pump(const Duration(milliseconds: 30));
    }
    expect(cloudVisible, isTrue);
    final player = game.playerCar!;
    player.body.setTransform(player.body.position + Vector2(4, 0), player.body.angle);
    player.body.linearVelocity = Vector2.zero();
    player.body.angularVelocity = 0;

    var stunned = false;
    for (var i = 0; i < 6; i++) {
      final smokePosition = game.debugSmokeCloudPositions.first;
      enemy.body.setTransform(smokePosition, enemy.body.angle);
      enemy.body.linearVelocity = Vector2.zero();
      enemy.body.angularVelocity = 0;
      await tester.pump(const Duration(milliseconds: 30));
      if (enemy.stunRemaining > 0) {
        stunned = true;
        break;
      }
    }
    await tester.pump(const Duration(milliseconds: 80));

    expect(stunned, isTrue);
    expect(enemy.stunRemaining, greaterThan(0));
    expect(game.isGameOver, isFalse);
  });

  testWidgets('enemy contact still triggers game over', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final inputSource = KeyboardInputSource();
    final game = RallyXGame(
      inputSource: inputSource,
      levelProvider: _StaticLevelProvider(baseLevel: _buildOpenLevel()),
      debugEnemyCountOverride: 1,
      initialSeed: 12,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GameWidget<RallyXGame>(game: game)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 900));

    final player = game.playerCar;
    expect(player, isNotNull);
    final enemy = game.debugActiveEnemies.first;

    enemy.stun(1.5);
    enemy.body.setTransform(player!.body.position, enemy.body.angle);
    enemy.body.linearVelocity = Vector2.zero();
    enemy.body.angularVelocity = 0;
    await tester.pump(const Duration(milliseconds: 20));

    expect(game.isGameOver, isTrue);
    expect(game.gameOverReason, 'Hit by Robo-Taxi');
    expect(game.topScores, isNotEmpty);
  });

  testWidgets('side body contact triggers game over', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final inputSource = KeyboardInputSource();
    final game = RallyXGame(
      inputSource: inputSource,
      levelProvider: _StaticLevelProvider(baseLevel: _buildOpenLevel()),
      debugEnemyCountOverride: 1,
      initialSeed: 13,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GameWidget<RallyXGame>(game: game)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 900));

    final player = game.playerCar;
    expect(player, isNotNull);
    final enemy = game.debugActiveEnemies.first;

    enemy.stun(1.5);
    player!.body.setTransform(player.body.position, 0);
    final sideTouchPosition = player.body.position + Vector2(0, 0.75);
    enemy.body.setTransform(sideTouchPosition, 0);
    enemy.body.linearVelocity = Vector2.zero();
    enemy.body.angularVelocity = 0;

    // Body centers are farther than old 0.70 threshold but still overlapping.
    expect((enemy.body.position - player.body.position).length, greaterThan(0.70));

    await tester.pump(const Duration(milliseconds: 20));
    expect(game.isGameOver, isTrue);
    expect(game.gameOverReason, 'Hit by Robo-Taxi');
  });
}

class _StaticLevelProvider implements LevelProvider {
  const _StaticLevelProvider({required this.baseLevel});

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

LevelData _buildOpenLevel({
  TileCoordinate playerSpawn = const TileCoordinate(3, 57),
  List<TileCoordinate> enemySpawns = const [TileCoordinate(57, 3)],
}) {
  const width = 65;
  const height = 65;
  final tiles = List<List<TileKind>>.generate(height, (y) {
    return List<TileKind>.generate(width, (x) {
      final border = x == 0 || y == 0 || x == width - 1 || y == height - 1;
      return border ? TileKind.wall : TileKind.road;
    });
  });

  const flags = <FlagSpawn>[
    FlagSpawn(tile: TileCoordinate(10, 10), isSpecial: true),
    FlagSpawn(tile: TileCoordinate(14, 14), isSpecial: false),
    FlagSpawn(tile: TileCoordinate(18, 18), isSpecial: false),
    FlagSpawn(tile: TileCoordinate(22, 22), isSpecial: false),
    FlagSpawn(tile: TileCoordinate(26, 26), isSpecial: false),
    FlagSpawn(tile: TileCoordinate(30, 30), isSpecial: false),
    FlagSpawn(tile: TileCoordinate(34, 34), isSpecial: false),
    FlagSpawn(tile: TileCoordinate(38, 38), isSpecial: false),
    FlagSpawn(tile: TileCoordinate(42, 42), isSpecial: false),
    FlagSpawn(tile: TileCoordinate(46, 46), isSpecial: false),
  ];

  return LevelData(
    stage: 1,
    seed: 0,
    width: width,
    height: height,
    tiles: tiles,
    playerSpawn: playerSpawn,
    enemySpawns: enemySpawns,
    flags: flags,
  );
}
