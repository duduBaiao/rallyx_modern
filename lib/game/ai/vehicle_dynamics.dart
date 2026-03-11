import 'dart:math' as math;

import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:rallyx_modern/game/input/vehicle_command.dart';

class VehicleDynamicsTuning {
  const VehicleDynamicsTuning({
    required this.engineForce,
    required this.brakeForce,
    required this.reverseForce,
    required this.coastDrag,
    required this.reverseThreshold,
    required this.maxForwardSpeed,
    required this.maxReverseSpeed,
    required this.minSteerSpeed,
    required this.lowSpeedSteerFactor,
    required this.maxSteerRate,
    required this.steerResponse,
    required this.lateralGrip,
    required this.angularDampingFactor,
    required this.wallSlideAssistForce,
    required this.wallSlideAssistForwardSpeedThreshold,
    required this.wallSlideAssistSteeringThreshold,
    required this.wallSlideAssistDelaySeconds,
    required this.stuckTurnAssistMinAngularVelocity,
    required this.stuckTurnAssistTorqueBoost,
  });

  final double engineForce;
  final double brakeForce;
  final double reverseForce;
  final double coastDrag;
  final double reverseThreshold;
  final double maxForwardSpeed;
  final double maxReverseSpeed;
  final double minSteerSpeed;
  final double lowSpeedSteerFactor;
  final double maxSteerRate;
  final double steerResponse;
  final double lateralGrip;
  final double angularDampingFactor;
  final double wallSlideAssistForce;
  final double wallSlideAssistForwardSpeedThreshold;
  final double wallSlideAssistSteeringThreshold;
  final double wallSlideAssistDelaySeconds;
  final double stuckTurnAssistMinAngularVelocity;
  final double stuckTurnAssistTorqueBoost;
}

class VehicleDynamicsRuntimeState {
  double lowForwardThrottleTime = 0;
}

class VehicleBodyState {
  const VehicleBodyState({
    required this.forward,
    required this.right,
    required this.signedForwardSpeed,
    required this.lateralSpeed,
    required this.speed,
  });

  factory VehicleBodyState.fromBody(Body body) {
    final forward = Vector2(math.cos(body.angle), math.sin(body.angle));
    final right = Vector2(-forward.y, forward.x);
    final velocity = body.linearVelocity;
    final signedForwardSpeed = velocity.dot(forward);
    final lateralSpeed = velocity.dot(right);
    return VehicleBodyState(
      forward: forward,
      right: right,
      signedForwardSpeed: signedForwardSpeed,
      lateralSpeed: lateralSpeed,
      speed: velocity.length,
    );
  }

  final Vector2 forward;
  final Vector2 right;
  final double signedForwardSpeed;
  final double lateralSpeed;
  final double speed;
}

class VehicleDynamicsController {
  const VehicleDynamicsController({required this.tuning});

