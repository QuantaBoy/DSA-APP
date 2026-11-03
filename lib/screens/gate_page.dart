import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../data/scan.dart';
import '../data/store.dart';
import '../logic/gate.dart';
import '../logic/models.dart';
import '../logic/srs.dart';
import 'aptitude_page.dart';
import 'goal_celebration.dart';
import 'widgets.dart';

/// GATE DA: the syllabus as a journey of stops, each with its subtopics on a tracker line
/// (covered ● · up next ◉ · ahead ○), questions per subtopic, and AI import of question papers.
class GateView extends StatelessWidget {
  const GateView({super.key, required this.store, required this.covered});

  final Store store;
  final Set<String> covered;

  @override
  Widget build(BuildContext context) => StreamBuilder<List<AptCard>>(
    stream: store.aptCards(),
    builder: (context, snap) {
      final cards = [...?snap.data?.where((c) => isGateCard(c.topic))];
      final now = today();
      final due = cards.where((c) => c.isDue(now)).toList();
      final next = nextGateTopic(covered);
      return ListView(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 120),
        children: [
          _Hero(store: store, covered: covered, cards: cards, due: due),
          const SizedBox(height: 18),
          for (final (i, s) in gateDa.indexed)
            _Stop(
              index: i,
              section: s,
              covered: covered,
              cards: cards,
              next: next,
              last: i == gateDa.length - 1,
              onOpen: () => _open(context, GateSectionPage(store: store, section: s)),
            ),
        ],
      );
    },
  );

  static void _open(BuildContext context, Widget page) => unawaited(Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page)));
}

/// Top card: overall progress ring, counts, review and paper import.
class _Hero extends StatelessWidget {
  const _Hero({required this.store, required this.covered, required this.cards, required this.due});

  final Store store;
  final Set<String> covered;
  final List<AptCard> cards;
  final List<AptCard> due;

