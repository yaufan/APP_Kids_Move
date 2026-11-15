import 'package:animal_moves/core/adventures.dart';
import 'package:animal_moves/core/game.dart';
import 'package:animal_moves/core/moves.dart';
import 'package:animal_moves/core/providers.dart';
import 'package:animal_moves/features/parent/parent_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// A child (and a parent) going through the whole app on a phone and a
/// tablet: every mode (the five adventures, 動物舞會, 自己排, 慢慢伸展) at
/// every level, on its side (the 「小電視」 way) and upright, with
/// screenshots in `build/screenshots/<device>/`.
void main() {
  setUpAll(loadFonts);

  for (final MapEntry(key: device, value: (size, ratio)) in {'phone': phone, 'tablet': tablet}.entries) {
    final upright = size;
    final onSide = Size(size.height, size.width);

    testWidgets('a day of moving ($device)', (tester) async {
      final app = await TestApp.start(tester, game: const Game(), size: onSide, ratio: ratio, seed: 4);
      var n = 0;
      Future<void> shot(String name) async {
        await app.settle(300);
        await shoot(tester, device, '${(++n).toString().padLeft(2, '0')}_$name');
      }

      String phase() {
        for (final p in ['look', 'move', 'wait', 'breathe', 'end']) {
          for (var i = 0; i < 12; i++) {
            if (find.byKey(ValueKey('follow-$p-$i')).evaluate().isNotEmpty) return '$p-$i';
          }
        }
        return '';
      }

      // 「先看看四周」: every card read and ticked, then 準備好了！
      Future<void> spaceCheck({String? as}) async {
        expect(app.location, '/space');
        expect(app.voice.said.last, startsWith('動之前，先看看四周'));
        await app.play(11);
        expect(app.voice.said.last, '準備好了，就按「準備好了！」');
        expect(app.sounds.played.where((s) => s == 'tick').length, greaterThanOrEqualTo(5));
        if (as != null) await shot(as);
        await app.tapLabel('準備好了！', ms: 600);
      }

      // Goes through a go, tapping 「做好了！」 in each move after [watch]
      // seconds (null: the music runs out by itself), up to the end panel.
      Future<void> followThrough({double? watch = 4, String? shotMove, String? shotStretch}) async {
        var guard = 0;
        var shotTaken = false;
        while (!phase().startsWith('end') && guard++ < 40) {
          final p = phase();
          if (p.startsWith('look')) {
            await app.play(3.6);
            continue;
          }
          if (p.startsWith('move') || p.startsWith('wait')) {
            final stretch = find.byKey(const ValueKey('flower')).evaluate().isNotEmpty;
            if (stretch) {
              if (shotStretch != null) {
                await app.play(4.5);
                await shot(shotStretch);
              }
              await app.play(26);
              continue;
            }
            await app.play(watch ?? 5);
            if (shotMove != null && !shotTaken) {
              shotTaken = true;
              await shot(shotMove);
            }
            if (watch == null) {
              // The music runs out and the screen goes on by itself.
              var wait = 0;
              while (phase().startsWith('move') && wait++ < 60) {
                await app.play(1);
              }
              continue;
            }
            await app.tapLabel('做好了！', ms: 300);
            continue;
          }
          await app.play(3.3);
        }
        expect(phase(), startsWith('end'));
      }

      Future<void> untilPartyEnds() async {
        var wait = 0;
        while (find.byKey(const ValueKey('party-end')).evaluate().isEmpty && wait++ < 60) {
          await app.play(5);
        }
        expect(find.byKey(const ValueKey('party-end')), findsOneWidget);
        expect(app.voice.said.last, '謝謝你一起跳舞！大家鞠躬！');
      }

      Future<void> openAdventure(String a) async {
        expect(app.location, '/', reason: 'opening $a');
        for (var i = 0; i < 8 && find.byKey(ValueKey('adventure-$a')).evaluate().isEmpty; i++) {
          await tester.drag(find.byKey(const ValueKey('cards')), const Offset(-250, 0));
          await app.settle(300);
        }
        await tester.ensureVisible(find.byKey(ValueKey('adventure-$a')));
        await app.settle(300);
        await tester.tap(find.byKey(ValueKey('adventure-$a')));
        await app.settle(900);
      }

      // ---- the first time: the parent's two questions, the child's guide
      expect(app.location, '/hello');
      await shot('hello');
      await app.tapLabel('小小（2～3 歲）');
      await app.tapLabel('不用，可以跳');
      await app.tapLabel('下一步', ms: 800);
      expect(app.game.settings.level, Level.small);
      expect(app.game.settings.asked, isTrue);
      expect(app.location, '/guide');
      expect(app.voice.said.last, '選一隻動物，帶你去動一動！');
      await shot('guide');
      await app.tapLabel('小獼猴', ms: 2400);
      expect(app.voice.said, contains('吱吱！我是小獼猴，我們一起動一動！'));
      expect(app.location, '/');
      await shot('home');
      await app.turn(upright);
      await shot('home_upright');
      await app.turn(onSide);

      // ---- 小小, on its side: 叢林探險, one move to its end by the music.
      await app.tapLabel('叢林探險', ms: 900);
      await spaceCheck(as: 'space');
      expect(app.location, '/go/jungle');
      expect(app.screen.awake, isTrue, reason: 'the screen stays on while moving');
      expect(app.voice.said.last, '吱吱！換長頸鹿伸高高囉！手往上伸，高高的！');
      expect(app.sounds.played.last, 'giraffe');
      await shot('jungle_look');
      await app.play(3.6);
      expect(phase(), 'move-0');
      await app.play(5);
      await shot('jungle_move');
      // The music for the move runs out (whole bars at 100 a minute): on by itself.
      var waited = 0.0;
      while (phase() == 'move-0' && waited < 30) {
        await app.play(.5);
        waited += .5;
      }
      expect(waited, greaterThan(5), reason: 'the move goes on until its music runs out');
      expect(phase(), 'breathe-0');
      expect(app.voice.said.last, '謝謝你陪長頸鹿伸高高！呼——喘口氣。');
      await shot('jungle_breathe');
      while (phase() == 'breathe-0') {
        await app.play(.5);
      }
      expect(phase(), 'look-1');
      expect(app.voice.said.last, startsWith('吱吱！換青蛙跳囉！'));
      await app.play(3.6);
      expect(app.sounds.played, contains('boing'));
      await app.turn(upright);
      await shot('jungle_move_upright');
      await app.turn(onSide);
      await followThrough(shotStretch: 'jungle_stretch');
      expect(app.voice.said, contains('吸氣——'));
      expect(app.game.stamped('jungle', app.now), isTrue);
      await shot('jungle_end');
      await app.tapLabel('回首頁', ms: 900);
      expect(app.screen.awake, isFalse);
      await shot('home_stamp');

      // ---- 動物舞會 (小小): the music stops at the end of each phrase; keep still.
      await app.tapLabel('動物舞會', ms: 900);
      await spaceCheck();
      expect(app.location, '/party');
      await app.play(3);
      expect(find.byKey(const ValueKey('party-dance')), findsOneWidget);
      expect(app.sounds.music?.file, 'music_party');
      await shot('party');
      var wait = 0;
      while (find.byKey(const ValueKey('party-freeze')).evaluate().isEmpty && wait++ < 100) {
        await app.play(.5);
      }
      expect(find.byKey(const ValueKey('party-freeze')), findsOneWidget);
      expect(app.sounds.music, isNull, reason: 'the music really stops');
      expect(app.voice.said.last, '停！不動！');
      await shot('party_freeze');
      await untilPartyEnds();
      expect(app.voice.said.last, '謝謝你一起跳舞！大家鞠躬！');
      await app.tapLabel('回首頁', ms: 900);

      // ---- 慢慢伸展 (小小)
      await app.tapLabel('慢慢伸展', ms: 900);
      await spaceCheck();
      expect(app.location, '/calm');
      await followThrough(watch: null, shotMove: 'calm', shotStretch: 'calm_flower');
      expect(app.voice.said.last, '身體安靜下來了。');
      await app.tapLabel('回首頁', ms: 900);

      // ---- 自己排 (小小: up to four cards), then do it.
      await app.tapLabel('自己排', ms: 900);
      expect(app.location, '/build');
      await shot('build');
      await tester.tap(find.byKey(const ValueKey('card-frog')));
      await app.settle();
      expect(app.voice.said.last, '青蛙跳！');
      await tester.tap(find.byKey(const ValueKey('card-bear')));
      await app.settle();
      await app.tapLabel('開始！');
      expect(app.voice.said.last, '再選 1 張動物卡。');
      await app.tapLabel('隨便來一個');
      await app.tapLabel('隨便來一個');
      await app.tapLabel('隨便來一個');
      expect(app.container.read(draftProvider).length, 4);
      expect(app.voice.said.last, '排滿了！按「開始！」吧。');
      await app.tapLabel('存起來');
      expect(app.game.routines.single.first, 'frog');
      await shot('build_full');
      await app.tapLabel('開始！', ms: 900);
      await spaceCheck();
      expect(app.location, '/run');
      await followThrough(shotMove: 'run');
      await app.tapLabel('回首頁', ms: 900);

      // ---- 中, upright: the level from parent mode; 去動物園 and 台灣山林.
      await app.turn(upright);
      ParentPass.grant();
      app.go('/parent');
      await app.settle(800);
      await shot('parent_upright');
      await tester.tap(find.byKey(const ValueKey('level-mid')));
      await app.settle();
      expect(app.game.settings.level, Level.mid);
      app.go('/');
      await app.settle(800);
      for (final a in ['zoo', 'mountain']) {
        await openAdventure(a);
        await spaceCheck(as: a == 'zoo' ? 'space_upright' : null);
        expect(app.location, '/go/$a');
        expect(app.voice.said.last, contains(adventuresById[a]!.steps.first.story), reason: '中 tells the story');
        await followThrough(shotMove: '${a}_upright', shotStretch: a == 'zoo' ? 'zoo_stretch_upright' : null);
        expect(app.game.stamped(a, app.now), isTrue);
        await app.tapLabel('回首頁', ms: 900);
      }
      // 動物舞會 (中): stops on a bar line and becomes an animal.
      await app.tapLabel('動物舞會', ms: 900);
      await spaceCheck();
      await app.play(3);
      await shot('party_upright');
      var guard = 0;
      while (find.byKey(const ValueKey('party-freeze')).evaluate().isEmpty && guard++ < 200) {
        await app.play(.5);
      }
      expect(app.voice.said.last, startsWith('停！變成'));
      await shot('party_freeze_upright');
      await untilPartyEnds();
      await app.tapLabel('回首頁', ms: 900);
      // 慢慢伸展 and the saved routine (中).
      await app.tapLabel('慢慢伸展', ms: 900);
      await spaceCheck();
      await followThrough(watch: null, shotStretch: 'calm_upright');
      await app.tapLabel('回首頁', ms: 900);
      await app.tapLabel('自己排', ms: 900);
      await app.tapLabel('青蛙那一套');
      await shot('build_upright');
      await app.tapLabel('開始！', ms: 900);
      await spaceCheck();
      await followThrough();
      await app.tapLabel('回首頁', ms: 900);

      // ---- 大, on its side, quiet mode and a grown-up joining in: 海底世界, 下雨天.
      await app.turn(onSide);
      app.change((g) => g.withSettings(g.settings.copyWith(level: Level.big, quiet: true, together: true)));
      await app.settle();
      for (final a in ['sea', 'rain']) {
        await openAdventure(a);
        await spaceCheck();
        expect(app.voice.said.last, contains('和爸爸媽媽一起'));
        expect(app.voice.said.last, contains('，練'), reason: '大 says why');
        await followThrough(shotMove: '${a}_big');
        await app.tapLabel('回首頁', ms: 900);
      }
      expect(app.sounds.played, contains('boing_soft'), reason: 'quiet mode: the frog does not thump');
      expect(app.sounds.played.where((s) => s == 'boing' || s == 'stomp' || s == 'freeze'), isNotEmpty, reason: 'before quiet mode');
      final quietFrom = app.sounds.played.length;
      // 動物舞會 (大) with the grown-up as DJ: holding the stage stops the music.
      await app.tapLabel('動物舞會', ms: 900);
      await spaceCheck();
      await app.play(3);
      expect(find.text('大人按住這裡，音樂就停；放開，音樂再響。'), findsOneWidget);
      final g = await tester.startGesture(tester.getCenter(find.byType(Scaffold).last));
      await app.play(2);
      expect(find.byKey(const ValueKey('party-freeze')), findsOneWidget);
      expect(app.sounds.music, isNull);
      await shot('party_dj');
      await app.play(8);
      expect(find.byKey(const ValueKey('party-freeze')), findsOneWidget, reason: 'stays still while the grown-up holds');
      await g.up();
      await app.play(1);
      expect(find.byKey(const ValueKey('party-dance')), findsOneWidget);
      await untilPartyEnds();
      await app.tapLabel('回首頁', ms: 900);
      expect(app.sounds.played.skip(quietFrom).where((s) => softSounds.containsKey(s)), isEmpty, reason: 'only soft sounds in quiet mode');
      // 慢慢伸展 and 自己排 (大: eight cards).
      await app.tapLabel('慢慢伸展', ms: 900);
      await spaceCheck();
      await followThrough(watch: 30);
      await app.tapLabel('回首頁', ms: 900);
      await app.tapLabel('自己排', ms: 900);
      for (var i = 0; i < 8; i++) {
        await app.tapLabel('隨便來一個');
      }
      expect(app.container.read(draftProvider).length, 8);
      await shot('build_big');
      await app.tapLabel('開始！', ms: 900);
      await spaceCheck();
      await followThrough(watch: 2);
      await app.tapLabel('回首頁', ms: 900);

      // ---- Parent mode on its side: the week's minutes and what was trained.
      ParentPass.grant();
      app.go('/parent');
      await app.settle(800);
      expect(app.game.movedOn(Days.key(app.now)), greaterThan(300));
      await tester.scrollUntilVisible(find.byKey(const ValueKey('week')), 200, scrollable: find.byType(Scrollable).first);
      await shot('parent_week');
      await tester.scrollUntilVisible(find.byKey(const ValueKey('move-frog')), 300, scrollable: find.byType(Scrollable).first);
      await shot('parent_moves');
      app.go('/');
      await app.settle(2600);

      // ---- The play time is up: the animals sleep.
      app.now = app.now.add(const Duration(minutes: 16));
      await app.settle(2600);
      expect(app.location, '/rest');
      expect(app.voice.said.last, '換你去做了！關掉螢幕，去外面走一走、跳一跳吧！');
      await shot('rest');
      await app.turn(upright);
      await shot('rest_upright');
      await app.end();
    }, timeout: const Timeout(Duration(minutes: 20)));
  }
}
