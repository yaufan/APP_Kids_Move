import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'game.dart';
import 'screen.dart';
import 'sounds.dart';
import 'store.dart';
import 'voice.dart';

/// What time it is (tests and screenshots set it): the play-time limit, the
/// day's stamps and parent mode's minutes use it.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Dice (tests give a seeded one).
final randomProvider = Provider<math.Random>((ref) => math.Random());

final storeProvider = Provider<GameStore>((ref) => MemoryStore());
final savedGameProvider = Provider<Game>((ref) => const Game());
final soundsProvider = Provider<Sounds>((ref) => const SilentSounds());
final voiceProvider = Provider<Voice>((ref) => const SilentVoice());
final screenProvider = Provider<ScreenControl>((ref) => RecordingScreen());

/// Who keeps the screen on (shared by the screens that do).
final awakeProvider = Provider<ScreenAwake>((ref) => ScreenAwake(ref.read(screenProvider)));

/// The game; every change is saved straight away.
final gameProvider = NotifierProvider<GameNotifier, Game>(GameNotifier.new);

class GameNotifier extends Notifier<Game> {
  @override
  Game build() => ref.read(savedGameProvider);

  void change(Game Function(Game g) f) {
    final next = f(state);
    if (identical(next, state)) return;
    state = next;
    ref.read(storeProvider).write(next.toJson());
  }

  void settings(Settings Function(Settings s) f) => change((g) => g.withSettings(f(g.settings)));
}

/// When this sitting started (reset when a parent lets play go on). The app
/// closed and opened again within ten minutes goes on with the sitting it
/// saved ([Sitting]).
final sessionStartProvider = NotifierProvider<SessionStart, DateTime>(SessionStart.new);

class SessionStart extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = ref.read(clockProvider)();
    return ref.read(gameProvider).sitting?.startAt(now) ?? now;
  }

  void restart() => state = ref.read(clockProvider)();

  /// Time [d] a parent spent in parent mode is not the child's: the sitting
  /// starts that much later (never later than now).
  void pause(Duration d) {
    if (d.isNegative) return;
    final now = ref.read(clockProvider)(), later = state.add(d);
    state = later.isAfter(now) ? now : later;
  }

  /// The phone's clock was moved back by [d]: the sitting moves back with
  /// it, so the minutes already played still count.
  void back(Duration d) {
    if (d > Duration.zero) state = state.subtract(d);
  }
}

/// A simple on/off flag that screens and the play-time keeper share.
class Flag extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool on) => state = on;
}

/// The play time is up while a child is in the middle of moving: the screen
/// finishes the move it is on and the slow stretch, then rests
/// (docs/design.md 「休息」).
final windDownProvider = NotifierProvider<Flag, bool>(Flag.new);

/// 「先看看四周」 was gone through for the go about to start.
final spaceOkProvider = NotifierProvider<Flag, bool>(Flag.new);

/// The moving screen is paused (its time is not 「跟著動」).
final pausedProvider = NotifierProvider<Flag, bool>(Flag.new);

/// The 自己排 row being made (move ids).
final draftProvider = NotifierProvider<Draft, List<String>>(Draft.new);

class Draft extends Notifier<List<String>> {
  @override
  List<String> build() => const [];

  void set(List<String> ids) => state = List.unmodifiable(ids);
}

/// Things said only once per app start.
final onceProvider = Provider<Set<String>>((ref) => <String>{});
