import 'package:rallyx_modern/game/input/vehicle_command.dart';

abstract class InputSource {
  VehicleCommand poll(double dt);
}
