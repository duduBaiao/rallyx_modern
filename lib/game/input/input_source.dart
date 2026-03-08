import 'package:flutter/services.dart';
import 'package:rallyx_modern/game/input/vehicle_command.dart';

abstract class InputSource {
  VehicleCommand poll(double dt);

  void clear() {}

  void handleKeyEvent(KeyEvent event) {}
}
