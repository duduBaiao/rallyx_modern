import 'dart:collection';
import 'dart:math' as math;

import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:rallyx_modern/game/level/level_data.dart';

class EnemyRoute {
  const EnemyRoute({required this.pathTiles, required this.waypointTiles});

  final List<TileCoordinate> pathTiles;
  final List<TileCoordinate> waypointTiles;

  List<Vector2> waypointWorldPositions() {
    return waypointTiles
        .map((tile) => tile.toWorldCenter())
        .toList(growable: false);
  }

  List<Vector2> pathWorldPositions({bool skipFirst = false}) {
    final source = skipFirst && pathTiles.length > 1
        ? pathTiles.skip(1)
        : pathTiles;
    return source.map((tile) => tile.toWorldCenter()).toList(growable: false);
  }
}

class EnemyNavPlanner {
  EnemyNavPlanner({
    required this.level,
    this.wallPenaltyWeight = 0.0,
    this.clearanceCap = 4,
    this.minClearanceFromWalls = 2,
    this.fallbackMinClearanceFromWalls = 1,
  }) : _clearanceMap = _buildClearanceMap(level);

  final LevelData level;
  final double wallPenaltyWeight;
  final int clearanceCap;
  final int minClearanceFromWalls;
  final int fallbackMinClearanceFromWalls;
  final List<List<int>> _clearanceMap; // [y][x]

  EnemyRoute? planRoute({
    required TileCoordinate from,
    required TileCoordinate to,
  }) {
    if (!level.isInside(from.x, from.y) || !level.isInside(to.x, to.y)) {
      return null;
    }
    if (!level.isWalkable(from.x, from.y) || !level.isWalkable(to.x, to.y)) {
      return null;
    }
    if (from == to) {
      return EnemyRoute(pathTiles: [from], waypointTiles: [from]);
    }

    final strictPath = _findPath(
      from: from,
      to: to,
      minClearance: minClearanceFromWalls,
    );
    final path =
        strictPath ??
        _findPath(
          from: from,
          to: to,
          minClearance: fallbackMinClearanceFromWalls,
        );
    if (path == null) {
      return null;
    }
    final waypoints = _compressToWaypoints(path);
    return EnemyRoute(pathTiles: path, waypointTiles: waypoints);
  }

  List<TileCoordinate>? _findPath({
    required TileCoordinate from,
    required TileCoordinate to,
    required int minClearance,
  }) {
    final gScore = <TileCoordinate, double>{from: 0};
    final previous = <TileCoordinate, TileCoordinate>{};
    final closed = <TileCoordinate>{};
    final open = _MinHeap();
    open.add(
      _HeapNode(
        tile: from,
        score: _heuristic(from, to),
        heuristicToGoal: _heuristic(from, to),
        axisImbalanceToGoal: _axisImbalance(from, to),
      ),
    );

    while (open.isNotEmpty) {
      final node = open.removeMin();
      final current = node.tile;
      if (!closed.add(current)) {
        continue;
      }
      if (current == to) {
        break;
      }

      final currentScore = gScore[current];
      if (currentScore == null) {
        continue;
      }

      for (final neighbor in _neighbors(current)) {
        if (closed.contains(neighbor) ||
            !_isTraversable(
              tile: neighbor,
              from: from,
              to: to,
              minClearance: minClearance,
            )) {
          continue;
        }

        final tentativeScore =
            currentScore + _movementCost(neighbor, minClearance: minClearance);
        final knownBest = gScore[neighbor];
        if (knownBest != null && tentativeScore >= knownBest) {
          continue;
        }

        gScore[neighbor] = tentativeScore;
        previous[neighbor] = current;
        open.add(
          _HeapNode(
            tile: neighbor,
            score: tentativeScore + _heuristic(neighbor, to),
            heuristicToGoal: _heuristic(neighbor, to),
            axisImbalanceToGoal: _axisImbalance(neighbor, to),
          ),
        );
      }
    }

    if (!previous.containsKey(to)) {
      return null;
    }
    return _reconstructPath(previous: previous, start: from, target: to);
  }

  double _heuristic(TileCoordinate from, TileCoordinate to) {
    return (from.x - to.x).abs().toDouble() + (from.y - to.y).abs().toDouble();
  }

  double _movementCost(TileCoordinate tile, {required int minClearance}) {
    if (wallPenaltyWeight <= 0) {
      return 1.0;
    }
    final clearance = _clearanceMap[tile.y][tile.x];
    final clamped = math.min(clearance, clearanceCap).toDouble();
    final floorClearance = math.min(minClearance, clearanceCap).toDouble();
    final penaltyBase = math.max(0.0, clearanceCap - clamped);
    final floorPenaltyBase = math.max(0.0, clearanceCap - floorClearance);
    final extraPenalty = math.max(0.0, penaltyBase - floorPenaltyBase);
    return 1.0 + extraPenalty * wallPenaltyWeight;
  }

  bool _isTraversable({
    required TileCoordinate tile,
    required TileCoordinate from,
    required TileCoordinate to,
    required int minClearance,
  }) {
    if (!level.isWalkable(tile.x, tile.y)) {
      return false;
    }
    if (tile == from || tile == to) {
      return true;
    }
    return _clearanceMap[tile.y][tile.x] >= minClearance;
  }

