import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_stack/data/runner.dart';
import 'package:memory_stack/data/store.dart';
import 'package:memory_stack/logic/models.dart';
import 'package:memory_stack/screens/open_link.dart';

void main() {
  test('only real web links are opened', () {
    expect(isWebLink('https://leetcode.com/problems/two-sum'), isTrue);
    expect(isWebLink('  http://example.com  '), isTrue);
    for (final bad in [
      'javascript:alert(1)',
      'intent://scan/#Intent;scheme=zxing;end',
      'file:///sdcard/secret.txt',
      'tel:123',
      'https://',
      'leetcode.com/problems/two-sum',
      '',
    ]) {
      expect(isWebLink(bad), isFalse, reason: bad);
    }
  });

  test('notes past the limit are refused before reaching the server', () async {
    final store = Store('u', db: FakeFirebaseFirestore());
    expect(() => store.setNotes('p', 'x' * (Limits.maxNoteLength + 1)), throwsArgumentError);
    await store.setNotes('p', 'x' * Limits.maxNoteLength);
    expect((await store.notes('p'))!.length, Limits.maxNoteLength);
  });

  test('oversized code is not sent to the runner', () async {
    final r = await runCode('Python', 'x' * (maxSourceLength + 1), '');
    expect([r.ok, r.status], [false, 'Too large']);
  });
}
