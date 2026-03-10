import 'dart:math' as math;
import 'dart:ui';

import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:rallyx_modern/game/ai/enemy_command_brain.dart';
import 'package:rallyx_modern/game/ai/enemy_nav_planner.dart';
import 'package:rallyx_modern/game/ai/vehicle_dynamics.dart';
import 'package:rallyx_modern/game/level/level_data.dart';
import 'package:rallyx_modern/game/rallyx_game.dart';

class EnemyCarComponent extends BodyComponent<RallyXGame> {
  EnemyCarComponent({
    required this.spawnTile,
    required this.stage,
    required this.navPlanner,
  }) : _dynamicsController = VehicleDynamicsController(
         tuning: _enemyDynamicsTuningForStage(stage),
       ),
       _brain = EnemyCommandBrain(config: _brainConfigForStage(stage)),
       super(
         renderBody: false,
         bodyDef: BodyDef(
           type: BodyType.dynamic,
           position: spawnTile.toWorldCenter(),
           linearDamping: 1.4,
           angularDamping: 6.0,
         ),
         fixtureDefs: [
           FixtureDef(
             PolygonShape()..setAsBoxXY(_halfLength, _halfWidth),
             density: 0.9,
             friction: 0.2,
             restitution: 0.0,
           ),
         ],
       );

  static const double _carLength = 1.25;
  static const double _carWidth = 0.72;
  static const double _halfLength = _carLength / 2;
  static const double _halfWidth = _carWidth / 2;
  static const double _playerMaxForwardSpeed = 4.2;
  static const double _enemySpeedRatioToPlayer = 0.95;
  static const double _enemyMaxForwardSpeed =
      _playerMaxForwardSpeed * _enemySpeedRatioToPlayer;

  final TileCoordinate spawnTile;
  final int stage;
  final EnemyNavPlanner navPlanner;
  final VehicleDynamicsController _dynamicsController;
  final VehicleDynamicsRuntimeState _dynamicsRuntimeState =
      VehicleDynamicsRuntimeState();
  final EnemyCommandBrain _brain;

  double _stunTimer = 0;
  double _routeReplanTimer = 0;
  bool _headingInitialized = false;

  double get stunRemaining => _stunTimer;

  final Paint _bodyPaint = Paint()..color = const Color(0xFFE05656);
  final Paint _roofPaint = Paint()..color = const Color(0xFFA73B3B);

