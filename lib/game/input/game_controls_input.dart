class GameControlsInput {
  const GameControlsInput({
    required this.steeringWheelDeg,
    required this.throttlePercent,
    required this.brakePercent,
    required this.emergencyPressed,
  });

  const GameControlsInput.neutral()
    : steeringWheelDeg = 0,
      throttlePercent = 0,
      brakePercent = 0,
      emergencyPressed = false;

  final double steeringWheelDeg;
  final double throttlePercent;
  final double brakePercent;
  final bool emergencyPressed;
}
