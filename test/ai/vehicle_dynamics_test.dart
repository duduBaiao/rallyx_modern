import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallyx_modern/game/ai/vehicle_dynamics.dart';
import 'package:rallyx_modern/game/input/vehicle_command.dart';

void main() {
  const tuning = VehicleDynamicsTuning(
    engineForce: 52,
    brakeForce: 110,
    reverseForce: 38,
    coastDrag: 8,
    reverseThreshold: 0.35,
    maxForwardSpeed: 4.2,
    maxReverseSpeed: 1.8,
    minSteerSpeed: 0.55,
    lowSpeedSteerFactor: 0.55,
    maxSteerRate: 5.12,
    steerResponse: 20.0,
    lateralGrip: 0.85,
    angularDampingFactor: 0.96,
    wallSlideAssistForce: 32,
    wallSlideAssistForwardSpeedThreshold: 0.45,
    wallSlideAssistSteeringThreshold: 0.30,
    wallSlideAssistDelaySeconds: 0.12,
    stuckTurnAssistMinAngularVelocity: 1.4,
    stuckTurnAssistTorqueBoost: 28,
  );

  group('VehicleDynamicsController', () {
    test('steering direction inverts while reversing travel direction', () {
      expect(
        VehicleDynamicsController.steeringForTravelDirection(
          steeringInput: 1,
          signedForwardSpeed: 0.8,
        ),
        1,
      );
      expect(
        VehicleDynamicsController.steeringForTravelDirection(
          steeringInput: 1,
          signedForwardSpeed: -0.8,
        ),
        -1,
      );
    });

    test('driver intent steering follows throttle and brake intent', () {
      final throttleCommand = VehicleDynamicsController.steeringForDriverIntent(
        command: const VehicleCommand(
          throttle: 1,
          brake: 0,
          steering: -1,
          smoke: false,
        ),
        signedForwardSpeed: -0.2,
      );
      final brakeCommand = VehicleDynamicsController.steeringForDriverIntent(
        command: const VehicleCommand(
          throttle: 0,
          brake: 1,
          steering: 1,
          smoke: false,
        ),
        signedForwardSpeed: 0.2,
      );
      expect(throttleCommand, -1);
      expect(brakeCommand, -1);
    });

    test('clamps forward speed to configured max', () {
      final world = World(Vector2.zero());
      final body = _spawnCarBody(world);
      body.linearVelocity = Vector2(28, 0);

      final controller = const VehicleDynamicsController(tuning: tuning);
      final runtimeState = VehicleDynamicsRuntimeState();
      controller.apply(
        body: body,
        command: const VehicleCommand.idle(),
        dt: 1 / 60,
        runtimeState: runtimeState,
      );

      final state = controller.captureBodyState(body);
      expect(
        state.signedForwardSpeed,
        lessThanOrEqualTo(tuning.maxForwardSpeed),
      );
    });

    test('idle command does not create steering spin from rest', () {
      final world = World(Vector2.zero());
      final body = _spawnCarBody(world);
      body.angularVelocity = 0;
      body.linearVelocity = Vector2.zero();

      final controller = const VehicleDynamicsController(tuning: tuning);
      final runtimeState = VehicleDynamicsRuntimeState();
      for (var i = 0; i < 6; i++) {
        controller.apply(
          body: body,
          command: const VehicleCommand.idle(),
          dt: 1 / 60,
          runtimeState: runtimeState,
        );
        world.stepDt(1 / 60);
      }

      expect(body.angularVelocity.abs(), lessThan(0.001));
      expect(body.angle.abs(), lessThan(0.001));
    });

    test(
      'near-zero steering stays restrained unless stuck assist is active',
      () {
        final controller = const VehicleDynamicsController(tuning: tuning);

        final normalWorld = World(Vector2.zero());
        final normalBody = _spawnCarBody(normalWorld);
        normalBody.linearVelocity = Vector2(0.05, 0);
        final normalRuntimeState = VehicleDynamicsRuntimeState();

        controller.apply(
          body: normalBody,
          command: const VehicleCommand(
            throttle: 1,
            brake: 0,
            steering: 1,
            smoke: false,
          ),
          dt: 1 / 60,
          runtimeState: normalRuntimeState,
        );
        normalWorld.stepDt(1 / 60);
        final restrainedAngularVelocity = normalBody.angularVelocity.abs();

        final stuckWorld = World(Vector2.zero());
        final stuckBody = _spawnCarBody(stuckWorld);
        stuckBody.linearVelocity = Vector2(0.05, 0);
        final stuckRuntimeState = VehicleDynamicsRuntimeState()
          ..lowForwardThrottleTime = tuning.wallSlideAssistDelaySeconds;

        controller.apply(
          body: stuckBody,
          command: const VehicleCommand(
            throttle: 1,
            brake: 0,
            steering: 1,
            smoke: false,
          ),
          dt: 1 / 60,
          runtimeState: stuckRuntimeState,
        );
        stuckWorld.stepDt(1 / 60);
        final stuckAssistAngularVelocity = stuckBody.angularVelocity.abs();

        expect(restrainedAngularVelocity, lessThan(0.35));
        expect(
          stuckAssistAngularVelocity,
          greaterThan(restrainedAngularVelocity * 2),
        );
      },
    );
  });
}

Body _spawnCarBody(World world) {
  final body = world.createBody(
    BodyDef(
      type: BodyType.dynamic,
      position: Vector2.zero(),
      angle: 0,
      linearDamping: 1.2,
      angularDamping: 3.8,
    ),
  );
  body.createFixture(
    FixtureDef(
      PolygonShape()..setAsBoxXY(0.7, 0.4),
      density: 1.0,
      friction: 0.2,
      restitution: 0.0,
    ),
  );
  return body;
}
