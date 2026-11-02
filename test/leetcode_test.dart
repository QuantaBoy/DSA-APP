import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:memory_stack/data/leetcode.dart';
import 'package:memory_stack/data/sheet.dart';
import 'package:memory_stack/logic/models.dart';

void main() {
  test('reads accepted submissions and reports unknown users', () async {
    final ok = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'data': {
            'matchedUser': {'username': 'me'},
            'recentAcSubmissionList': [
              {'title': 'Two Sum', 'titleSlug': 'two-sum', 'timestamp': '1793500000'},
            ],
          },
        }),
        200,
      ),
    );
    final list = await recentAccepted('me', client: ok);
    expect(list.single.slug, 'two-sum');
    expect(list.single.on, DateTime.fromMillisecondsSinceEpoch(1793500000 * 1000));

    final missing = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'errors': [
            {'message': 'That user does not exist.'},
          ],
          'data': {'matchedUser': null},
        }),
        200,
      ),
    );
    expect(() => recentAccepted('nobody', client: missing), throwsA(isA<LeetCodeException>()));
  });

  test('new solves skip problems you have, repeats, and prefer the sheet you follow', () {
    SheetProblem sp(String id, String slug) =>
        SheetProblem(id: id, step: 1, section: 'S', title: slug, platform: 'LeetCode', url: 'https://leetcode.com/problems/$slug/');
    final mine = Sheet(title: 'A2Z', source: '', steps: ['Arrays'], problems: [sp('a2z-1', 'two-sum'), sp('a2z-2', 'three-sum')]);
    final other = Sheet(title: 'NC', source: '', steps: ['Arrays'], problems: [sp('lc-two-sum', 'two-sum')]);
    final day = DateTime(2026, 11, 1);
    Accepted a(String slug) => (slug: slug, title: slug, on: day);
    final have = [
      Problem.solved(id: 'a2z-2', name: '3Sum', platform: 'LeetCode', difficulty: 'Medium', topic: 'Arrays', solvedOn: day),
      Problem.solved(
        id: 'x',
        name: 'Valid',
        platform: 'LeetCode',
        difficulty: 'Easy',
        topic: 'Stack',
        url: 'https://leetcode.com/problems/valid-parentheses/description/',
        solvedOn: day,
      ),
    ];
    final fresh = newSolves([a('two-sum'), a('three-sum'), a('valid-parentheses'), a('lru-cache'), a('two-sum')], have, [mine, other]);
    expect([for (final (s, p) in fresh) '${s.slug}:${p?.id}'], ['two-sum:a2z-1', 'lru-cache:null']);
  });
}
