import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../logic/models.dart';
import '../logic/srs.dart';
import 'sheet.dart';
import 'store.dart';

/// An accepted LeetCode submission.
typedef Accepted = ({String slug, String title, DateTime on});

class LeetCodeException implements Exception {
  const LeetCodeException(this.message);
  final String message;
  @override
  String toString() => message;
}

final _endpoint = Uri.parse('https://leetcode.com/graphql');
final _usernamePattern = RegExp(r'^[A-Za-z0-9_-]{1,40}$');
final _slugInUrl = RegExp(r'leetcode\.com/problems/([a-z0-9-]+)');

bool isLeetCodeUsername(String name) => _usernamePattern.hasMatch(name);

/// The LeetCode problem a link points to, or null.
String? leetCodeSlug(String? url) => url == null ? null : _slugInUrl.firstMatch(url)?.group(1);

Future<Map<String, dynamic>> _query(http.Client client, String query, Map<String, Object> variables) async {
  final http.Response r;
  try {
    r = await client
        .post(
          _endpoint,
          headers: {'Content-Type': 'application/json', 'Referer': 'https://leetcode.com'},
          body: jsonEncode({'query': query, 'variables': variables}),
        )
        .timeout(const Duration(seconds: 15));
  } on Exception {
    throw const LeetCodeException('Could not reach LeetCode. Check your internet.');
  }
  if (r.statusCode != 200) throw const LeetCodeException('LeetCode is not answering right now. Try later.');
  final body = jsonDecode(r.body) as Map<String, dynamic>;
  if (body['errors'] case [final Map<String, dynamic> first, ...]) {
    throw LeetCodeException(first['message'] as String? ?? 'LeetCode refused the request.');
  }
  return body['data'] as Map<String, dynamic>;
}

/// Your latest accepted submissions, newest first.
/// ponytail: LeetCode's public API returns at most the last 20; syncing on every app start keeps up with that.
Future<List<Accepted>> recentAccepted(String username, {http.Client? client}) async {
  final c = client ?? http.Client();
  try {
    final data = await _query(
      c,
      r'query($u: String!) { matchedUser(username: $u) { username } recentAcSubmissionList(username: $u, limit: 20) { title titleSlug timestamp } }',
      {'u': username},
    );
    return [
      for (final s in (data['recentAcSubmissionList'] as List? ?? const []).cast<Map<String, dynamic>>())
        (
          slug: s['titleSlug'] as String,
          title: s['title'] as String,
          on: DateTime.fromMillisecondsSinceEpoch(int.parse(s['timestamp'] as String) * 1000),
        ),
    ];
  } finally {
    if (client == null) c.close();
  }
}

Future<({String difficulty, String topic})> _details(http.Client client, String slug) async {
  final data = await _query(client, r'query($s: String!) { question(titleSlug: $s) { difficulty topicTags { name } } }', {'s': slug});
  final q = data['question'] as Map<String, dynamic>?;
  final tags = (q?['topicTags'] as List? ?? const []).cast<Map<String, dynamic>>();
  return (
    difficulty: difficulties.contains(q?['difficulty']) ? q!['difficulty'] as String : 'Medium',
    topic: tags.isEmpty ? 'LeetCode' : tags.first['name'] as String,
  );
}

/// Which accepted problems are new: not already in [have] (by id or LeetCode link), each once,
/// paired with its entry in the first of [sheets] that has it (null if no sheet does).
List<(Accepted, SheetProblem?)> newSolves(List<Accepted> accepted, Iterable<Problem> have, List<Sheet> sheets) {
  final known = {
    for (final p in have) ...[p.id, ?leetCodeSlug(p.url)],
  };
  final inSheets = <String, SheetProblem>{};
  for (final sheet in sheets.reversed) {
    for (final p in sheet.problems) {
      final slug = leetCodeSlug(p.url);
      if (slug != null) inSheets[slug] = p; // earlier sheets overwrite later ones
    }
  }
  final result = <(Accepted, SheetProblem?)>[];
  for (final a in accepted.reversed) {
    final sheetProblem = inSheets[a.slug];
    if (known.contains(a.slug) || known.contains('lc-${a.slug}') || (sheetProblem != null && known.contains(sheetProblem.id))) {
      continue;
    }
    known.add(a.slug);
    result.add((a, sheetProblem));
  }
  return result;
}

/// Adds your new LeetCode solves (offline: throws, nothing is added) to your stack, dated the day you solved them. Returns how many were added.
/// [sheetId] is the sheet you follow: a problem in it is ticked there.
Future<int> syncLeetCode({required String username, required Store store, required String sheetId, http.Client? client}) async {
  final c = client ?? http.Client();
  try {
    final accepted = await recentAccepted(username, client: c);
    // Compared with the server copy: adding a problem that is already there would reset its reviews.
    final have = await store.serverProblems();
    final order = [sheetId, ...sheets.map((s) => s.id).where((id) => id != sheetId)];
    final loaded = await Future.wait(order.map(loadSheet));
    final fresh = newSolves(accepted, have, loaded);
    for (final (a, sheetProblem) in fresh) {
      final Problem problem;
      if (sheetProblem != null) {
        final sheet = loaded.firstWhere((s) => s.problems.contains(sheetProblem));
        problem = sheet.toProblem(sheetProblem, a.on);
      } else {
        final d = await _details(c, a.slug);
        problem = Problem.solved(
          id: 'lc-${a.slug}',
          name: a.title,
          platform: 'LeetCode',
          difficulty: d.difficulty,
          topic: d.topic,
          url: 'https://leetcode.com/problems/${a.slug}/',
          solvedOn: dateOnly(a.on),
        );
      }
      unawaited(store.addProblem(problem)); // saved locally at once, synced when online
    }
    return fresh.length;
  } finally {
    if (client == null) c.close();
  }
}
