import 'dart:io';
import 'dart:math' as math;

import 'package:animal_moves/core/adventures.dart';
import 'package:animal_moves/core/game.dart';
import 'package:animal_moves/core/guides.dart';
import 'package:animal_moves/core/moves.dart';
import 'package:animal_moves/core/session.dart';
import 'package:animal_moves/core/sounds.dart';
import 'package:flutter_test/flutter_test.dart';

/// The rules in plain Dart (docs/design.md): the moves, the adventures and
/// what replaces a move a parent turned off, 動物舞會's stops, 自己排, saving.
void main() {
  group('the moves', () {
    test('29 moves, each with a how for every level, invitations and its own sounds', () {
      expect(moves.length, 29);
      expect(movesById.length, 29, reason: 'ids are unique');
      for (final m in moves) {
        expect(m.how.length, 3, reason: m.id);
        expect(m.how.every((h) => h.isNotEmpty), isTrue, reason: m.id);
        expect(m.invites, isNotEmpty, reason: m.id);
        expect(m.skills, isNotEmpty, reason: m.id);
        expect(m.caution, isNotEmpty, reason: m.id);
        expect(m.call, isNotEmpty);
        expect(m.beat, isNotEmpty);
      }
      expect({for (final m in moves) if (m.stretch) m.id}, stretches.toSet());
      expect([for (final m in moves) if (m.jump) m.id], containsAll(['frog', 'bunny', 'kangaroo']));
      expect(moves.where((m) => m.jump).every((m) => m.quiet != null), isTrue, reason: 'every jump has a quiet version');
      expect({for (final m in moves) m.kind}, Kind.values.toSet(), reason: 'stability, locomotor and the pretend picking-up');
    });

    test('the app never says a move was done well (it cannot see the child)', () {
      const judging = ['做對', '答對', '標準', '跳得好', '做得好', '好厲害', '好棒', '分數', '失敗', '錯了', '不對喔，再'];
      final texts = <String>[
        for (final m in moves) ...[...m.how, ...m.invites, ...?m.quietInvites, ?m.quiet],
        for (final a in adventures) ...[a.story, for (final s in a.steps) s.story],
        for (final g in Guide.values) ...[g.hello, g.cheer],
      ];
      for (final t in texts) {
        for (final w in judging) {
          expect(t.contains(w), isFalse, reason: '「$t」 says $w');
        }
      }
      // The parent gate's 「不對喔，換一題」 is about the grown-up's sum, not a move.
      final strings = File('lib/app/strings.dart').readAsStringSync().replaceAll('不對喔，換一題。', '');
      for (final w in judging) {
        expect(strings.contains(w), isFalse, reason: 'strings.dart says $w');
      }
    });

    test('quiet mode swaps every thumping sound for a soft one', () {
      expect(soundFor('boing', quiet: true), 'boing_soft');
      expect(soundFor('boing', quiet: false), 'boing');
      expect(soundFor('count', quiet: true), 'count');
      for (final m in moves.where((m) => m.jump)) {
        expect(m.motionFor(quietMode: true), isNot(Motion.hop), reason: '${m.id} does not leap in quiet mode');
      }
      expect(movesById['frog']!.howFor(Level.big, quietMode: true), '蹲下來，站起來，呱！');
    });
  });

  group('the adventures', () {
    test('five adventures, each step a known move, from 5 moves (小小) to 7 or 8 (大), ending with a stretch', () {
      expect(adventures.length, 5);
      for (final a in adventures) {
        for (final s in a.steps) {
          expect(movesById.containsKey(s.move), isTrue, reason: '${a.id} ${s.move}');
          final species = s.species;
          if (species != null) expect(alsoDoneBy[s.move], contains(species));
        }
        expect(movesById[a.stretch]!.stretch, isTrue);
        final counts = [for (final l in Level.values) adventurePlan(a, Settings(level: l)).steps.length - 1];
        expect(counts[0], 5, reason: a.id);
        expect(counts[1], inInclusiveRange(6, 7), reason: a.id);
        expect(counts[2], inInclusiveRange(7, 8), reason: a.id);
        for (final l in Level.values) {
          final p = adventurePlan(a, Settings(level: l));
          expect(p.steps.last.stretch, isTrue);
          expect(p.steps.where((s) => s.stretch).length, 1);
        }
      }
      expect(adventures.where((a) => a.free).map((a) => a.id), ['jungle', 'zoo']);
    });

    test('a move a parent turned off never comes back: a spare that is on stands in, or it is left out', () {
      final off = {'frog', 'bear', 'snake', 'giraffe', 'monkey'};
      for (final a in adventures) {
        for (final l in Level.values) {
          final p = adventurePlan(a, Settings(level: l, off: off));
          expect(p.steps.map((s) => s.move.id).toSet().intersection(off), isEmpty, reason: '${a.id} ${l.name}');
          expect(p.steps.length, adventurePlan(a, Settings(level: l)).steps.length, reason: 'spares stand in');
        }
      }
      final allJumps = {for (final m in moves) if (m.jump) m.id};
      final p = adventurePlan(adventuresById['jungle']!, Settings(level: Level.big, off: allJumps));
      expect(p.steps.any((s) => s.move.jump), isFalse);
    });

    test('a spare does not bring the story of the move it stands in for (「跳過荷葉！」, 「爬過山洞！」)', () {
      final off = {for (final m in moves) if (m.jump || m.floor) m.id};
      for (final a in adventures) {
        final p = adventurePlan(a, Settings(level: Level.big, off: off));
        for (final s in p.steps) {
          expect(s.story == null || !RegExp('[跳跨爬鑽]').hasMatch(s.story!), isTrue, reason: '${a.id}: ${s.story} for ${s.move.id}');
        }
      }
    });

    test('quiet mode: the stories do not ask for a jump either', () {
      for (final a in adventures) {
        final p = adventurePlan(a, const Settings(level: Level.big, quiet: true));
        for (final s in p.steps.where((s) => s.move.jump)) {
          expect(s.story, isNot(matches('[跳跨]')), reason: '${a.id} ${s.move.id}');
        }
        final loud = adventurePlan(a, const Settings(level: Level.big));
        expect([for (final s in loud.steps) s.story], contains(a.steps.first.story), reason: 'the story itself is kept when not quiet');
      }
    });

    test('a small space only has moves done on the spot', () {
      for (final a in adventures) {
        final p = adventurePlan(a, const Settings(level: Level.big, smallSpace: true));
        expect(p.steps.where((s) => s.move.travels), isEmpty, reason: a.id);
      }
    });

    test('with every stretch turned off, a go ends with the breathing flower', () {
      final p = adventurePlan(adventuresById['sea']!, Settings(off: stretches.toSet()));
      expect(p.steps.last.move, breathe);
      expect(stretchFor('tortoise', Settings(off: {'tortoise'}))!.id, 'catarch');
    });

    test('a move lasts whole bars of its music, near the level\'s seconds', () {
      for (final m in Music.values) {
        for (final l in Level.values) {
          final beats = moveBeats(l, m.bpm);
          expect(beats % 4, 0);
          final seconds = beats * 60 / m.bpm;
          expect((seconds - l.moveSeconds).abs(), lessThanOrEqualTo(4 * 60 / m.bpm), reason: '${m.name} ${l.name}');
        }
      }
      expect(moveBeats(Level.small, 100), lessThan(moveBeats(Level.big, 100)));
    });
  });

  group('自己排 and 慢慢伸展', () {
    test('a routine leaves out cards turned off since, and ends with a stretch', () {
      final p = routinePlan(['frog', 'bear', 'monkey'], Settings(off: {'bear'}));
      expect(p.steps.map((s) => s.move.id), ['frog', 'monkey', 'tortoise']);
    });

    test('the cards and 「隨便來一個」 only offer moves that are on, never the stretches', () {
      final s = Settings(off: {'frog', 'bunny'});
      final cards = buildCards(s);
      expect(cards.map((m) => m.id), isNot(contains('frog')));
      expect(cards.where((m) => m.stretch), isEmpty);
      final r = math.Random(1);
      final row = <String>[];
      for (var i = 0; i < 40; i++) {
        final m = randomCard(s, row, r)!;
        expect(s.allows(m), isTrue);
        expect(m.stretch, isFalse);
        if (i < cards.length) {
          expect(row, isNot(contains(m.id)), reason: 'a new card while there are new ones');
          row.add(m.id);
        }
      }
      expect(randomCard(Settings(off: {for (final m in moves) m.id}), const [], r), isNull);
    });

    test('慢慢伸展 alone: two stretches that are on, then the flower', () {
      final p = calmPlan(Settings(off: {'tortoise'}), DateTime(2026, 11, 15));
      expect(p.steps.length, 3);
      expect(p.steps.take(2).every((s) => s.move.stretch && s.move.id != 'tortoise'), isTrue);
      expect(p.steps.last.move, breathe);
      expect(calmPlan(Settings(off: stretches.toSet()), DateTime(2026, 11, 15)).steps.single.move, breathe);
    });
  });

  group('動物舞會', () {
    test('小小 stops at the end of each phrase and only keeps still', () {
      final f = partyPlan(const Settings(level: Level.small), math.Random(1));
      expect(f, isNotEmpty);
      expect(f.every((x) => x.atBeat % 32 == 0 && x.pose == null && x.seconds == 3), isTrue);
    });

    test('中 and 大 become animals a parent left on; 大 counts to five on any beat; nobody is ever out', () {
      for (final seed in [1, 2, 3, 4, 5]) {
        final mid = partyPlan(Settings(level: Level.mid, off: {'flamingo', 'giraffe'}), math.Random(seed));
        expect(mid.every((x) => x.atBeat % 8 == 0 && x.pose != null && x.pose!.id != 'flamingo' && x.pose!.id != 'giraffe'), isTrue);
        final big = partyPlan(const Settings(level: Level.big), math.Random(seed));
        expect(big.every((x) => x.seconds == 5 && x.atBeat < partyBeats), isTrue);
        for (var i = 1; i < big.length; i++) {
          expect(big[i].atBeat - big[i - 1].atBeat, greaterThanOrEqualTo(14));
        }
      }
      final none = partyPlan(Settings(level: Level.big, off: freezePoses.toSet()), math.Random(1));
      expect(none.every((x) => x.pose == null), isTrue, reason: 'all poses off: just keep still');
    });

    test('the dancers are animals a parent left on (four, fewer, or none)', () {
      expect(partyDancers(const Settings()), dancers);
      final jumpsOff = Settings(off: {for (final m in moves) if (m.jump) m.id});
      expect(partyDancers(jumpsOff), hasLength(4));
      expect(partyDancers(jumpsOff).where(jumpsOff.off.contains), isEmpty);
      expect(partyDancers(Settings(off: {for (final m in moves) m.id})), isEmpty);
    });
  });

  group('settings and saving', () {
    test('settings come back as they were; unknown moves and bad minutes are dropped', () {
      final s = Settings(level: Level.big, minutes: 20, quiet: true, asked: true, smallSpace: true, checkDaily: true, mustTap: true, together: true, off: {'frog'}, music: false, sounds: false, voice: false, slow: true, full: false);
      final back = Settings.fromJson(s.toJson());
      expect(back.toJson(), s.toJson());
      final odd = Settings.fromJson({'minutes': 7, 'off': ['frog', 'dragon', 3], 'level': 'huge'});
      expect(odd.minutes, 15);
      expect(odd.off, {'frog'});
      expect(odd.level, Level.mid);
      expect(Settings(off: {'nope'}).copyWith(off: {'nope', 'bear'}).off, {'bear'});
    });

    test('a game comes back as it was; broken parts are left out', () {
      final now = DateTime(2026, 11, 15, 10);
      final g = const Game(guide: Guide.bear).stamp('zoo', now).followed(now, 90).playedFor(now, 120).did('frog').did('bear').save(['frog', 'bear']).checked(now).rest(now);
      final back = Game.fromJson(g.toJson());
      expect(back.toJson(), g.toJson());
      final odd = Game.fromJson({
        'guide': 'dragon',
        'stamps': {'zoo': 'yesterday', 'moon': '2026-11-15'},
        'moved': {'2026-11-15': -5, 'x': 3},
        'recent': ['frog', 7, 'unicorn'],
        'routines': [['frog', 'nope'], [], 'x'],
        'settings': 'broken',
      });
      expect(odd.guide, isNull);
      expect(odd.stamps, isEmpty);
      expect(odd.moved, isEmpty);
      expect(odd.recent, ['frog']);
      expect(odd.routines, [['frog']]);
      expect(Game.fromJson(null).settings.minutes, 15);
    });

    test('the 「去過了」 stamp is for today only: past midnight the card is fresh', () {
      final night = DateTime(2026, 11, 15, 23, 59);
      final g = const Game().stamp('jungle', night);
      expect(g.stamped('jungle', night), isTrue);
      expect(g.stamped('jungle', DateTime(2026, 11, 16, 0, 1)), isFalse);
    });

    test('minutes go to the day they were followed; two weeks are kept', () {
      var g = const Game();
      g = g.followed(DateTime(2026, 11, 15, 23, 59), 60).followed(DateTime(2026, 11, 16, 0, 0, 30), 30);
      expect(g.movedOn('2026-11-15'), 60);
      expect(g.movedOn('2026-11-16'), 30);
      g = g.followed(DateTime(2026, 12, 10), 10);
      expect(g.moved.keys, ['2026-12-10']);
      expect(Days.week(DateTime(2026, 11, 3)), ['2026-10-28', '2026-10-29', '2026-10-30', '2026-10-31', '2026-11-01', '2026-11-02', '2026-11-03']);
    });

    test('「先看看四周」: every time, or the first time each day', () {
      final now = DateTime(2026, 11, 15, 10);
      const g = Game();
      expect(g.checkDue(now, passed: false), isTrue);
      expect(g.checkDue(now, passed: true), isFalse);
      final daily = g.withSettings(const Settings(checkDaily: true));
      expect(daily.checkDue(now, passed: false), isTrue);
      expect(daily.checked(now).checkDue(now, passed: false), isFalse);
      expect(daily.checked(now).checkDue(DateTime(2026, 11, 16, 0, 1), passed: false), isTrue, reason: 'a new day');
    });

    test('six routines at most, the newest first, the same one only once', () {
      var g = const Game();
      for (var i = 0; i < 8; i++) {
        g = g.save([moves[i].id, 'monkey']);
      }
      expect(g.routines.length, Game.maxRoutines);
      expect(g.routines.first.first, moves[7].id);
      g = g.save([moves[3].id, 'monkey']);
      expect(g.routines.length, Game.maxRoutines);
      expect(g.routines.where((r) => r.first == moves[3].id).length, 1);
      expect(g.forget(0).routines.length, Game.maxRoutines - 1);
    });

    test('the rest lasts an hour; a clock moved back does not lock the app', () {
      final now = DateTime(2026, 11, 15, 10);
      final g = const Game().rest(now);
      expect(g.resting(now.add(const Duration(minutes: 59))), isTrue);
      expect(g.resting(now.add(const Duration(minutes: 61))), isFalse);
      expect(g.resting(now.subtract(const Duration(minutes: 5))), isFalse);
    });

    test('six guides, each with its own voice', () {
      expect(Guide.values.length, 6);
      expect(Guide.values.map((g) => g.pitch).toSet().length, 6);
    });
  });
}
