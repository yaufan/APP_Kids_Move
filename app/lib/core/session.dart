import 'dart:math' as math;

import 'adventures.dart';
import 'game.dart';
import 'moves.dart';
import 'sounds.dart';

/// One thing to do in a go (an adventure, a 自己排 routine, 慢慢伸展).
class PlanStep {
  const PlanStep(this.move, {this.animal, this.title, this.story, this.fast = false, this.stretch = false});

  final Move move;

  /// Another animal doing it (蚯蚓 for 蛇扭扭), and its name then.
  final Species? animal;
  final String? title;

  Species get species => animal ?? move.species;
  String get name => title ?? move.zh;
  final String? story;
  final bool fast;

  /// The slow stretch at the end, with the breathing flower.
  final bool stretch;

  String pose(String frame) => poseArt(move, species, frame);
}

/// What a go is, in order, and what it ends with.
class Plan {
  const Plan(this.title, this.steps, {required this.music, this.scene = 'scenes/home', this.adventure});

  final String title;
  final List<PlanStep> steps;
  final Music music;
  final String scene;

  /// The adventure (null: 自己排 or 慢慢伸展).
  final String? adventure;
}

/// Moves that can stand in for one a parent turned off, or one that needs
/// room when the space is small: all done on the spot, none on the floor.
const spares = ['monkey', 'giraffe', 'jellyfish', 'fish', 'salmon', 'elephant', 'sloth', 'flamingo', 'starfish', 'squirrel'];

/// The slow stretches, in the order they stand in for each other.
const stretches = ['tortoise', 'catarch', 'butterfly', 'pangolin', 'rainbow'];

/// The stretch for the end: [wanted], or another one the parent left on.
/// Null when every stretch is off: the go ends with the breathing flower only.
Move? stretchFor(String wanted, Settings s) {
  final want = movesById[wanted];
  if (want != null && s.allows(want)) return want;
  for (final id in stretches) {
    final m = movesById[id]!;
    if (s.allows(m)) return m;
  }
  return null;
}

/// The breathing at the very end when no stretch is left (a flower only).
const breathe = Move(
  id: 'breathe',
  zh: '小花呼吸',
  species: Species.butterfly,
  how: ['看小花，吸氣、吐氣。', '花開吸氣，花合吐氣。', '花開吸氣，花合吐氣，慢慢的。'],
  invites: ['吸氣——', '吐氣——'],
  skills: [Skill.breath],
  kind: Kind.stability,
  caution: '',
  stretch: true,
  motion: Motion.still,
  call: 'calm',
  beat: 'breath_in',
);

/// An adventure for these settings: the steps of its level, with moves a
/// parent turned off (or that need room in a small space) replaced by a
/// spare that is on, or left out; it always ends with a slow stretch.
Plan adventurePlan(Adventure a, Settings s) {
  final out = <PlanStep>[];
  final used = <String>{};
  for (final step in a.steps) {
    if (step.from.index > s.level.index) continue;
    final m = movesById[step.move]!;
    if (s.allows(m) && !(used.contains(m.id) && !step.fast)) {
      out.add(PlanStep(m, animal: step.species, title: step.name, story: step.story, fast: step.fast));
      used.add(m.id);
      continue;
    }
    final inPlan = {for (final x in a.steps) x.move};
    final spare = spares.map((id) => movesById[id]!).where((x) => s.allows(x) && !used.contains(x.id) && !inPlan.contains(x.id)).firstOrNull;
    if (spare != null) {
      out.add(PlanStep(spare, story: step.story));
      used.add(spare.id);
    }
  }
  out.add(_end(a.stretch, s));
  return Plan(a.zh, out, music: a.music, scene: a.scene, adventure: a.id);
}

PlanStep _end(String wanted, Settings s) {
  final m = stretchFor(wanted, s);
  return m == null ? const PlanStep(breathe, stretch: true) : PlanStep(m, stretch: true);
}

/// A 自己排 routine: the cards in order (any a parent has since turned off
/// are left out), then the slow stretch.
Plan routinePlan(List<String> ids, Settings s) {
  final out = [
    for (final id in ids)
      if (movesById[id] case final m? when s.allows(m)) PlanStep(m),
  ];
  out.add(_end('tortoise', s));
  return Plan('我的體操', out, music: Music.home, scene: 'scenes/home');
}