  @override
  void update(double dt) {
    super.update(dt);

    if (game.isGameOver) {
      body.linearVelocity = body.linearVelocity * 0.9;
      body.angularVelocity *= 0.85;
      return;
    }

    if (!_headingInitialized) {
      final player = game.playerCar;
      if (player != null) {
        final toPlayer = player.body.position - body.position;
        if (toPlayer.length2 > 0.0001) {
          body.setTransform(body.position, math.atan2(toPlayer.y, toPlayer.x));
        }
        _headingInitialized = true;
      }
    }

    if (_stunTimer > 0) {
      _stunTimer -= dt;
      body.linearVelocity = body.linearVelocity * 0.85;
      body.angularVelocity *= 0.8;
      return;
    }

    _routeReplanTimer -= dt;
    if (_routeReplanTimer <= 0) {
      _routeReplanTimer = 0.5;
      _replanRoute();
    }

    final bodyState = _dynamicsController.captureBodyState(body);
    final command = _brain.nextCommand(
      position: body.position.clone(),
      headingAngle: body.angle,
      signedForwardSpeed: bodyState.signedForwardSpeed,
      dt: dt,
      isBlockedWorldPosition: _isBlockedWorldPosition,
    );
    _dynamicsController.apply(
      body: body,
      command: command,
      dt: dt,
      runtimeState: _dynamicsRuntimeState,
    );
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final bodyRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-_halfLength, -_halfWidth, _carLength, _carWidth),
      const Radius.circular(0.10),
    );
    canvas.drawRRect(bodyRect, _bodyPaint);

    final roofRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-0.30, -0.22, 0.6, 0.44),
      const Radius.circular(0.07),
    );
    canvas.drawRRect(roofRect, _roofPaint);

    if (_stunTimer > 0) {
      final stunPaint = Paint()..color = const Color(0x88D8D8D8);
      canvas.drawCircle(Offset.zero, 0.7, stunPaint);
    }
  }

  void stun(double seconds) {
    _stunTimer = math.max(_stunTimer, seconds);
  }

  void _replanRoute() {
    final player = game.playerCar;
    if (player == null) {
      return;
    }
    final from = game.worldToTile(body.position);
    final to = game.worldToTile(player.body.position);
    final route = navPlanner.planRoute(from: from, to: to);
    if (route == null || route.waypointTiles.isEmpty) {
      _brain.setRoute([player.body.position.clone()]);
      return;
    }
    final pathPoints = route.pathWorldPositions(skipFirst: true);
    if (pathPoints.isEmpty) {
      _brain.setRoute([player.body.position.clone()]);
      return;
    }
    _brain.setRoute(pathPoints);
  }

  bool _isBlockedWorldPosition(Vector2 worldPosition) {
    final level = game.currentLevel;
    if (level == null) {
      return false;
    }
    final tileX = worldPosition.x.floor();
    final tileY = worldPosition.y.floor();
    if (!level.isInside(tileX, tileY)) {
      return true;
    }
    return !level.isWalkable(tileX, tileY);
  }

  static VehicleDynamicsTuning _enemyDynamicsTuningForStage(int stage) {
    return VehicleDynamicsTuning(
      engineForce: 46 + stage * 4.0,
      brakeForce: 120,
      reverseForce: 42,
      coastDrag: 10,
      reverseThreshold: 0.35,
      maxForwardSpeed: _enemyMaxForwardSpeed,
      maxReverseSpeed: 1.75,
      minSteerSpeed: 0.45,
      lowSpeedSteerFactor: 0.72,
      maxSteerRate: 13.824, // 10% down from 3x player steer rate
      steerResponse: 22, // avoid over-correction while keeping sharp turn cap
      lateralGrip: 0.9,
      angularDampingFactor: 0.95,
      wallSlideAssistForce: 34,
      wallSlideAssistForwardSpeedThreshold: 0.7,
      wallSlideAssistSteeringThreshold: 0.26,
      wallSlideAssistDelaySeconds: 0.08,
      stuckTurnAssistMinAngularVelocity: 1.4,
      stuckTurnAssistTorqueBoost: 30,
    );
  }

  static EnemyCommandBrainConfig _brainConfigForStage(int stage) {
    final desiredCruiseSpeed = 3.9 + stage * 0.45;
    return EnemyCommandBrainConfig(
      maxCruiseSpeed: math.min(desiredCruiseSpeed, _enemyMaxForwardSpeed),
      minTurnSpeed: 1.05 + stage * 0.06,
      lookaheadDistance: 2.0,
      minLookaheadDistance: 0.95,
      turnLookaheadReduction: 0.72,
      cornerCommitDistance: 0.95,
      cornerDotThreshold: 0.45,
      waypointReachDistance: 0.55,
      headingForFullSteer: 1.6,
      sharpTurnHeading: 1.0,
      speedHysteresis: 0.18,
      cruiseThrottle: 0.60,
      brakeWhenOverspeed: 0.55,
      stuckSpeedThreshold: 0.30,
      stuckProgressDistance: 0.12,
      stuckWindowSeconds: 0.75,
      escapeDurationSeconds: 0.80,
      escapeThrottle: 1.0,
      escapeSteering: 1.0,
      postEscapeCooldownSeconds: 0.20,
      obstacleProbeNearDistance: 1.0,
      obstacleProbeMidDistance: 1.8,
      obstacleProbeFarDistance: 2.6,
      obstacleProbeLateralOffset: 0.6,
      obstacleAvoidanceSteeringGain: 0.7,
      obstacleMaxSteeringBias: 0.63,
      obstacleImmediateTurnStrength: 1.0,
      obstacleSlowdownThreshold: 0.2,
      obstacleThrottleReduction: 0.7,
      obstacleBrakeStrength: 0.45,
      obstacleNearBlockMinThrottle: 0.42,
      obstacleNearBlockMaxBrake: 0.35,
    );
  }
}
