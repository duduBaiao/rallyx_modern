import 'package:rallyx_modern/game/persistence/score_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class HighScoreRepository {
  Future<List<ScoreEntry>> loadTop10();
  Future<List<ScoreEntry>> saveScore(ScoreEntry entry);
}

class SharedPrefsHighScoreRepository implements HighScoreRepository {
  SharedPrefsHighScoreRepository({this.storageKey = 'rallyx_top10_scores_v1'});

  final String storageKey;

  @override
  Future<List<ScoreEntry>> loadTop10() async {
    final prefs = await SharedPreferences.getInstance();
    final rawScores = prefs.getStringList(storageKey) ?? const <String>[];

    final parsed = <ScoreEntry>[];
    for (final raw in rawScores) {
      try {
        parsed.add(ScoreEntry.decode(raw));
      } catch (_) {
        // Ignore invalid legacy entries.
      }
    }

    parsed.sort((a, b) => b.totalScore.compareTo(a.totalScore));
    return parsed.take(10).toList(growable: false);
  }

  @override
  Future<List<ScoreEntry>> saveScore(ScoreEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await loadTop10();
    final updated = [...current, entry]
      ..sort((a, b) => b.totalScore.compareTo(a.totalScore));
    final trimmed = updated.take(10).toList(growable: false);

    final serialized = trimmed
        .map((item) => item.encode())
        .toList(growable: false);
    await prefs.setStringList(storageKey, serialized);
    return trimmed;
  }
}