  final VehicleDynamicsTuning tuning;

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
    required double wallSlideAssistSteeringThreshold,
    required double wallSlideAssistForwardSpeedThreshold,
    required double wallSlideAssistDelaySeconds,
  }) {
    if (throttle <= 0) {
      return false;
    }
    if (steering.abs() < wallSlideAssistSteeringThreshold) {
      return false;
    }
    if (forwardSpeed > wallSlideAssistForwardSpeedThreshold) {
      return false;
    }
    return lowForwardThrottleTime >= wallSlideAssistDelaySeconds;
  }

  VehicleBodyState captureBodyState(Body body) =>
      VehicleBodyState.fromBody(body);

  void apply({
    required Body body,
    required VehicleCommand command,
    required double dt,
    required VehicleDynamicsRuntimeState runtimeState,
  }) {
    _applyLateralFriction(body);
    _applyDrive(body, command, dt, runtimeState);
    _applySteering(body, command, runtimeState);
  }

  void _applyDrive(
    Body body,
    VehicleCommand command,
    double dt,
    VehicleDynamicsRuntimeState runtimeState,
  ) {
    final forward = _forwardVector(body);
    final right = _rightVector(forward);
    final velocity = body.linearVelocity;
    final forwardSpeed = velocity.dot(forward);

    var driveForce = 0.0;
    if (command.throttle > 0) {
      driveForce += tuning.engineForce * command.throttle;
    }
    if (command.brake > 0) {
      if (forwardSpeed > tuning.reverseThreshold) {
        driveForce -= tuning.brakeForce * command.brake;
      } else {
        driveForce -= tuning.reverseForce * command.brake;
      }
    }

    if (driveForce != 0) {
      body.applyForce(forward * driveForce);
    } else if (forwardSpeed.abs() > 0.05) {
      body.applyForce(forward * (-forwardSpeed * tuning.coastDrag));
    }

    if (command.throttle > 0 &&
        forwardSpeed < tuning.wallSlideAssistForwardSpeedThreshold) {
      runtimeState.lowForwardThrottleTime += dt;
    } else {
      runtimeState.lowForwardThrottleTime = 0;
    }

    if (shouldApplyWallSlideAssist(
      throttle: command.throttle,
      steering: command.steering,
      forwardSpeed: forwardSpeed,
      lowForwardThrottleTime: runtimeState.lowForwardThrottleTime,
      wallSlideAssistSteeringThreshold: tuning.wallSlideAssistSteeringThreshold,
      wallSlideAssistForwardSpeedThreshold:
          tuning.wallSlideAssistForwardSpeedThreshold,
      wallSlideAssistDelaySeconds: tuning.wallSlideAssistDelaySeconds,
    )) {
      final sideDirection = steeringForDriverIntent(
        command: command,
        signedForwardSpeed: forwardSpeed,
      ).sign;
      final sideForceMagnitude =
          tuning.wallSlideAssistForce *
          command.throttle *
          command.steering.abs();
      body.applyForce(right * (sideDirection * sideForceMagnitude));
    }

    _clampVelocity(body, forward, right);
  }

  void _applySteering(
    Body body,
    VehicleCommand command,
    VehicleDynamicsRuntimeState runtimeState,
  ) {
    final forward = _forwardVector(body);
    final signedForwardSpeed = body.linearVelocity.dot(forward);
    final speed = signedForwardSpeed.abs();
    final stuckAssistActive = shouldApplyWallSlideAssist(
      throttle: command.throttle,
      steering: command.steering,
      forwardSpeed: speed,
      lowForwardThrottleTime: runtimeState.lowForwardThrottleTime,
      wallSlideAssistSteeringThreshold: tuning.wallSlideAssistSteeringThreshold,
      wallSlideAssistForwardSpeedThreshold:
          tuning.wallSlideAssistForwardSpeedThreshold,
      wallSlideAssistDelaySeconds: tuning.wallSlideAssistDelaySeconds,
    );
    final hasDriveInput = command.throttle > 0 || command.brake > 0;
    if (speed < tuning.minSteerSpeed) {
      if (!hasDriveInput || command.steering.abs() < 0.05) {
        body.angularVelocity *= 0.7;
        return;
      }
    }

    final lowSpeedRatio = speed < tuning.minSteerSpeed
        ? (speed / tuning.minSteerSpeed).clamp(0.0, 1.0)
        : 1.0;
    var speedRatio = speed < tuning.minSteerSpeed
        ? (0.18 + lowSpeedRatio * 0.47).clamp(0.18, 0.65)
        : (speed / tuning.maxForwardSpeed).clamp(0.45, 1.0);
    var steeringGain = speed < tuning.minSteerSpeed
        ? (tuning.lowSpeedSteerFactor * (0.45 + lowSpeedRatio * 0.55)).clamp(
            0.22,
            tuning.lowSpeedSteerFactor,
          )
        : 1.0;
    if (stuckAssistActive) {
      speedRatio = math.max(speedRatio, 0.85);
      steeringGain = math.max(steeringGain, 1.15);
    }
    final steeringDirection = steeringForDriverIntent(
      command: command,
      signedForwardSpeed: signedForwardSpeed,
    );
    final targetAngularVelocity =
        steeringDirection * tuning.maxSteerRate * speedRatio * steeringGain;
    final angularVelocityDelta = targetAngularVelocity - body.angularVelocity;
    final torque =
        angularVelocityDelta * body.getInertia() * tuning.steerResponse;
    body.applyTorque(torque);

    if (stuckAssistActive) {
      final desiredSpin =
          steeringDirection * tuning.stuckTurnAssistMinAngularVelocity;
      if (body.angularVelocity.abs() <
          tuning.stuckTurnAssistMinAngularVelocity * 0.65) {
        body.angularVelocity = body.angularVelocity * 0.8 + desiredSpin * 0.2;
      }
      body.applyTorque(
        steeringDirection *
            body.getInertia() *
            tuning.stuckTurnAssistTorqueBoost,
      );
    }
  }

  void _applyLateralFriction(Body body) {
    final forward = _forwardVector(body);
    final right = _rightVector(forward);
    final lateralSpeed = body.linearVelocity.dot(right);
    final lateralImpulse =
        right * (-lateralSpeed * body.mass * tuning.lateralGrip);
    body.applyLinearImpulse(lateralImpulse);
    body.angularVelocity *= tuning.angularDampingFactor;
  }

  void _clampVelocity(Body body, Vector2 forward, Vector2 right) {
    final velocity = body.linearVelocity;
    final forwardSpeed = velocity
        .dot(forward)
        .clamp(-tuning.maxReverseSpeed, tuning.maxForwardSpeed);
    final lateralSpeed = velocity.dot(right);
    body.linearVelocity = forward * forwardSpeed + right * lateralSpeed;
  }

  Vector2 _forwardVector(Body body) =>
      Vector2(math.cos(body.angle), math.sin(body.angle));

  Vector2 _rightVector(Vector2 forward) => Vector2(-forward.y, forward.x);
}
