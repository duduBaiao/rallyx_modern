import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:rallyx_modern/game/input/input_source.dart';
import 'package:rallyx_modern/game/input/vehicle_command.dart';

class KeyboardInputSource implements InputSource {
  final Set<LogicalKeyboardKey> _pressedKeys = <LogicalKeyboardKey>{};

  @override
  void clear() => _pressedKeys.clear();

  @override
  void handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      _pressedKeys.add(event.logicalKey);
      return;
    }
    if (event is KeyUpEvent) {
      _pressedKeys.remove(event.logicalKey);
    }
  }

  bool isPressed(LogicalKeyboardKey key) => _pressedKeys.contains(key);

  @override
  VehicleCommand poll(double dt) {
    final throttle = isPressed(LogicalKeyboardKey.arrowUp) ? 1.0 : 0.0;
    final brake = isPressed(LogicalKeyboardKey.arrowDown) ? 1.0 : 0.0;

    final left = isPressed(LogicalKeyboardKey.arrowLeft) ? -1.0 : 0.0;
    final right = isPressed(LogicalKeyboardKey.arrowRight) ? 1.0 : 0.0;
    final steering = math.max(-1.0, math.min(1.0, left + right));

    final smoke = isPressed(LogicalKeyboardKey.space);

    return VehicleCommand(
      throttle: throttle,
      brake: brake,
      steering: steering,
      smoke: smoke,
    );
  }
}
