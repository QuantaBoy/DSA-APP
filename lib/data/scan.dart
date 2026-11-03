import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';

import '../logic/models.dart';

/// Gemini model used to read photos, through Firebase AI Logic (no key in the app).
/// Override at build time with `--dart-define=AI_MODEL=name` when Google retires it.
const aiModel = String.fromEnvironment('AI_MODEL', defaultValue: 'gemini-3.5-flash');

/// One question read from a photo. [answer] is the model's own solution; [photoAnswer] is the answer
/// marked in the photo, if any. When both exist and differ, the user should check before saving.
typedef ScannedQuestion = ({
  String question,
  List<String> options,
  int answer,
  int? photoAnswer,
  String explanation,
  String topic,
  String? subtopic,
});

class ScanException implements Exception {
  const ScanException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// What a GATE paper scan adds to the prompt: file each question under one syllabus subtopic id.
String gatePrompt(List<({String id, String name})> topics) => '''
These are GATE Data Science & AI exam questions. For numerical-answer questions, write 4 plausible options
including the correct value. For each question also give "subtopic": the id of the best matching syllabus
subtopic from this list (id: name):
${topics.map((t) => '${t.id}: ${t.name}').join('\n')}''';

const _prompt = '''
You read photos or PDF pages of multiple-choice exam questions (aptitude, or the subject named below).
For every multiple-choice question in the image:
- copy the question text exactly, without the option labels;
- copy each option's text, without its letter or number label;
- solve the question yourself and give the 0-based index of the correct option in "answer";
- if the image itself marks or states an answer, give its 0-based index in "photoAnswer", otherwise -1;
- write a short step-by-step explanation (at most 6 lines) in "explanation";
- give a short topic such as "Percentages", "Time and Work", "Blood Relations", "Syllogism".
If a question has no options, write 4 plausible options including the correct one.
If there is no question in the image, return an empty list.''';

const _schema = {
  'type': 'object',
  'properties': {
    'questions': {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {
          'question': {'type': 'string'},
          'options': {
            'type': 'array',
            'items': {'type': 'string'},
          },
          'answer': {'type': 'integer'},
          'photoAnswer': {'type': 'integer'},
          'explanation': {'type': 'string'},
          'topic': {'type': 'string'},
          'subtopic': {'type': 'string'},
        },
        'required': ['question', 'options', 'answer', 'explanation', 'topic'],
      },
    },
  },
  'required': ['questions'],
};

String _clip(String s, int max) => s.length <= max ? s.trim() : s.substring(0, max).trim();

/// Turns the model's JSON into questions, dropping anything malformed and clipping to the stored limits.
List<ScannedQuestion> parseScan(String json) {
  final Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException {
    throw const ScanException('Could not read the answer from the AI. Try again.');
  }
  final list = decoded is Map<String, dynamic> ? decoded['questions'] : null;
  if (list is! List) return const [];
  final result = <ScannedQuestion>[];
  for (final q in list.whereType<Map<String, dynamic>>()) {
    final options = [
      for (final o in (q['options'] as List? ?? const []).whereType<String>())
        if (o.trim().isNotEmpty) _clip(o, Limits.aptOptionLength),
    ].take(Limits.maxOptions).toList();
    final question = q['question'];
    final answer = q['answer'];
    if (question is! String || question.trim().isEmpty || options.length < Limits.minOptions) continue;
    if (answer is! int || answer < 0 || answer >= options.length) continue;
    final photo = q['photoAnswer'];
    final topic = q['topic'] is String && (q['topic'] as String).trim().isNotEmpty ? q['topic'] as String : 'General';
    result.add((
      question: _clip(question, Limits.aptQuestionLength),
      options: options,
      answer: answer,
      photoAnswer: photo is int && photo >= 0 && photo < options.length ? photo : null,
      explanation: _clip(q['explanation'] is String ? q['explanation'] as String : '', Limits.aptExplanationLength),
      topic: _clip(topic, Limits.topicLength),
      subtopic: q['subtopic'] is String ? q['subtopic'] as String : null,
    ));
  }
  return result;
}

/// Google's long error text, cut down to one short line.
String scanErrorMessage(String raw) => switch (raw.toLowerCase()) {
  final m when m.contains('app check') => 'This app could not prove it is genuine. Update it from the Play Store.',
  final m when m.contains('has not been used') || m.contains('is disabled') => 'AI is not switched on for this app yet. Try again later.',
  final m when m.contains('quota') || m.contains('resource exhausted') =>
    'Daily AI limit reached. Try again tomorrow, or type the question.',
  final m when m.contains('not found') && m.contains('model') => 'This AI model was retired. Update the app.',
  _ => 'The AI could not read this photo. Try a clearer one.',
};

/// Reads the aptitude questions in a photo and solves them.
/// [extra] adds instructions (e.g. [gatePrompt]); a PDF ([mimeType] application/pdf) may hold a whole paper.
Future<List<ScannedQuestion>> scanQuestions(Uint8List image, {String mimeType = 'image/jpeg', String extra = ''}) async {
  final model = FirebaseAI.googleAI().generativeModel(
    model: aiModel,
    generationConfig: GenerationConfig(responseMimeType: 'application/json', responseJsonSchema: _schema),
  );
  try {
    final response = await model
        .generateContent([
          Content.multi([TextPart('$_prompt\n$extra'), InlineDataPart(mimeType, image)]),
        ])
        .timeout(Duration(seconds: mimeType == 'application/pdf' ? 240 : 60));
    return parseScan(response.text ?? '');
  } on QuotaExceeded {
    throw const ScanException('Daily AI limit reached. Try again tomorrow, or type the question.');
  } on ServiceApiNotEnabled {
    throw const ScanException('AI is not switched on for this app yet (Firebase console → AI Logic).');
  } on FirebaseAIException catch (e) {
    throw ScanException(scanErrorMessage(e.message));
  } on Exception {
    throw const ScanException('Could not reach the AI. Check your internet.');
  }
}
