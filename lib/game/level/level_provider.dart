import 'package:rallyx_modern/game/level/level_data.dart';

abstract class LevelProvider {
  LevelData loadLevel({required int stage, required int seed});
}
