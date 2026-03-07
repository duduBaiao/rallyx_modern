import 'dart:math' as math;

import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:rallyx_modern/game/config/game_config.dart';

class FixedStepForge2DWorld extends Forge2DWorld {
  FixedStepForge2DWorld({super.gravity, super.contactListener});

  double _accumulator = 0;

  @override
  void update(double dt) {
    _accumulator = math.min(_accumulator + dt, GameConfig.maxAccumulatedTime);

    while (_accumulator >= GameConfig.fixedTimeStep) {
      physicsWorld.stepDt(GameConfig.fixedTimeStep);
      _accumulator -= GameConfig.fixedTimeStep;
    }
  }
}
