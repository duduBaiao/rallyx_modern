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

      final enemySpawns = _pickEnemySpawns(
        reachable: reachable,
        playerSpawn: playerSpawn,
      );
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
    final target = _normalizedTile(0.20, 0.84);
    final strictZone = roads.where(
      (tile) => _isInNormalizedZone(tile, minX: 0.08, maxX: 0.35, minY: 0.64),
    );
    final relaxedZone = roads.where(
      (tile) => _isInNormalizedZone(tile, minX: 0.05, maxX: 0.50, minY: 0.56),
    );

    final candidates = strictZone.isNotEmpty
        ? strictZone.toList()
        : (relaxedZone.isNotEmpty ? relaxedZone.toList() : roads);
    return _pickNearAnchorWithVariance(
      candidates: candidates,
      anchor: target,
      random: random,
      poolSize: 20,
    );
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

  List<TileCoordinate> _pickEnemySpawns({
    required List<TileCoordinate> reachable,
    required TileCoordinate playerSpawn,
  }) {
    final garageAnchor = _normalizedTile(0.50, 0.18);
    final minPlayerDistance = max(14, min(width, height) ~/ 4);

    bool farEnoughFromPlayer(TileCoordinate tile) =>
        tile.manhattanDistanceTo(playerSpawn) >= minPlayerDistance;

    final strictGarage = reachable
        .where(
          (tile) =>
              tile != playerSpawn &&
              farEnoughFromPlayer(tile) &&
              _isInNormalizedZone(
                tile,
                minX: 0.38,
                maxX: 0.62,
                minY: 0.06,
                maxY: 0.33,
              ),
        )
        .toList();
    final relaxedGarage = reachable
        .where(
          (tile) =>
              tile != playerSpawn &&
              tile.manhattanDistanceTo(playerSpawn) >= minPlayerDistance - 4 &&
              _isInNormalizedZone(
                tile,
                minX: 0.28,
                maxX: 0.72,
                minY: 0.04,
                maxY: 0.45,
              ),
        )
        .toList();
    final fallbackFar = reachable.where((tile) => tile != playerSpawn).toList()
      ..sort(
        (a, b) => b
            .manhattanDistanceTo(playerSpawn)
            .compareTo(a.manhattanDistanceTo(playerSpawn)),
      );

    final orderedCandidates = _mergeUniqueInOrder([
      _sortByDistanceToAnchor(strictGarage, garageAnchor),
      _sortByDistanceToAnchor(relaxedGarage, garageAnchor),
      fallbackFar,
    ]);

    final selected = _pickDistributedEnemySpawns(
      candidates: orderedCandidates,
      desiredCount: GameConfig.enemySpawnCount,
      playerSpawn: playerSpawn,
      anchor: garageAnchor,
      initialMinSpacing: 7,
      minimumMinSpacing: 4,
    );
    return selected;
  }

  List<FlagSpawn> _pickFlags({
    required List<TileCoordinate> reachable,
    required TileCoordinate playerSpawn,
    required List<TileCoordinate> enemySpawns,
    required Random random,
  }) {
    final blocked = <TileCoordinate>{playerSpawn, ...enemySpawns};
    final allCandidates = reachable
        .where((tile) => !blocked.contains(tile))
        .toList();
    if (allCandidates.length < GameConfig.flagsPerStage) {
      return const [];
    }

    final preferredCandidates = allCandidates.where((tile) {
      final distanceFromPlayer = tile.manhattanDistanceTo(playerSpawn);
      final nearestEnemyDistance = _minDistanceToAny(tile, enemySpawns);
      return distanceFromPlayer >= 6 && nearestEnemyDistance >= 3;
    }).toList();
    final candidates = preferredCandidates.length >= GameConfig.flagsPerStage
        ? preferredCandidates
        : allCandidates;

    final selected = <TileCoordinate>[];
    final byQuadrant = <int, List<TileCoordinate>>{
      0: <TileCoordinate>[],
      1: <TileCoordinate>[],
      2: <TileCoordinate>[],
      3: <TileCoordinate>[],
    };
    for (final tile in candidates) {
      byQuadrant[_quadrantIndex(tile)]!.add(tile);
    }

    for (var quadrant = 0; quadrant < 4; quadrant++) {
      final quadrantCandidates = byQuadrant[quadrant]!;
      final quadrantCenter = _quadrantCenter(quadrant);
      quadrantCandidates.sort((a, b) {
        final playerDistanceComparison = b
            .manhattanDistanceTo(playerSpawn)
            .compareTo(a.manhattanDistanceTo(playerSpawn));
        if (playerDistanceComparison != 0) {
          return playerDistanceComparison;
        }
        return a
            .manhattanDistanceTo(quadrantCenter)
            .compareTo(b.manhattanDistanceTo(quadrantCenter));
      });

      final selectedCandidate = quadrantCandidates.firstWhere(
        (tile) =>
            _isFarEnoughFromSet(tile, selected, 5) &&
            _isFarEnoughFromSet(tile, enemySpawns, 3),
        orElse: () => const TileCoordinate(-1, -1),
      );
      if (selectedCandidate.x >= 0) {
        selected.add(selectedCandidate);
      }
    }

    final remaining = candidates.where((tile) => !selected.contains(tile));
    while (selected.length < GameConfig.flagsPerStage) {
      final next = _pickBestSpreadCandidate(
        candidates: remaining,
        selected: selected,
        playerSpawn: playerSpawn,
      );
      if (next == null) {
        break;
      }
      selected.add(next);
    }

    if (selected.length < GameConfig.flagsPerStage) {
      final fallback =
          allCandidates.where((tile) => !selected.contains(tile)).toList()
            ..sort(
              (a, b) => b
                  .manhattanDistanceTo(playerSpawn)
                  .compareTo(a.manhattanDistanceTo(playerSpawn)),
            );
      for (final tile in fallback) {
        selected.add(tile);
        if (selected.length == GameConfig.flagsPerStage) {
          break;
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

  TileCoordinate _normalizedTile(double nx, double ny) {
    final x = (width * nx).round().clamp(1, width - 2);
    final y = (height * ny).round().clamp(1, height - 2);
    return TileCoordinate(x, y);
  }

  bool _isInNormalizedZone(
    TileCoordinate tile, {
    required double minX,
    double maxX = 1.0,
    required double minY,
    double maxY = 1.0,
  }) {
    final x = (tile.x + 0.5) / width;
    final y = (tile.y + 0.5) / height;
    return x >= minX && x <= maxX && y >= minY && y <= maxY;
  }

  TileCoordinate _pickNearAnchorWithVariance({
    required List<TileCoordinate> candidates,
    required TileCoordinate anchor,
    required Random random,
    int poolSize = 16,
  }) {
    final ordered = _sortByDistanceToAnchor(candidates, anchor);
    final pool = min(poolSize, ordered.length);
    return ordered[random.nextInt(pool)];
  }

  List<TileCoordinate> _sortByDistanceToAnchor(
    List<TileCoordinate> tiles,
    TileCoordinate anchor,
  ) {
    final sorted = List<TileCoordinate>.from(tiles);
    sorted.sort(
      (a, b) => a
          .manhattanDistanceTo(anchor)
          .compareTo(b.manhattanDistanceTo(anchor)),
    );
    return sorted;
  }

  List<TileCoordinate> _mergeUniqueInOrder(List<List<TileCoordinate>> groups) {
    final merged = <TileCoordinate>[];
    final seen = <TileCoordinate>{};
    for (final group in groups) {
      for (final tile in group) {
        if (seen.add(tile)) {
          merged.add(tile);
        }
      }
    }
    return merged;
  }

  List<TileCoordinate> _pickDistributedEnemySpawns({
    required List<TileCoordinate> candidates,
    required int desiredCount,
    required TileCoordinate playerSpawn,
    required TileCoordinate anchor,
    required int initialMinSpacing,
    required int minimumMinSpacing,
  }) {
    if (candidates.isEmpty || desiredCount <= 0) {
      return const [];
    }

    final selected = <TileCoordinate>[];
    selected.add(candidates.first);

    var spacing = initialMinSpacing;
    while (selected.length < desiredCount) {
      TileCoordinate? best;
      var bestScore = -1;

      for (final tile in candidates) {
        if (selected.contains(tile)) {
          continue;
        }
        final spreadDistance = _minDistanceToAny(tile, selected);
        if (spreadDistance < spacing) {
          continue;
        }
        final distanceFromPlayer = tile.manhattanDistanceTo(playerSpawn);
        final distanceToAnchor = tile.manhattanDistanceTo(anchor);
        final score =
            spreadDistance * 100 + distanceFromPlayer * 3 - distanceToAnchor;
        if (score > bestScore) {
          bestScore = score;
          best = tile;
        }
      }

      if (best != null) {
        selected.add(best);
        continue;
      }
      if (spacing > minimumMinSpacing) {
        spacing--;
        continue;
      }
      break;
    }

    while (selected.length < desiredCount) {
      TileCoordinate? best;
      var bestScore = -1;
      for (final tile in candidates) {
        if (selected.contains(tile)) {
          continue;
        }
        final spreadDistance = _minDistanceToAny(tile, selected);
        final distanceFromPlayer = tile.manhattanDistanceTo(playerSpawn);
        final score = spreadDistance * 100 + distanceFromPlayer * 2;
        if (score > bestScore) {
          bestScore = score;
          best = tile;
        }
      }
      if (best == null) {
        break;
      }
      selected.add(best);
    }

    if (selected.length < desiredCount) {
      for (final tile in candidates) {
        if (selected.contains(tile)) {
          continue;
        }
        selected.add(tile);
        if (selected.length >= desiredCount) {
          break;
        }
      }
    }
    return selected;
  }

  int _quadrantIndex(TileCoordinate tile) {
    final east = tile.x >= width ~/ 2;
    final south = tile.y >= height ~/ 2;
    if (!east && !south) {
      return 0;
    }
    if (east && !south) {
      return 1;
    }
    if (!east && south) {
      return 2;
    }
    return 3;
  }

  TileCoordinate _quadrantCenter(int quadrant) {
    final quarterX = width ~/ 4;
    final threeQuarterX = (width * 3) ~/ 4;
    final quarterY = height ~/ 4;
    final threeQuarterY = (height * 3) ~/ 4;

    return switch (quadrant) {
      0 => TileCoordinate(quarterX, quarterY),
      1 => TileCoordinate(threeQuarterX, quarterY),
      2 => TileCoordinate(quarterX, threeQuarterY),
      _ => TileCoordinate(threeQuarterX, threeQuarterY),
    };
  }

  bool _isFarEnoughFromSet(
    TileCoordinate tile,
    Iterable<TileCoordinate> others,
    int minDistance,
  ) {
    for (final other in others) {
      if (tile.manhattanDistanceTo(other) < minDistance) {
        return false;
      }
    }
    return true;
  }

  int _minDistanceToAny(TileCoordinate tile, Iterable<TileCoordinate> others) {
    var distance = 1 << 30;
    for (final other in others) {
      distance = min(distance, tile.manhattanDistanceTo(other));
    }
    return distance == (1 << 30) ? 0 : distance;
  }

  TileCoordinate? _pickBestSpreadCandidate({
    required Iterable<TileCoordinate> candidates,
    required List<TileCoordinate> selected,
    required TileCoordinate playerSpawn,
  }) {
    TileCoordinate? best;
    var bestScore = -1;
    for (final candidate in candidates) {
      final distanceFromPlayer = candidate.manhattanDistanceTo(playerSpawn);
      final spreadDistance = selected.isEmpty
          ? distanceFromPlayer
          : _minDistanceToAny(candidate, selected);
      final score = spreadDistance * 3 + distanceFromPlayer;
      if (spreadDistance < 3 && selected.isNotEmpty) {
        continue;
      }
      if (score > bestScore) {
        bestScore = score;
        best = candidate;
      }
    }
    return best;
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
