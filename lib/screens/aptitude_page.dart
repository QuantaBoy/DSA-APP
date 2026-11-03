import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../data/scan.dart';
import '../data/store.dart';
import '../logic/gate.dart';
import '../logic/models.dart';
import '../logic/srs.dart';
import 'widgets.dart';

String _letter(int i) => String.fromCharCode(65 + i); // A, B, C…

/// Aptitude deck: scan or type multiple-choice questions, then revise them on a schedule.
class AptitudeView extends StatelessWidget {
  const AptitudeView({super.key, required this.store});

  final Store store;

  @override
  Widget build(BuildContext context) => StreamBuilder<List<AptCard>>(
    stream: store.aptCards(),
    builder: (context, snap) {
      if (snap.hasError) return const Center(child: Text('Could not load your aptitude questions.'));
      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
      final now = today();
      // GATE questions live in the GATE tab.
      final cards = [...snap.data!.where((c) => !isGateCard(c.topic))]..sort((a, b) => a.nextDue.compareTo(b.nextDue));
      final due = cards.where((c) => c.isDue(now)).toList();
      final theme = Theme.of(context);
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          HeroCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  due.isEmpty ? 'No aptitude reviews due' : '${due.length} aptitude ${due.length == 1 ? 'question' : 'questions'} due',
                  style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Snap a question from any website. AI reads it, solves it and explains it; you check and save.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (due.isNotEmpty)
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: theme.colorScheme.primary),
                        onPressed: () => _push(context, AptReviewPage(store: store, cards: due)),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Review'),
                      ),
                    _HeroButton(
                      icon: Icons.photo_camera_rounded,
                      label: 'Scan',
                      onPressed: () => scanAptitude(context, store, ImageSource.camera),
                    ),
                    _HeroButton(
                      icon: Icons.photo_library_rounded,
                      label: 'Photo',
                      onPressed: () => scanAptitude(context, store, ImageSource.gallery),
                    ),
                    _HeroButton(
                      icon: Icons.edit_rounded,
                      label: 'Type',
                      onPressed: () => _push(context, AptEditPage(store: store)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (cards.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: EmptyState(
                icon: Icons.calculate_outlined,
                title: 'No aptitude questions yet',
                message: 'Tap Scan to photograph a question, or Photo to pick a screenshot.',
              ),
            ),
          for (final c in cards)
            Card(
              margin: const EdgeInsets.only(top: 10),
              child: ListTile(
                title: Text(c.question, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Flexible(child: Pill(c.topic, color: Accent.violet)),
                      const SizedBox(width: 8),
                      Text(dueLabel(now.difference(c.nextDue).inDays), style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                onTap: () => _push(context, AptEditPage(store: store, card: c)),
              ),
            ),
        ],
      );
    },
  );

  void _push(BuildContext context, Widget page) => unawaited(Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page)));
}

/// Opens the camera or photos, has the AI read the questions, then shows each one to check and save.
/// [topic] files every question under one tag (a GATE subtopic); [extra] adds instructions for the AI.
Future<void> scanAptitude(BuildContext context, Store store, ImageSource source, {String? topic, String extra = ''}) async {
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  final XFile? photo;
  try {
    photo = await ImagePicker().pickImage(source: source, maxWidth: 2000, maxHeight: 2000, imageQuality: 85);
  } on PlatformException {
    messenger.showSnackBar(const SnackBar(content: Text('Could not open the camera or photos. Check the app permissions.')));
    return;
  }
  if (photo == null || !context.mounted) return;
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text('Reading and solving…')),
          ],
        ),
      ),
    ),
  );
  List<ScannedQuestion> found;
  try {
    found = await scanQuestions(await photo.readAsBytes(), mimeType: photo.mimeType ?? 'image/jpeg', extra: extra);
  } on ScanException catch (e) {
    navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
    return;
  }
  navigator.pop();
  if (found.isEmpty) {
    messenger.showSnackBar(const SnackBar(content: Text('No multiple-choice question found in that photo.')));
    return;
  }
  var saved = 0;
  for (final (i, q) in found.indexed) {
    final ok = await navigator.push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            AptEditPage(store: store, scanned: q, position: found.length > 1 ? '${i + 1} of ${found.length}' : null, fixedTopic: topic),
      ),
    );
    if (ok ?? false) saved++;
  }
  if (saved > 0) {
    messenger.showSnackBar(SnackBar(content: Text('$saved ${saved == 1 ? 'question' : 'questions'} added. First review tomorrow.')));
  }
}

/// The three ways to add an aptitude question, from the centre button of the bottom bar.
Future<void> showScanSheet(BuildContext context, Store store) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  builder: (sheet) {
    void go(Future<void> Function() action) {
      Navigator.pop(sheet);
      unawaited(action());
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Add an aptitude question', style: Theme.of(sheet).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Take a photo'),
              subtitle: const Text('AI reads, solves and explains it'),
              onTap: () => go(() => scanAptitude(context, store, ImageSource.camera)),
            ),
            ListTile(
              leading: const Icon(Icons.screenshot_rounded),
              title: const Text('Pick a screenshot'),
              subtitle: const Text('From your photos'),
              onTap: () => go(() => scanAptitude(context, store, ImageSource.gallery)),
            ),
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Type it'),
              onTap: () => go(() => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => AptEditPage(store: store)))),
            ),
          ],
        ),
      ),
    );
  },
);

