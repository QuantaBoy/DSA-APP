import 'dart:async';

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../logic/gate.dart';
import '../logic/models.dart';
import 'aptitude_page.dart';
import 'review_page.dart';
import 'widgets.dart';

/// One search box over everything you saved: problems (name, topic, patterns), aptitude and GATE questions.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.store, required this.problems});

  final Store store;
  final List<Problem> problems;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  String _q = '';
  late final Stream<List<AptCard>> _cards = widget.store.aptCards();

  bool _hit(String text) => text.toLowerCase().contains(_q);

  void _open(Widget page) => unawaited(Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page)));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: TextField(
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Search problems, patterns, questions', border: InputBorder.none, filled: false),
        onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
      ),
    ),
    body: StreamBuilder<List<AptCard>>(
      stream: _cards,
      builder: (context, snap) {
        if (_q.length < 2) {
          return const Center(child: Text('Type at least 2 letters.'));
        }
        final problems = widget.problems.where((p) => _hit(p.name) || _hit(p.topic) || p.patterns.any(_hit)).toList();
        final cards = [...?snap.data?.where((c) => _hit(c.question) || _hit(c.topic))];
        if (problems.isEmpty && cards.isEmpty) return const Center(child: Text('Nothing found.'));
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            if (problems.isNotEmpty) SectionTitle('Problems (${problems.length})'),
            for (final p in problems)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.code_rounded),
                  title: Text(p.name),
                  subtitle: Text([p.topic, ...p.patterns].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => _open(ReviewPage(store: widget.store, queue: [p])),
                ),
              ),
            if (cards.isNotEmpty) SectionTitle('Questions (${cards.length})'),
            for (final c in cards)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(isGateCard(c.topic) ? Icons.school_rounded : Icons.calculate_rounded),
                  title: Text(c.question, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    isGateCard(c.topic) ? 'GATE · ${gateLookup(gateTopicOf(c.topic)!)?.topic.name ?? ''}' : c.topic,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _open(AptEditPage(store: widget.store, card: c, fixedTopic: isGateCard(c.topic) ? c.topic : null)),
                ),
              ),
          ],
        );
      },
    ),
  );
}