/// 慢慢伸展 on its own (about two minutes): two stretches that are on, a
/// different pair each day, then the breathing flower.
Plan calmPlan(Settings s, DateTime now) {
  final on = [for (final id in stretches) if (s.allows(movesById[id]!)) movesById[id]!];
  final out = <PlanStep>[];
  if (on.isNotEmpty) {
    final first = Days.number(now) % on.length;
    out.add(PlanStep(on[first]));
    if (on.length > 1) out.add(PlanStep(on[(first + 1) % on.length]));
  }
  out.add(const PlanStep(breathe, stretch: true));
  return Plan('慢慢伸展', out, music: Music.calm, scene: 'scenes/calm');
}

/// How many beats a move lasts at [level] with music at [bpm]: whole bars
/// (four beats) close to the level's seconds.
int moveBeats(Level level, int bpm) {
  final bar = 4 * 60 / bpm;
  return math.max(2, (level.moveSeconds / bar).round()) * 4;
}

/// Beats per 「一起數」 number: the count goes up on the beat, then starts again.
const beatsPerCount = 2;

/// The breathing flower: in for four seconds, out for four, three times.
const breathIn = Duration(seconds: 4), breathOut = Duration(seconds: 4), breaths = 3;

// ---------------------------------------------------------------- 動物舞會

/// When the music stops in 動物舞會, for how long, and what to become.
class Freeze {
  const Freeze(this.atBeat, this.seconds, this.pose);

  /// The dancing beat it stops on (counted without the stops).
  final int atBeat;

  /// How long everyone stays still (counted up, never down).
  final int seconds;

  /// The animal to become (null: just keep still, 小小).
  final Move? pose;
}

/// The animals to become when the music stops.
const freezePoses = ['flamingo', 'giraffe', 'starfish', 'sloth', 'frog', 'elephant', 'monkey', 'penguin'];

/// The song's length in dancing beats (two minutes at 120).
const partyBeats = 240;

/// The stops: 小小 at the end of each phrase (it can hear the stop coming)
/// and only keeps still; 中 on a bar line and becomes an animal; 大 on any
/// beat (harder to guess) and becomes an animal while counting to five.
/// Poses a parent turned off are never asked for.
List<Freeze> partyPlan(Settings s, math.Random r) {
  final poses = [for (final id in freezePoses) if (!s.off.contains(id)) movesById[id]!];
  final out = <Freeze>[];
  var at = 0, last = -1;
  while (true) {
    at += switch (s.level) {
      Level.small => 32,
      Level.mid => 16 + 8 * r.nextInt(3),
      Level.big => 14 + r.nextInt(17),
    };
    if (at >= partyBeats - 8) break;
    Move? pose;
    if (s.level != Level.small && poses.isNotEmpty) {
      var i = r.nextInt(poses.length);
      if (i == last && poses.length > 1) i = (i + 1) % poses.length;
      last = i;
      pose = poses[i];
    }
    out.add(Freeze(at, switch (s.level) { Level.small => 3, Level.mid => 4, Level.big => 5 }, pose));
  }
  return out;
}

/// The dancers on the stage in 動物舞會.
const dancers = ['frog', 'penguin', 'elephant', 'monkey'];

/// A card for 自己排's 「隨便來一個」: one that is on and not in the row yet
/// (any that is on, if all are in the row). Null when none is on.
Move? randomCard(Settings s, List<String> row, math.Random r) {
  final on = [for (final m in moves) if (s.allows(m) && !m.stretch) m];
  if (on.isEmpty) return null;
  final fresh = [for (final m in on) if (!row.contains(m.id)) m];
  final from = fresh.isEmpty ? on : fresh;
  return from[r.nextInt(from.length)];
}

/// The cards 自己排 offers: every move that is on, but not the stretches
/// (the last place is always the slow stretch).
List<Move> buildCards(Settings s) => [for (final m in moves) if (s.allows(m) && !m.stretch) m];
