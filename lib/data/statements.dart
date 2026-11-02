import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// LeetCode problem statements, fetched from LeetCode for you and kept on this device so they open offline.
/// They are not stored in our database or shipped with the app: the text belongs to LeetCode.
/// ponytail: SharedPreferences holds a few KB per problem; move to files if thousands are cached.

final _endpoint = Uri.parse('https://leetcode.com/graphql');
String _key(String slug) => 'statement:$slug';
final _tried = <String>{}; // slugs fetched (or failed) this session, so prefetching never repeats

/// The statement as HTML: from this device if seen before, else from LeetCode.
/// Null for paid-only problems, when offline and not cached, and on the web (LeetCode blocks web pages).
Future<String?> leetCodeStatement(String slug, {http.Client? client}) async {
  final prefs = await SharedPreferences.getInstance();
  final cached = prefs.getString(_key(slug));
  if (cached != null || kIsWeb) return cached;
  _tried.add(slug);
  final c = client ?? http.Client();
  try {
    final r = await c
        .post(
          _endpoint,
          headers: {'Content-Type': 'application/json', 'Referer': 'https://leetcode.com'},
          body: jsonEncode({
            'query': r'query($s: String!) { question(titleSlug: $s) { content } }',
            'variables': {'s': slug},
          }),
        )
        .timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) return null;
    final question = ((jsonDecode(r.body) as Map<String, dynamic>)['data'] as Map<String, dynamic>?)?['question'] as Map<String, dynamic>?;
    final html = question?['content'] as String?; // null when the problem is paid-only
    if (html == null || html.isEmpty) return null;
    await prefs.setString(_key(slug), html);
    return html;
  } on Exception {
    return null; // offline: the caller offers the link instead
  } finally {
    if (client == null) c.close();
  }
}

/// Saves upcoming statements while online, one at a time, so they are there offline later.
Future<void> prefetchStatements(Iterable<String> slugs) async {
  if (kIsWeb) return;
  for (final slug in slugs) {
    if (_tried.contains(slug)) continue;
    if (await leetCodeStatement(slug) == null) return; // most likely offline: stop until next time
  }
}
