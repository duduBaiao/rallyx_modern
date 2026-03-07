import 'dart:ui';

import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:rallyx_modern/game/level/level_data.dart';
import 'package:rallyx_modern/game/rallyx_game.dart';

class WallTileComponent extends BodyComponent<RallyXGame> {
  WallTileComponent({required this.tile})
    : super(
        bodyDef: BodyDef(position: tile.toWorldCenter()),
        fixtureDefs: [
          FixtureDef(
            PolygonShape()..setAsBoxXY(0.5, 0.5),
            friction: 0.05,
            restitution: 0.0,
          ),
        ],
      ) {
    paint.color = const Color(0xFF262D3A);
  }

  final TileCoordinate tile;
}
