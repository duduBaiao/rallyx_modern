import 'package:flutter_test/flutter_test.dart';
import 'package:rallyx_modern/game/persistence/high_score_repository.dart';
import 'package:rallyx_modern/game/persistence/score_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SharedPrefsHighScoreRepository', () {
    test('keeps top 10 sorted by survival time descending', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = SharedPrefsHighScoreRepository(storageKey: 'test_scores');

      for (var i = 1; i <= 12; i++) {
        await repo.saveScore(
          ScoreEntry(
            survivalSeconds: i.toDouble(),
            stageReached: i,
            createdAtIso: '2026-03-07T00:00:00Z',
          ),
        );
      }

      final scores = await repo.loadTop10();
      expect(scores.length, 10);
      expect(scores.first.survivalSeconds, 12);
      expect(scores.last.survivalSeconds, 3);
    });

    test('ignores malformed stored entries', () async {
      final valid = ScoreEntry(
        survivalSeconds: 10.5,
        stageReached: 4,
        createdAtIso: '2026-03-07T00:00:00Z',
      );

      SharedPreferences.setMockInitialValues({
        'test_scores_malformed': <String>[
          'not-json',
          valid.encode(),
          '{"broken":"shape"}',
        ],
      });
      final repo = SharedPrefsHighScoreRepository(
        storageKey: 'test_scores_malformed',
      );

      final scores = await repo.loadTop10();
      expect(scores.length, 1);
      expect(scores.first.survivalSeconds, 10.5);
    });

    test('persists scores across repository instances', () async {
      SharedPreferences.setMockInitialValues({});
      final repo1 = SharedPrefsHighScoreRepository(
        storageKey: 'test_scores_reopen',
      );
      final repo2 = SharedPrefsHighScoreRepository(
        storageKey: 'test_scores_reopen',
      );

      await repo1.saveScore(
        const ScoreEntry(
          survivalSeconds: 21.0,
          stageReached: 3,
          createdAtIso: '2026-03-07T00:00:00Z',
        ),
      );
      await repo1.saveScore(
        const ScoreEntry(
          survivalSeconds: 10.0,
          stageReached: 1,
          createdAtIso: '2026-03-07T00:01:00Z',
        ),
      );

      final reloaded = await repo2.loadTop10();
      expect(reloaded.length, 2);
      expect(reloaded.first.survivalSeconds, 21.0);
      expect(reloaded.last.survivalSeconds, 10.0);
    });
  });
}