  double _axisImbalance(TileCoordinate tile, TileCoordinate target) {
    final dx = (tile.x - target.x).abs();
    final dy = (tile.y - target.y).abs();
    return (dx - dy).abs().toDouble();
  }

  Iterable<TileCoordinate> _neighbors(TileCoordinate tile) sync* {
    const offsets = <(int, int)>[(0, -1), (1, 0), (0, 1), (-1, 0)];
    for (final (dx, dy) in offsets) {
      final nx = tile.x + dx;
      final ny = tile.y + dy;
      if (level.isInside(nx, ny)) {
        yield TileCoordinate(nx, ny);
      }
    }
  }

  List<TileCoordinate> _reconstructPath({
    required Map<TileCoordinate, TileCoordinate> previous,
    required TileCoordinate start,
    required TileCoordinate target,
  }) {
    final path = <TileCoordinate>[target];
    var cursor = target;
    while (cursor != start) {
      final prior = previous[cursor];
      if (prior == null) {
        return const <TileCoordinate>[];
      }
      cursor = prior;
      path.add(cursor);
    }
    return path.reversed.toList(growable: false);
  }

  List<TileCoordinate> _compressToWaypoints(List<TileCoordinate> path) {
    if (path.length <= 2) {
      return List<TileCoordinate>.from(path, growable: false);
    }

    final waypoints = <TileCoordinate>[path.first];
    var currentDirX = path[1].x - path[0].x;
    var currentDirY = path[1].y - path[0].y;

    for (var i = 2; i < path.length; i++) {
      final dx = path[i].x - path[i - 1].x;
      final dy = path[i].y - path[i - 1].y;
      if (dx != currentDirX || dy != currentDirY) {
        waypoints.add(path[i - 1]);
        currentDirX = dx;
        currentDirY = dy;
      }
    }
    waypoints.add(path.last);
    return waypoints;
  }

  static List<List<int>> _buildClearanceMap(LevelData level) {
    final width = level.width;
    final height = level.height;
    const unvisited = 1 << 30;
    final distances = List<List<int>>.generate(
      height,
      (_) => List<int>.filled(width, unvisited),
    );
    final queue = ListQueue<TileCoordinate>();

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (!level.isWalkable(x, y)) {
          distances[y][x] = 0;
          queue.add(TileCoordinate(x, y));
        }
      }
    }

    if (queue.isEmpty) {
      return List<List<int>>.generate(
        height,
        (_) => List<int>.filled(width, 1),
      );
    }

    const offsets = <(int, int)>[(0, -1), (1, 0), (0, 1), (-1, 0)];
    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      final baseDistance = distances[current.y][current.x];
      for (final (dx, dy) in offsets) {
        final nx = current.x + dx;
        final ny = current.y + dy;
        if (!level.isInside(nx, ny)) {
          continue;
        }
        final next = baseDistance + 1;
        if (next >= distances[ny][nx]) {
          continue;
        }
        distances[ny][nx] = next;
        queue.add(TileCoordinate(nx, ny));
      }
    }
    return distances;
  }
}

class _HeapNode {
  const _HeapNode({
    required this.tile,
    required this.score,
    required this.heuristicToGoal,
    required this.axisImbalanceToGoal,
  });

  final TileCoordinate tile;
  final double score;
  final double heuristicToGoal;
  final double axisImbalanceToGoal;

  int compareTo(_HeapNode other) {
    final scoreCmp = score.compareTo(other.score);
    if (scoreCmp != 0) {
      return scoreCmp;
    }
    final imbalanceCmp = axisImbalanceToGoal.compareTo(
      other.axisImbalanceToGoal,
    );
    if (imbalanceCmp != 0) {
      return imbalanceCmp;
    }
    final heuristicCmp = heuristicToGoal.compareTo(other.heuristicToGoal);
    if (heuristicCmp != 0) {
      return heuristicCmp;
    }
    final yCmp = tile.y.compareTo(other.tile.y);
    if (yCmp != 0) {
      return yCmp;
    }
    return tile.x.compareTo(other.tile.x);
  }
}

class _MinHeap {
  final List<_HeapNode> _items = <_HeapNode>[];

  bool get isNotEmpty => _items.isNotEmpty;

  void add(_HeapNode node) {
    _items.add(node);
    _bubbleUp(_items.length - 1);
  }

  _HeapNode removeMin() {
    final min = _items.first;
    final last = _items.removeLast();
    if (_items.isNotEmpty) {
      _items[0] = last;
      _bubbleDown(0);
    }
    return min;
  }

  void _bubbleUp(int index) {
    var i = index;
    while (i > 0) {
      final parent = (i - 1) ~/ 2;
      if (_items[i].compareTo(_items[parent]) >= 0) {
        break;
      }
      final tmp = _items[i];
      _items[i] = _items[parent];
      _items[parent] = tmp;
      i = parent;
    }
  }

  void _bubbleDown(int index) {
    var i = index;
    while (true) {
      final left = i * 2 + 1;
      final right = left + 1;
      var smallest = i;

      if (left < _items.length &&
          _items[left].compareTo(_items[smallest]) < 0) {
        smallest = left;
      }
      if (right < _items.length &&
          _items[right].compareTo(_items[smallest]) < 0) {
        smallest = right;
      }
      if (smallest == i) {
        break;
      }
      final tmp = _items[i];
      _items[i] = _items[smallest];
      _items[smallest] = tmp;
      i = smallest;
    }
  }
}
