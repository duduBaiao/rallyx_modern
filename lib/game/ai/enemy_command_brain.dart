import 'dart:math' as math;

import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:rallyx_modern/game/input/vehicle_command.dart';

class EnemyCommandBrainConfig {
  const EnemyCommandBrainConfig({
    this.lookaheadDistance = 2.2,
    this.minLookaheadDistance = 1.05,
    this.turnLookaheadReduction = 0.6,
    this.cornerCommitDistance = 1.05,
    this.cornerDotThreshold = 0.4,
    this.waypointReachDistance = 0.55,
    this.maxCruiseSpeed = 4.2,
    this.minTurnSpeed = 1.2,
    this.headingForFullSteer = 1.2,
    this.sharpTurnHeading = 1.0,
    this.speedHysteresis = 0.22,
    this.cruiseThrottle = 0.42,
    this.brakeWhenOverspeed = 0.75,
    this.stuckSpeedThreshold = 0.30,
    this.stuckProgressDistance = 0.12,
    this.stuckWindowSeconds = 1.0,
    this.escapeDurationSeconds = 0.65,
    this.escapeThrottle = 1.0,
    this.escapeSteering = 0.85,
    this.postEscapeCooldownSeconds = 0.35,
    this.obstacleProbeNearDistance = 0.9,
    this.obstacleProbeMidDistance = 1.6,
    this.obstacleProbeFarDistance = 2.3,
    this.obstacleProbeLateralOffset = 0.8,
    this.obstacleAvoidanceSteeringGain = 0.9,
    this.obstacleMaxSteeringBias = 0.85,
    this.obstacleImmediateTurnStrength = 1.0,
    this.obstacleSlowdownThreshold = 0.35,
    this.obstacleThrottleReduction = 0.55,
    this.obstacleBrakeStrength = 0.35,
    this.obstacleNearBlockMinThrottle = 0.55,
    this.obstacleNearBlockMaxBrake = 0.20,
  });

  final double lookaheadDistance;
  final double minLookaheadDistance;
  final double turnLookaheadReduction;
  final double cornerCommitDistance;
  final double cornerDotThreshold;
  final double waypointReachDistance;
  final double maxCruiseSpeed;
  final double minTurnSpeed;
  final double headingForFullSteer;
  final double sharpTurnHeading;
  final double speedHysteresis;
  final double cruiseThrottle;
  final double brakeWhenOverspeed;
  final double stuckSpeedThreshold;
  final double stuckProgressDistance;
  final double stuckWindowSeconds;
  final double escapeDurationSeconds;
  final double escapeThrottle;
  final double escapeSteering;
  final double postEscapeCooldownSeconds;
  final double obstacleProbeNearDistance;
  final double obstacleProbeMidDistance;
  final double obstacleProbeFarDistance;
  final double obstacleProbeLateralOffset;
  final double obstacleAvoidanceSteeringGain;
  final double obstacleMaxSteeringBias;
  final double obstacleImmediateTurnStrength;
  final double obstacleSlowdownThreshold;
  final double obstacleThrottleReduction;
  final double obstacleBrakeStrength;
  final double obstacleNearBlockMinThrottle;
  final double obstacleNearBlockMaxBrake;
}

class EnemyCommandBrain {
  EnemyCommandBrain({EnemyCommandBrainConfig? config})
    : config = config ?? const EnemyCommandBrainConfig();

  final EnemyCommandBrainConfig config;
  final List<Vector2> _routeWaypoints = <Vector2>[];
  int _waypointIndex = 0;
  int _routeSignature = 0;

  Vector2? _lastProgressPosition;
  double _stuckTimer = 0;
  double _escapeTimer = 0;
  double _postEscapeCooldown = 0;
  double _escapeSteeringSign = 1;

  bool get isEscaping => _escapeTimer > 0;

  void setRoute(List<Vector2> waypoints) {
    final signature = _signatureForRoute(waypoints);
    if (signature != _routeSignature) {
      _routeSignature = signature;
      _waypointIndex = 0;
    }
    _routeWaypoints
      ..clear()
      ..addAll(waypoints.map((point) => point.clone()));
  }

