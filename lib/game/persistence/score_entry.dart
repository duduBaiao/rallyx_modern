import 'dart:convert';

class ScoreEntry {
  const ScoreEntry({
    required this.survivalSeconds,
    required this.stageReached,
    required this.createdAtIso,
  });

  final double survivalSeconds;
  final int stageReached;
  final String createdAtIso;

  Map<String, dynamic> toJson() {
    return {
      'survivalSeconds': survivalSeconds,
      'stageReached': stageReached,
      'createdAtIso': createdAtIso,
    };
  }

  static ScoreEntry fromJson(Map<String, dynamic> json) {
    final survivalRaw = json['survivalSeconds'];
    final stageRaw = json['stageReached'];
    final createdRaw = json['createdAtIso'];

    if (survivalRaw is! num || stageRaw is! num || createdRaw is! String) {
      throw const FormatException('Invalid score entry shape');
    }

    return ScoreEntry(
      survivalSeconds: survivalRaw.toDouble(),
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
