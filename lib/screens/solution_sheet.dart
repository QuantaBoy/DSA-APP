import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/store.dart';
import '../logic/models.dart';
import 'widgets.dart';

/// What the solution card editor returns.
typedef SolutionCard = ({Solution solution, List<String> patterns});

/// Opens the solution card editor as a bottom sheet. Returns null when dismissed.
Future<SolutionCard?> editSolutionCard(
  BuildContext context, {
  required String title,
  Solution initial = const Solution(),
  List<String> patterns = const [],
  String saveLabel = 'Save',
}) => showModalBottomSheet<SolutionCard>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => _SolutionEditor(title: title, initial: initial, patterns: patterns, saveLabel: saveLabel),
);

class _SolutionEditor extends StatefulWidget {
  const _SolutionEditor({required this.title, required this.initial, required this.patterns, required this.saveLabel});

  final String title;
  final Solution initial;
  final List<String> patterns;
  final String saveLabel;

  @override
  State<_SolutionEditor> createState() => _SolutionEditorState();
}

class _SolutionEditorState extends State<_SolutionEditor> {
  late final _idea = TextEditingController(text: widget.initial.idea);
  late final _mistake = TextEditingController(text: widget.initial.mistake);
  late final _code = TextEditingController(text: widget.initial.code);
  late String _time = widget.initial.time;
  late String _space = widget.initial.space;
  late final Set<String> _patterns = {...widget.patterns};
  late bool _showCode = widget.initial.code.isNotEmpty;

  @override
  void dispose() {
    _idea.dispose();
    _mistake.dispose();
    _code.dispose();
    super.dispose();
  }

  void _save() {
    final solution = Solution(idea: _idea.text.trim(), time: _time, space: _space, mistake: _mistake.text.trim(), code: _code.text.trim());
    if (!Store.fitsLimits(solution)) return; // fields have maxLength, so this only guards pasted text
    unawaited(HapticFeedback.mediumImpact());
    Navigator.pop(context, (solution: solution, patterns: _patterns.toList()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    Widget label(String text, {String? hint}) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Row(
        children: [
          Text(text, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          if (hint != null) ...[
            const SizedBox(width: 8),
            Text(hint, style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
          ],
        ],
      ),
    );
    Widget complexity(String value, ValueChanged<String> onPick) => Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final c in complexities)
          ChoiceChip(
            label: Text(c),
            selected: value == c,
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
            onSelected: (on) => setState(() => onPick(on ? c : '')),
          ),
      ],
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.86,
        maxChildSize: 0.95,
        builder: (context, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text(
              'Solution card',
              style: theme.textTheme.labelLarge?.copyWith(color: colors.primary, fontWeight: FontWeight.w800),
            ),
            Text(widget.title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            Text(
              'Write what you want to remember. Reviews show this card.',
              style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
            label('Pattern', hint: 'pick up to ${Limits.maxPatterns}'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final p in dsaPatterns)
                  FilterChip(
                    label: Text(p),
                    selected: _patterns.contains(p),
                    visualDensity: VisualDensity.compact,
                    onSelected: (on) => setState(() {
                      if (!on) {
                        _patterns.remove(p);
                      } else if (_patterns.length < Limits.maxPatterns) {
                        _patterns.add(p);
                      }
                    }),
                  ),
              ],
            ),
            label('Key idea', hint: 'one line'),
            TextField(
              controller: _idea,
              maxLength: Limits.shortTextLength,
              minLines: 1,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'e.g. Store value → index; for each x look up target − x'),
            ),
            label('Time'),
            complexity(_time, (v) => _time = v),
            label('Space'),
            complexity(_space, (v) => _space = v),
            label('My mistake', hint: 'optional'),
            TextField(
              controller: _mistake,
              maxLength: Limits.shortTextLength,
              minLines: 1,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'e.g. Forgot the empty array case'),
            ),
            const SizedBox(height: 4),
            if (_showCode) ...[
              label('Code', hint: 'optional'),
              TextField(
                controller: _code,
                maxLength: Limits.maxNoteLength,
                minLines: 4,
                maxLines: 14,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                decoration: const InputDecoration(hintText: 'Paste your solution'),
              ),
            ] else
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _showCode = true),
                  icon: const Icon(Icons.code_rounded),
                  label: const Text('Add code'),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
              child: Text(widget.saveLabel),
            ),
          ],
        ),
      ),
    );
  }
}

/// Read-only view of a solution card: the back of a review flashcard.
class SolutionView extends StatelessWidget {
  const SolutionView({super.key, required this.solution, required this.patterns, this.onEdit});

  final Solution solution;
  final List<String> patterns;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    if (solution.isEmpty && patterns.isEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.edit_note_rounded, size: 40, color: colors.primary),
          const SizedBox(height: 8),
          const Text('No solution card yet', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            'Add the key idea and complexity now; your next review will show them.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          if (onEdit != null) ...[
            const SizedBox(height: 12),
            FilledButton.tonalIcon(onPressed: onEdit, icon: const Icon(Icons.add_rounded), label: const Text('Add solution card')),
          ],
        ],
      );
    }
    Widget row(IconData icon, String title, String value, {Color? color}) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color ?? colors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.labelMedium?.copyWith(color: colors.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(value, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (patterns.isNotEmpty) ...[
          Wrap(spacing: 6, runSpacing: 6, children: [for (final p in patterns) Pill(p, color: colors.primary)]),
          const SizedBox(height: 14),
        ],
        if (solution.idea.isNotEmpty) row(Icons.lightbulb_rounded, 'Key idea', solution.idea, color: Accent.amber),
        if (solution.time.isNotEmpty || solution.space.isNotEmpty)
          row(
            Icons.speed_rounded,
            'Complexity',
            [
              if (solution.time.isNotEmpty) 'Time ${solution.time}',
              if (solution.space.isNotEmpty) 'Space ${solution.space}',
            ].join('   ·   '),
            color: Accent.sky,
          ),
        if (solution.mistake.isNotEmpty) row(Icons.report_rounded, 'My mistake', solution.mistake, color: Accent.red),
        if (solution.code.isNotEmpty)
          Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              leading: Icon(Icons.code_rounded, color: colors.primary),
              title: const Text('Code', style: TextStyle(fontWeight: FontWeight.w700)),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFF16161D), borderRadius: BorderRadius.circular(12)),
                  child: SelectableText(
                    solution.code,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5, height: 1.4, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        if (onEdit != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit_rounded, size: 18), label: const Text('Edit card')),
          ),
      ],
    );
  }
}
