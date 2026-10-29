import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../logic/models.dart';

/// One problem in a DSA sheet, in the sheet's own order.
class SheetProblem {
  const SheetProblem({
    required this.id,
    required this.step,
    required this.section,
    required this.title,
    this.difficulty,
    required this.platform,
    required this.url,
    this.article,
    this.video,
  });

  factory SheetProblem.fromJson(Map<String, dynamic> j) => SheetProblem(
    id: j['id'] as String,
    step: j['s'] as int,
    section: j['sec'] as String,
    title: j['t'] as String,
    difficulty: j['d'] as String?,
    platform: j['p'] as String,
    url: j['u'] as String,
    article: j['a'] as String?,
    video: j['v'] as String?,
  );

  final String id; // also the id of the Problem in your stack once solved
  final int step; // 1-based
  final String section; // e.g. "Logic Building"
  final String title;
  final String? difficulty;
  final String platform;
  final String url;
  final String? article;
  final String? video;
}

class Sheet {
  Sheet({required this.title, required this.source, required this.steps, required this.problems})
    : _byStep = _groupByStep(problems, steps.length);

  factory Sheet.fromJson(Map<String, dynamic> j) => Sheet(
    title: j['title'] as String,
    source: j['source'] as String,
    steps: (j['steps'] as List).cast<String>(),
    problems: [for (final p in j['problems'] as List) SheetProblem.fromJson(p as Map<String, dynamic>)],
  );

  final String title;
  final String source;
  final List<String> steps;
  final List<SheetProblem> problems;

  final List<List<SheetProblem>> _byStep; // index step - 1; built once, the sheet never changes

  static List<List<SheetProblem>> _groupByStep(List<SheetProblem> problems, int stepCount) {
    final groups = List.generate(stepCount, (_) => <SheetProblem>[]);
    for (final p in problems) {
      groups[p.step - 1].add(p);
    }
    return [for (final g in groups) List.unmodifiable(g)];
  }

  /// Problems of one step (1-based), in sheet order. O(1).
  List<SheetProblem> inStep(int step) => _byStep[step - 1];

  /// The first problem, in sheet order, you have not solved yet.
  SheetProblem? nextUnsolved(Set<String> solvedIds) {
    for (final p in problems) {
      if (!solvedIds.contains(p.id)) return p;
    }
    return null;
  }

  /// The stack entry for a solved sheet problem; its topic is the step name, e.g. "Arrays".
  Problem toProblem(SheetProblem p, DateTime solvedOn) => Problem.solved(
    id: p.id,
    name: p.title,
    platform: p.platform,
    difficulty: p.difficulty ?? 'Easy',
    topic: steps[p.step - 1],
    url: p.url,
    solvedOn: solvedOn,
  );
}

/// The sheets you can follow. The id is the asset file name; [credit] is shown under the list.
const sheets = [
  (id: 'a2z', name: "Striver's A2Z", size: 402, credit: "Problem list from Striver's A2Z DSA Sheet by takeUforward."),
  (id: 'neetcode150', name: 'NeetCode 150', size: 150, credit: 'Problem list from NeetCode 150 by neetcode.io. Problems on LeetCode.'),
  (id: 'blind75', name: 'Blind 75', size: 75, credit: 'The Blind 75 list, first shared on Blind. Problems on LeetCode.'),
];

final _cache = <String, Future<Sheet>>{};

/// Loads a sheet once; later calls get the same Future. Unknown ids fall back to A2Z.
Future<Sheet> loadSheet(String id) {
  final known = sheets.any((s) => s.id == id) ? id : 'a2z';
  return _cache[known] ??= rootBundle
      .loadString('assets/sheets/$known.json')
      .then((text) => Sheet.fromJson(jsonDecode(text) as Map<String, dynamic>));
}

Future<Sheet> loadA2zSheet() => loadSheet('a2z');
