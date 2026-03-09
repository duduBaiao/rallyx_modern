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

    test('prefers corridor center in wide straight sections', () {
      final level = _levelFromAscii([
        '#########',
        '#.......#',
        '#.......#',
        '#.......#',
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
      final interior = route!.pathTiles
          .where(
            (tile) =>
                tile != route.pathTiles.first && tile != route.pathTiles.last,
          )
          .toList(growable: false);
      expect(interior, isNotEmpty);
      expect(interior.every((tile) => tile.y == 3), isTrue);
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
