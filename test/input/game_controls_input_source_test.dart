import 'package:flutter_test/flutter_test.dart';
import 'package:rallyx_modern/game/input/game_controls_input.dart';
import 'package:rallyx_modern/game/input/game_controls_input_source.dart';

void main() {
  group('GameControlsInputSource', () {
    test('neutral input maps to idle command', () {
      final source = GameControlsInputSource();

      final command = source.poll(1 / 60);

      expect(command.throttle, 0.0);
      expect(command.brake, 0.0);
      expect(command.steering, 0.0);
      expect(command.smoke, isFalse);
    });

    test('maps 70-degree full lock with arcade steering response', () {
      final source = GameControlsInputSource();

      source.update(
        const GameControlsInput(
          steeringWheelDeg: -70,
          throttlePercent: 0,
          brakePercent: 100,
          emergencyPressed: false,
        ),
      );
      final left = source.poll(1 / 60);
      expect(left.steering, -1.0);
      expect(left.throttle, 0.0);
      expect(left.brake, 1.0);

      source.update(
        const GameControlsInput(
          steeringWheelDeg: 0,
          throttlePercent: 50,
          brakePercent: 50,
          emergencyPressed: true,
        ),
      );
      final center = source.poll(1 / 60);
      expect(center.steering, 0.0);
      expect(center.throttle, 0.5);
      expect(center.brake, 0.5);
      expect(center.smoke, isTrue);

      source.update(
        const GameControlsInput(
          steeringWheelDeg: 35,
          throttlePercent: 100,
          brakePercent: 0,
          emergencyPressed: false,
        ),
      );
      final halfLock = source.poll(1 / 60);
      expect(halfLock.steering, 0.5);
      expect(halfLock.throttle, 1.0);
      expect(halfLock.brake, 0.0);

      source.update(
        const GameControlsInput(
          steeringWheelDeg: 70,
          throttlePercent: 100,
          brakePercent: 0,
          emergencyPressed: false,
        ),
      );
      final right = source.poll(1 / 60);
      expect(right.steering, 1.0);
      expect(right.throttle, 1.0);
      expect(right.brake, 0.0);
    });

    test('clamps out-of-range values', () {
      final source = GameControlsInputSource();

      source.update(
        const GameControlsInput(
          steeringWheelDeg: 900,
          throttlePercent: -25,
          brakePercent: 140,
          emergencyPressed: true,
        ),
      );
      final command = source.poll(1 / 60);

      expect(command.steering, 1.0);
      expect(command.throttle, 0.0);
      expect(command.brake, 1.0);
      expect(command.smoke, isTrue);
    });

    test('holds latest values across polls without update', () {
      final source = GameControlsInputSource();

      source.update(
        const GameControlsInput(
          steeringWheelDeg: 240,
          throttlePercent: 25,
          brakePercent: 75,
          emergencyPressed: true,
        ),
      );

      final first = source.poll(1 / 60);
      final second = source.poll(1 / 60);

      expect(second.steering, first.steering);
      expect(second.throttle, first.throttle);
      expect(second.brake, first.brake);
      expect(second.smoke, first.smoke);
    });

    test('clear resets to neutral command', () {
      final source = GameControlsInputSource();

      source.update(
        const GameControlsInput(
          steeringWheelDeg: -300,
          throttlePercent: 80,
          brakePercent: 10,
          emergencyPressed: true,
        ),
      );
      expect(source.poll(1 / 60).throttle, greaterThan(0));

      source.clear();
      final command = source.poll(1 / 60);

      expect(command.throttle, 0.0);
      expect(command.brake, 0.0);
      expect(command.steering, 0.0);
      expect(command.smoke, isFalse);
    });
  });
}
