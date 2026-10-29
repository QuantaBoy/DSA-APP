import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../logic/srs.dart';

/// One known problem from the bundled catalog (LeetCode, plus a few Codeforces/CodeChef).
class CatalogItem {
  const CatalogItem({required this.platform, required this.title, required this.difficulty, required this.topics, required this.url});

  factory CatalogItem.fromJson(Map<String, dynamic> j) => CatalogItem(
    platform: j['p'] as String,
    title: j['t'] as String,
    difficulty: j['d'] as String,
    topics: (j['g'] as List).cast<String>(),
    url: j['u'] as String,
  );

  final String platform;
  final String title;
  final String difficulty;
  final List<String> topics;
  final String url;

  /// The topic to file it under: its tag that comes earliest on the roadmap, else its first tag.
  String get mainTopic => roadmap.firstWhere(topics.contains, orElse: () => topics.isEmpty ? 'Array' : topics.first);
}

List<CatalogItem>? _cache;

Future<List<CatalogItem>> loadCatalog() async => _cache ??= [
  for (final j in jsonDecode(await rootBundle.loadString('assets/catalog.json')) as List) CatalogItem.fromJson(j as Map<String, dynamic>),
];

/// Titles starting with the query first, then titles containing it.
List<CatalogItem> searchCatalog(List<CatalogItem> items, String platform, String query, {int limit = 8}) {
  final q = query.trim().toLowerCase();
  if (q.length < 2) return const [];
  final starts = <CatalogItem>[], contains = <CatalogItem>[];
  for (final item in items) {
    if (item.platform != platform) continue;
    final title = item.title.toLowerCase();
    if (title.startsWith(q)) {
      starts.add(item);
    } else if (title.contains(q)) {
      contains.add(item);
    }
  }
  return [...starts, ...contains].take(limit).toList();
}

/// Topic choices for the Add form: roadmap order first, then every other catalog tag A–Z.
List<String> topicChoices(List<CatalogItem> items) {
  final others = {for (final i in items) ...i.topics}.difference(roadmap.toSet()).toList()..sort();
  return [...roadmap, ...others];
}
