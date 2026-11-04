import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import 'prefs.dart';

/// Short tones made for this app (generated, no third-party audio). Muted from Profile.
enum Sound { correct, wrong, levelUp, goal }

final _player = AudioPlayer()..setReleaseMode(ReleaseMode.stop);

void play(Sound s) {
  if (!Prefs.sounds.value) return;
  final file = switch (s) {
    Sound.correct => 'sounds/correct.wav',
    Sound.wrong => 'sounds/wrong.wav',
    Sound.levelUp => 'sounds/levelup.wav',
    Sound.goal => 'sounds/goal.wav',
  };
  unawaited(_player.play(AssetSource(file), volume: 0.6).catchError((Object _) {})); // never let a sound break the app
}
