import 'dart:math';

import 'package:rallyx_modern/game/config/game_config.dart';
import 'package:rallyx_modern/game/level/level_data.dart';
import 'package:rallyx_modern/game/level/level_provider.dart';

class ProceduralLevelProvider implements LevelProvider {
  ProceduralLevelProvider({
    this.width = GameConfig.playfieldTilesWide,
    this.height = GameConfig.playfieldTilesHigh,
    this.maxAttempts = 32,
  });

  final int width;
  final int height;
  final int maxAttempts;

  @override
  LevelData loadLevel({required int stage, required int seed}) {
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final random = Random(_mixSeed(seed, stage, attempt));
      final tiles = _newFilledGrid(TileKind.wall);

      _carveMaze(tiles, random);
      _addLoops(tiles, random);

      final roads = _collectTiles(tiles, TileKind.road);
      if (roads.length < 80) {
        continue;
      }

      final playerSpawn = _pickPlayerSpawn(roads, random);
      _placeRocks(tiles, roads, playerSpawn, random);

      final baseLevel = LevelData(
        stage: stage,
        seed: seed,
        width: width,
        height: height,
        tiles: tiles,
        playerSpawn: playerSpawn,
        enemySpawns: const [],
        flags: const [],
      );

      final reachable = baseLevel.reachableFrom(playerSpawn).toList();
      if (reachable.length <
          GameConfig.flagsPerStage + GameConfig.enemySpawnCount + 12) {
        continue;
      }

      final enemySpawns = _pickEnemySpawns(reachable, playerSpawn);
      if (enemySpawns.length < GameConfig.enemySpawnCount) {
        continue;
      }

      final flags = _pickFlags(
        reachable: reachable,
        playerSpawn: playerSpawn,
        enemySpawns: enemySpawns,
        random: random,
      );
      if (flags.length != GameConfig.flagsPerStage) {
        continue;
      }

      final level = LevelData(
        stage: stage,
        seed: seed,
        width: width,
        height: height,
        tiles: tiles,
        playerSpawn: playerSpawn,
        enemySpawns: enemySpawns,
        flags: flags,
      );

      if (validateLevel(level)) {
        return level;
      }
    }

