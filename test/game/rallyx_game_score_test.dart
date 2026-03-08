import 'package:flutter_test/flutter_test.dart';
import 'package:rallyx_modern/game/input/keyboard_input_source.dart';
import 'package:rallyx_modern/game/rallyx_game.dart';

void main() {
  test('score combines survival time and bonus score', () {
    final game = RallyXGame(inputSource: KeyboardInputSource());
    game.survivalTime = 42.5;
    game.bonusScore = 12;

    expect(game.score, 54.5);
  });
}
