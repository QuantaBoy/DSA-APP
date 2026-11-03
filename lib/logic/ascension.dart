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

/// Solving more than this many new problems in a day turns on Overdrive: each extra one earns [overdriveXp].
const overdriveFrom = 3;
const overdriveXp = 15;

int totalXp(Deeds d) {
  var xp = 0;
  for (final p in d.problems) {
    xp += solveXp(p.difficulty) + p.remembered * 10 + (p.reviews - p.remembered) * 3;
  }
  // Overdrive: every new problem past 3 in one day is worth a bonus.
  final perDay = <DateTime, int>{};
  for (final p in d.problems) {
    perDay.update(dateOnly(p.solvedOn), (n) => n + 1, ifAbsent: () => 1);
  }
  for (final n in perDay.values) {
    xp += max(0, n - overdriveFrom) * overdriveXp;
  }
  return xp + d.aptCorrect * 8 + d.aptWrong * 2 + d.stats.quizRight * 5;
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
  awakened('Awakened', 1, [Color(0xFF8B7CFF), Color(0xFF3B2A99)]),
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

/// A topic title, earned only when every problem of that topic in A2Z is solved.
class HunterTitle {
  const HunterTitle(this.id, this.name, this.topic, this.progress);
  final String id;
  final String name;
  final String topic; // shown while locked
  final Progress Function(Deeds d, Sheet? a2z) progress;

  bool earned(Progress p) => p.total > 0 && p.done >= p.total;
}

/// How much of an A2Z step (or section) is solved.
Progress _part(Deeds d, Sheet? a2z, bool Function(SheetProblem) part) {
  if (a2z == null) return (done: 0, total: 0);
  final ids = {for (final p in d.problems) p.id};
  final inPart = a2z.problems.where(part).toList();
  return (done: inPart.where((p) => ids.contains(p.id)).length, total: inPart.length);
}

HunterTitle _step(String id, String name, String step) =>
    HunterTitle(id, name, step, (d, s) => _part(d, s, (p) => s!.steps[p.step - 1] == step));

final titles = <HunterTitle>[
  HunterTitle('patterns', 'Pattern Reaper', 'Patterns', (d, s) => _part(d, s, (p) => p.section == 'Patterns')),
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
  HunterTitle('a2z', 'The Unbound', "all of Striver's A2Z", (d, s) => _part(d, s, (_) => true)),
];

/// What a locked title needs, in words.
String howToEarn(HunterTitle t) => t.id == 'a2z' ? 'Solve all of A2Z' : 'Solve every ${t.topic} problem in A2Z';

/// Ids of the titles you have earned.
Set<String> earnedTitles(Deeds d, Sheet? a2z) => {
  for (final t in titles)
    if (t.earned(t.progress(d, a2z))) t.id,
};

HunterTitle? titleById(String? id) => titles.where((t) => t.id == id).firstOrNull;

/// The title you are closest to (by share solved), to chase next. Null once all are earned.
({HunterTitle title, Progress progress})? nextTitle(Deeds d, Sheet? a2z) {
  ({HunterTitle title, Progress progress})? best;
  for (final t in titles) {
    final p = t.progress(d, a2z);
    if (p.total == 0 || p.done >= p.total) continue;
    if (best == null || p.done / p.total > best.progress.done / best.progress.total) best = (title: t, progress: p);
  }
  return best;
}
