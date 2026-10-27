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
}