  VehicleCommand nextCommand({
    required Vector2 position,
    required double headingAngle,
    required double signedForwardSpeed,
    required double dt,
    bool Function(Vector2 worldPosition)? isBlockedWorldPosition,
  }) {
    if (_routeWaypoints.isEmpty) {
      return const VehicleCommand.idle();
    }

    _advanceWaypointIndex(position);
    final speed = signedForwardSpeed.abs();
    var lookaheadDistance = _effectiveLookaheadDistance(
      speed: speed,
      headingError: 0,
    );
    var lookahead = _resolveLookaheadTarget(
      position,
      lookaheadDistance: lookaheadDistance,
    );
    var toTarget = lookahead - position;
    if (toTarget.length2 <= 0.0001) {
      return VehicleCommand(
        throttle: config.cruiseThrottle,
        brake: 0,
        steering: 0,
        smoke: false,
      );
    }

    final desiredHeading = math.atan2(toTarget.y, toTarget.x);
    var headingError = _normalizeAngle(desiredHeading - headingAngle);
    lookaheadDistance = _effectiveLookaheadDistance(
      speed: speed,
      headingError: headingError.abs(),
    );
    lookahead = _resolveLookaheadTarget(
      position,
      lookaheadDistance: lookaheadDistance,
    );
    toTarget = lookahead - position;
    if (toTarget.length2 > 0.0001) {
      final refinedDesiredHeading = math.atan2(toTarget.y, toTarget.x);
      headingError = _normalizeAngle(refinedDesiredHeading - headingAngle);
    }
    final steering = (headingError / config.headingForFullSteer).clamp(
      -1.0,
      1.0,
    );

    final escape = _maybeEscape(
      position: position,
      signedForwardSpeed: signedForwardSpeed,
      dt: dt,
      steering: steering,
    );
    if (escape != null) {
      return _applyObstacleAvoidance(
        command: escape,
        position: position,
        headingAngle: headingAngle,
        isBlockedWorldPosition: isBlockedWorldPosition,
      );
    }

    final targetSpeed = _targetSpeedForHeadingError(headingError.abs());
    var throttle = 0.0;
    var brake = 0.0;

    if (headingError.abs() > config.sharpTurnHeading &&
        speed > targetSpeed + config.speedHysteresis) {
      brake = config.brakeWhenOverspeed;
    } else if (speed < targetSpeed - config.speedHysteresis) {
      throttle = 1.0;
    } else if (speed > targetSpeed + config.speedHysteresis) {
      brake = config.brakeWhenOverspeed;
    } else {
      throttle = config.cruiseThrottle;
    }

    final driveCommand = VehicleCommand(
      throttle: throttle,
      brake: brake,
      steering: steering,
      smoke: false,
    );
    return _applyObstacleAvoidance(
      command: driveCommand,
      position: position,
      headingAngle: headingAngle,
      isBlockedWorldPosition: isBlockedWorldPosition,
    );
  }

  double _targetSpeedForHeadingError(double headingError) {
    final turnFactor = (headingError / config.sharpTurnHeading).clamp(0.0, 1.0);
    return config.maxCruiseSpeed -
        (config.maxCruiseSpeed - config.minTurnSpeed) * turnFactor;
  }

  VehicleCommand? _maybeEscape({
    required Vector2 position,
    required double signedForwardSpeed,
    required double dt,
    required double steering,
  }) {
    _postEscapeCooldown = math.max(0, _postEscapeCooldown - dt);

    if (_escapeTimer > 0) {
      _escapeTimer = math.max(0, _escapeTimer - dt);
      if (_escapeTimer == 0) {
        _postEscapeCooldown = config.postEscapeCooldownSeconds;
      }
      return VehicleCommand(
        throttle: config.escapeThrottle,
        brake: 0,
        steering: _escapeSteeringSign * config.escapeSteering,
        smoke: false,
      );
    }

    final previous = _lastProgressPosition;
    if (previous == null) {
      _lastProgressPosition = position.clone();
    } else if ((position - previous).length >= config.stuckProgressDistance) {
      _lastProgressPosition = position.clone();
      _stuckTimer = 0;
      return null;
    }

    if (_postEscapeCooldown > 0) {
      return null;
    }
    if (signedForwardSpeed.abs() <= config.stuckSpeedThreshold) {
      _stuckTimer += dt;
    } else {
      _stuckTimer = math.max(0, _stuckTimer - dt * 0.5);
    }

    if (_stuckTimer < config.stuckWindowSeconds) {
      return null;
    }

    _stuckTimer = 0;
    _escapeTimer = config.escapeDurationSeconds;
    final steeringSign = steering.sign;
    _escapeSteeringSign = steeringSign == 0 ? 1 : steeringSign;
    return VehicleCommand(
      throttle: config.escapeThrottle,
      brake: 0,
      steering: _escapeSteeringSign * config.escapeSteering,
      smoke: false,
    );
  }

  void _advanceWaypointIndex(Vector2 position) {
    while (_waypointIndex < _routeWaypoints.length - 1 &&
        (_routeWaypoints[_waypointIndex] - position).length <=
            config.waypointReachDistance) {
      _waypointIndex++;
    }
  }

