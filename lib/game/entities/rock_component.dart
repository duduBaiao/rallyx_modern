import 'dart:ui';

import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:rallyx_modern/game/level/level_data.dart';
import 'package:rallyx_modern/game/rallyx_game.dart';

class RockComponent extends BodyComponent<RallyXGame> {
  RockComponent({required this.tile})
    : super(
        bodyDef: BodyDef(position: tile.toWorldCenter()),
        fixtureDefs: [
          FixtureDef(
            CircleShape()..radius = 0.40,
            friction: 0.05,
            restitution: 0.0,
          ),
        ],
      ) {
    paint.color = const Color(0xFF5D6370);
  }

  final TileCoordinate tile;
}
