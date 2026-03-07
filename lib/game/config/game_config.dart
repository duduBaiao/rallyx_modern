class GameConfig {
  const GameConfig._();

  static const int targetFps = 60;
  static const double fixedTimeStep = 1 / targetFps;
  static const double maxAccumulatedTime = fixedTimeStep * 5;

  static const double cameraZoom = 18;

  static const int worldTilesWide = 32 + 8; // playfield + radar strip
  static const int worldTilesHigh = 32;
}