  @override
  Widget build(BuildContext context) {
    final share = covered.length / gateTopicCount;
    final theme = Theme.of(context);
    return HeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox.square(
                dimension: 86,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: share),
                      duration: const Duration(milliseconds: 1100),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, _) => CircularProgressIndicator(
                        value: v,
                        strokeWidth: 8,
                        strokeCap: StrokeCap.round,
                        color: Colors.white,
                        backgroundColor: Colors.white24,
                      ),
                    ),
                    Center(
                      child: Text('${(share * 100).round()}%', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GATE DA JOURNEY',
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 1.6,
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${covered.length} of $gateTopicCount subtopics covered',
                      style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text('${cards.length} questions · ${due.length} due', style: TextStyle(color: Colors.white.withValues(alpha: 0.85))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (due.isNotEmpty)
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: HeroCard.ink(context)),
                  onPressed: () => GateView._open(context, AptReviewPage(store: store, cards: due)),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text('Review ${due.length}'),
                ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.6)),
                ),
                onPressed: () => importGatePaper(context, store),
                icon: const Icon(Icons.picture_as_pdf_rounded),
                label: const Text('Import paper (PDF)'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One stop on the journey: a numbered node on the rail, and a card with the section's subtopic tracker.
class _Stop extends StatelessWidget {
  const _Stop({
    required this.index,
    required this.section,
    required this.covered,
    required this.cards,
    required this.next,
    required this.last,
    required this.onOpen,
  });

  final int index;
  final GateSection section;
  final Set<String> covered;
  final List<AptCard> cards;
  final GateTopic? next;
  final bool last;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final done = section.topics.where((t) => covered.contains(t.id)).length;
    final complete = done == section.topics.length;
    final questions = cards.where((c) => section.topics.any((t) => gateTag(t.id) == c.topic)).length;
    final current = section.topics.contains(next);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The rail: node + line down to the next stop (solid once this stop is complete).
          SizedBox(
            width: 64,
            child: Column(
              children: [
                const SizedBox(height: 14),
                _Node(color: section.color, number: index + 1, share: done / section.topics.length, glow: current),
                if (!last)
                  Expanded(
                    child: complete
                        ? Container(width: 4, margin: const EdgeInsets.only(top: 4), color: section.color)
                        : CustomPaint(painter: _DottedLine(colors.outlineVariant), child: const SizedBox(width: 4)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 4, 16, 14),
              child: Card(
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: current ? BorderSide(color: section.color, width: 2) : BorderSide.none,
                ),
                child: InkWell(
                  onTap: onOpen,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(section.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                            ),
                            if (complete)
                              Icon(Icons.verified_rounded, color: section.color)
                            else if (current)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: section.color, borderRadius: BorderRadius.circular(10)),
                                child: const Text(
                                  'NOW',
                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$done/${section.topics.length} covered · $questions questions',
                          style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                        ),
                        const SizedBox(height: 14),
                        _Tracker(section: section, covered: covered, next: next),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Node extends StatelessWidget {
  const _Node({required this.color, required this.number, required this.share, required this.glow});

  final Color color;
  final int number;
  final double share;
  final bool glow;

  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: share == 1 ? color : Theme.of(context).colorScheme.surfaceContainerLowest,
      boxShadow: glow ? [BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 14, spreadRadius: 2)] : null,
    ),
    child: Stack(
      alignment: Alignment.center,
      children: [
        if (share < 1)
          CircularProgressIndicator(value: share, strokeWidth: 4, color: color, backgroundColor: color.withValues(alpha: 0.15)),
        share == 1
            ? const Icon(Icons.check_rounded, color: Colors.white)
            : Text(
                '$number',
                style: TextStyle(fontWeight: FontWeight.w900, color: color),
              ),
      ],
    ),
  );
}

/// The delivery-style tracker: a dot per subtopic on a line, filled up to where you are.
class _Tracker extends StatelessWidget {
  const _Tracker({required this.section, required this.covered, required this.next});

  final GateSection section;
  final Set<String> covered;
  final GateTopic? next;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outlineVariant;
    final topics = section.topics;
    return Row(
      children: [
        for (final (i, t) in topics.indexed) ...[
          _Dot(color: section.color, state: covered.contains(t.id) ? _DotState.done : (t == next ? _DotState.now : _DotState.ahead)),
          if (i < topics.length - 1)
            Expanded(
              child: Container(height: 3, color: covered.contains(t.id) && covered.contains(topics[i + 1].id) ? section.color : outline),
            ),
        ],
      ],
    );
  }
}

enum _DotState { done, now, ahead }

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.state, this.size = 14});

  final Color color;
  final _DotState state;
  final double size;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surfaceContainerLowest;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: state == _DotState.done ? color : surface,
        border: Border.all(color: state == _DotState.ahead ? Theme.of(context).colorScheme.outline : color, width: 2.5),
        boxShadow: state == _DotState.now ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 10, spreadRadius: 2)] : null,
      ),
    );
  }
}

class _DottedLine extends CustomPainter {
  _DottedLine(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    for (var y = 8.0; y < size.height; y += 10) {
      canvas.drawCircle(Offset(size.width / 2, y), 2.2, p);
    }
  }

  @override
  bool shouldRepaint(_DottedLine old) => old.color != color;
}

/// A section's subtopics as a vertical shipment tracker: tap one to study it.
class GateSectionPage extends StatelessWidget {
  const GateSectionPage({super.key, required this.store, required this.section});

