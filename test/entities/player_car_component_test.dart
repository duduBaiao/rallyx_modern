import 'package:flutter_test/flutter_test.dart';
import 'package:rallyx_modern/game/entities/player_car_component.dart';
import 'package:rallyx_modern/game/input/vehicle_command.dart';

void main() {
  test('steering direction is unchanged while moving forward', () {
    final steering = PlayerCarComponent.steeringForTravelDirection(
      steeringInput: 1,
      signedForwardSpeed: 0.8,
    );
    expect(steering, 1);
  });

  test('steering direction is inverted while moving in reverse', () {
    final steering = PlayerCarComponent.steeringForTravelDirection(
      steeringInput: 1,
      signedForwardSpeed: -0.8,
    );
    expect(steering, -1);
  });

  test('wall slide assist activates only in stuck-like throttle state', () {
    final shouldAssist = PlayerCarComponent.shouldApplyWallSlideAssist(
      throttle: 1.0,
      steering: 0.8,
      forwardSpeed: 0.1,
      lowForwardThrottleTime: 0.2,
    );
    expect(shouldAssist, isTrue);
  });

  test('near-zero speed steering follows throttle intent', () {
    final steering = PlayerCarComponent.steeringForDriverIntent(
      command: const VehicleCommand(
        throttle: 1,
        brake: 0,
        steering: 1,
        smoke: false,
      ),
      signedForwardSpeed: -0.05,
    );
    expect(steering, 1);
  });

  test('throttle steering intent stays stable while moving backward fast', () {
    final steering = PlayerCarComponent.steeringForDriverIntent(
      command: const VehicleCommand(
        throttle: 1,
        brake: 0,
        steering: -1,
        smoke: false,
      ),
      signedForwardSpeed: -1.1,
    );
    expect(steering, -1);
  });

  test('near-zero speed steering follows brake intent as reverse', () {
    final steering = PlayerCarComponent.steeringForDriverIntent(
      command: const VehicleCommand(
        throttle: 0,
        brake: 1,
        steering: 1,
        smoke: false,
      ),
      signedForwardSpeed: 0.05,
    );
    expect(steering, -1);
  });

  test('brake steering intent stays stable while moving forward fast', () {
    final steering = PlayerCarComponent.steeringForDriverIntent(
      command: const VehicleCommand(
        throttle: 0,
        brake: 1,
        steering: -1,
        smoke: false,
      ),
      signedForwardSpeed: 1.1,
    );
    expect(steering, 1);
  });

  test(
    'wall slide assist stays off when steering or delay is insufficient',
    () {
      final noAssistByDelay = PlayerCarComponent.shouldApplyWallSlideAssist(
        throttle: 1.0,
        steering: 0.8,
        forwardSpeed: 0.1,
        lowForwardThrottleTime: 0.02,
      );
      final noAssistBySteering = PlayerCarComponent.shouldApplyWallSlideAssist(
        throttle: 1.0,
        steering: 0.1,
        forwardSpeed: 0.1,
        lowForwardThrottleTime: 0.2,
      );
      expect(noAssistByDelay, isFalse);
      expect(noAssistBySteering, isFalse);
    },
  );
}
