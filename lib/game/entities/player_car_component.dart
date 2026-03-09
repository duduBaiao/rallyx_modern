import 'dart:math' as math;
import 'dart:ui';

import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:rallyx_modern/game/input/input_source.dart';
import 'package:rallyx_modern/game/input/vehicle_command.dart';
import 'package:rallyx_modern/game/rallyx_game.dart';

class PlayerCarComponent extends BodyComponent<RallyXGame> {
  PlayerCarComponent({
    required this.inputSource,
    required Vector2 spawnPosition,
  }) : super(
         renderBody: false,
         bodyDef: BodyDef(
           type: BodyType.dynamic,
           position: spawnPosition,
           angle: -math.pi / 2,
           linearDamping: 1.2,
           angularDamping: 3.8,
         ),
         fixtureDefs: [
           FixtureDef(
             PolygonShape()..setAsBoxXY(_halfLength, _halfWidth),
             density: 1.0,
             friction: 0.2,
             restitution: 0.0,
           ),
         ],
       );

  static const double _carLength = 1.4;
  static const double _carWidth = 0.8;
  static const double _halfLength = _carLength / 2;
  static const double _halfWidth = _carWidth / 2;

  static const double _engineForce = 52;
  static const double _brakeForce = 110;
  static const double _reverseForce = 38;
  static const double _coastDrag = 8;
  static const double _reverseThreshold = 0.35;
  static const double _maxForwardSpeed = 4.2;
  static const double _maxReverseSpeed = 1.8;
  static const double _minSteerSpeed = 0.55;
  static const double _lowSpeedSteerFactor = 0.55;
  static const double _maxSteerRate = 5.12;
  static const double _steerResponse = 20.0;
  static const double _lateralGrip = 0.85;
  static const double _wallSlideAssistForce = 32;
  static const double _wallSlideAssistForwardSpeedThreshold = 0.45;
  static const double _wallSlideAssistSteeringThreshold = 0.30;
  static const double _wallSlideAssistDelaySeconds = 0.12;
  static const double _stuckTurnAssistMinAngularVelocity = 1.4;
  static const double _stuckTurnAssistTorqueBoost = 28;

  final InputSource inputSource;
  bool controlsEnabled = true;
  double _lowForwardThrottleTime = 0;

  VehicleCommand _lastCommand = const VehicleCommand.idle();

  VehicleCommand get lastCommand => _lastCommand;
  double get speed => body.linearVelocity.length;

  static double steeringForTravelDirection({
    required double steeringInput,
    required double signedForwardSpeed,
  }) {
    return signedForwardSpeed >= 0 ? steeringInput : -steeringInput;
  }

  static double steeringForDriverIntent({
    required VehicleCommand command,
    required double signedForwardSpeed,
  }) {
    if (command.throttle > command.brake + 0.05) {
      return command.steering;
    }
    if (command.brake > command.throttle + 0.05) {
      return -command.steering;
    }
    return steeringForTravelDirection(
      steeringInput: command.steering,
      signedForwardSpeed: signedForwardSpeed,
    );
  }

  static bool shouldApplyWallSlideAssist({
    required double throttle,
    required double steering,
    required double forwardSpeed,
    required double lowForwardThrottleTime,
  }) {
    if (throttle <= 0) {
      return false;
    }
    if (steering.abs() < _wallSlideAssistSteeringThreshold) {
      return false;
    }
    if (forwardSpeed > _wallSlideAssistForwardSpeedThreshold) {
      return false;
    }
    return lowForwardThrottleTime >= _wallSlideAssistDelaySeconds;
  }

  final Paint _bodyPaint = Paint()..color = const Color(0xFF2B8CFF);
  final Paint _roofPaint = Paint()..color = const Color(0xFF1259AA);
  final Paint _windshieldPaint = Paint()..color = const Color(0xFF99D8FF);

