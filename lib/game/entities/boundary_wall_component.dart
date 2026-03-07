import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:rallyx_modern/game/rallyx_game.dart';

class BoundaryWallComponent extends BodyComponent<RallyXGame> {
  BoundaryWallComponent(this.start, this.end) : super(renderBody: false);

  final Vector2 start;
  final Vector2 end;

  @override
  Body createBody() {
    final shape = EdgeShape()..set(start, end);
    final fixture = FixtureDef(shape, friction: 0.05, restitution: 0.0);
    return world.createBody(BodyDef())..createFixture(fixture);
  }
}