class _HeroButton extends StatelessWidget {
  const _HeroButton({required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    style: OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      side: const BorderSide(color: Colors.white70),
    ),
    onPressed: onPressed,
    icon: Icon(icon),
    label: Text(label),
  );
}

/// Check and edit a question before it is saved: new (typed or scanned) or existing.
class AptEditPage extends StatefulWidget {
  const AptEditPage({super.key, required this.store, this.card, this.scanned, this.position, this.fixedTopic});

  final Store store;
  final AptCard? card; // editing an existing card
  final ScannedQuestion? scanned; // filled by the AI
  final String? position; // "2 of 3" when a photo had several questions
  final String? fixedTopic; // set for GATE questions: the subtopic tag, and the topic field is hidden

  @override
  State<AptEditPage> createState() => _AptEditPageState();
}

class _AptEditPageState extends State<AptEditPage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _question, _explanation, _topic;
  late final List<TextEditingController> _options;
  late int _answer;

  @override
  void initState() {
    super.initState();
    final c = widget.card, s = widget.scanned;
    _question = TextEditingController(text: c?.question ?? s?.question);
    _explanation = TextEditingController(text: c?.explanation ?? s?.explanation);
    _topic = TextEditingController(text: c?.topic ?? s?.topic);
    _options = [
      for (final o in c?.options ?? s?.options ?? const ['', '', '', '']) TextEditingController(text: o),
    ];
    _answer = c?.answer ?? s?.answer ?? 0;
  }

  @override
  void dispose() {
    for (final t in [_question, _explanation, _topic, ..._options]) {
      t.dispose();
    }
    super.dispose();
  }

  void _removeOption(int i) => setState(() {
    _options.removeAt(i).dispose();
    if (_answer == i) {
      _answer = 0;
    } else if (_answer > i) {
      _answer--;
    }
  });

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final topic = widget.fixedTopic ?? (_topic.text.trim().isEmpty ? 'General' : _topic.text.trim());
    final options = [for (final o in _options) o.text.trim()];
    final card =
        widget.card?.copyWith(
          question: _question.text.trim(),
          options: options,
          answer: _answer,
          explanation: _explanation.text.trim(),
          topic: topic,
        ) ??
        AptCard.fresh(
          id: widget.store.newAptId(),
          question: _question.text.trim(),
          options: options,
          answer: _answer,
          explanation: _explanation.text.trim(),
          topic: topic,
        );
    unawaited(widget.store.saveApt(card)); // saved locally at once, synced when online
    Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    final ok = await showAdaptiveDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: const Text('Delete this question?'),
        actions: [
          adaptiveAction(context, 'Cancel', () => Navigator.pop(context, false)),
          adaptiveAction(context, 'Delete', () => Navigator.pop(context, true), destructive: true),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    unawaited(widget.store.deleteApt(widget.card!.id));
    Navigator.pop(context, false);
  }

  String? _required(String? v, int max) {
    if (v == null || v.trim().isEmpty) return 'Required';
    if (v.length > max) return 'At most $max characters';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = widget.scanned;
    final disagree = s != null && s.photoAnswer != null && s.photoAnswer != s.answer;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.card != null ? 'Edit question' : 'Check question${widget.position == null ? '' : ' ${widget.position}'}'),
        actions: [
          if (widget.card != null) IconButton(tooltip: 'Delete', onPressed: _delete, icon: const Icon(Icons.delete_outline_rounded)),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (s != null)
                _Banner(
                  color: disagree ? Accent.amber : Accent.sky,
                  icon: disagree ? Icons.warning_amber_rounded : Icons.auto_awesome_rounded,
                  text: disagree
                      ? 'The photo marks option ${_letter(s.photoAnswer!)}, but the AI got ${_letter(s.answer)}. '
                            'Check the explanation and pick the right one.'
                      : 'Read by AI. Check the text and the answer before saving.',
                ),
              TextFormField(
                controller: _question,
                minLines: 2,
                maxLines: 8,
                decoration: const InputDecoration(labelText: 'Question'),
                validator: (v) => _required(v, Limits.aptQuestionLength),
              ),
              const SizedBox(height: 16),
              Text('Options · tap the circle of the right one', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              RadioGroup<int>(
                groupValue: _answer,
                onChanged: (v) => setState(() => _answer = v!),
                child: Column(
                  children: [
                    for (final (i, option) in _options.indexed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Radio<int>(value: i),
                            Expanded(
                              child: TextFormField(
                                controller: option,
                                decoration: InputDecoration(labelText: 'Option ${_letter(i)}'),
                                validator: (v) => _required(v, Limits.aptOptionLength),
                              ),
                            ),
                            if (_options.length > Limits.minOptions)
                              IconButton(
                                tooltip: 'Remove option',
                                onPressed: () => _removeOption(i),
                                icon: const Icon(Icons.close_rounded),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (_options.length < Limits.maxOptions)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _options.add(TextEditingController())),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add option'),
                  ),
                ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _explanation,
                minLines: 3,
                maxLines: 10,
                decoration: const InputDecoration(labelText: 'Explanation (shown when you get it wrong)'),
                validator: (v) => (v?.length ?? 0) > Limits.aptExplanationLength ? 'Too long' : null,
              ),
              const SizedBox(height: 16),
              if (widget.fixedTopic == null)
                TextFormField(
                  controller: _topic,
                  decoration: const InputDecoration(labelText: 'Topic', hintText: 'e.g. Percentages'),
                  validator: (v) => (v?.length ?? 0) > Limits.topicLength ? 'Too long' : null,
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            onPressed: _save,
            icon: const Icon(Icons.check_rounded),
            label: Text(widget.card != null ? 'Save' : 'Save to my stack'),
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.color, required this.icon, required this.text});

  final Color color;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withValues(alpha: 0.35)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

/// Revise due questions: pick an option; a wrong pick shows the explanation.
class AptReviewPage extends StatefulWidget {
  const AptReviewPage({super.key, required this.store, required this.cards});

  final Store store;
  final List<AptCard> cards;

  @override
  State<AptReviewPage> createState() => _AptReviewPageState();
}

class _AptReviewPageState extends State<AptReviewPage> {
  int _index = 0;
  int? _picked;
  int _correct = 0;
  bool _showExplanation = false;

  void _pick(int i) {
    if (_picked != null) return;
    final card = widget.cards[_index];
    final right = i == card.answer;
    setState(() {
      _picked = i;
      _showExplanation = !right;
      if (right) _correct++;
    });
    unawaited(right ? HapticFeedback.mediumImpact() : HapticFeedback.heavyImpact());
    unawaited(widget.store.reviewApt(card, correct: right));
  }

  void _next() => setState(() {
    _index++;
    _picked = null;
    _showExplanation = false;
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final total = widget.cards.length;
    if (_index >= total) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: EmptyState(
            icon: Icons.emoji_events_rounded,
            title: '$_correct / $total correct',
            message: _correct == total ? 'Perfect! They come back later, spaced out.' : 'Missed ones come back tomorrow.',
            action: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
          ),
        ),
      );
    }
    final card = widget.cards[_index];
    final picked = _picked;
    return Scaffold(
      appBar: AppBar(title: Text('${_index + 1} / $total')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            LinearProgressIndicator(value: _index / total, borderRadius: BorderRadius.circular(4)),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Pill(card.topic, color: Accent.violet),
            ),
            const SizedBox(height: 12),
            Text(card.question, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, height: 1.4)),
            const SizedBox(height: 20),
            for (final (i, option) in card.options.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _OptionButton(
                  letter: _letter(i),
                  text: option,
                  state: picked == null
                      ? _OptionState.open
                      : i == card.answer
                      ? _OptionState.right
                      : i == picked
                      ? _OptionState.wrong
                      : _OptionState.faded,
                  onTap: () => _pick(i),
                ),
              ),
            if (picked != null && card.explanation.isNotEmpty) ...[
              const SizedBox(height: 8),
              if (_showExplanation)
                Card(
                  color: colors.surfaceContainerHigh,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Explanation', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        Text(card.explanation, style: const TextStyle(height: 1.5)),
                      ],
                    ),
                  ),
                )
              else
                TextButton.icon(
                  onPressed: () => setState(() => _showExplanation = true),
                  icon: const Icon(Icons.lightbulb_outline_rounded),
                  label: const Text('Show explanation'),
                ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: picked == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                  onPressed: _next,
                  child: Text(_index + 1 == total ? 'Finish' : 'Next'),
                ),
              ),
            ),
    );
  }
}

enum _OptionState { open, right, wrong, faded }

class _OptionButton extends StatelessWidget {
  const _OptionButton({required this.letter, required this.text, required this.state, required this.onTap});

  final String letter;
  final String text;
  final _OptionState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = switch (state) {
      _OptionState.right => Accent.green,
      _OptionState.wrong => Accent.red,
      _ => colors.outlineVariant,
    };
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: state == _OptionState.faded ? 0.5 : 1,
      child: Material(
        color: state == _OptionState.right || state == _OptionState.wrong ? accent.withValues(alpha: 0.12) : colors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: accent, width: state == _OptionState.open || state == _OptionState.faded ? 1 : 2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: state == _OptionState.open ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: accent.withValues(alpha: 0.2),
                  child: Text(letter, style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(text)),
                if (state == _OptionState.right) const Icon(Icons.check_circle_rounded, color: Accent.green),
                if (state == _OptionState.wrong) const Icon(Icons.cancel_rounded, color: Accent.red),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
