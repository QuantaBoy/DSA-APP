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
import 'package:memory_stack/screens/roadmap_page.dart';

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
        const Scaffold(
          body: Column(children: [SizedBox(height: 16), PowerStrip()]),
        ),
        'strip_${rank.index}_${rank.name}',
        size: const Size(1290, 640),
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