  Vector2 _resolveLookaheadTarget(
    Vector2 position, {
    required double lookaheadDistance,
  }) {
    var index = _waypointIndex;
    final cornerIndex = _firstCornerIndexFrom(_waypointIndex);
    while (index < _routeWaypoints.length - 1 &&
        (_routeWaypoints[index] - position).length < lookaheadDistance) {
      if (cornerIndex != null &&
          index >= cornerIndex &&
          (_routeWaypoints[cornerIndex] - position).length >
              config.cornerCommitDistance) {
        break;
      }
      index++;
    }
    return _routeWaypoints[index];
  }

  int? _firstCornerIndexFrom(int startIndex) {
    if (_routeWaypoints.length < 3) {
      return null;
    }
    final begin = math.max(1, startIndex);
    for (var i = begin; i < _routeWaypoints.length - 1; i++) {
      final from = _routeWaypoints[i] - _routeWaypoints[i - 1];
      final to = _routeWaypoints[i + 1] - _routeWaypoints[i];
      if (from.length2 <= 0.0001 || to.length2 <= 0.0001) {
        continue;
      }
      from.normalize();
      to.normalize();
      if (from.dot(to) < config.cornerDotThreshold) {
        return i;
      }
    }
    return null;
  }

  double _effectiveLookaheadDistance({
    required double speed,
    required double headingError,
  }) {
    final cruise = math.max(config.maxCruiseSpeed, 0.001);
    final speedFactor = (speed / cruise).clamp(0.0, 1.0);
    var lookahead =
        config.minLookaheadDistance +
        (config.lookaheadDistance - config.minLookaheadDistance) * speedFactor;
    final turnFactor = (headingError / config.sharpTurnHeading).clamp(0.0, 1.0);
    lookahead *= 1 - turnFactor * config.turnLookaheadReduction;
    return lookahead.clamp(
      config.minLookaheadDistance,
      config.lookaheadDistance,
    );
  }

  VehicleCommand _applyObstacleAvoidance({
    required VehicleCommand command,
    required Vector2 position,
    required double headingAngle,
    required bool Function(Vector2 worldPosition)? isBlockedWorldPosition,
  }) {
    if (isBlockedWorldPosition == null) {
      return command;
    }

    final forward = Vector2(math.cos(headingAngle), math.sin(headingAngle));
    final side = Vector2(-forward.y, forward.x);
    final probe = _probeObstacleDanger(
      position: position,
      headingAngle: headingAngle,
      forward: forward,
      side: side,
      isBlockedWorldPosition: isBlockedWorldPosition,
    );
    if (probe.totalDanger <= 0.0001) {
      return command;
    }

    final bias =
        (probe.negativeSteerDanger - probe.positiveSteerDanger) *
        config.obstacleAvoidanceSteeringGain;
    var steering =
        (command.steering +
                bias.clamp(
                  -config.obstacleMaxSteeringBias,
                  config.obstacleMaxSteeringBias,
                ))
            .clamp(-1.0, 1.0);

    if (probe.nearCenterBlocked) {
      final clearSideSteerSign =
          probe.positiveSteerDanger <= probe.negativeSteerDanger ? 1.0 : -1.0;
      final steerMagnitude = math.max(
        steering.abs(),
        config.obstacleImmediateTurnStrength,
      );
      steering = clearSideSteerSign * steerMagnitude;
    }

    var throttle = command.throttle;
    var brake = command.brake;
    if (probe.centerDanger > config.obstacleSlowdownThreshold) {
      final overThreshold =
          (probe.centerDanger - config.obstacleSlowdownThreshold) /
          (1 - config.obstacleSlowdownThreshold);
      final normalized = overThreshold.clamp(0.0, 1.0);
      throttle *= (1 - normalized * config.obstacleThrottleReduction).clamp(
        0.0,
        1.0,
      );
      brake = math.max(brake, normalized * config.obstacleBrakeStrength);
    }
    if (probe.nearCenterBlocked) {
      throttle = math.max(throttle, config.obstacleNearBlockMinThrottle);
      brake = math.min(brake, config.obstacleNearBlockMaxBrake);
    }

    return VehicleCommand(
      throttle: throttle,
      brake: brake,
      steering: steering,
      smoke: command.smoke,
    );
  }

