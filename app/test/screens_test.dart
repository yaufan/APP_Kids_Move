import 'dart:async';

import 'package:animal_moves/app/strings.dart';
import 'package:animal_moves/app/widgets.dart';
import 'package:animal_moves/core/game.dart';
import 'package:animal_moves/core/moves.dart';
import 'package:animal_moves/core/providers.dart';
import 'package:animal_moves/core/sounds.dart';
import 'package:animal_moves/core/voice.dart';
import 'package:animal_moves/features/parent/parent_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// A voice that takes as long as the test says (a slow phone voice).
/// A music player that takes as long as the test says to start a tune.
class SlowLoop implements MusicLoop {
  final calls = <String>[];
  String? playing;
  Completer<void>? loading;

  @override
  Future<void> stop() async {
    calls.add('stop');
    playing = null;
  }

  @override
  Future<void> play(String file, double volume) async {
    calls.add('play $file');
    final c = loading = Completer<void>();
    await c.future;
    playing = file;
  }
}

class SlowVoice extends RecordingVoice {
  final pending = <Completer<void>>[];

  @override
  Future<void> say(String zh, {bool slow = false, double pitch = 1.15}) {
    super.say(zh, slow: slow, pitch: pitch);
    final c = Completer<void>();
    pending.add(c);
    return c.future;
  }
}

