@Tags(['shots'])
library;

// Renders the level system (rank strips, roadmap, System windows, party, leaderboard) to PNGs:
// flutter test test/shots/game_shots_test.dart --update-goldens
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_stack/data/leaderboard.dart';
import 'package:memory_stack/data/prefs.dart';
import 'package:memory_stack/logic/ascension.dart';
import 'package:memory_stack/main.dart';
import 'package:memory_stack/screens/ascension_view.dart';
import 'package:memory_stack/screens/goal_celebration.dart';
import 'package:memory_stack/screens/leaderboard_page.dart';
import 'package:memory_stack/screens/gate_page.dart';
import 'package:memory_stack/logic/gate.dart';
import 'package:memory_stack/screens/quiz_page.dart';
import 'package:memory_stack/screens/roadmap_page.dart';
import 'package:memory_stack/screens/widgets.dart';
import 'package:memory_stack/data/store.dart';
import 'package:memory_stack/logic/models.dart';

const fonts = r'C:/flutter/bin/cache/artifacts/material_fonts';

Future<void> load(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(Future.value(ByteData.sublistView(File('$fonts/$f').readAsBytesSync())));
  }
  await loader.load();
}

Power at(Rank rank, int level, {Set<String> titles = const {}}) => (
  xp: 0,
  level: (level: level, into: 70, needed: xpToNext(level)),
  rank: rank,
  titles: titles,
  next: null,
  progress: {'patterns': (done: 14, total: 14), 'sorting': (done: 4, total: 7), 'arrays': (done: 0, total: 40)},
);

Future<void> phone(WidgetTester t, Widget home, String name, {Size size = const Size(1170, 2532)}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, theme: appTheme(Brightness.light), home: home));
  await t.pump(const Duration(milliseconds: 1500));
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('game/$name.png'));
}

