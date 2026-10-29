import 'dart:async';

import 'package:flutter/material.dart';

import '../data/catalog.dart';
import '../data/store.dart';
import '../logic/models.dart';
import '../logic/srs.dart';
import 'open_link.dart';

class AddProblemPage extends StatefulWidget {
  const AddProblemPage({super.key, required this.store});

  final Store store;

  @override
  State<AddProblemPage> createState() => _AddProblemPageState();
}

class _AddProblemPageState extends State<AddProblemPage> {
  final _form = GlobalKey<FormState>();
  final _url = TextEditingController();
  final _notes = TextEditingController();
  TextEditingController? _name; // owned by the Autocomplete fields
  TextEditingController? _topic;
  List<CatalogItem> _catalog = const [];
  String _platform = platforms.first;
  String _difficulty = 'Medium';
  DateTime _solvedOn = today();

  @override
  void initState() {
    super.initState();
    unawaited(
      loadCatalog().then((c) {
        if (mounted) setState(() => _catalog = c);
      }),
    );
  }

  @override
  void dispose() {
    _url.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _pick(CatalogItem item) => setState(() {
    _url.text = item.url;
    _difficulty = item.difficulty;
    _topic?.text = item.mainTopic;
  });

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _solvedOn, firstDate: DateTime(2000), lastDate: today());
    if (picked != null) setState(() => _solvedOn = dateOnly(picked));
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    String? optional(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    final problem = Problem.solved(
      id: widget.store.newProblemId(),
      name: _name!.text.trim(),
      platform: _platform,
      difficulty: _difficulty,
      topic: _topic!.text.trim(),
      url: optional(_url),
      solvedOn: _solvedOn,
    );
    unawaited(widget.store.addProblem(problem, notes: optional(_notes))); // saved locally at once, syncs when online
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Added ${problem.name}. First review on ${prettyDay(problem.nextDue)}.')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 16);
    return Scaffold(
      appBar: AppBar(title: const Text('Add solved problem')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _platform,
              decoration: const InputDecoration(labelText: 'Platform', border: OutlineInputBorder()),
              items: [for (final p in platforms) DropdownMenuItem(value: p, child: Text(p))],
              onChanged: (v) => setState(() => _platform = v!),
            ),
            gap,
            Autocomplete<CatalogItem>(
              displayStringForOption: (i) => i.title,
              optionsBuilder: (v) => searchCatalog(_catalog, _platform, v.text),
              onSelected: _pick,
              fieldViewBuilder: (context, controller, focus, onSubmit) {
                _name = controller;
                return TextFormField(
                  controller: controller,
                  focusNode: focus,
                  decoration: const InputDecoration(
                    labelText: 'Problem name',
                    hintText: 'Start typing, e.g. Two Sum',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                  maxLength: Limits.nameLength,
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Enter the problem name' : null,
                );
              },
              optionsViewBuilder: (context, onSelected, options) => _Options(
                options: options.toList(),
                onSelected: onSelected,
                title: (i) => i.title,
                subtitle: (i) => '${i.difficulty} · ${i.topics.take(3).join(', ')}',
              ),
            ),
            gap,
            SegmentedButton<String>(
              segments: [for (final d in difficulties) ButtonSegment(value: d, label: Text(d))],
              selected: {_difficulty},
              onSelectionChanged: (s) => setState(() => _difficulty = s.first),
            ),
            gap,
            Autocomplete<String>(
              optionsBuilder: (v) {
                final q = v.text.trim().toLowerCase();
                final all = topicChoices(_catalog.isEmpty ? const [] : _catalog);
                return q.isEmpty ? all.take(roadmap.length) : all.where((t) => t.toLowerCase().contains(q)).take(10);
              },
              fieldViewBuilder: (context, controller, focus, onSubmit) {
                _topic = controller;
                return TextFormField(
                  controller: controller,
                  focusNode: focus,
                  decoration: const InputDecoration(labelText: 'Topic', hintText: 'e.g. Two Pointers', border: OutlineInputBorder()),
                  textInputAction: TextInputAction.next,
                  maxLength: Limits.topicLength,
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Pick or type a topic' : null,
                );
              },
              optionsViewBuilder: (context, onSelected, options) =>
                  _Options(options: options.toList(), onSelected: onSelected, title: (t) => t),
            ),
            gap,
            TextFormField(
              controller: _url,
              decoration: const InputDecoration(labelText: 'Link (optional)', border: OutlineInputBorder()),
              keyboardType: TextInputType.url,
              maxLength: Limits.urlLength,
              validator: (v) {
                final t = (v ?? '').trim();
                return t.isEmpty || isWebLink(t) ? null : 'Enter a full link starting with https://';
              },
            ),
            gap,
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.event),
              label: Text('Solved on ${prettyDay(_solvedOn)}'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), alignment: Alignment.centerLeft),
            ),
            gap,
            TextFormField(
              controller: _notes,
              minLines: 5,
              maxLines: 12,
              maxLength: Limits.maxNoteLength,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
              decoration: const InputDecoration(
                labelText: 'Your solution / key idea (optional)',
                hintText: "Paste your code, or the trick in one line: 'hash map of value → index'",
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: const Text('Add to my stack'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dropdown list under an Autocomplete field.
class _Options<T extends Object> extends StatelessWidget {
  const _Options({required this.options, required this.onSelected, required this.title, this.subtitle});

  final List<T> options;
  final void Function(T) onSelected;
  final String Function(T) title;
  final String Function(T)? subtitle;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topLeft,
    child: Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 280, maxWidth: 560),
        child: ListView(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          children: [
            for (final o in options)
              ListTile(title: Text(title(o)), subtitle: subtitle == null ? null : Text(subtitle!(o)), onTap: () => onSelected(o)),
          ],
        ),
      ),
    ),
  );
}
