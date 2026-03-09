import 'dart:convert';

class ScoreEntry {
  const ScoreEntry({
    required this.survivalSeconds,
    this.bonusScore = 0,
    required this.stageReached,
    required this.createdAtIso,
  });

  final double survivalSeconds;
  final double bonusScore;
  final int stageReached;
  final String createdAtIso;
  double get totalScore => survivalSeconds + bonusScore;

  Map<String, dynamic> toJson() {
    return {
      'survivalSeconds': survivalSeconds,
      'bonusScore': bonusScore,
      'stageReached': stageReached,
      'createdAtIso': createdAtIso,
    };
  }

  static ScoreEntry fromJson(Map<String, dynamic> json) {
    final survivalRaw = json['survivalSeconds'];
    final bonusRaw = json['bonusScore'];
    final stageRaw = json['stageReached'];
    final createdRaw = json['createdAtIso'];

    if (survivalRaw is! num || stageRaw is! num || createdRaw is! String) {
      throw const FormatException('Invalid score entry shape');
    }
    final resolvedBonus = bonusRaw is num ? bonusRaw.toDouble() : 0.0;

    return ScoreEntry(
      survivalSeconds: survivalRaw.toDouble(),
      bonusScore: resolvedBonus,
      stageReached: stageRaw.toInt(),
      createdAtIso: createdRaw,
    );
  }

  String encode() => jsonEncode(toJson());

  static ScoreEntry decode(String data) {
    final dynamic json = jsonDecode(data);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Invalid score entry JSON');
    }
    return fromJson(json);
  }
}