void main() {
  setUpAll(() async {
    await load('Roboto', ['roboto-regular.ttf', 'roboto-medium.ttf', 'roboto-bold.ttf', 'roboto-black.ttf']);
    await load('MaterialIcons', ['materialicons-regular.otf']);
  });

  for (final rank in Rank.values) {
    testWidgets('strip ${rank.name}', (t) async {
      power.value = at(rank, rank.fromLevel);
      await phone(
        t,
        const Scaffold(body: Column(children: [SizedBox(height: 16), PowerStrip()])),
        'strip_${rank.index}_${rank.name}',
        size: const Size(1290, 640),
      );
    });
  }

  for (final (name, earned) in [
    ('pill_title', {'patterns'}),
    ('pill_none', <String>{}),
  ]) {
    testWidgets(name, (t) async {
      final base = at(Rank.awakened, 3, titles: earned);
      power.value = (
        xp: base.xp,
        level: base.level,
        rank: base.rank,
        titles: base.titles,
        next: (title: titles[1], progress: (done: 4, total: 7)),
        progress: base.progress,
      );
      Prefs.equippedTitle.value = null;
      await phone(
        t,
        Scaffold(
          appBar: AppBar(
            title: const Text('Hi, Alone'),
            actions: const [Padding(padding: EdgeInsets.only(right: 12), child: TitlePill())],
          ),
        ),
        name,
        size: const Size(1170, 300),
      );
    });
  }

  testWidgets('roadmap', (t) async {
    power.value = at(Rank.shadowInitiate, 6, titles: {'patterns'});
    Prefs.equippedTitle.value = 'patterns';
    await phone(t, const RoadmapPage(), 'roadmap');
  });

  for (final (name, before, after) in [
    ('levelup', at(Rank.awakened, 3), at(Rank.awakened, 4)),
    ('rankup', at(Rank.awakened, 4), at(Rank.abyssSovereign, 35)),
    ('title', at(Rank.awakened, 4), at(Rank.awakened, 4, titles: {'arrays'})),
  ]) {
    testWidgets('system $name', (t) async {
      t.view.physicalSize = const Size(1170, 2532);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(onPressed: () => celebrate(context, before, after), child: const Text('go')),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('go'));
      await t.pump();
      await t.pump(const Duration(seconds: 3));
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('game/system_$name.png'));
    });
  }

  testWidgets('quiz', (t) async {
    final store = Store('u', db: FakeFirebaseFirestore());
    final p = Problem.solved(
      id: 'p',
      name: 'Two Sum',
      platform: 'LeetCode',
      difficulty: 'Easy',
      topic: 'Arrays',
      solvedOn: DateTime.utc(2026),
    );
    await t.runAsync(
      () => store.addProblem(
        p,
        solution: const Solution(time: 'O(n)', code: 'int n = nums.size();\nfor (int i = 0; i < n; i++) {\n  seen[nums[i]] = i;\n}'),
      ),
    );
    t.view.physicalSize = const Size(1170, 2532);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: appTheme(Brightness.light),
        home: QuizPage(store: store, problems: [p], level: 9),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await t.pump(const Duration(milliseconds: 200));
    }
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('game/quiz.png'));
  });

  testWidgets('overdrive tile', (t) async {
    await phone(
      t,
      const Scaffold(
        body: Padding(
          padding: EdgeInsets.only(top: 24),
          child: Column(
            children: [
              StatRow(
                children: [
                  StatTile(icon: Icons.local_fire_department_rounded, value: '2', label: 'Day streak', color: Accent.orange),
                  StatTile(icon: Icons.local_fire_department_rounded, value: '6/3', label: 'Overdrive +45', fire: true),
                  StatTile(icon: Icons.event_note_rounded, value: '0', label: 'Due now', color: Accent.red),
                ],
              ),
            ],
          ),
        ),
      ),
      'overdrive',
      size: const Size(1170, 600),
    );
  });

  testWidgets('gate journey', (t) async {
    final store = Store('u', db: FakeFirebaseFirestore());
    final covered = {...gateDa[0].topics.map((x) => x.id), ...gateDa[1].topics.take(3).map((x) => x.id)};
    await t.runAsync(() async {
      for (final id in covered) {
        await store.setGateCovered(id, covered: true);
      }
    });
    await phone(
      t,
      Scaffold(
        body: GateView(store: store, covered: covered),
      ),
      'gate',
      size: const Size(1170, 3000),
    );
    await phone(
      t,
      GateSectionPage(store: store, section: gateDa[1]),
      'gate_section',
      size: const Size(1170, 2532),
    );
    await phone(
      t,
      GateTopicPage(store: store, section: gateDa[1], topic: gateDa[1].topics[3]),
      'gate_topic',
      size: const Size(1170, 2532),
    );
  });

  testWidgets('party', (t) => phone(t, const GoalCelebration(streak: 5, solvedToday: 3), 'party'));

  testWidgets('leaderboard', (t) async {
    final board = Leaderboard(db: FakeFirebaseFirestore());
    await t.runAsync(() async {
      for (final (i, n) in ['Bilal', 'Asha', 'Chen', 'Divya', 'Emeka', 'Fatima'].indexed) {
        await board.publish(
          uid: n == 'Asha' ? 'me' : n,
          name: n,
          streak: [42, 30, 21, 14, 9, 5][i],
          solved: [120, 98, 77, 60, 41, 20][i],
          level: [52, 37, 21, 12, 6, 2][i],
          title: ['Conqueror of Paths', 'Sage of Memory', 'Lord of Echoes', 'Array Executioner', 'Pattern Reaper', null][i],
        );
      }
    });
    Prefs.leaderboard.value = true;
    t.view.physicalSize = const Size(1170, 2532);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: appTheme(Brightness.light),
        home: LeaderboardPage(uid: 'me', name: 'Asha', streak: 30, solved: 98, board: board),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await t.pump(const Duration(milliseconds: 500));
    }
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('game/leaderboard.png'));
  });
}
