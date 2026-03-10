import 'package:flutter_test/flutter_test.dart';
import 'package:rallyx_modern/game/ai/enemy_nav_planner.dart';
import 'package:rallyx_modern/game/level/level_data.dart';

void main() {
  group('EnemyNavPlanner', () {
    test('finds a valid walkable route between two road tiles', () {
      final level = _levelFromAscii([
        '###########',
        '#....#....#',
        '#.##.#.##.#',
        '#....#....#',
        '#.######..#',
        '#.........#',
        '###########',
      ]);
      final planner = EnemyNavPlanner(level: level);

      final route = planner.planRoute(
        from: const TileCoordinate(1, 1),
        to: const TileCoordinate(9, 5),
      );

      expect(route, isNotNull);
      expect(route!.pathTiles.first, const TileCoordinate(1, 1));
      expect(route.pathTiles.last, const TileCoordinate(9, 5));
      for (final tile in route.pathTiles) {
        expect(level.isWalkable(tile.x, tile.y), isTrue);
      }
      for (var i = 1; i < route.pathTiles.length; i++) {
        final prev = route.pathTiles[i - 1];
        final curr = route.pathTiles[i];
        final manhattan = (prev.x - curr.x).abs() + (prev.y - curr.y).abs();
        expect(manhattan, 1);
      }
    });

    test('avoids rock tiles when planning', () {
      final level = _levelFromAscii([
        '#########',
        '#.......#',
        '#.......#',
        '#...R...#',
        '#.......#',
        '#.......#',
        '#########',
      ]);
      final planner = EnemyNavPlanner(level: level);

      final route = planner.planRoute(
        from: const TileCoordinate(1, 3),
        to: const TileCoordinate(7, 3),
      );

      expect(route, isNotNull);
      expect(route!.pathTiles.contains(const TileCoordinate(4, 3)), isFalse);
    });

    test('uses shortest route while keeping one-tile wall clearance', () {
      final level = _levelFromAscii([
        '###########',
        '#.........#',
        '#.........#',
        '#.........#',
        '#.........#',
        '###########',
      ]);
      final planner = EnemyNavPlanner(level: level);

      final route = planner.planRoute(
        from: const TileCoordinate(2, 2),
        to: const TileCoordinate(8, 2),
      );

      expect(route, isNotNull);
      final path = route!.pathTiles;
      final interior = path
          .where(
            (tile) =>
                tile != path.first && tile != path.last,
          )
          .toList(growable: false);
      expect(interior, isNotEmpty);
      for (final tile in interior) {
        expect(_isAdjacentToObstacle(level, tile), isFalse);
      }
      expect(path.length, 7);
    });

    test('falls back when strict one-tile clearance is impossible', () {
      final level = _levelFromAscii([
        '#######',
        '#.....#',
        '#######',
      ]);
      final planner = EnemyNavPlanner(level: level);

      final route = planner.planRoute(
        from: const TileCoordinate(1, 1),
        to: const TileCoordinate(5, 1),
      );

      expect(route, isNotNull);
      expect(route!.pathTiles.length, 5);
    });

    test('produces deterministic paths for same inputs', () {
      final level = _levelFromAscii([
        '###########',
        '#....#....#',
        '#.##.#.##.#',
        '#....#....#',
        '#.######..#',
        '#.........#',
        '###########',
      ]);
      final planner = EnemyNavPlanner(level: level);

      final routeA = planner.planRoute(
        from: const TileCoordinate(1, 1),
        to: const TileCoordinate(9, 5),
      );
      final routeB = planner.planRoute(
        from: const TileCoordinate(1, 1),
        to: const TileCoordinate(9, 5),
      );

      expect(routeA, isNotNull);
      expect(routeB, isNotNull);
      expect(routeA!.pathTiles, routeB!.pathTiles);
      expect(routeA.waypointTiles, routeB.waypointTiles);
    });
  });
}

bool _isAdjacentToObstacle(LevelData level, TileCoordinate tile) {
  const offsets = <(int, int)>[(0, -1), (1, 0), (0, 1), (-1, 0)];
  for (final (dx, dy) in offsets) {
    final x = tile.x + dx;
    final y = tile.y + dy;
    if (!level.isInside(x, y) || !level.isWalkable(x, y)) {
      return true;
    }
  }
  return false;
}

LevelData _levelFromAscii(List<String> lines) {
  final height = lines.length;
  final width = lines.first.length;
  final tiles = List<List<TileKind>>.generate(height, (y) {
    return List<TileKind>.generate(width, (x) {
      final symbol = lines[y][x];
      return switch (symbol) {
        '#' => TileKind.wall,
        'R' => TileKind.rock,
        _ => TileKind.road,
      };
    });
  });

  return LevelData(
    stage: 1,
    seed: 0,
    width: width,
    height: height,
    tiles: tiles,
    playerSpawn: const TileCoordinate(1, 1),
    enemySpawns: const [],
    flags: const [],
  );
}