  _ObstacleProbeResult _probeObstacleDanger({
    required Vector2 position,
    required double headingAngle,
    required Vector2 forward,
    required Vector2 side,
    required bool Function(Vector2 worldPosition) isBlockedWorldPosition,
  }) {
    const ringWeights = <double>[1.0, 0.7, 0.45];
    final ringDistances = <double>[
      config.obstacleProbeNearDistance,
      config.obstacleProbeMidDistance,
      config.obstacleProbeFarDistance,
    ];

    var centerDanger = 0.0;
    var centerWeightTotal = 0.0;
    var positiveSteerDanger = 0.0;
    var negativeSteerDanger = 0.0;
    var sideWeightTotal = 0.0;
    var nearCenterBlocked = false;

    for (var i = 0; i < ringDistances.length; i++) {
      final distance = ringDistances[i];
      final ringWeight = ringWeights[i];
      centerWeightTotal += ringWeight;
      sideWeightTotal += ringWeight * 1.5;
      final ahead = position + forward * distance;
      if (isBlockedWorldPosition(ahead)) {
        centerDanger += ringWeight;
        if (i == 0) {
          nearCenterBlocked = true;
        }
      }

      final primaryOffset = side * config.obstacleProbeLateralOffset;
      final outerOffset = side * (config.obstacleProbeLateralOffset * 1.6);
      _accumulateSideDanger(
        sample: ahead + primaryOffset,
        sampleWeight: ringWeight,
        position: position,
        headingAngle: headingAngle,
        isBlockedWorldPosition: isBlockedWorldPosition,
        onPositiveSteerDanger: (weight) => positiveSteerDanger += weight,
        onNegativeSteerDanger: (weight) => negativeSteerDanger += weight,
      );
      _accumulateSideDanger(
        sample: ahead - primaryOffset,
        sampleWeight: ringWeight,
        position: position,
        headingAngle: headingAngle,
        isBlockedWorldPosition: isBlockedWorldPosition,
        onPositiveSteerDanger: (weight) => positiveSteerDanger += weight,
        onNegativeSteerDanger: (weight) => negativeSteerDanger += weight,
      );
      _accumulateSideDanger(
        sample: ahead + outerOffset,
        sampleWeight: ringWeight * 0.5,
        position: position,
        headingAngle: headingAngle,
        isBlockedWorldPosition: isBlockedWorldPosition,
        onPositiveSteerDanger: (weight) => positiveSteerDanger += weight,
        onNegativeSteerDanger: (weight) => negativeSteerDanger += weight,
      );
      _accumulateSideDanger(
        sample: ahead - outerOffset,
        sampleWeight: ringWeight * 0.5,
        position: position,
        headingAngle: headingAngle,
        isBlockedWorldPosition: isBlockedWorldPosition,
        onPositiveSteerDanger: (weight) => positiveSteerDanger += weight,
        onNegativeSteerDanger: (weight) => negativeSteerDanger += weight,
      );
    }

    return _ObstacleProbeResult(
      centerDanger: centerWeightTotal == 0
          ? 0
          : centerDanger / centerWeightTotal,
      positiveSteerDanger: sideWeightTotal == 0
          ? 0
          : positiveSteerDanger / sideWeightTotal,
      negativeSteerDanger: sideWeightTotal == 0
          ? 0
          : negativeSteerDanger / sideWeightTotal,
      nearCenterBlocked: nearCenterBlocked,
    );
  }

  void _accumulateSideDanger({
    required Vector2 sample,
    required double sampleWeight,
    required Vector2 position,
    required double headingAngle,
    required bool Function(Vector2 worldPosition) isBlockedWorldPosition,
    required void Function(double weight) onPositiveSteerDanger,
    required void Function(double weight) onNegativeSteerDanger,
  }) {
    if (!isBlockedWorldPosition(sample)) {
      return;
    }
    final sampleDirection = sample - position;
    final sampleHeading = math.atan2(sampleDirection.y, sampleDirection.x);
    final steerSign = _normalizeAngle(sampleHeading - headingAngle).sign;
    if (steerSign >= 0) {
      onPositiveSteerDanger(sampleWeight);
    } else {
      onNegativeSteerDanger(sampleWeight);
    }
  }

  int _signatureForRoute(List<Vector2> waypoints) {
    if (waypoints.isEmpty) {
      return 0;
    }
    final first = waypoints.first;
    final last = waypoints.last;
    return Object.hash(
      waypoints.length,
      (first.x * 100).round(),
      (first.y * 100).round(),
      (last.x * 100).round(),
      (last.y * 100).round(),
    );
  }

  double _normalizeAngle(double angle) {
    while (angle > math.pi) {
      angle -= 2 * math.pi;
    }
    while (angle < -math.pi) {
      angle += 2 * math.pi;
    }
    return angle;
  }
}

class _ObstacleProbeResult {
  const _ObstacleProbeResult({
    required this.centerDanger,
    required this.positiveSteerDanger,
    required this.negativeSteerDanger,
    required this.nearCenterBlocked,
  });

  final double centerDanger;
  final double positiveSteerDanger;
  final double negativeSteerDanger;
  final bool nearCenterBlocked;

  double get totalDanger => math.max(
    centerDanger,
    math.max(positiveSteerDanger, negativeSteerDanger),
  );
}
