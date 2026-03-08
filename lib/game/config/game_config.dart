class GameConfig {
  const GameConfig._();

  static const int targetFps = 60;
  static const double fixedTimeStep = 1 / targetFps;
  static const double maxAccumulatedTime = fixedTimeStep * 5;

  static const double cameraZoom = 18;
  static const int cameraTargetVisibleTiles = 24;
  static const double idealViewportWidthPx = 1920;
  static const double idealViewportHeightPx = 1080;

  static const int playfieldTilesWide = 175;
  static const int playfieldTilesHigh = 97;
  static const int hudTilesWide = 8;
  static const int proceduralDimensionStep = 6;
  static const int proceduralDimensionOffset = 1;

  static const int worldTilesWide = playfieldTilesWide + hudTilesWide;
  static const int worldTilesHigh = playfieldTilesHigh;

  static const int flagsPerStage = 10;
  static const int enemySpawnCount = 4;
  static const int rocksPerStage = 14;

  static const double maxFuel = 100;
  static const double fuelDrainPerSecond = 3.5;
  static const double fuelDrainSpeedThreshold = 0.05;
  static const double idleFuelDrainFactor = 0.25;
  static const double smokeFuelCost = 9;
  static const double smokeLifetimeSeconds = 2.0;
  static const double flagBonusScore = 6;
}
