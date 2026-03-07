import 'dart:math';

import 'package:rallyx_modern/game/config/game_config.dart';
import 'package:rallyx_modern/game/level/level_data.dart';
import 'package:rallyx_modern/game/level/level_provider.dart';

class ProceduralLevelProvider implements LevelProvider {
  ProceduralLevelProvider({
    this.width = GameConfig.playfieldTilesWide,
    this.height = GameConfig.playfieldTilesHigh,
    this.maxAttempts = 32,
    this.corridorWidth = 5,
    this.wallThickness = 1,
  });

  final int width;
  final int height;
  final int maxAttempts;
  final int corridorWidth;
  final int wallThickness;

  @override
  LevelData loadLevel({required int stage, required int seed}) {
    _validateDimensions();

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final random = Random(_mixSeed(seed, stage, attempt));
      final tiles = _newFilledGrid(TileKind.wall);

      _carveWideMaze(tiles, random);
      _addWideLoops(tiles, random);

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

  void _carveWideMaze(List<List<TileKind>> tiles, Random random) {
    final mazeWidth = _mazeCellsWide();
    final mazeHeight = _mazeCellsHigh();
    final visited = List<List<bool>>.generate(
      mazeHeight,
      (_) => List<bool>.filled(mazeWidth, false),
    );

    final start = TileCoordinate(0, 0);
    final stack = <TileCoordinate>[start];
    visited[start.y][start.x] = true;
    _carveCellBlock(tiles, start.x, start.y);

    const directions = <(int, int)>[(1, 0), (-1, 0), (0, 1), (0, -1)];

    while (stack.isNotEmpty) {
      final current = stack.last;
      final candidates = <TileCoordinate>[];

      for (final (dx, dy) in directions) {
        final nx = current.x + dx;
        final ny = current.y + dy;
        if (!_isInsideMazeCell(nx, ny, mazeWidth, mazeHeight)) {
          continue;
        }
        if (!visited[ny][nx]) {
          candidates.add(TileCoordinate(nx, ny));
        }
      }

      if (candidates.isEmpty) {
        stack.removeLast();
        continue;
      }

      final next = candidates[random.nextInt(candidates.length)];
      _carvePassage(tiles, current, next);
      _carveCellBlock(tiles, next.x, next.y);
      visited[next.y][next.x] = true;
      stack.add(next);
    }
  }

  void _addWideLoops(List<List<TileKind>> tiles, Random random) {
    const loopChance = 0.08;

    final mazeWidth = _mazeCellsWide();
    final mazeHeight = _mazeCellsHigh();

    for (var y = 0; y < mazeHeight; y++) {
      for (var x = 0; x < mazeWidth; x++) {
        final current = TileCoordinate(x, y);

        if (x + 1 < mazeWidth && random.nextDouble() < loopChance) {
          _carvePassage(tiles, current, TileCoordinate(x + 1, y));
        }
        if (y + 1 < mazeHeight && random.nextDouble() < loopChance) {
          _carvePassage(tiles, current, TileCoordinate(x, y + 1));
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
    final mapCenter = TileCoordinate(width ~/ 2, height ~/ 2);

    List<TileCoordinate> pickCandidates(int margin) => roads
        .where(
          (tile) =>
              tile.x >= margin &&
              tile.y >= margin &&
              tile.x < width - margin &&
              tile.y < height - margin,
        )
        .toList();

    var candidates = pickCandidates(6);
    if (candidates.isEmpty) {
      candidates = pickCandidates(4);
    }
    if (candidates.isEmpty) {
      candidates = pickCandidates(2);
    }
    if (candidates.isEmpty) {
      candidates = List<TileCoordinate>.from(roads);
    }

    candidates.sort(
      (a, b) => a
          .manhattanDistanceTo(mapCenter)
          .compareTo(b.manhattanDistanceTo(mapCenter)),
    );
    final centerPoolSize = min(24, candidates.length);
    return candidates[random.nextInt(centerPoolSize)];
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

  int _mazeStep() => corridorWidth + wallThickness;

  int _mazeCellsWide() => (width - wallThickness) ~/ _mazeStep();

  int _mazeCellsHigh() => (height - wallThickness) ~/ _mazeStep();

  void _validateDimensions() {
    final step = _mazeStep();
    if (corridorWidth <= 0 || wallThickness <= 0) {
      throw StateError('corridorWidth and wallThickness must be positive');
    }
    if (width < step + wallThickness || height < step + wallThickness) {
      throw StateError(
        'Map too small for corridorWidth=$corridorWidth and wallThickness=$wallThickness',
      );
    }
    final validWidth = (width - wallThickness) % step == 0;
    final validHeight = (height - wallThickness) % step == 0;
    if (!validWidth || !validHeight) {
      throw StateError(
        'Map dimensions must satisfy: size = N*(corridorWidth+wallThickness)+wallThickness',
      );
    }
  }

  bool _isInsideMazeCell(int x, int y, int mazeWidth, int mazeHeight) {
    return x >= 0 && y >= 0 && x < mazeWidth && y < mazeHeight;
  }

  int _cellStart(int index) => wallThickness + index * _mazeStep();

  void _carveCellBlock(List<List<TileKind>> tiles, int cellX, int cellY) {
    final startX = _cellStart(cellX);
    final startY = _cellStart(cellY);
    for (var y = startY; y < startY + corridorWidth; y++) {
      for (var x = startX; x < startX + corridorWidth; x++) {
        tiles[y][x] = TileKind.road;
      }
    }
  }

  void _carvePassage(
    List<List<TileKind>> tiles,
    TileCoordinate from,
    TileCoordinate to,
  ) {
    final dx = to.x - from.x;
    final dy = to.y - from.y;
    if (!((dx.abs() == 1 && dy == 0) || (dy.abs() == 1 && dx == 0))) {
      return;
    }

    final fromStartX = _cellStart(from.x);
    final fromStartY = _cellStart(from.y);

    if (dx == 1) {
      final gapStartX = fromStartX + corridorWidth;
      for (var y = fromStartY; y < fromStartY + corridorWidth; y++) {
        for (var x = gapStartX; x < gapStartX + wallThickness; x++) {
          tiles[y][x] = TileKind.road;
        }
      }
      return;
    }
    if (dx == -1) {
      final gapStartX = fromStartX - wallThickness;
      for (var y = fromStartY; y < fromStartY + corridorWidth; y++) {
        for (var x = gapStartX; x < gapStartX + wallThickness; x++) {
          tiles[y][x] = TileKind.road;
        }
      }
      return;
    }
    if (dy == 1) {
      final gapStartY = fromStartY + corridorWidth;
      for (var y = gapStartY; y < gapStartY + wallThickness; y++) {
        for (var x = fromStartX; x < fromStartX + corridorWidth; x++) {
          tiles[y][x] = TileKind.road;
        }
      }
      return;
    }
    final gapStartY = fromStartY - wallThickness;
    for (var y = gapStartY; y < gapStartY + wallThickness; y++) {
      for (var x = fromStartX; x < fromStartX + corridorWidth; x++) {
        tiles[y][x] = TileKind.road;
      }
    }
  }

  int _mixSeed(int seed, int stage, int attempt) {
    var value = seed ^ 0x9E3779B9;
    value = 0x1fffffff & (value + stage * 92821);
    value = 0x1fffffff & (value + attempt * 48611);
    return value;
  }
}
