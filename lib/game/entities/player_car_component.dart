import 'dart:math' as math;
import 'dart:ui';

import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:rallyx_modern/game/ai/vehicle_dynamics.dart';
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
  static const VehicleDynamicsTuning _playerDynamicsTuning =
      VehicleDynamicsTuning(
        engineForce: _engineForce,
        brakeForce: _brakeForce,
        reverseForce: _reverseForce,
        coastDrag: _coastDrag,
        reverseThreshold: _reverseThreshold,
        maxForwardSpeed: _maxForwardSpeed,
        maxReverseSpeed: _maxReverseSpeed,
        minSteerSpeed: _minSteerSpeed,
        lowSpeedSteerFactor: _lowSpeedSteerFactor,
        maxSteerRate: _maxSteerRate,
        steerResponse: _steerResponse,
        lateralGrip: _lateralGrip,
        angularDampingFactor: 0.96,
        wallSlideAssistForce: _wallSlideAssistForce,
        wallSlideAssistForwardSpeedThreshold:
            _wallSlideAssistForwardSpeedThreshold,
        wallSlideAssistSteeringThreshold: _wallSlideAssistSteeringThreshold,
        wallSlideAssistDelaySeconds: _wallSlideAssistDelaySeconds,
        stuckTurnAssistMinAngularVelocity: _stuckTurnAssistMinAngularVelocity,
        stuckTurnAssistTorqueBoost: _stuckTurnAssistTorqueBoost,
      );

  final InputSource inputSource;
  bool controlsEnabled = true;
  final VehicleDynamicsController _dynamicsController =
      const VehicleDynamicsController(tuning: _playerDynamicsTuning);
  final VehicleDynamicsRuntimeState _dynamicsState =
      VehicleDynamicsRuntimeState();

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
    _dynamicsController.apply(
      body: body,
      command: command,
      dt: dt,
      runtimeState: _dynamicsState,
    );
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
}