    throw StateError(
      'Could not generate a valid level after $maxAttempts attempts',
    );
  }

  bool validateLevel(LevelData level) {
    if (level.flags.length != GameConfig.flagsPerStage) {
      return false;
    }
    final specialCount = level.flags.where((flag) => flag.isSpecial).length;
    if (specialCount != 1) {
      return false;
    }

    final reachable = level.reachableFrom(level.playerSpawn);
    final allFlagsReachable = level.flags.every(
      (flag) => reachable.contains(flag.tile),
    );
    final allEnemiesReachable = level.enemySpawns.every(reachable.contains);
    return allFlagsReachable && allEnemiesReachable;
  }

  List<List<TileKind>> _newFilledGrid(TileKind fill) {
    return List<List<TileKind>>.generate(
      height,
      (_) => List<TileKind>.filled(width, fill),
    );
  }

  void _carveMaze(List<List<TileKind>> tiles, Random random) {
    final start = TileCoordinate(1, 1);
    tiles[start.y][start.x] = TileKind.road;
    final stack = <TileCoordinate>[start];

    const directions = [(2, 0), (-2, 0), (0, 2), (0, -2)];

    while (stack.isNotEmpty) {
      final current = stack.last;
      final candidates = <TileCoordinate>[];

      for (final (dx, dy) in directions) {
        final nx = current.x + dx;
        final ny = current.y + dy;
        if (!_isInterior(nx, ny)) {
          continue;
        }
        if (tiles[ny][nx] == TileKind.wall) {
          candidates.add(TileCoordinate(nx, ny));
        }
      }

      if (candidates.isEmpty) {
        stack.removeLast();
        continue;
      }

      final next = candidates[random.nextInt(candidates.length)];
      final betweenX = (current.x + next.x) ~/ 2;
      final betweenY = (current.y + next.y) ~/ 2;
      tiles[betweenY][betweenX] = TileKind.road;
      tiles[next.y][next.x] = TileKind.road;
      stack.add(next);
    }
  }

  void _addLoops(List<List<TileKind>> tiles, Random random) {
    const loopChance = 0.08;

    for (var y = 1; y < height - 1; y++) {
      for (var x = 1; x < width - 1; x++) {
        if (tiles[y][x] != TileKind.wall) {
          continue;
        }
        final horizontal =
            tiles[y][x - 1] == TileKind.road &&
            tiles[y][x + 1] == TileKind.road;
        final vertical =
            tiles[y - 1][x] == TileKind.road &&
            tiles[y + 1][x] == TileKind.road;
        if ((horizontal || vertical) && random.nextDouble() < loopChance) {
          tiles[y][x] = TileKind.road;
        }
      }
    }
  }

  List<TileCoordinate> _collectTiles(
    List<List<TileKind>> tiles,
    TileKind kind,
  ) {
    final result = <TileCoordinate>[];
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (tiles[y][x] == kind) {
          result.add(TileCoordinate(x, y));
        }
      }
    }
    return result;
  }

  TileCoordinate _pickPlayerSpawn(List<TileCoordinate> roads, Random random) {
    final sorted = [...roads]..sort((a, b) => (a.x + a.y).compareTo(b.x + b.y));
    final topLeftPoolSize = min(20, sorted.length);
    return sorted[random.nextInt(topLeftPoolSize)];
  }

  void _placeRocks(
    List<List<TileKind>> tiles,
    List<TileCoordinate> roads,
    TileCoordinate playerSpawn,
    Random random,
  ) {
    final candidates = roads.where((tile) {
      if (tile == playerSpawn) {
        return false;
      }
      if (tile.x < 2 ||
          tile.y < 2 ||
          tile.x > width - 3 ||
          tile.y > height - 3) {
        return false;
      }
      return tile.manhattanDistanceTo(playerSpawn) >= 5;
    }).toList()..shuffle(random);

    var placed = 0;
    for (final tile in candidates) {
      if (placed >= GameConfig.rocksPerStage) {
        break;
      }
      tiles[tile.y][tile.x] = TileKind.rock;
      placed++;
    }
  }

  List<TileCoordinate> _pickEnemySpawns(
    List<TileCoordinate> reachable,
    TileCoordinate playerSpawn,
  ) {
    final candidates = [...reachable]
      ..remove(playerSpawn)
      ..sort(
        (a, b) => b
            .manhattanDistanceTo(playerSpawn)
            .compareTo(a.manhattanDistanceTo(playerSpawn)),
      );

    final selected = <TileCoordinate>[];
    for (final tile in candidates) {
      final tooCloseToSelected = selected.any(
        (other) => other.manhattanDistanceTo(tile) < 4,
      );
      if (!tooCloseToSelected) {
        selected.add(tile);
      }
      if (selected.length == GameConfig.enemySpawnCount) {
        return selected;
      }
    }

    for (final tile in candidates) {
      if (selected.length == GameConfig.enemySpawnCount) {
        break;
      }
      if (!selected.contains(tile)) {
        selected.add(tile);
      }
    }
    return selected;
  }

  List<FlagSpawn> _pickFlags({
    required List<TileCoordinate> reachable,
    required TileCoordinate playerSpawn,
    required List<TileCoordinate> enemySpawns,
    required Random random,
  }) {
    final blocked = <TileCoordinate>{playerSpawn, ...enemySpawns};
    final candidates = reachable
        .where((tile) => !blocked.contains(tile))
        .toList();
    if (candidates.length < GameConfig.flagsPerStage) {
      return const [];
    }

    candidates.shuffle(random);
    candidates.sort(
      (a, b) => b
          .manhattanDistanceTo(playerSpawn)
          .compareTo(a.manhattanDistanceTo(playerSpawn)),
    );

    final selected = <TileCoordinate>[];
    for (final tile in candidates) {
      final tooClose = selected.any(
        (other) => other.manhattanDistanceTo(tile) < 3,
      );
      if (!tooClose) {
        selected.add(tile);
      }
      if (selected.length == GameConfig.flagsPerStage) {
        break;
      }
    }

    if (selected.length < GameConfig.flagsPerStage) {
      for (final tile in candidates) {
        if (selected.length == GameConfig.flagsPerStage) {
          break;
        }
        if (!selected.contains(tile)) {
          selected.add(tile);
        }
      }
    }

    if (selected.length != GameConfig.flagsPerStage) {
      return const [];
    }

    selected.sort(
      (a, b) => b
          .manhattanDistanceTo(playerSpawn)
          .compareTo(a.manhattanDistanceTo(playerSpawn)),
    );
    final specialTile = selected.first;

    return selected
        .map((tile) => FlagSpawn(tile: tile, isSpecial: tile == specialTile))
        .toList(growable: false);
  }

  bool _isInterior(int x, int y) {
    return x > 0 && y > 0 && x < width - 1 && y < height - 1;
  }

  int _mixSeed(int seed, int stage, int attempt) {
    var value = seed ^ 0x9E3779B9;
    value = 0x1fffffff & (value + stage * 92821);
    value = 0x1fffffff & (value + attempt * 48611);
    return value;
  }
}
