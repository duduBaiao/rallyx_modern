import 'package:flutter_test/flutter_test.dart';
import 'package:rallyx_modern/game/level/procedural_level_provider.dart';

void main() {
  test('level generation remains valid across multiple seeds and stages', () {
    final provider = ProceduralLevelProvider();

    for (var stage = 1; stage <= 6; stage++) {
      for (var seed = 1979; seed < 2019; seed++) {
        final level = provider.loadLevel(stage: stage, seed: seed);
        expect(
          provider.validateLevel(level),
          isTrue,
          reason: 'Invalid level at stage=$stage seed=$seed',
        );
      }
    }
  });
}
