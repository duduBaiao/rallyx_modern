import 'dart:math' as math;
import 'dart:ui';

import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:rallyx_modern/game/level/level_data.dart';
import 'package:rallyx_modern/game/rallyx_game.dart';

class EnemyCarComponent extends BodyComponent<RallyXGame> {
  EnemyCarComponent({required this.spawnTile, required this.stage})
    : super(
        renderBody: false,
        bodyDef: BodyDef(
          type: BodyType.dynamic,
          position: spawnTile.toWorldCenter(),
          linearDamping: 1.4,
          angularDamping: 6.0,
        ),
        fixtureDefs: [
          FixtureDef(
            PolygonShape()..setAsBoxXY(_halfLength, _halfWidth),
            density: 0.9,
            friction: 0.2,
            restitution: 0.0,
          ),
        ],
      );

  static const double _carLength = 1.25;
  static const double _carWidth = 0.72;
  static const double _halfLength = _carLength / 2;
  static const double _halfWidth = _carWidth / 2;

  final TileCoordinate spawnTile;
  final int stage;

  double _stunTimer = 0;
  double _pathTimer = 0;
  TileCoordinate? _waypointTile;

  double get stunRemaining => _stunTimer;

  double get _engineForce => 58 + stage * 4.5;
  double get _maxSpeed => 9.5 + stage * 0.5;

  final Paint _bodyPaint = Paint()..color = const Color(0xFFE05656);
  final Paint _roofPaint = Paint()..color = const Color(0xFFA73B3B);

  @override
  void update(double dt) {
    super.update(dt);

    if (game.isGameOver) {
      body.linearVelocity = body.linearVelocity * 0.9;
      body.angularVelocity *= 0.85;
      return;
    }

    _applyLateralFriction();

    if (_stunTimer > 0) {
      _stunTimer -= dt;
      body.linearVelocity = body.linearVelocity * 0.85;
      body.angularVelocity *= 0.8;
      return;
    }

    _pathTimer -= dt;
    if (_pathTimer <= 0) {
      _pathTimer = 0.22;
      _waypointTile = game.nextTileTowardsPlayer(
        game.worldToTile(body.position),
      );
    }

    final target =
        _waypointTile?.toWorldCenter() ?? game.playerCar?.body.position;
    if (target == null) {
      return;
    }
    _driveToward(target);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final bodyRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-_halfLength, -_halfWidth, _carLength, _carWidth),
      const Radius.circular(0.10),
    );
    canvas.drawRRect(bodyRect, _bodyPaint);

    final roofRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-0.30, -0.22, 0.6, 0.44),
      const Radius.circular(0.07),
    );
    canvas.drawRRect(roofRect, _roofPaint);

    if (_stunTimer > 0) {
      final stunPaint = Paint()..color = const Color(0x88D8D8D8);
      canvas.drawCircle(Offset.zero, 0.7, stunPaint);
    }
  }

  void stun(double seconds) {
    _stunTimer = math.max(_stunTimer, seconds);
  }

  void _driveToward(Vector2 target) {
    final toTarget = target - body.position;
    if (toTarget.length2 < 0.0001) {
      return;
    }

    final desiredAngle = math.atan2(toTarget.y, toTarget.x);
    final angleDelta = _normalizeAngle(desiredAngle - body.angle);
    final torque = angleDelta * body.getInertia() * 8.0;
    body.applyTorque(torque);

    final forward = Vector2(math.cos(body.angle), math.sin(body.angle));
    body.applyForce(forward * _engineForce);

    final velocity = body.linearVelocity;
    final speed = velocity.length;
    if (speed > _maxSpeed) {
      body.linearVelocity = velocity.normalized() * _maxSpeed;
    }
  }

  void _applyLateralFriction() {
    final forward = Vector2(math.cos(body.angle), math.sin(body.angle));
    final right = Vector2(-forward.y, forward.x);
    final lateralSpeed = body.linearVelocity.dot(right);
    final impulse = right * (-lateralSpeed * body.mass * 0.92);
    body.applyLinearImpulse(impulse);
  }

  double _normalizeAngle(double angle) {
    while (angle > math.pi) {
      angle -= 2 * math.pi;
    }
    while (angle < -math.pi) {
      angle += 2 * math.pi;
    }
    return angle;
  }
}
