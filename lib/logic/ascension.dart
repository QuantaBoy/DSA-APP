import 'dart:math';

import 'package:flutter/painting.dart';

import '../data/sheet.dart';
import 'models.dart';
import 'srs.dart';

/// Levels, ranks and titles, all worked out from what you already did, so nothing extra is stored
/// and past work counts at once. Reset progress takes you back to level 1.

/// XP for one solve, by difficulty.
int solveXp(String difficulty) => switch (difficulty) {
  'Easy' => 30,
  'Hard' => 100,
  _ => 60,
};

/// Everything that earns XP, read from your data.
typedef Deeds = ({List<Problem> problems, Stats stats, int aptCorrect, int aptWrong});

int totalXp(Deeds d) {
  var xp = 0;
  for (final p in d.problems) {
    xp += solveXp(p.difficulty) + p.remembered * 10 + (p.reviews - p.remembered) * 3;
  }
  // Streak fire: each day in a run is worth more the longer the run (5 XP per day of run, at most 100).
  var run = 0;
  DateTime? last;
  for (final day in d.stats.days.keys.map(dateOnly).toList()..sort()) {
    run = last != null && day.difference(last).inDays == 1 ? run + 1 : 1;
    last = day;
    xp += min(5 * run, 100);
  }
  return xp + d.aptCorrect * 8 + d.aptWrong * 2;
}

/// XP needed to go from [level] to the next one: quick early, slow later.
int xpToNext(int level) => 100 + 40 * level;

typedef Level = ({int level, int into, int needed});

Level levelFor(int xp) {
  var level = 1;
  while (xp >= xpToNext(level)) {
    xp -= xpToNext(level);
    level++;
  }
  return (level: level, into: xp, needed: xpToNext(level));
}

enum Rank {
  awakened('Awakened', 1, [Color(0xFFE6E8F0), Color(0xFF9CA1B8)]),
  shadowInitiate('Shadow Initiate', 5, [Color(0xFF8A8FA3), Color(0xFF2B2E3B)]),
  bladeOfLogic('Blade of Logic', 10, [Color(0xFFF1F5F9), Color(0xFF7C8BA1)]),
  voidArchitect('Void Architect', 20, [Color(0xFF38BDF8), Color(0xFF1E3A8A)]),
  abyssSovereign('Abyss Sovereign', 35, [Color(0xFFC084FC), Color(0xFF4C1D95)]),
  eclipseEmperor('Eclipse Emperor', 50, [Color(0xFFFACC15), Color(0xFF111111)]),
  monarch('The Monarch of Memory', 75, [Color(0xFFFFD700), Color(0xFF7F1D1D)]);

  const Rank(this.title, this.fromLevel, this.colors);
  final String title;
  final int fromLevel;
  final List<Color> colors; // glow, core

  static Rank of(int level) => values.lastWhere((r) => level >= r.fromLevel);
}

typedef Progress = ({int done, int total});

class HunterTitle {
  const HunterTitle(this.id, this.name, this.how, this.progress, {this.secret = false});
  final String id;
  final String name;
  final String how; // shown while locked (unless secret)
  final Progress Function(Deeds d, Sheet? a2z) progress;
  final bool secret;

  bool earned(Deeds d, Sheet? a2z) {
    final p = progress(d, a2z);
    return p.total > 0 && p.done >= p.total;
  }
}

/// How much of an A2Z step (or section) is solved.
Progress _part(Deeds d, Sheet? a2z, bool Function(SheetProblem) part) {
  if (a2z == null) return (done: 0, total: 0);
  final ids = {for (final p in d.problems) p.id};
  final inPart = a2z.problems.where(part).toList();
  return (done: inPart.where((p) => ids.contains(p.id)).length, total: inPart.length);
}

HunterTitle _step(String id, String name, String step) =>
    HunterTitle(id, name, 'Clear every $step problem in A2Z', (d, s) => _part(d, s, (p) => s!.steps[p.step - 1] == step));

HunterTitle _count(String id, String name, String how, int goal, int Function(Deeds d) count) =>
    HunterTitle(id, name, how, (d, _) => (done: min(count(d), goal), total: goal));

