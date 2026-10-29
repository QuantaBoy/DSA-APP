import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:memory_stack/data/runner.dart';
import 'package:memory_stack/screens/code_pad.dart';

void main() {
  test('sends code, language and input to Judge0, and reads the result', () async {
    late Map<String, dynamic> sent;
    final client = MockClient((request) async {
      sent = jsonDecode(request.body) as Map<String, dynamic>;
      expect(request.url.path, '/submissions');
      expect(request.url.queryParameters['wait'], 'true');
      return http.Response(
        jsonEncode({
          'stdout': '42\n',
          'status': {'id': 3, 'description': 'Accepted'},
          'time': '0.01',
          'memory': 2048,
        }),
        200,
      );
    });
    final r = await runCode('Python', 'print(int(input())*2)', '21', client: client);
    expect(sent, {'language_id': 71, 'source_code': 'print(int(input())*2)', 'stdin': '21'});
    expect([r.ok, r.status, r.output, r.time, r.memoryKb], [true, 'Ran successfully', '42\n', '0.01', 2048]);
  });

  test('compile errors and a busy runner come back as readable messages', () async {
    final broken = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'compile_output': "error: expected ';'",
          'status': {'id': 6, 'description': 'Compilation Error'},
        }),
        200,
      ),
    );
    final r = await runCode('C++', 'int main(){', '', client: broken);
    expect([r.ok, r.status, r.error], [false, 'Compilation Error', "error: expected ';'"]);

    final busy = MockClient((_) async => http.Response('', 429));
    expect((await runCode('C++', '', '', client: busy)).status, 'Too many runs');
  });

  testWidgets('code pad starts with a starter program, swaps it per language, and shows the run output', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final code = CodeController();
    String? ranWith;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CodePad(
              controller: code,
              runner: (language, source, stdin) async {
                ranWith = '$language|$stdin';
                return const RunResult(status: 'Ran successfully', ok: true, output: '5\n', time: '0.002');
              },
            ),
          ),
        ),
      ),
    );
    expect(code.fullText, languages['C++']!.starter);

    await tester.tap(find.text('C++'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Python').last);
    await tester.pumpAndSettle();
    expect(code.fullText, languages['Python']!.starter, reason: 'untouched starter is replaced');

    await tester.enterText(find.widgetWithText(TextField, 'Input (stdin)'), '5');
    await tester.tap(find.text('Run'));
    await tester.pumpAndSettle();
    expect(ranWith, 'Python|5');
    expect(find.text('Ran successfully'), findsOneWidget);
    expect(find.text('5'), findsWidgets);
  });
}
