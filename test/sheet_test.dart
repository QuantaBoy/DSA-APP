import 'package:flutter_test/flutter_test.dart';
import 'package:memory_stack/data/sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('A2Z sheet loads all 402 problems in 19 steps, in order', () async {
    final sheet = await loadA2zSheet();
    expect(sheet.problems.length, 402);
    expect(sheet.steps.length, 19);
    expect(sheet.steps[2], 'Arrays');
    expect(sheet.problems.map((p) => p.id).toSet().length, 402, reason: 'ids must be unique: they are Firestore doc ids');
    final stepOrder = sheet.problems.map((p) => p.step).toList();
    expect(stepOrder, [...stepOrder]..sort(), reason: 'steps never go backwards');
    expect(sheet.problems.every((p) => p.url.startsWith('https://')), isTrue);
  });

  test('continue points at the first unsolved problem', () async {
    final sheet = await loadA2zSheet();
    final first = sheet.problems[0], second = sheet.problems[1];
    expect(sheet.nextUnsolved({}), first);
    expect(sheet.nextUnsolved({first.id}), second);
    expect(sheet.nextUnsolved({for (final p in sheet.problems) p.id}), isNull);
  });

  test('a solved sheet problem becomes a stack problem filed under its step', () async {
    final sheet = await loadA2zSheet();
    final p = sheet.problems.firstWhere((p) => p.step == 3);
    final problem = sheet.toProblem(p, DateTime(2026, 10, 27));
    expect(problem.id, p.id);
    expect(problem.topic, 'Arrays');
    expect(problem.url, p.url);
    expect(problem.nextDue, DateTime.utc(2026, 10, 28));
  });

  test('NeetCode 150 and Blind 75 load in full, with LeetCode links and shared ids', () async {
    for (final (id, size) in [('neetcode150', 150), ('blind75', 75)]) {
      final sheet = await loadSheet(id);
      expect(sheet.problems.length, size, reason: id);
      expect(sheet.problems.map((p) => p.id).toSet().length, size, reason: 'ids are Firestore doc ids');
      expect(sheet.problems.every((p) => p.url.startsWith('https://leetcode.com/problems/') && p.id.startsWith('lc-')), isTrue);
      expect(sheet.problems.every((p) => p.difficulty != null), isTrue);
    }
    // The same problem has the same id in both sheets, so solving it once counts in both.
    final nc = (await loadSheet('neetcode150')).problems.map((p) => p.id).toSet();
    final blind = (await loadSheet('blind75')).problems.map((p) => p.id).toSet();
    expect(blind.difference(nc).length, lessThan(10));
    expect(nc.contains('lc-two-sum') && blind.contains('lc-two-sum'), isTrue);
    expect((await loadSheet('nope')).title, contains('A2Z'), reason: 'unknown ids fall back to A2Z');
  });
}