  @override
  void update(double dt) {
    super.update(dt);

    if (!controlsEnabled) {
      body.linearVelocity = body.linearVelocity * 0.95;
      body.angularVelocity *= 0.8;
      return;
    }

    final command = inputSource.poll(dt);
    _lastCommand = command;

    _applyLateralFriction();
    _applyDrive(command, dt);
    _applySteering(command);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final bodyRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-_halfLength, -_halfWidth, _carLength, _carWidth),
      const Radius.circular(0.12),
    );
    canvas.drawRRect(bodyRect, _bodyPaint);

    final roofRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-0.35, -0.26, 0.7, 0.52),
      const Radius.circular(0.08),
    );
    canvas.drawRRect(roofRect, _roofPaint);

    final windshieldRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0.10, -0.20, 0.28, 0.40),
      const Radius.circular(0.06),
    );
    canvas.drawRRect(windshieldRect, _windshieldPaint);
  }

  void _applyDrive(VehicleCommand command, double dt) {
    final forward = _forwardVector();
    final right = _rightVector(forward);
    final velocity = body.linearVelocity;
    final forwardSpeed = velocity.dot(forward);

    var driveForce = 0.0;

    if (command.throttle > 0) {
      driveForce += _engineForce * command.throttle;
    }

    if (command.brake > 0) {
      if (forwardSpeed > _reverseThreshold) {
        driveForce -= _brakeForce * command.brake;
      } else {
        driveForce -= _reverseForce * command.brake;
      }
    }

    if (driveForce != 0) {
      body.applyForce(forward * driveForce);
    } else if (forwardSpeed.abs() > 0.05) {
      body.applyForce(forward * (-forwardSpeed * _coastDrag));
    }

    if (command.throttle > 0 &&
        forwardSpeed < _wallSlideAssistForwardSpeedThreshold) {
      _lowForwardThrottleTime += dt;
    } else {
      _lowForwardThrottleTime = 0;
    }

    if (shouldApplyWallSlideAssist(
      throttle: command.throttle,
      steering: command.steering,
      forwardSpeed: forwardSpeed,
      lowForwardThrottleTime: _lowForwardThrottleTime,
    )) {
      final sideDirection = steeringForDriverIntent(
        command: command,
        signedForwardSpeed: forwardSpeed,
      ).sign;
      final sideForceMagnitude =
          _wallSlideAssistForce * command.throttle * command.steering.abs();
      body.applyForce(right * (sideDirection * sideForceMagnitude));
    }

    _clampVelocity(forward, right);
  }

  void _applySteering(VehicleCommand command) {
    final forward = _forwardVector();
    final signedForwardSpeed = body.linearVelocity.dot(forward);
    final speed = signedForwardSpeed.abs();
    final stuckAssistActive = shouldApplyWallSlideAssist(
      throttle: command.throttle,
      steering: command.steering,
      forwardSpeed: speed,
      lowForwardThrottleTime: _lowForwardThrottleTime,
    );
    final hasDriveInput = command.throttle > 0 || command.brake > 0;
    if (speed < _minSteerSpeed) {
      if (!hasDriveInput || command.steering.abs() < 0.05) {
        body.angularVelocity *= 0.7;
        return;
      }
    }

    var speedRatio = speed < _minSteerSpeed
        ? ((speed / _minSteerSpeed) * 0.65 + 0.35).clamp(0.35, 1.0)
        : (speed / _maxForwardSpeed).clamp(0.45, 1.0);
    var steeringGain = speed < _minSteerSpeed ? _lowSpeedSteerFactor : 1.0;
    if (stuckAssistActive) {
      speedRatio = math.max(speedRatio, 0.85);
      steeringGain = math.max(steeringGain, 1.15);
    }
    final steeringDirection = steeringForDriverIntent(
      command: command,
      signedForwardSpeed: signedForwardSpeed,
    );
    final targetAngularVelocity =
        steeringDirection * _maxSteerRate * speedRatio * steeringGain;
    final angularVelocityDelta = targetAngularVelocity - body.angularVelocity;
    final torque = angularVelocityDelta * body.getInertia() * _steerResponse;
    body.applyTorque(torque);

    if (stuckAssistActive) {
      final desiredSpin =
          steeringDirection * _stuckTurnAssistMinAngularVelocity;
      if (body.angularVelocity.abs() <
          _stuckTurnAssistMinAngularVelocity * 0.65) {
        body.angularVelocity = body.angularVelocity * 0.8 + desiredSpin * 0.2;
      }
      body.applyTorque(
        steeringDirection * body.getInertia() * _stuckTurnAssistTorqueBoost,
      );
    }
  }

  void _applyLateralFriction() {
    final forward = _forwardVector();
    final right = _rightVector(forward);
    final lateralSpeed = body.linearVelocity.dot(right);
    final lateralImpulse = right * (-lateralSpeed * body.mass * _lateralGrip);
    body.applyLinearImpulse(lateralImpulse);

    body.angularVelocity *= 0.96;
  }

  void _clampVelocity(Vector2 forward, Vector2 right) {
    final velocity = body.linearVelocity;
    final forwardSpeed = velocity
        .dot(forward)
        .clamp(-_maxReverseSpeed, _maxForwardSpeed);
    final lateralSpeed = velocity.dot(right);
    body.linearVelocity = forward * forwardSpeed + right * lateralSpeed;
  }

  Vector2 _forwardVector() =>
      Vector2(math.cos(body.angle), math.sin(body.angle));

  Vector2 _rightVector(Vector2 forward) => Vector2(-forward.y, forward.x);
}
