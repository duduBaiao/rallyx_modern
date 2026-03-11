import 'package:flutter/services.dart';
import 'package:rallyx_modern/game/input/game_controls_input.dart';
import 'package:rallyx_modern/game/input/input_source.dart';
import 'package:rallyx_modern/game/input/vehicle_command.dart';

class GameControlsInputSource implements InputSource {
  GameControlsInput _latestInput = const GameControlsInput.neutral();

  static const double maxSteeringWheelDeg = 70;
  static const double maxRoadWheelDeg = 35;
  static const double steeringRatio = maxSteeringWheelDeg / maxRoadWheelDeg;

  void update(GameControlsInput input) {
    _latestInput = input;
  }

  @override
  void clear() {
    _latestInput = const GameControlsInput.neutral();
  }

  @override
  void handleKeyEvent(KeyEvent event) {}

  @override
  VehicleCommand poll(double dt) {
    final roadWheelDeg = (_latestInput.steeringWheelDeg / steeringRatio).clamp(
      -maxRoadWheelDeg,
      maxRoadWheelDeg,
    );
    final steering = (roadWheelDeg / maxRoadWheelDeg).clamp(-1.0, 1.0);

    final throttle = (_latestInput.throttlePercent / 100).clamp(0.0, 1.0);
    final brake = (_latestInput.brakePercent / 100).clamp(0.0, 1.0);

    return VehicleCommand(
      throttle: throttle,
      brake: brake,
      steering: steering,
      smoke: _latestInput.emergencyPressed,
    );
  }
}
