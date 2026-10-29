import 'dart:convert';

import 'package:http/http.dart' as http;

import 'templates.dart';

/// Where code runs: a Judge0 server (https://judge0.com). Phones cannot compile C++ or Java themselves.
///
/// Defaults to the free public instance, which is rate-limited. For launch, run your own
/// (Judge0's Docker image on any small cloud server) and build with
///   flutter build apk --dart-define=JUDGE0_URL=https://your-server
/// or use the RapidAPI Judge0 plan with --dart-define=JUDGE0_URL=https://judge0-ce.p.rapidapi.com --dart-define=JUDGE0_KEY=...
// ponytail: a key passed this way ships inside the app and can be extracted; put a small proxy in front if that matters.
const judge0Url = String.fromEnvironment('JUDGE0_URL', defaultValue: 'https://ce.judge0.com');
const judge0Key = String.fromEnvironment('JUDGE0_KEY');

/// Judge0 language ids. Each language's starter program reads a number (see templates.dart for other inputs).
const _languageIds = {'C++': 54, 'Java': 62, 'Python': 71, 'JavaScript': 63};

final languages = {for (final e in _languageIds.entries) e.key: (id: e.value, starter: template(e.key, InputKind.number))};

/// True when [code] is empty or one of the untouched starter programs, so switching templates may replace it.
bool isStarterCode(String code) {
  final text = code.trim();
  return text.isEmpty ||
      [
        for (final l in _languageIds.keys)
          for (final k in InputKind.values) template(l, k).trim(),
      ].contains(text);
}

/// What happened when the code ran.
class RunResult {
  const RunResult({required this.status, required this.ok, this.output = '', this.error = '', this.time, this.memoryKb});

  final String status; // "Accepted", "Compilation Error", "Time Limit Exceeded", ...
  final bool ok; // ran and exited normally
  final String output;
  final String error; // compiler output or runtime error
  final String? time; // seconds, e.g. "0.012"
  final int? memoryKb;

  factory RunResult.fromJudge0(Map<String, dynamic> j) {
    final statusId = (j['status'] as Map?)?['id'] as int? ?? 0;
    return RunResult(
      status: statusId == 3 ? 'Ran successfully' : (j['status'] as Map?)?['description'] as String? ?? 'Unknown',
      ok: statusId == 3,
      output: j['stdout'] as String? ?? '',
      error: [j['compile_output'], j['stderr'], if (statusId != 3) j['message']].whereType<String>().join('\n').trim(),
      time: j['time'] as String?,
      memoryKb: (j['memory'] as num?)?.toInt(),
    );
  }
}

/// Largest program and input we send; the runner rejects bigger ones anyway, this fails fast and clearly.
const maxSourceLength = 64 * 1024, maxInputLength = 64 * 1024;

/// Runs [code] with [stdin] and waits for the result (Judge0 limits each run to a few seconds).
Future<RunResult> runCode(String language, String code, String stdin, {http.Client? client}) async {
  if (code.length > maxSourceLength || stdin.length > maxInputLength) {
    return const RunResult(status: 'Too large', ok: false, error: 'Code and input are limited to 64 KB each.');
  }
  final c = client ?? http.Client();
  try {
    final response = await c
        .post(
          Uri.parse('$judge0Url/submissions?base64_encoded=false&wait=true'),
          headers: {
            'Content-Type': 'application/json',
            if (judge0Key.isNotEmpty) 'X-RapidAPI-Key': judge0Key,
            if (judge0Key.isNotEmpty) 'X-RapidAPI-Host': Uri.parse(judge0Url).host,
          },
          body: jsonEncode({'language_id': languages[language]!.id, 'source_code': code, 'stdin': stdin}),
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode == 429) {
      return const RunResult(status: 'Too many runs', ok: false, error: 'The code runner is busy. Wait a minute and try again.');
    }
    if (response.statusCode >= 400) {
      return RunResult(status: 'Runner error ${response.statusCode}', ok: false, error: response.body);
    }
    return RunResult.fromJudge0(jsonDecode(response.body) as Map<String, dynamic>);
  } on Exception catch (e) {
    return RunResult(status: 'Could not reach the runner', ok: false, error: 'Check your internet connection.\n$e');
  } finally {
    if (client == null) c.close();
  }
}
