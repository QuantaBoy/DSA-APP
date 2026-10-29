import 'package:cloud_firestore/cloud_firestore.dart';

/// One person on the leaderboard. Only what they chose to share: first name and two numbers.
typedef LeaderboardEntry = ({String uid, String name, int streak, int solved});

/// What the leaderboard can be sorted by.
enum Ranking {
  streak('Streak'),
  solved('Solved');

  const Ranking(this.label);
  final String label;
}

/// Opt-in leaderboard in leaderboard/{uid}. Joining publishes your first name, streak and solved count;
/// leaving deletes the entry. Firestore rules allow reading only when signed in and writing only your own entry.
class Leaderboard {
  Leaderboard({FirebaseFirestore? db}) : _dbOverride = db;

  final FirebaseFirestore? _dbOverride; // tests pass a fake
  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _entries => _db.collection('leaderboard');

  static const size = 50; // one read per entry each time the list opens

  Stream<List<LeaderboardEntry>> top(Ranking by) => _entries
      .orderBy(by.name, descending: true)
      .limit(size)
      .snapshots()
      .map(
        (s) => [
          for (final d in s.docs)
            (
              uid: d.id,
              name: d.data()['name'] as String? ?? '?',
              streak: d.data()['streak'] as int? ?? 0,
              solved: d.data()['solved'] as int? ?? 0,
            ),
        ],
      );

  Future<bool> isJoined(String uid) async => (await _entries.doc(uid).get()).exists;

  Future<void> publish({required String uid, required String name, required int streak, required int solved}) => _entries.doc(uid).set({
    'name': name.trim().isEmpty ? 'Coder' : name.trim().substring(0, name.trim().length.clamp(0, 30)),
    'streak': streak.clamp(0, 5000),
    'solved': solved.clamp(0, 5000),
    'updatedAt': FieldValue.serverTimestamp(),
  });

  Future<void> leave(String uid) => _entries.doc(uid).delete();
}
