import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/input.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:rallyx_modern/game/config/game_config.dart';
import 'package:rallyx_modern/game/entities/enemy_car_component.dart';
import 'package:rallyx_modern/game/entities/flag_component.dart';
import 'package:rallyx_modern/game/entities/player_car_component.dart';
import 'package:rallyx_modern/game/entities/rock_component.dart';
import 'package:rallyx_modern/game/entities/smoke_cloud_component.dart';
import 'package:rallyx_modern/game/entities/wall_tile_component.dart';
import 'package:rallyx_modern/game/input/input_source.dart';
import 'package:rallyx_modern/game/input/vehicle_command.dart';
import 'package:rallyx_modern/game/level/level_data.dart';
import 'package:rallyx_modern/game/level/level_provider.dart';
import 'package:rallyx_modern/game/level/procedural_level_provider.dart';
import 'package:rallyx_modern/game/persistence/high_score_repository.dart';
import 'package:rallyx_modern/game/persistence/score_entry.dart';
import 'package:rallyx_modern/game/ui/debug_overlay.dart';
import 'package:rallyx_modern/game/world/fixed_step_forge2d_world.dart';

class RallyXGame extends Forge2DGame<FixedStepForge2DWorld>
    with KeyboardEvents, HasCollisionDetection {
  RallyXGame({
    required this.inputSource,
    LevelProvider? levelProvider,
    HighScoreRepository? highScoreRepository,
    Random? seedRandom,
    int initialSeed = 1980,
    this.debugEnemyCountOverride,
  }) : _usesDefaultProceduralLevelProvider = levelProvider == null,
       levelProvider = levelProvider ?? ProceduralLevelProvider(),
       highScoreRepository =
           highScoreRepository ?? SharedPrefsHighScoreRepository(),
       _seedRandom = seedRandom ?? Random(),
       currentSeed = initialSeed,
       super(
         world: FixedStepForge2DWorld(gravity: Vector2.zero()),
         zoom: GameConfig.cameraZoom,
       );

  final LevelProvider levelProvider;
  final bool _usesDefaultProceduralLevelProvider;
  final HighScoreRepository highScoreRepository;
  final Random _seedRandom;
  final int? debugEnemyCountOverride;
  final InputSource inputSource;
  final PositionComponent _levelLayer = PositionComponent();
  final List<FlagComponent> _activeFlags = <FlagComponent>[];
  final List<EnemyCarComponent> _activeEnemies = <EnemyCarComponent>[];
  final List<SmokeCloudComponent> _activeSmokeClouds = <SmokeCloudComponent>[];
  int _nextPlayfieldTilesWide = GameConfig.playfieldTilesWide;
  int _nextPlayfieldTilesHigh = GameConfig.playfieldTilesHigh;
  double _targetVisibleTilesX = GameConfig.cameraTargetVisibleTiles.toDouble();
  double _targetVisibleTilesY = GameConfig.cameraTargetVisibleTiles.toDouble();

  int currentStage = 1;
  int currentSeed;
  LevelData? currentLevel;
  PlayerCarComponent? playerCar;

  bool isGameOver = false;
  bool _isLoadingStage = false;
  bool _smokePressedLastFrame = false;

  double fuel = GameConfig.maxFuel;
  double survivalTime = 0;
  double bonusScore = 0;
  String gameOverReason = '';
  List<ScoreEntry> highScores = const [];
  double _smoothedFps = 0;

  bool debugOverlayVisible = false;

  double get playerSpeed => playerCar?.speed ?? 0;
  double get score => survivalTime + bonusScore;
  double get fps => _smoothedFps;
  VehicleCommand get currentCommand =>
      playerCar?.lastCommand ?? const VehicleCommand.idle();
  int get currentFlagCount => _activeFlags.length;
  int get currentEnemySpawnCount => _activeEnemies.length;
  int get remainingFlagCount =>
      _activeFlags.where((flag) => !flag.isCollected).length;
  double get fuelPercent => (fuel / GameConfig.maxFuel).clamp(0, 1) * 100;
  String get runState =>
      isGameOver ? 'GAME OVER' : (_isLoadingStage ? 'LOADING' : 'RUNNING');
  List<ScoreEntry> get topScores => highScores;

  TileCoordinate? get playerTile =>
      playerCar == null ? null : worldToTile(playerCar!.body.position);

  List<TileCoordinate> get enemyTiles => _activeEnemies
      .where((enemy) => enemy.isMounted && !enemy.isRemoving)
      .map((enemy) => worldToTile(enemy.body.position))
      .toList(growable: false);

  List<Vector2> get enemyPositions => _activeEnemies
      .where((enemy) => enemy.isMounted && !enemy.isRemoving)
      .map((enemy) => enemy.body.position.clone())
      .toList(growable: false);

  List<FlagSpawn> get remainingFlags => _activeFlags
      .where((flag) => !flag.isCollected && flag.isMounted && !flag.isRemoving)
      .map((flag) => flag.spawn)
      .toList(growable: false);

  @override
  Color backgroundColor() => const Color(0xFF0E1116);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _refreshResponsiveLayoutTargets();
    _updateCameraZoomForViewport();
    await world.add(_levelLayer);

    await _loadHighScores();
    await _startNewRun(seed: currentSeed);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _refreshResponsiveLayoutTargets();
    _updateCameraZoomForViewport();
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (dt > 0) {
      final instantFps = 1 / dt;
      _smoothedFps = _smoothedFps == 0
          ? instantFps
          : (_smoothedFps * 0.9) + (instantFps * 0.1);
    }
    _updateCameraZoomForViewport();
    _updateCameraPosition();

    if (_isLoadingStage || isGameOver || playerCar == null) {
      return;
    }

    survivalTime += dt;
    _consumeFuel(GameConfig.fuelDrainPerSecond * dt);
    _handleSmokeInput();
    _checkFlagCollection();
    _updateSmokeEffectsOnEnemies();
    _checkEnemyCollision();
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    inputSource.handleKeyEvent(event);

    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.f3) {
        toggleDebugOverlay();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyN) {
        unawaited(debugSkipStage());
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyG) {
        debugForceGameOver();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyR) {
        unawaited(_startNewRun());
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  Future<void> _startNewRun({int? seed}) async {
    if (_isLoadingStage) {
      return;
    }
    currentSeed = seed ?? _seedRandom.nextInt(0x7FFFFFFF);
    currentStage = 1;
    isGameOver = false;
    gameOverReason = '';
    fuel = GameConfig.maxFuel;
    survivalTime = 0;
    bonusScore = 0;
    _smokePressedLastFrame = false;
    inputSource.clear();
    await _loadStage();
  }

  Future<void> _advanceStage() async {
    if (_isLoadingStage || isGameOver) {
      return;
    }
    currentStage += 1;
    fuel = GameConfig.maxFuel;
    _smokePressedLastFrame = false;
    await _loadStage();
  }

  Future<void> _loadStage() async {
    _isLoadingStage = true;
    _removeCurrentLevelComponents();
    _refreshResponsiveLayoutTargets();

    final level = _providerForCurrentViewport().loadLevel(
      stage: currentStage,
      seed: currentSeed,
    );
    currentLevel = level;
    await _addLevelToWorld(level);
    _updateCameraZoomForViewport();
    _setCameraPositionForTarget(level.playerSpawn.toWorldCenter());

    playerCar = PlayerCarComponent(
      inputSource: inputSource,
      spawnPosition: level.playerSpawn.toWorldCenter(),
    );
    await _levelLayer.add(playerCar!);
    camera.stop();
    _updateCameraPosition();

    _isLoadingStage = false;
  }

  void _removeCurrentLevelComponents() {
    for (final child in _levelLayer.children.toList()) {
      child.removeFromParent();
    }
    _activeFlags.clear();
    _activeEnemies.clear();
    _activeSmokeClouds.clear();
    playerCar = null;
  }

  Future<void> _addLevelToWorld(LevelData level) async {
    final components = <Component>[
      _BackdropComponent(
        playfieldTilesWide: level.width,
        playfieldTilesHigh: level.height,
      ),
    ];

    for (var y = 0; y < level.height; y++) {
      for (var x = 0; x < level.width; x++) {
        final tile = TileCoordinate(x, y);
        final kind = level.tileAt(x, y);
        if (kind == TileKind.wall) {
          components.add(WallTileComponent(tile: tile));
        } else if (kind == TileKind.rock) {
          components.add(RockComponent(tile: tile));
        }
      }
    }

    final desiredEnemyCount = debugEnemyCountOverride == null
        ? 1 + currentStage
        : max(1, debugEnemyCountOverride!);
    final activeEnemyCount = min(level.enemySpawns.length, desiredEnemyCount);
    for (var i = 0; i < activeEnemyCount; i++) {
      final enemy = EnemyCarComponent(
        spawnTile: level.enemySpawns[i],
        stage: currentStage,
      );
      _activeEnemies.add(enemy);
      components.add(enemy);
    }

    for (final flagSpawn in level.flags) {
      final flagComponent = FlagComponent(spawn: flagSpawn);
      _activeFlags.add(flagComponent);
      components.add(flagComponent);
    }

    await _levelLayer.addAll(components);
  }

  void _consumeFuel(double amount) {
    fuel = (fuel - amount).clamp(0, GameConfig.maxFuel);
    if (fuel <= 0) {
      _setGameOver('Fuel depleted');
    }
  }

  void _setGameOver(String reason) {
    if (isGameOver) {
      return;
    }
    isGameOver = true;
    gameOverReason = reason;
    playerCar?.controlsEnabled = false;
    unawaited(_saveCurrentScore());
  }

  void _handleSmokeInput() {
    final smokePressed = currentCommand.smoke;
    if (smokePressed && !_smokePressedLastFrame) {
      _deploySmoke();
    }
    _smokePressedLastFrame = smokePressed;
  }

  void _deploySmoke() {
    if (playerCar == null || fuel < GameConfig.smokeFuelCost) {
      return;
    }

    _consumeFuel(GameConfig.smokeFuelCost);
    if (isGameOver || playerCar == null) {
      return;
    }

    final angle = playerCar!.body.angle;
    final forward = Vector2(cos(angle), sin(angle));
    final smokePosition = playerCar!.body.position - (forward * 0.8);
    final smoke = SmokeCloudComponent(
      position: smokePosition,
      lifetimeSeconds: GameConfig.smokeLifetimeSeconds,
    );
    _activeSmokeClouds.add(smoke);
    _levelLayer.add(smoke);
  }

  void _checkFlagCollection() {
    if (playerCar == null) {
      return;
    }
    final playerPosition = playerCar!.body.position;

    var collectedAny = false;
    for (final flag in _activeFlags) {
      if (flag.isCollected || flag.isRemoving) {
        continue;
      }
      final distance = (flag.body.position - playerPosition).length;
      if (distance <= 0.55) {
        flag.collect();
        bonusScore += GameConfig.flagBonusScore * (flag.isSpecial ? 2 : 1);
        collectedAny = true;
      }
    }

    if (collectedAny && remainingFlagCount == 0) {
      unawaited(_advanceStage());
    }
  }

  void _updateSmokeEffectsOnEnemies() {
    _activeSmokeClouds.removeWhere(
      (smoke) => smoke.isRemoving || !smoke.isMounted,
    );
    _activeEnemies.removeWhere((enemy) => enemy.isRemoving || !enemy.isMounted);

    for (final enemy in _activeEnemies) {
      if (enemy.stunRemaining > 0) {
        continue;
      }
      for (final smoke in _activeSmokeClouds) {
        final distance = (smoke.position - enemy.body.position).length;
        if (distance <= 0.75) {
          enemy.stun(1.25);
          break;
        }
      }
    }
  }

  void _checkEnemyCollision() {
    if (playerCar == null) {
      return;
    }
    final playerPosition = playerCar!.body.position;
    for (final enemy in _activeEnemies) {
      final distance = (enemy.body.position - playerPosition).length;
      if (distance <= 0.70) {
        _setGameOver('Hit by Robo-Taxi');
        return;
      }
    }
  }

  TileCoordinate worldToTile(Vector2 position) {
    final x = position.x.floor().clamp(0, _activePlayfieldTilesWide - 1);
    final y = position.y.floor().clamp(0, _activePlayfieldTilesHigh - 1);
    return TileCoordinate(x, y);
  }

  TileCoordinate? nextTileTowardsPlayer(TileCoordinate fromTile) {
    final level = currentLevel;
    final player = playerCar;
    if (level == null || player == null) {
      return null;
    }

    final targetTile = worldToTile(player.body.position);
    return _nextStepOnTileGraph(level, fromTile, targetTile);
  }

  TileCoordinate? _nextStepOnTileGraph(
    LevelData level,
    TileCoordinate from,
    TileCoordinate target,
  ) {
    if (from == target) {
      return target;
    }
    if (!level.isWalkable(from.x, from.y) ||
        !level.isWalkable(target.x, target.y)) {
      return null;
    }

    final queue = Queue<TileCoordinate>()..add(from);
    final visited = <TileCoordinate>{from};
    final previous = <TileCoordinate, TileCoordinate>{};

    const offsets = <(int, int)>[(0, -1), (1, 0), (0, 1), (-1, 0)];

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      if (current == target) {
        break;
      }

      for (final (dx, dy) in offsets) {
        final neighbor = TileCoordinate(current.x + dx, current.y + dy);
        if (!level.isInside(neighbor.x, neighbor.y) ||
            !level.isWalkable(neighbor.x, neighbor.y)) {
          continue;
        }
        if (visited.add(neighbor)) {
          previous[neighbor] = current;
          queue.add(neighbor);
        }
      }
    }

    if (!visited.contains(target)) {
      return null;
    }

    var step = target;
    while (previous.containsKey(step) && previous[step] != from) {
      step = previous[step]!;
    }
    return step;
  }

  void _updateCameraZoomForViewport() {
    final viewportSize = _resolveViewportSize();
    if (viewportSize == null) {
      return;
    }
    _refreshResponsiveLayoutTargetsForViewport(
      viewportWidth: viewportSize.width,
      viewportHeight: viewportSize.height,
    );

    final viewportWidth = viewportSize.width;
    final viewportHeight = viewportSize.height;
    final levelWidth = _activePlayfieldTilesWide.toDouble();
    final levelHeight = _activePlayfieldTilesHigh.toDouble();

    final minZoomForWidth = viewportWidth / levelWidth;
    final minZoomForHeight = viewportHeight / levelHeight;
    final minZoomNoOverscan = max(minZoomForWidth, minZoomForHeight);

    final rallyTargetWidthZoom = viewportWidth / _targetVisibleTilesX;
    final rallyTargetHeightZoom = viewportHeight / _targetVisibleTilesY;
    final rallyTargetZoom = max(rallyTargetWidthZoom, rallyTargetHeightZoom);

    final targetZoom = max(
      GameConfig.cameraZoom,
      max(minZoomNoOverscan + 0.05, rallyTargetZoom),
    );
    if ((camera.viewfinder.zoom - targetZoom).abs() > 0.001) {
      camera.viewfinder.zoom = targetZoom;
    }
  }

  void _updateCameraPosition() {
    final player = playerCar;
    if (player == null || !hasLayout) {
      return;
    }
    _setCameraPositionForTarget(player.body.position);
  }

  void _setCameraPositionForTarget(Vector2 target) {
    if (!hasLayout) {
      return;
    }

    final visibleRect = camera.visibleWorldRect;
    final halfWidth = visibleRect.width / 2;
    final halfHeight = visibleRect.height / 2;

    final levelWidth = _activePlayfieldTilesWide.toDouble();
    final levelHeight = _activePlayfieldTilesHigh.toDouble();
    var minX = halfWidth;
    var maxX = levelWidth - halfWidth;
    var minY = halfHeight;
    var maxY = levelHeight - halfHeight;

    if (minX > maxX) {
      minX = levelWidth / 2;
      maxX = minX;
    }
    if (minY > maxY) {
      minY = levelHeight / 2;
      maxY = minY;
    }

    final clampedX = target.x.clamp(minX, maxX).toDouble();
    final clampedY = target.y.clamp(minY, maxY).toDouble();
    camera.viewfinder.position = Vector2(clampedX, clampedY);
  }

  void toggleDebugOverlay() {
    debugOverlayVisible = !debugOverlayVisible;
    if (debugOverlayVisible) {
      overlays.add(DebugOverlay.id);
    } else {
      overlays.remove(DebugOverlay.id);
    }
  }

  void requestRestart() {
    unawaited(_startNewRun());
  }

  Future<void> debugSkipStage() => _advanceStage();

  void debugForceGameOver() {
    _setGameOver('Debug forced');
  }

  Future<void> debugCollectAllFlags() async {
    for (final flag in _activeFlags) {
      if (!flag.isCollected && !flag.isRemoving && flag.isMounted) {
        flag.collect();
      }
    }
    await _advanceStage();
  }

  Future<void> _loadHighScores() async {
    highScores = await highScoreRepository.loadTop10();
  }

  Future<void> _saveCurrentScore() async {
    final entry = ScoreEntry(
      survivalSeconds: survivalTime,
      stageReached: currentStage,
      createdAtIso: DateTime.now().toUtc().toIso8601String(),
    );
    highScores = await highScoreRepository.saveScore(entry);
  }

  int get _activePlayfieldTilesWide =>
      currentLevel?.width ?? _nextPlayfieldTilesWide;

  int get _activePlayfieldTilesHigh =>
      currentLevel?.height ?? _nextPlayfieldTilesHigh;

  LevelProvider _providerForCurrentViewport() {
    if (!_usesDefaultProceduralLevelProvider) {
      return levelProvider;
    }
    return ProceduralLevelProvider(
      width: _nextPlayfieldTilesWide,
      height: _nextPlayfieldTilesHigh,
    );
  }

  Size? _resolveViewportSize() {
    if (!hasLayout) {
      return null;
    }

    var viewportWidth = canvasSize.x;
    var viewportHeight = canvasSize.y;
    if (isAttached) {
      final boxSize = renderBox.size;
      viewportWidth = boxSize.width;
      viewportHeight = boxSize.height;
    }
    if (viewportWidth <= 0 || viewportHeight <= 0) {
      return null;
    }
    return Size(viewportWidth, viewportHeight);
  }

  void _refreshResponsiveLayoutTargets() {
    final viewportSize = _resolveViewportSize();
    if (viewportSize == null) {
      return;
    }
    _refreshResponsiveLayoutTargetsForViewport(
      viewportWidth: viewportSize.width,
      viewportHeight: viewportSize.height,
    );
  }

  void _refreshResponsiveLayoutTargetsForViewport({
    required double viewportWidth,
    required double viewportHeight,
  }) {
    final widthScale = max(
      1.0,
      viewportWidth / GameConfig.idealViewportWidthPx,
    );
    final heightScale = max(
      1.0,
      viewportHeight / GameConfig.idealViewportHeightPx,
    );

    _targetVisibleTilesX = GameConfig.cameraTargetVisibleTiles * widthScale;
    _targetVisibleTilesY = GameConfig.cameraTargetVisibleTiles * heightScale;

    _nextPlayfieldTilesWide = _snapProceduralDimension(
      desired: (GameConfig.playfieldTilesWide * widthScale).round(),
      minimum: GameConfig.playfieldTilesWide,
    );
    _nextPlayfieldTilesHigh = _snapProceduralDimension(
      desired: (GameConfig.playfieldTilesHigh * heightScale).round(),
      minimum: GameConfig.playfieldTilesHigh,
    );
  }

  int _snapProceduralDimension({required int desired, required int minimum}) {
    if (desired <= minimum) {
      return minimum;
    }

    final step = GameConfig.proceduralDimensionStep;
    final offset = GameConfig.proceduralDimensionOffset;
    final cells = ((desired - offset) / step).ceil();
    final snapped = cells * step + offset;
    return max(minimum, snapped);
  }
}

class _BackdropComponent extends PositionComponent {
  _BackdropComponent({
    required this.playfieldTilesWide,
    required this.playfieldTilesHigh,
  }) : super(
         size: Vector2(
           playfieldTilesWide.toDouble(),
           playfieldTilesHigh.toDouble(),
         ),
       );

  final int playfieldTilesWide;
  final int playfieldTilesHigh;

  final Paint _playfieldPaint = Paint()..color = const Color(0xFF161B22);
  final Paint _linePaint = Paint()
    ..color = const Color(0xFF2A3240)
    ..strokeWidth = 0.03;

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    canvas.drawRect(
      Rect.fromLTWH(
        0,
        0,
        playfieldTilesWide.toDouble(),
        playfieldTilesHigh.toDouble(),
      ),
      _playfieldPaint,
    );

    for (var x = 0.0; x <= playfieldTilesWide; x += 1.0) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, playfieldTilesHigh.toDouble()),
        _linePaint,
      );
    }
    for (var y = 0.0; y <= playfieldTilesHigh; y += 1.0) {
      canvas.drawLine(
        Offset(0, y),
        Offset(playfieldTilesWide.toDouble(), y),
        _linePaint,
      );
    }
  }
}
