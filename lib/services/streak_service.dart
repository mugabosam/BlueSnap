/// BlueSnap streaks (Snapchat-style).
///
/// A conversation is "on a streak" for every consecutive day that BOTH people
/// send at least one message. Miss a full day and the streak resets. The count
/// is shown with a 🔥 next to the conversation, and turns to an ⌛ warning as it
/// nears expiry.
library;

import '../data/database/database_service.dart';

class StreakService {
  static final StreakService _instance = StreakService._();
  factory StreakService() => _instance;
  StreakService._();

  final DatabaseService _db = DatabaseService();

  int get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day).millisecondsSinceEpoch ~/ 86400000;
  }

  Map<String, dynamic> _read(String convId) {
    final raw = _db.getSetting('streak_$convId');
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {'count': 0, 'lastDay': -1, 'mineDay': -1, 'peerDay': -1};
  }

  Future<void> _write(String convId, Map<String, dynamic> s) =>
      _db.setSetting('streak_$convId', s);

  /// Record that *I* sent in this conversation today.
  Future<void> recordMine(String convId) async {
    final s = _read(convId);
    s['mineDay'] = _today;
    await _maybeAdvance(convId, s);
  }

  /// Record that the *peer* sent in this conversation today.
  Future<void> recordPeer(String convId) async {
    final s = _read(convId);
    s['peerDay'] = _today;
    await _maybeAdvance(convId, s);
  }

  Future<void> _maybeAdvance(String convId, Map<String, dynamic> s) async {
    final today = _today;
    final bothToday = s['mineDay'] == today && s['peerDay'] == today;
    if (bothToday && s['lastDay'] != today) {
      // Continue if yesterday was the last streak day, else start fresh at 1.
      s['count'] = (s['lastDay'] == today - 1) ? (s['count'] as int) + 1 : 1;
      s['lastDay'] = today;
    }
    await _write(convId, s);
  }

  /// The live streak count, or 0 if it has lapsed (a full day with no exchange).
  int streakFor(String convId) {
    final s = _read(convId);
    final last = s['lastDay'] as int;
    final count = s['count'] as int;
    if (count <= 0) return 0;
    // Alive if the streak advanced today or yesterday; otherwise it's broken.
    return (last >= _today - 1) ? count : 0;
  }

  /// True when the streak is still alive but hasn't been kept up today yet —
  /// i.e. it will lapse if no exchange happens before midnight.
  bool isAtRisk(String convId) {
    final s = _read(convId);
    return streakFor(convId) > 0 && s['lastDay'] != _today;
  }
}
