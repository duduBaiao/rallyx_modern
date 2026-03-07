class VehicleCommand {
  const VehicleCommand({
    required this.throttle,
    required this.brake,
    required this.steering,
    required this.smoke,
  });

  const VehicleCommand.idle()
    : throttle = 0,
      brake = 0,
      steering = 0,
      smoke = false;

  final double throttle; // 0..1
  final double brake; // 0..1
  final double steering; // -1..1
  final bool smoke;
}
