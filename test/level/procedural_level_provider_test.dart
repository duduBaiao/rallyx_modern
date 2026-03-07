import 'package:flutter_test/flutter_test.dart';
import 'package:rallyx_modern/game/config/game_config.dart';
import 'package:rallyx_modern/game/level/level_data.dart';
import 'package:rallyx_modern/game/level/procedural_level_provider.dart';

void main() {
  group('ProceduralLevelProvider', () {
    test('generates level with expected counts and valid spawns', () {
      final provider = ProceduralLevelProvider();
      final level = provider.loadLevel(stage: 1, seed: 1980);

      expect(level.width, GameConfig.playfieldTilesWide);
      expect(level.height, GameConfig.playfieldTilesHigh);
      expect(level.flags.length, GameConfig.flagsPerStage);
      expect(level.enemySpawns.length, GameConfig.enemySpawnCount);

      final specialFlags = level.flags.where((flag) => flag.isSpecial).length;
      expect(specialFlags, 1);

      expect(
        level.isWalkable(level.playerSpawn.x, level.playerSpawn.y),
        isTrue,
      );

      for (final enemySpawn in level.enemySpawns) {
        expect(level.isWalkable(enemySpawn.x, enemySpawn.y), isTrue);
      }
      for (final flag in level.flags) {
        expect(level.isWalkable(flag.tile.x, flag.tile.y), isTrue);
      }

      expect(provider.validateLevel(level), isTrue);
    });

    test('deterministic for same stage and seed', () {
      final provider = ProceduralLevelProvider();
      final levelA = provider.loadLevel(stage: 2, seed: 4242);
      final levelB = provider.loadLevel(stage: 2, seed: 4242);

      expect(levelA.playerSpawn, levelB.playerSpawn);
      expect(
        _tileCounts(levelA, TileKind.wall),
        _tileCounts(levelB, TileKind.wall),
      );
      expect(
        _tileCounts(levelA, TileKind.rock),
        _tileCounts(levelB, TileKind.rock),
      );
      expect(levelA.enemySpawns, levelB.enemySpawns);
      expect(
        levelA.flags.map((flag) => flag.tile).toList(),
        levelB.flags.map((flag) => flag.tile).toList(),
      );
    });

    test('player spawn is not pinned to map corners', () {
      final provider = ProceduralLevelProvider();

      for (var stage = 1; stage <= 4; stage++) {
        for (var seed = 2000; seed < 2020; seed++) {
          final level = provider.loadLevel(stage: stage, seed: seed);
          expect(level.playerSpawn.x, inInclusiveRange(2, level.width - 3));
          expect(level.playerSpawn.y, inInclusiveRange(2, level.height - 3));
        }
      }
    });
  });
}

int _tileCounts(LevelData level, TileKind kind) {
  var count = 0;
  for (var y = 0; y < level.height; y++) {
    for (var x = 0; x < level.width; x++) {
      if (level.tileAt(x, y) == kind) {
        count++;
      }
    }
  }
  return count;
}
