import 'dart:collection';

import 'package:flame_forge2d/flame_forge2d.dart';

enum TileKind { wall, road, rock }

class TileCoordinate {
  const TileCoordinate(this.x, this.y);

  final int x;
  final int y;

  Vector2 toWorldCenter() => Vector2(x + 0.5, y + 0.5);

  int manhattanDistanceTo(TileCoordinate other) {
    return (x - other.x).abs() + (y - other.y).abs();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TileCoordinate &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y;

  @override
  int get hashCode => Object.hash(x, y);
}

class FlagSpawn {
  const FlagSpawn({required this.tile, required this.isSpecial});

  final TileCoordinate tile;
  final bool isSpecial;
}

class LevelData {
  const LevelData({
    required this.stage,
    required this.seed,
    required this.width,
    required this.height,
    required this.tiles,
    required this.playerSpawn,
    required this.enemySpawns,
    required this.flags,
  });

  final int stage;
  final int seed;
  final int width;
  final int height;
  final List<List<TileKind>> tiles; // [y][x]

  final TileCoordinate playerSpawn;
  final List<TileCoordinate> enemySpawns;
  final List<FlagSpawn> flags;

  bool isInside(int x, int y) => x >= 0 && y >= 0 && x < width && y < height;

  TileKind tileAt(int x, int y) => tiles[y][x];

  bool isWalkable(int x, int y) => tileAt(x, y) == TileKind.road;

  Set<TileCoordinate> reachableFrom(TileCoordinate start) {
    if (!isInside(start.x, start.y) || !isWalkable(start.x, start.y)) {
      return <TileCoordinate>{};
    }

    final visited = <TileCoordinate>{start};
    final queue = Queue<TileCoordinate>()..add(start);

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      for (final neighbor in _neighbors(current)) {
        if (!isWalkable(neighbor.x, neighbor.y)) {
          continue;
        }
        if (visited.add(neighbor)) {
          queue.add(neighbor);
        }
      }
    }

    return visited;
  }

  Iterable<TileCoordinate> _neighbors(TileCoordinate tile) sync* {
    const offsets = [(0, -1), (1, 0), (0, 1), (-1, 0)];

    for (final (dx, dy) in offsets) {
      final nx = tile.x + dx;
      final ny = tile.y + dy;
      if (isInside(nx, ny)) {
        yield TileCoordinate(nx, ny);
      }
    }
  }
}
