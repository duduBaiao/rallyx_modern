import 'dart:ui';

import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:rallyx_modern/game/level/level_data.dart';
import 'package:rallyx_modern/game/rallyx_game.dart';

class FlagComponent extends BodyComponent<RallyXGame> {
  FlagComponent({required this.spawn})
    : super(
        renderBody: false,
        bodyDef: BodyDef(position: spawn.tile.toWorldCenter()),
        fixtureDefs: [FixtureDef(CircleShape()..radius = 0.22, isSensor: true)],
      );

  final FlagSpawn spawn;
  bool _collected = false;

  final Paint _polePaint = Paint()..color = const Color(0xFFE8E8E8);
  late final Paint _flagPaint = Paint()
    ..color = spawn.isSpecial
        ? const Color(0xFFFC6A6A)
        : const Color(0xFFF2E85A);

  bool get isCollected => _collected;
  bool get isSpecial => spawn.isSpecial;

  void collect() {
    if (_collected) {
      return;
    }
    _collected = true;
    removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    canvas.drawRect(const Rect.fromLTWH(-0.18, -0.26, 0.05, 0.52), _polePaint);
    canvas.drawRect(const Rect.fromLTWH(-0.13, -0.22, 0.28, 0.18), _flagPaint);
  }
}