  final Store store;
  final GateSection section;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(section.name)),
    body: StreamBuilder<UserData>(
      stream: store.data(),
      builder: (context, data) => StreamBuilder<List<AptCard>>(
        stream: store.aptCards(),
        builder: (context, snap) {
          final covered = data.data?.stats.gateCovered ?? const <String>{};
          final cards = snap.data ?? const <AptCard>[];
          final next = section.topics.where((t) => !covered.contains(t.id)).firstOrNull;
          final theme = Theme.of(context);
          final colors = theme.colorScheme;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: sectionProgress(section, covered),
                  minHeight: 10,
                  color: section.color,
                  backgroundColor: section.color.withValues(alpha: 0.15),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${section.topics.where((t) => covered.contains(t.id)).length} of ${section.topics.length} covered',
                style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 18),
              for (final (i, t) in section.topics.indexed)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 28,
                        child: Column(
                          children: [
                            const SizedBox(height: 4),
                            _Dot(
                              color: section.color,
                              size: 20,
                              state: covered.contains(t.id) ? _DotState.done : (t == next ? _DotState.now : _DotState.ahead),
                            ),
                            if (i < section.topics.length - 1)
                              Expanded(
                                child: covered.contains(t.id)
                                    ? Container(width: 3, color: section.color)
                                    : CustomPaint(painter: _DottedLine(colors.outlineVariant), child: const SizedBox(width: 3)),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => GateView._open(context, GateTopicPage(store: store, section: section, topic: t)),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 22),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.name,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: covered.contains(t.id) || t == next ? null : colors.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  [
                                    if (covered.contains(t.id)) 'Covered' else if (t == next) 'Up next' else 'Ahead',
                                    '${cards.where((c) => c.topic == gateTag(t.id)).length} questions',
                                  ].join(' · '),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: t == next ? section.color : colors.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}

/// One subtopic: mark it covered (confetti!), and its own question stack to add to and revise.
class GateTopicPage extends StatelessWidget {
  const GateTopicPage({super.key, required this.store, required this.section, required this.topic});

  final Store store;
  final GateSection section;
  final GateTopic topic;

  Future<void> _toggle(BuildContext context, Set<String> covered) async {
    final on = !covered.contains(topic.id);
    unawaited(on ? HapticFeedback.heavyImpact() : HapticFeedback.selectionClick());
    unawaited(store.setGateCovered(topic.id, covered: on));
    if (!on) return;
    confettiBurst(context);
    final sectionDone = section.topics.every((t) => t.id == topic.id || covered.contains(t.id));
    if (sectionDone) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: Icon(Icons.workspace_premium_rounded, size: 56, color: section.color),
          title: Text('${section.name} complete!', textAlign: TextAlign.center),
          content: const Text('Every subtopic covered. On to the next stop of your GATE journey.', textAlign: TextAlign.center),
          actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text("Let's go"))],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(section.name)),
    body: StreamBuilder<UserData>(
      stream: store.data(),
      builder: (context, data) => StreamBuilder<List<AptCard>>(
        stream: store.aptCards(),
        builder: (context, snap) {
          final covered = data.data?.stats.gateCovered ?? const <String>{};
          final isCovered = covered.contains(topic.id);
          final tag = gateTag(topic.id);
          final cards = [...?snap.data?.where((c) => c.topic == tag)]..sort((a, b) => a.nextDue.compareTo(b.nextDue));
          final due = cards.where((c) => c.isDue(today())).toList();
          final theme = Theme.of(context);
          final colors = theme.colorScheme;
          void open(Widget page) => GateView._open(context, page);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              Text(topic.name, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: isCovered ? LinearGradient(colors: [section.color, Color.lerp(section.color, Colors.black, 0.25)!]) : null,
                  color: isCovered ? null : section.color.withValues(alpha: 0.1),
                  border: Border.all(color: section.color, width: 2),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => _toggle(context, covered),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          isCovered ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                          color: isCovered ? Colors.white : section.color,
                          size: 30,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            isCovered ? 'Covered · +25 XP' : 'Mark as covered',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: isCovered ? Colors.white : section.color),
                          ),
                        ),
                        if (isCovered) const Text('tap to undo', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text('Questions (${cards.length})', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                  if (due.isNotEmpty)
                    FilledButton.tonalIcon(
                      onPressed: () => open(AptReviewPage(store: store, cards: due)),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text('Review ${due.length}'),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final (icon, label, action) in [
                    (Icons.photo_camera_rounded, 'Scan', () => _scan(context, ImageSource.camera)),
                    (Icons.photo_library_rounded, 'Photo', () => _scan(context, ImageSource.gallery)),
                    (Icons.edit_rounded, 'Type', () => open(AptEditPage(store: store, fixedTopic: tag))),
                  ]) ...[
                    Expanded(
                      child: OutlinedButton.icon(onPressed: action, icon: Icon(icon, size: 18), label: Text(label)),
                    ),
                    if (label != 'Type') const SizedBox(width: 8),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              if (cards.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Text(
                    'No questions yet. Snap one from a book or a past paper: the AI reads it, solves it and explains it.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ),
              for (final c in cards)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(c.question, maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text(dueLabel(today().difference(c.nextDue).inDays)),
                    onTap: () => open(AptEditPage(store: store, card: c, fixedTopic: tag)),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );

  Future<void> _scan(BuildContext context, ImageSource source) => scanAptitude(
    context,
    store,
    source,
    topic: gateTag(topic.id),
    extra: 'The questions are GATE Data Science & AI questions on ${topic.name}.',
  );
}

/// Pick a question-paper PDF, let the AI pull out every question (solved, explained, filed under a subtopic),
/// then check them all on one screen and save.
Future<void> importGatePaper(BuildContext context, Store store) async {
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  final List<PlatformFile> files;
  try {
    files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
  } on PlatformException {
    messenger.showSnackBar(const SnackBar(content: Text('Could not open your files.')));
    return;
  }
  if (files.isEmpty || !context.mounted) return;
  final bytes = await files.first.readAsBytes();
  // One AI request carries at most ~20 MB, and the file grows a third when sent: keep PDFs under 10 MB.
  if (bytes.length > 10 * 1024 * 1024) {
    messenger.showSnackBar(const SnackBar(content: Text('That PDF is over 10 MB. Split it and import the parts.')));
    return;
  }
  if (!context.mounted) return;
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text('Reading the paper, solving every question… this can take a minute or two.')),
          ],
        ),
      ),
    ),
  );
  final List<ScannedQuestion> found;
  try {
    found = await scanQuestions(bytes, mimeType: 'application/pdf', extra: gatePrompt([for (final s in gateDa) ...s.topics]));
  } on ScanException catch (e) {
    navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
    return;
  }
  navigator.pop();
  if (found.isEmpty) {
    messenger.showSnackBar(const SnackBar(content: Text('No questions found in that PDF.')));
    return;
  }
  final saved = await navigator.push<int>(
    MaterialPageRoute(
      builder: (_) => _ImportPage(store: store, found: found, name: files.first.name),
    ),
  );
  if ((saved ?? 0) > 0) {
    messenger.showSnackBar(SnackBar(content: Text('$saved questions added to your GATE journey.')));
  }
}

/// Every question the AI found, with its subtopic: untick the bad ones, fix a subtopic, save all.
class _ImportPage extends StatefulWidget {
  const _ImportPage({required this.store, required this.found, required this.name});

  final Store store;
  final List<ScannedQuestion> found;
  final String name;

  @override
  State<_ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<_ImportPage> {
  late final _keep = List.filled(widget.found.length, true);
  late final _topic = [for (final q in widget.found) gateLookup(q.subtopic ?? '') == null ? gateDa.last.topics.first.id : q.subtopic!];

  void _save() {
    var n = 0;
    for (final (i, q) in widget.found.indexed) {
      if (!_keep[i]) continue;
      final card = AptCard.fresh(
        id: widget.store.newAptId(),
        question: q.question,
        options: q.options,
        answer: q.answer,
        explanation: q.explanation,
        topic: gateTag(_topic[i]),
      );
      if (!card.isValid) continue;
      unawaited(widget.store.saveApt(card));
      n++;
    }
    Navigator.pop(context, n);
  }

  @override
  Widget build(BuildContext context) {
    final kept = _keep.where((k) => k).length;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.name, overflow: TextOverflow.ellipsis)),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
        itemCount: widget.found.length,
        itemBuilder: (context, i) {
          final q = widget.found[i];
          final where = gateLookup(_topic[i])!;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(value: _keep[i], onChanged: (v) => setState(() => _keep[i] = v ?? false)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Q${i + 1}. ${q.question}', maxLines: 4, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        Text(
                          'Answer: ${q.options[q.answer]}',
                          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700, color: const Color(0xFF16A34A)),
                        ),
                        const SizedBox(height: 6),
                        // Tap to move it to another subtopic.
                        ActionChip(
                          avatar: CircleAvatar(backgroundColor: where.section.color, radius: 6),
                          label: Text(where.topic.name, overflow: TextOverflow.ellipsis),
                          onPressed: () async {
                            final picked = await showModalBottomSheet<String>(
                              context: context,
                              showDragHandle: true,
                              builder: (context) => ListView(
                                children: [
                                  for (final s in gateDa) ...[
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                                      child: Text(
                                        s.name,
                                        style: TextStyle(fontWeight: FontWeight.w800, color: s.color),
                                      ),
                                    ),
                                    for (final t in s.topics)
                                      ListTile(dense: true, title: Text(t.name), onTap: () => Navigator.pop(context, t.id)),
                                  ],
                                ],
                              ),
                            );
                            if (picked != null) setState(() => _topic[i] = picked);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: kept == 0 ? null : _save,
        icon: const Icon(Icons.save_rounded),
        label: Text('Save $kept'),
      ),
    );
  }
}