int _longest(Deeds d) => longestStreak(d.stats.days.keys);

final titles = <HunterTitle>[
  HunterTitle('patterns', 'Pattern Reaper', 'Clear every Patterns problem in A2Z', (d, s) => _part(d, s, (p) => p.section == 'Patterns')),
  _step('sorting', 'Order Bringer', 'Sorting'),
  _step('arrays', 'Array Executioner', 'Arrays'),
  _step('hashing', 'Keeper of Keys', 'Hashing'),
  _step('bsearch', 'The Splitter of Worlds', 'Binary Search'),
  _step('recursion', 'Lord of Echoes', 'Recursion'),
  _step('linked', 'Chainbreaker', 'Linked-List'),
  _step('bits', 'Bitwraith', 'Bit Manipulation'),
  _step('greedy', 'The Insatiable', 'Greedy Algorithms'),
  _step('window', 'Windwalker', 'Sliding Window / 2 Pointer'),
  _step('stack', 'Tower Lord', 'Stack / Queues'),
  _step('trees', 'Warden of Roots', 'Binary Trees'),
  _step('bst', 'Judge of the Grove', 'Binary Search Trees'),
  _step('heaps', 'Crown of Heaps', 'Heaps'),
  _step('graphs', 'Conqueror of Paths', 'Graphs'),
  _step('dp', 'Sage of Memory', 'Dynamic Programming'),
  _step('tries', 'Rootspeaker', 'Tries'),
  _step('strings', 'Threadweaver', 'Strings (Advanced Algo)'),
  HunterTitle('a2z', 'The Unbound', "Clear all of Striver's A2Z", (d, s) => _part(d, s, (_) => true)),
  _count('ember', 'Ember-Born', 'Keep a 7-day streak', 7, _longest),
  _count('unyielding', 'The Unyielding', 'Keep a 30-day streak', 30, _longest),
  _count('eternal', 'Eternal Flame', 'Keep a 100-day streak', 100, _longest),
  _count('undying', 'Undying', 'Keep a 365-day streak', 365, _longest),
  _count('relentless', 'Relentless', 'Solve 50 problems', 50, (d) => d.problems.length),
  _count('warmachine', 'War Machine', 'Solve 200 problems', 200, (d) => d.problems.length),
  _count('ironmind', 'Iron Mind', 'Do 500 reviews', 500, (d) => d.stats.reviews),
  _count('lightning', 'Lightning Mind', 'Answer 100 aptitude questions right', 100, (d) => d.aptCorrect),
  HunterTitle('ashes', 'Risen from Ashes', 'Come back after a broken streak', (d, _) => (done: _risen(d) ? 1 : 0, total: 1), secret: true),
];

/// The locked title you are closest to (by share done), to chase next. Null once all are earned.
({HunterTitle title, Progress progress})? nextTitle(Deeds d, Sheet? a2z) {
  ({HunterTitle title, Progress progress})? best;
  for (final t in titles.where((t) => !t.secret)) {
    final p = t.progress(d, a2z);
    if (p.total == 0 || p.done >= p.total) continue;
    if (best == null || p.done / p.total > best.progress.done / best.progress.total) best = (title: t, progress: p);
  }
  return best;
}

/// A gap of 3+ days, then a run of 3+ days after it.
bool _risen(Deeds d) {
  final days = d.stats.days.keys.map(dateOnly).toList()..sort();
  var gap = false;
  var run = 0;
  for (var i = 1; i < days.length; i++) {
    final step = days[i].difference(days[i - 1]).inDays;
    if (step >= 3) {
      gap = true;
      run = 1;
    } else if (step == 1 && gap) {
      run++;
      if (run >= 3) return true;
    }
  }
  return false;
}

Set<String> earnedTitles(Deeds d, Sheet? a2z) => {
  for (final t in titles)
    if (t.earned(d, a2z)) t.id,
};

HunterTitle? titleById(String? id) => titles.where((t) => t.id == id).firstOrNull;
