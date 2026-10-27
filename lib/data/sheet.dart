import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../logic/models.dart';

/// One problem in a DSA sheet, in the sheet's own order.
class SheetProblem {
  const SheetProblem({
    required this.id, required this.step, required this.section, required this.title, this.difficulty,
    required this.platform, required this.url, this.article, this.video,
  });

  factory SheetProblem.fromJson(Map<String, dynamic> j) => SheetProblem(
        id: j['id'] as String, step: j['s'] as int, section: j['sec'] as String, title: j['t'] as String,
        difficulty: j['d'] as String?, platform: j['p'] as String, url: j['u'] as String,
        article: j['a'] as String?, video: j['v'] as String?,
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
  const Sheet({required this.title, required this.source, required this.steps, required this.problems});

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

  List<SheetProblem> inStep(int step) => [for (final p in problems) if (p.step == step) p];

  /// The first problem, in sheet order, you have not solved yet.
  SheetProblem? nextUnsolved(Set<String> solvedIds) {
    for (final p in problems) {
      if (!solvedIds.contains(p.id)) return p;
    }
    return null;
  }

  /// The stack entry for a solved sheet problem; its topic is the step name, e.g. "Arrays".
  Problem toProblem(SheetProblem p, DateTime solvedOn) => Problem.solved(
        id: p.id, name: p.title, platform: p.platform, difficulty: p.difficulty ?? 'Easy',
        topic: steps[p.step - 1], url: p.url, solvedOn: solvedOn,
      );
}

Sheet? _a2z;

Future<Sheet> loadA2zSheet() async =>
    _a2z ??= Sheet.fromJson(jsonDecode(await rootBundle.loadString('assets/sheets/a2z.json')) as Map<String, dynamic>);