/// The lessons from the sibling apps' reviews (docs/design.md), on the
/// screens: play time, the voice between screens and between steps, the
/// first finger only, what a parent turned off, midnight, the sound
/// switches, finishing the move and the stretch before the rest.
void main() {
  testWidgets('time in parent mode is not the child\'s play time', (tester) async {
    final app = await TestApp.start(tester);
    app.now = app.now.add(const Duration(minutes: 10));
    await app.settle(2600);
    ParentPass.grant();
    app.go('/parent');
    await app.settle(2600);
    app.now = app.now.add(const Duration(minutes: 20));
    await app.settle(2600);
    expect(app.location, '/parent');
    app.go('/');
    await app.settle(2600);
    expect(app.location, '/', reason: 'the child has played 10 of the 15 minutes');
    app.now = app.now.add(const Duration(minutes: 6));
    await app.settle(2600);
    expect(app.location, '/rest');
    await app.end();
  });

  testWidgets('in the background the go pauses, and the minutes do not count', (tester) async {
    final app = await TestApp.start(tester);
    await app.goMoving('/go/jungle');
    await app.play(6);
    expect(app.phase(), 'move-0');
    expect(app.screen.awake, isTrue);
    for (final s in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
    await app.settle(400);
    final played = app.game.playedOn(Days.key(app.now)), moved = app.game.movedOn(Days.key(app.now));
    for (var i = 0; i < 4; i++) {
      await app.settle(30000);
    }
    for (final s in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
    await app.settle(2600);
    expect(find.text(Strings.paused), findsOneWidget, reason: 'it waits for the child');
    expect(app.screen.awake, isFalse, reason: 'paused: the screen may sleep');
    expect(app.game.playedOn(Days.key(app.now)) - played, lessThan(10), reason: 'two minutes away are not two minutes played');
    expect(app.game.movedOn(Days.key(app.now)) - moved, lessThan(10));
    await app.settle(30000);
    expect(app.game.movedOn(Days.key(app.now)) - moved, lessThan(10), reason: 'paused is not 「跟著動」');
    await app.tapLabel(Strings.goOn, ms: 600);
    expect(app.screen.awake, isTrue);
    await app.end();
  });

  testWidgets('leaving a screen stops its own voice, never the next screen\'s first line', (tester) async {
    final app = await TestApp.start(tester);
    await app.goMoving('/go/jungle');
    expect(app.voice.said.last, contains('吱吱！換長頸鹿伸高高囉！'));
    app.go('/');
    await app.settle(1200);
    expect(app.voice.said.last, '吱吱！今天想去哪裡動一動？');
    expect(app.voice.stops, 0, reason: 'the home screen\'s greeting is not cut off');
    ParentPass.grant();
    app.go('/parent');
    await app.settle(1200);
    expect(app.voice.stops, 1, reason: 'the greeting does not go on over parent mode');
    await app.end();
  });

  testWidgets('the next step waits until a slow line has been said, but not for ever', (tester) async {
    final line = Completer<void>();
    var ran = 0;
    Later(const Duration(milliseconds: 500), () => ran++, after: line.future);
    await tester.pump(const Duration(seconds: 2));
    expect(ran, 0, reason: 'still speaking');
    line.complete();
    await tester.pump();
    expect(ran, 1);

    Later(const Duration(milliseconds: 500), () => ran++, after: Completer<void>().future, atMost: const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 2));
    expect(ran, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(ran, 2, reason: 'a voice that never says it is done does not hold the game up');

    Later(const Duration(milliseconds: 500), () => ran++).cancel();
    await tester.pump(const Duration(seconds: 1));
    expect(ran, 2);
  });

  testWidgets('a move starts only once its announcement has been said', (tester) async {
    final voice = SlowVoice();
    final app = await TestApp.start(tester, voice: voice);
    await app.goMoving('/go/jungle');
    expect(voice.said.last, contains('吱吱！換長頸鹿伸高高囉！'));
    await app.play(6);
    expect(app.phase(), 'look-0', reason: 'the slow voice is still announcing the giraffe');
    voice.pending.last.complete();
    await app.play(.5);
    expect(app.phase(), 'move-0');
    await app.end();
  });

  testWidgets('only the first finger counts; a cancelled or sliding touch is not a tap', (tester) async {
    final app = await TestApp.start(tester);
    await app.goMoving('/go/jungle');
    await app.play(4);
    expect(app.phase(), 'move-0');
    final done = find.bySemanticsLabel(Strings.done).last;
    var g = await tester.startGesture(tester.getCenter(done));
    await app.settle(100);
    await g.cancel();
    await app.settle(300);
    expect(app.phase(), 'move-0', reason: 'a cancelled touch is not a tap');
    g = await tester.startGesture(tester.getCenter(done));
    await g.moveBy(const Offset(0, -80));
    await g.up();
    await app.settle(300);
    expect(app.phase(), 'move-0', reason: 'a finger that slid away is not a tap');
    final first = await tester.startGesture(tester.getCenter(done), pointer: 1);
    final second = await tester.startGesture(tester.getCenter(done) + const Offset(10, 0), pointer: 2);
    await second.up();
    await app.settle(300);
    expect(app.phase(), 'move-0', reason: 'the second finger does nothing');
    await first.up();
    await app.settle(300);
    expect(app.phase(), 'breathe-0');
    await app.end();
  });

  testWidgets('大人當 DJ: the first finger holds the music; another finger does nothing; a cancel lets go', (tester) async {
    final app = await TestApp.start(tester, game: ready.withSettings(const Settings(asked: true, together: true)));
    await app.goMoving('/party');
    await app.play(3);
    expect(find.byKey(const ValueKey('party-dance')), findsOneWidget);
    final stage = tester.getCenter(find.byType(Scaffold).last);
    final first = await tester.startGesture(stage, pointer: 1);
    await app.play(1);
    expect(find.byKey(const ValueKey('party-freeze')), findsOneWidget);
    expect(app.sounds.music, isNull);
    final second = await tester.startGesture(stage + const Offset(60, 0), pointer: 2);
    await second.up();
    await app.play(6);
    expect(find.byKey(const ValueKey('party-freeze')), findsOneWidget, reason: 'only the first finger counts');
    await first.cancel();
    await app.play(1);
    expect(find.byKey(const ValueKey('party-dance')), findsOneWidget, reason: 'the hold ended');
    expect(app.sounds.music?.file, 'music_party');
    await app.end();
  });

  testWidgets('moves a parent turned off never come back: not in the row, the cards, a saved routine or a go', (tester) async {
    final off = {'frog', for (final m in moves) if (m.jump) m.id};
    final app = await TestApp.start(tester, game: ready.withSettings(Settings(asked: true, off: off)).save(['frog', 'bunny', 'monkey', 'bear']));
    app.container.read(draftProvider.notifier).set(['frog', 'bear', 'monkey']);
    app.go('/build');
    await app.settle(800);
    expect(app.container.read(draftProvider), ['bear', 'monkey']);
    expect(find.byKey(const ValueKey('card-frog')), findsNothing);
    expect(find.byKey(const ValueKey('card-bunny')), findsNothing);
    await app.tapLabel('青蛙那一套');
    expect(app.container.read(draftProvider), ['bear', 'monkey']);
    for (var i = 0; i < 6; i++) {
      await app.tapLabel(Strings.random);
    }
    expect(app.container.read(draftProvider).where(off.contains), isEmpty);
    app.go('/');
    await app.settle();
    await app.goMoving('/go/jungle');
    final names = <String>{};
    var guard = 0;
    while (!app.phase().startsWith('end') && guard++ < 40) {
      final name = find.byKey(const ValueKey('move-name')).evaluate().map((e) => (e.widget as Text).data!).firstOrNull;
      if (name != null) names.add(name);
      await app.tapLabel(Strings.done, ms: 300);
      await app.play(3.5);
    }
    expect(names.intersection({for (final id in off) movesById[id]!.zh}), isEmpty);
    expect(names, isNot(contains('青蛙跳')));
    await app.end();
  });

  testWidgets('midnight: the 「去過了」 stamp of yesterday is gone from today\'s card', (tester) async {
    final app = await TestApp.start(tester);
    app.now = DateTime(2026, 11, 15, 23, 59);
    app.change((g) => g.stamp('jungle', app.now));
    app.go('/build');
    await app.settle();
    app.go('/');
    await app.settle();
    expect(find.text(Strings.been), findsOneWidget);
    app.now = DateTime(2026, 11, 16, 0, 1);
    app.container.read(sessionStartProvider.notifier).restart();
    app.go('/build');
    await app.settle();
    app.go('/');
    await app.settle();
    expect(find.text(Strings.been), findsNothing);
    await app.end();
  });

  testWidgets('each sound switch silences only its own sound', (tester) async {
    final app = await TestApp.start(tester);
    expect(app.sounds.music?.file, 'music_home');
    app.change((g) => g.withSettings(g.settings.copyWith(music: false)));
    await app.settle();
    expect(app.sounds.music, isNull);
    await app.goMoving('/go/jungle');
    expect(app.sounds.played.last, 'giraffe', reason: 'effects still on');
    expect(app.voice.said.last, contains('吱吱！換長頸鹿'), reason: 'the voice still on');
    app.change((g) => g.withSettings(g.settings.copyWith(music: true, sounds: false)));
    await app.settle();
    final played = app.sounds.played.length;
    await app.play(6);
    expect(app.sounds.played.length, played, reason: 'effects off');
    expect(app.sounds.music?.file, 'music_jungle', reason: 'the music back on');
    app.change((g) => g.withSettings(g.settings.copyWith(sounds: true, voice: false)));
    await app.settle();
    final said = app.voice.said.length;
    await app.tapLabel(Strings.done, ms: 300);
    await app.play(4);
    expect(app.voice.said.length, said, reason: 'the voice off');
    expect(app.sounds.played.length, greaterThan(played), reason: 'effects back on');
    await app.end();
  });

  testWidgets('「做好了」才往下: when the music ends the animal keeps going until the tap', (tester) async {
    final app = await TestApp.start(tester, game: ready.withSettings(const Settings(asked: true, level: Level.small, mustTap: true)));
    await app.goMoving('/go/jungle');
    await app.play(3.6);
    expect(app.phase(), 'move-0');
    await app.play(moveBeats100Small + 2);
    expect(app.phase(), 'wait-0');
    expect(app.voice.said.last, Strings.tapWhenDone);
    await app.play(30);
    expect(app.phase(), 'wait-0');
    await app.tapLabel(Strings.done, ms: 300);
    expect(app.phase(), 'breathe-0');
    await app.end();
  });

  testWidgets('time up in the middle of an adventure: the move ends, the stretch, then the rest', (tester) async {
    final app = await TestApp.start(tester);
    await app.goMoving('/go/jungle');
    await app.play(3.6);
    await app.tapLabel(Strings.done, ms: 300);
    await app.play(7);
    expect(app.phase(), 'move-1');
    app.now = app.now.add(const Duration(minutes: 16));
    await app.play(4);
    expect(app.location, '/go/jungle', reason: 'not in the middle of a move');
    expect(app.container.read(windDownProvider), isTrue);
    expect(app.phase(), 'move-1');
    await app.tapLabel(Strings.done, ms: 300);
    await app.play(3.5);
    final last = app.phase();
    expect(last, startsWith('look-'));
    expect(app.voice.said.last, startsWith(Strings.stretchNow), reason: 'straight to the slow stretch');
    await app.play(3.6 + 26);
    expect(app.phase(), startsWith('end'));
    expect(app.screen.awake, isFalse);
    await app.play(7);
    expect(app.location, '/rest');
    expect(app.game.resting(app.now), isTrue);
    await app.end();
  });

  testWidgets('慢慢伸展 is not cut short by the rest', (tester) async {
    final app = await TestApp.start(tester);
    await app.goMoving('/calm');
    await app.play(5);
    app.now = app.now.add(const Duration(minutes: 16));
    await app.play(30);
    expect(app.location, '/calm');
    var guard = 0;
    while (!app.phase().startsWith('end') && guard++ < 120) {
      await app.play(1);
    }
    expect(app.voice.said.last, Strings.calmDone);
    await app.play(7);
    expect(app.location, '/rest');
    await app.end();
  });

  // ---------------------------------------------------------------- the code review

  testWidgets('quiet mode: the child showing 「像這樣」 keeps the feet down, the deer walks, the story asks for no jump', (tester) async {
    final app = await TestApp.start(tester, game: ready.withSettings(const Settings(asked: true, level: Level.big, quiet: true)));
    Finder art(String path) => find.byWidgetPredicate((w) => w is Art && w.path == path);
    await app.goMoving('/go/mountain');
    for (var i = 0; i < 2; i++) {
      await app.play(3.6);
      expect(app.phase(), 'move-$i');
      await app.tapLabel(Strings.done, ms: 300);
      await app.play(3.5);
    }
    expect(app.phase(), 'look-2');
    expect(app.voice.said.last, startsWith('梅花鹿大步走過小溪！'));
    await app.play(3.6);
    expect(app.phase(), 'move-2');
    expect(art('kids/deer-quiet_b'), findsOneWidget);
    expect(art('kids/deer_b'), findsNothing, reason: 'that child is in the air');
    expect(art('moves/deer-quiet_b'), findsOneWidget);
    expect(art('moves/deer_b'), findsNothing, reason: 'that deer is leaping');
    expect(app.sounds.played.where((s) => softSounds.containsKey(s)), isEmpty);
    await app.end();
  });

  testWidgets('「做好了！」 tapped twice, or just as the music runs out, moves on only once', (tester) async {
    final app = await TestApp.start(tester, game: ready.withSettings(const Settings(asked: true, level: Level.small)));
    await app.goMoving('/go/jungle');
    await app.play(4);
    expect(app.phase(), 'move-0');
    final done = find.bySemanticsLabel(Strings.done).last;
    await tester.tap(done, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.tap(done, warnIfMissed: false);
    await app.settle(300);
    expect(app.phase(), 'breathe-0', reason: 'a quick second tap does not skip the breather');
    await app.play(1);
    await tester.tap(find.bySemanticsLabel(Strings.done).last, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 150));
    expect(app.phase(), 'look-1', reason: 'a tap in the breather goes on to the next animal');
    await tester.tap(find.bySemanticsLabel(Strings.done).last, warnIfMissed: false);
    await app.settle(300);
    expect(app.phase(), 'look-1', reason: 'and a quick second tap does not skip that animal too');
    await app.play(3.6);
    expect(app.phase(), 'move-1');
    var guard = 0;
    while (app.phase() == 'move-1' && guard++ < 400) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(app.phase(), 'breathe-1', reason: 'the music ran out');
    await tester.tap(find.bySemanticsLabel(Strings.done).last, warnIfMissed: false);
    await app.settle(300);
    expect(app.phase(), 'breathe-1', reason: 'tapped as the music ran out: the same 「做好了」');
    await app.play(1);
    await tester.tap(find.bySemanticsLabel(Strings.done).last, warnIfMissed: false);
    await app.settle(300);
    expect(app.phase(), 'look-2', reason: 'a tap a moment later skips the rest of the breather');
    await app.end();
  });

  testWidgets('time up while waiting for 「做好了！」: on to the stretch, no 「再一次」, then the rest', (tester) async {
    final app = await TestApp.start(tester, game: ready.withSettings(const Settings(asked: true, level: Level.small, mustTap: true)));
    await app.goMoving('/go/jungle');
    await app.play(3.6);
    await app.play(moveBeats100Small + 2);
    expect(app.phase(), 'wait-0');
    app.now = app.now.add(const Duration(minutes: 16));
    await app.play(4);
    expect(app.container.read(windDownProvider), isTrue);
    expect(app.phase(), isNot('wait-0'), reason: 'the move\'s music is over and the time is up');
    var guard = 0;
    while (app.phase() != 'move-5' && guard++ < 40) {
      await app.play(.5);
    }
    expect(app.phase(), 'move-5', reason: 'straight on to the slow stretch');
    expect(app.voice.said, contains(startsWith(Strings.stretchNow)));
    final again = tester.widget<RoundButton>(find.byWidgetPredicate((w) => w is RoundButton && w.label == Strings.again));
    expect(again.onTap, isNull, reason: '「再一次」 would never end');
    await app.play(26);
    expect(app.phase(), startsWith('end'));
    await app.play(7);
    expect(app.location, '/rest');
    await app.end();
  });

  testWidgets('time up while the 「謝謝你陪我們！」 panel is up: the rest comes anyway', (tester) async {
    final app = await TestApp.start(tester);
    await app.goMoving('/calm');
    var guard = 0;
    while (!app.phase().startsWith('end') && guard++ < 30) {
      await app.play(3.6);
      if (app.phase().startsWith('move')) await app.tapLabel(Strings.done, ms: 300);
    }
    expect(app.phase(), startsWith('end'));
    await app.play(10);
    expect(app.location, '/calm', reason: 'the panel waits for 「回首頁」');
    app.now = app.now.add(const Duration(minutes: 16));
    await app.play(9);
    expect(app.location, '/rest');
    await app.end();
  });

  testWidgets('time up: going round again and again (pause, go on) still ends in the rest', (tester) async {
    final app = await TestApp.start(tester, game: ready.withSettings(const Settings(asked: true, level: Level.big)));
    await app.goMoving('/go/jungle');
    await app.play(3.6);
    app.now = app.now.add(const Duration(minutes: 16));
    await app.play(3);
    expect(app.container.read(windDownProvider), isTrue);
    var rounds = 0;
    while (app.location == '/go/jungle' && rounds++ < 40) {
      await app.tapLabel(Strings.pause, ms: 200);
      await app.tapLabel(Strings.goOn, ms: 200);
      await app.play(8);
      expect(app.phase(), anyOf('move-0', ''), reason: 'the move starts again each time');
    }
    expect(app.location, '/rest');
    expect(rounds, greaterThan(15), reason: 'not before the move and the stretch could have been done');
    expect(app.screen.awake, isFalse);
    await app.end();
  });

  testWidgets('a few minutes with the app in the background are not play time', (tester) async {
    final app = await TestApp.start(tester);
    app.now = app.now.add(const Duration(minutes: 10));
    await app.settle(2600);
    for (final s in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
    app.now = app.now.add(const Duration(minutes: 8));
    await app.settle(2600);
    for (final s in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
    await app.settle(2600);
    expect(app.location, '/', reason: '10 of the 15 minutes played');
    app.now = app.now.add(const Duration(minutes: 6));
    await app.settle(2600);
    expect(app.location, '/rest');
    await app.end();
  });

  testWidgets('a phone clock moved back gives no extra play time', (tester) async {
    final app = await TestApp.start(tester);
    app.now = app.now.add(const Duration(minutes: 10));
    await app.settle(2600);
    app.now = app.now.subtract(const Duration(hours: 2));
    await app.settle(2600);
    expect(app.location, '/');
    app.now = app.now.add(const Duration(minutes: 6));
    await app.settle(2600);
    expect(app.location, '/rest', reason: '10 + 6 minutes played');
    await app.end();
  });

  testWidgets('parent mode is not play time from the moment it opens, not from the next check', (tester) async {
    final app = await TestApp.start(tester);
    app.now = app.now.add(const Duration(minutes: 10));
    await app.settle(2600);
    ParentPass.grant();
    app.go('/parent');
    await tester.pump();
    // The parent's time, before the guard looks again (in real life, the
    // seconds before its next check).
    app.now = app.now.add(const Duration(minutes: 20));
    await app.settle(2600);
    app.go('/');
    await tester.pump();
    app.now = app.now.add(const Duration(minutes: 2));
    await app.settle(2600);
    expect(app.location, '/', reason: '12 of the 15 minutes played');
    app.now = app.now.add(const Duration(minutes: 4));
    await app.settle(2600);
    expect(app.location, '/rest');
    await app.end();
  });

  testWidgets('動物舞會: an animal whose move a parent turned off does not dance', (tester) async {
    final app = await TestApp.start(tester, game: ready.withSettings(const Settings(asked: true, off: {'frog'})));
    await app.goMoving('/party');
    await app.play(3);
    expect(find.byKey(const ValueKey('party-dance')), findsOneWidget);
    expect(find.byKey(const ValueKey('dancer-frog')), findsNothing);
    expect(find.byKey(const ValueKey('dancer-penguin')), findsOneWidget);
    expect(find.byKey(const ValueKey('dancer-giraffe')), findsOneWidget, reason: 'another steps in');
    await app.end();
  });

  testWidgets('every move turned off: an adventure is the breathing flower, the party just keeps still, 自己排 offers nothing', (tester) async {
    final app = await TestApp.start(tester, game: ready.withSettings(Settings(asked: true, level: Level.mid, off: {for (final m in moves) m.id})));
    await app.goMoving('/go/jungle');
    var guard = 0;
    while (!app.phase().startsWith('end') && guard++ < 20) {
      await app.play(2);
    }
    expect(app.phase(), 'end-0', reason: 'only the flower, then 「謝謝你陪我們！」');
    expect(app.voice.said, contains(startsWith(Strings.stretchNow)));
    await app.tapLabel(Strings.home, ms: 900);
    await app.goMoving('/party');
    guard = 0;
    while (find.byKey(const ValueKey('party-freeze')).evaluate().isEmpty && guard++ < 80) {
      await app.play(.5);
    }
    expect(app.voice.said.last, '${Strings.stop}${Strings.freeze}', reason: 'no animal to become: just keep still');
    expect(find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('dancer-')), findsNothing);
    await app.tapLabel(Strings.pause, ms: 200);
    await app.tapLabel(Strings.home, ms: 900);
    app.go('/build');
    await app.settle(800);
    await app.tapLabel(Strings.random);
    expect(app.container.read(draftProvider), isEmpty);
    await app.tapLabel(Strings.start);
    expect(app.location, '/build');
    expect(tester.takeException(), isNull);
    await app.end();
  });

  testWidgets('the music never starts after it was stopped (a quick 「停！」 while it is still loading)', (tester) async {
    final loop = SlowLoop();
    final sounds = SystemSounds(loop: loop);
    final owner = Object();
    sounds.hold(owner, Music.party);
    await tester.pump();
    expect(loop.calls, ['stop', 'play music_party']);
    sounds.hold(owner, null);
    await tester.pump();
    loop.loading!.complete();
    await tester.pump();
    expect(loop.playing, isNull, reason: 'stopped after the start, not before it');
    expect(loop.calls.last, 'stop');
    sounds.hold(owner, Music.party);
    await tester.pump();
    loop.loading!.complete();
    await tester.pump();
    expect(loop.playing, 'music_party');
    sounds.dispose();
  });
}

/// The seconds of a 小小 move to 叢林探險's music (8 bars at 100 a minute).
const moveBeats100Small = 32 * .6;
