import 'package:flutter_test/flutter_test.dart';
import 'package:rallyx_modern/game/entities/player_car_component.dart';

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
}
