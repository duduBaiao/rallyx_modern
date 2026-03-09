import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallyx_modern/game/ai/enemy_command_brain.dart';
import 'package:rallyx_modern/game/input/vehicle_command.dart';

void main() {
  group('EnemyCommandBrain', () {
    test('steering sign follows heading error direction', () {
      final brain = EnemyCommandBrain();
      brain.setRoute([Vector2(0, 0), Vector2(0, 5)]);

      final commandNorth = brain.nextCommand(
        position: Vector2.zero(),
        headingAngle: 0,
        signedForwardSpeed: 0.5,
        dt: 0.1,
      );
      expect(commandNorth.steering, greaterThan(0));

      brain.setRoute([Vector2(0, 0), Vector2(0, -5)]);
      final commandSouth = brain.nextCommand(
        position: Vector2.zero(),
        headingAngle: 0,
        signedForwardSpeed: 0.5,
        dt: 0.1,
      );
      expect(commandSouth.steering, lessThan(0));
    });

    test(
      'brakes when overspeeding into sharp turns and throttles at low speed',
      () {
        final brain = EnemyCommandBrain();
        brain.setRoute([Vector2(0, 0), Vector2(0, 6)]);

        final brakeCommand = brain.nextCommand(
          position: Vector2.zero(),
          headingAngle: 0,
          signedForwardSpeed: 4.0,
          dt: 0.1,
        );
        expect(
          brakeCommand.brake,
          closeTo(brain.config.brakeWhenOverspeed, 1e-6),
        );
        expect(brakeCommand.throttle, 0);

        final throttleCommand = brain.nextCommand(
          position: Vector2.zero(),
          headingAngle: 0,
          signedForwardSpeed: 0.15,
          dt: 0.1,
        );
        expect(throttleCommand.throttle, greaterThan(0.9));
        expect(throttleCommand.brake, 0);
      },
    );

    test('stuck recovery is deterministic and resets after progress', () {
      const config = EnemyCommandBrainConfig(
        stuckWindowSeconds: 0.5,
        escapeDurationSeconds: 0.4,
        postEscapeCooldownSeconds: 0.2,
      );

      List<VehicleCommand> runStuckSequence() {
        final brain = EnemyCommandBrain(config: config);
        brain.setRoute([Vector2(0, 0), Vector2(8, 0)]);
        final commands = <VehicleCommand>[];
        for (var i = 0; i < 12; i++) {
          commands.add(
            brain.nextCommand(
              position: Vector2.zero(),
              headingAngle: 0,
              signedForwardSpeed: 0,
              dt: 0.1,
            ),
          );
        }
        return commands;
      }

      final runA = runStuckSequence();
      final runB = runStuckSequence();
      expect(
        runA
            .map(
              (command) => (command.throttle, command.brake, command.steering),
            )
            .toList(growable: false),
        runB
            .map(
              (command) => (command.throttle, command.brake, command.steering),
            )
            .toList(growable: false),
      );

      final escapeCommands = runA
          .where(
            (command) =>
                command.throttle >= config.escapeThrottle - 0.001 &&
                command.steering.abs() >= config.escapeSteering * 0.95,
          )
          .toList();
      expect(escapeCommands, isNotEmpty);
      expect(escapeCommands.every((command) => command.brake == 0), isTrue);
      expect(
        escapeCommands.first.steering.abs(),
        closeTo(config.escapeSteering, 0.001),
      );
      final steerSign = escapeCommands.first.steering.sign;
      expect(
        escapeCommands.every((command) => command.steering.sign == steerSign),
        isTrue,
      );

      final brain = EnemyCommandBrain(config: config);
      brain.setRoute([Vector2(0, 0), Vector2(8, 0)]);
      for (var i = 0; i < 12; i++) {
        brain.nextCommand(
          position: Vector2.zero(),
          headingAngle: 0,
          signedForwardSpeed: 0,
          dt: 0.1,
        );
      }

      var position = Vector2.zero();
      var observedForwardDrive = false;
      for (var i = 0; i < 16; i++) {
        position = position + Vector2(0.2, 0);
        final command = brain.nextCommand(
          position: position,
          headingAngle: 0,
          signedForwardSpeed: 1.1,
          dt: 0.1,
        );
        if (command.throttle > 0 && command.brake == 0) {
          observedForwardDrive = true;
          break;
        }
      }
      expect(observedForwardDrive, isTrue);
    });

    test('obstacle probes steer away from whichever side is blocked', () {
      final brain = EnemyCommandBrain();
      brain.setRoute([Vector2(0, 0), Vector2(12, 0)]);

      bool positiveSideBlocked(Vector2 point) =>
          point.x >= 1.0 && point.x <= 2.6 && point.y >= 0.55 && point.y <= 2.4;
      bool negativeSideBlocked(Vector2 point) =>
          point.x >= 1.0 &&
          point.x <= 2.6 &&
          point.y <= -0.55 &&
          point.y >= -2.4;

      final steerWithPositiveBlocked = brain.nextCommand(
        position: Vector2.zero(),
        headingAngle: 0,
        signedForwardSpeed: 1.2,
        dt: 0.1,
        isBlockedWorldPosition: positiveSideBlocked,
      );
      final steerWithNegativeBlocked = brain.nextCommand(
        position: Vector2.zero(),
        headingAngle: 0,
        signedForwardSpeed: 1.2,
        dt: 0.1,
        isBlockedWorldPosition: negativeSideBlocked,
      );

      expect(steerWithPositiveBlocked.steering.abs(), greaterThan(0.1));
      expect(steerWithNegativeBlocked.steering.abs(), greaterThan(0.1));
      expect(
        steerWithPositiveBlocked.steering.sign,
        isNot(steerWithNegativeBlocked.steering.sign),
      );
    });

    test(
      'near-front blockage forces turn-away while preserving slide throttle',
      () {
        final brain = EnemyCommandBrain();
        brain.setRoute([Vector2(0, 0), Vector2(12, 0)]);

        bool nearFrontBlocked(Vector2 point) =>
            point.x >= 0.8 && point.x <= 2.4 && point.y.abs() <= 0.25;

        final command = brain.nextCommand(
          position: Vector2.zero(),
          headingAngle: 0,
          signedForwardSpeed: 0.8,
          dt: 0.1,
          isBlockedWorldPosition: nearFrontBlocked,
        );

        expect(
          command.steering.abs(),
          greaterThanOrEqualTo(
            brain.config.obstacleImmediateTurnStrength - 0.01,
          ),
        );
        expect(
          command.throttle,
          greaterThanOrEqualTo(
            brain.config.obstacleNearBlockMinThrottle - 0.01,
          ),
        );
        expect(
          command.brake,
          lessThanOrEqualTo(brain.config.obstacleNearBlockMaxBrake + 0.01),
        );
      },
    );

    test('does not commit to corner turn too early on dense route points', () {
      final brain = EnemyCommandBrain(
        config: const EnemyCommandBrainConfig(
          lookaheadDistance: 2.2,
          minLookaheadDistance: 1.0,
          turnLookaheadReduction: 0.7,
          cornerCommitDistance: 1.0,
          cornerDotThreshold: 0.45,
        ),
      );
      brain.setRoute([
        Vector2(0, 0),
        Vector2(1, 0),
        Vector2(2, 0),
        Vector2(3, 0),
        Vector2(3, 1),
        Vector2(3, 2),
      ]);

      final command = brain.nextCommand(
        position: Vector2(1.0, 0.0),
        headingAngle: 0,
        signedForwardSpeed: 2.0,
        dt: 0.1,
      );

      expect(command.steering.abs(), lessThan(0.25));
    });
  });
}
