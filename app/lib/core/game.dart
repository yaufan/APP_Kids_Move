import 'dart:math' as math;

import 'adventures.dart';
import 'guides.dart';
import 'moves.dart';

/// What a parent set (parent mode, docs/design.md 「家長模式」).
class Settings {
  const Settings({
    this.level = Level.mid,
    this.minutes = 15,
    this.quiet = false,
    this.asked = false,
    this.smallSpace = false,
    this.checkDaily = false,
    this.mustTap = false,
    this.together = false,
    this.off = const {},
    this.music = true,
    this.sounds = true,
    this.voice = true,
    this.slow = false,
    this.full = true,
  });

  final Level level;

  /// How long one sitting may be before a rest.
  final int minutes;

  /// Quiet mode: no thumping jumps (an apartment, the evening).
  final bool quiet;

  /// Whether the first-time question (age and quiet mode) was answered.
  final bool asked;

  /// Only moves done on the spot.
  final bool smallSpace;

  /// 「先看看四周」 only the first time each day (otherwise every time).
  final bool checkDaily;

  /// Moves go on only when 「做好了！」 is tapped.
  final bool mustTap;

  /// A grown-up joins in: 「和爸爸媽媽一起」, and 大人當 DJ in 動物舞會.
  final bool together;

  /// Moves a parent turned off (they never come back by themselves).
  final Set<String> off;

  final bool music;
  final bool sounds;
  final bool voice;

  /// A slower voice.
  final bool slow;

  /// The full version (everything); on while testing.
  final bool full;

  static const minuteChoices = [10, 15, 20, 30];

  /// Whether [m] may be done: not turned off, and on the spot when the space is small.
  bool allows(Move m) => !off.contains(m.id) && !(smallSpace && m.travels);

  bool opens(Adventure a) => full || a.free;

  /// 自己排 is in the full version.
  bool get buildOpen => full;

  Settings copyWith({
    Level? level,
    int? minutes,
    bool? quiet,
    bool? asked,
    bool? smallSpace,
    bool? checkDaily,
    bool? mustTap,
    bool? together,
    Set<String>? off,
    bool? music,
    bool? sounds,
    bool? voice,
    bool? slow,
    bool? full,
  }) =>
      Settings(
        level: level ?? this.level,
        minutes: minutes ?? this.minutes,
        quiet: quiet ?? this.quiet,
        asked: asked ?? this.asked,
        smallSpace: smallSpace ?? this.smallSpace,
        checkDaily: checkDaily ?? this.checkDaily,
        mustTap: mustTap ?? this.mustTap,
        together: together ?? this.together,
        off: off == null ? this.off : {for (final id in off) if (movesById.containsKey(id)) id},
        music: music ?? this.music,
        sounds: sounds ?? this.sounds,
        voice: voice ?? this.voice,
        slow: slow ?? this.slow,
        full: full ?? this.full,
      );

  Map<String, dynamic> toJson() => {
        'level': level.name,
        'minutes': minutes,
        'quiet': quiet,
        'asked': asked,
        'smallSpace': smallSpace,
        'checkDaily': checkDaily,
        'mustTap': mustTap,
        'together': together,
        'off': (off.toList()..sort()),
        'music': music,
        'sounds': sounds,
        'voice': voice,
        'slow': slow,
        'full': full,
      };

  factory Settings.fromJson(Map<String, dynamic> j) {
    final m = j['minutes'], off = j['off'];
    bool flag(String k, bool d) => j[k] is bool ? j[k] as bool : d;
    return Settings(
      level: Level.values.asNameMap()[j['level']] ?? Level.mid,
      minutes: m is int && minuteChoices.contains(m) ? m : 15,
      quiet: flag('quiet', false),
      asked: flag('asked', false),
      smallSpace: flag('smallSpace', false),
      checkDaily: flag('checkDaily', false),
      mustTap: flag('mustTap', false),
      together: flag('together', false),
      off: {
        if (off is List)
          for (final id in off)
            if (id is String && movesById.containsKey(id)) id,
      },
      music: flag('music', true),
      sounds: flag('sounds', true),
      voice: flag('voice', true),
      slow: flag('slow', false),
      full: flag('full', true),
    );
  }
}

/// Dates as 'yyyy-mm-dd' in the phone's own time.
abstract final class Days {
  static String key(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime? parse(String k) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(k);
    if (m == null) return null;
    final d = DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
    return key(d) == k ? d : null;
  }

  /// Days since 1 January 2000.
  static int number(DateTime d) => DateTime.utc(d.year, d.month, d.day).difference(DateTime.utc(2000)).inDays;

  /// The last seven days' keys, oldest first, ending today.
  static List<String> week(DateTime now) => [for (var i = 6; i >= 0; i--) key(DateTime(now.year, now.month, now.day - i))];
}

/// Everything kept on the phone (one small file, store.dart): no name, no
/// photo, nothing about the child's body.
class Game {
  const Game({
    this.settings = const Settings(),
    this.guide,
    this.stamps = const {},
    this.moved = const {},
    this.played = const {},
    this.checkedDay,
    this.recent = const [],
    this.routines = const [],
    this.restSince,
  });

  final Settings settings;

  /// The guide the child picked (null: not picked yet).
  final Guide? guide;

  /// Adventure id -> the day it was last finished (the red 「去過了」 stamp is
  /// for today only).
  final Map<String, String> stamps;

  /// Day -> seconds spent following moves (adventures, 舞會, 自己排,
  /// 伸展; not while paused): parent mode's week. The app cannot see whether
  /// the child really moved, so it is called 「跟著動」.
  final Map<String, int> moved;

  /// Day -> seconds the app was played.
  final Map<String, int> played;

  /// The day 「先看看四周」 was last gone through.
  final String? checkedDay;

  /// The moves done lately, newest first (parent mode's 「練到什麼」).
  final List<String> recent;

  /// Saved 自己排 routines (move ids), newest first.
  final List<List<String>> routines;

  /// When the play time ran out (null: playing).
  final DateTime? restSince;

  static const restLength = Duration(hours: 1);
  static const maxRoutines = 6;
  static const maxRecent = 20;
  static const keepDays = 14;

  /// Resting for an hour after the time ran out. A clock moved back (now
  /// before the rest began) does not lock the app: it counts as rested.
  bool resting(DateTime now) {
    final since = restSince;
    if (since == null) return false;
    final d = now.difference(since);
    return !d.isNegative && d < restLength;
  }

  bool stamped(String adventure, DateTime now) => stamps[adventure] == Days.key(now);

  /// Whether 「先看看四周」 is due before moving: every time, or (if the parent
  /// chose) only the first time each day. [passed]: gone through for this go.
  bool checkDue(DateTime now, {required bool passed}) => settings.checkDaily ? checkedDay != Days.key(now) : !passed;

  int movedOn(String day) => moved[day] ?? 0;
  int playedOn(String day) => played[day] ?? 0;

  Game copyWith({
    Settings? settings,
    Guide? guide,
    bool clearGuide = false,
    Map<String, String>? stamps,
    Map<String, int>? moved,
    Map<String, int>? played,
    String? checkedDay,
    List<String>? recent,
    List<List<String>>? routines,
    DateTime? restSince,
    bool clearRest = false,
  }) =>
      Game(
        settings: settings ?? this.settings,
        guide: clearGuide ? null : (guide ?? this.guide),
        stamps: stamps ?? this.stamps,
        moved: moved ?? this.moved,
        played: played ?? this.played,
        checkedDay: checkedDay ?? this.checkedDay,
        recent: recent ?? this.recent,
        routines: routines ?? this.routines,
        restSince: clearRest ? null : (restSince ?? this.restSince),
      );

  Game withSettings(Settings s) => copyWith(settings: s);

  /// Finished [adventure] today: its card gets the red stamp.
  Game stamp(String adventure, DateTime now) => copyWith(stamps: {...stamps, adventure: Days.key(now)});

  Game checked(DateTime now) => copyWith(checkedDay: Days.key(now));

  static Map<String, int> _add(Map<String, int> m, DateTime now, int seconds) {
    final day = Days.key(now);
    final out = {...m, day: (m[day] ?? 0) + seconds};
    // Only the last two weeks are kept.
    final cut = Days.key(DateTime(now.year, now.month, now.day - keepDays));
    out.removeWhere((k, _) => k.compareTo(cut) < 0);
    return out;
  }

  /// [seconds] more of following moves on [now]'s day.
  Game followed(DateTime now, int seconds) => seconds <= 0 ? this : copyWith(moved: _add(moved, now, seconds));

  /// [seconds] more of play on [now]'s day.
  Game playedFor(DateTime now, int seconds) => seconds <= 0 ? this : copyWith(played: _add(played, now, seconds));

  /// [move] was done.
  Game did(String move) {
    final list = [move, ...recent.where((m) => m != move)];
    return copyWith(recent: list.take(maxRecent).toList());
  }

  /// Saves a 自己排 routine (the oldest goes when there are six).
  Game save(List<String> routine) {
    if (routine.isEmpty) return this;
    final same = routines.indexWhere((r) => _same(r, routine));
    final list = [List<String>.unmodifiable(routine), for (var i = 0; i < routines.length; i++) if (i != same) routines[i]];
    return copyWith(routines: list.take(maxRoutines).toList());
  }

  Game forget(int i) => i < 0 || i >= routines.length ? this : copyWith(routines: [...routines]..removeAt(i));

  static bool _same(List<String> a, List<String> b) => a.length == b.length && [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((x) => x);

  Game rest(DateTime now) => copyWith(restSince: now);

  Game playOn() => copyWith(clearRest: true);

  Map<String, dynamic> toJson() => {
        'version': 1,
        'settings': settings.toJson(),
        if (guide != null) 'guide': guide!.name,
        'stamps': stamps,
        'moved': moved,
        'played': played,
        if (checkedDay != null) 'checkedDay': checkedDay,
        'recent': recent,
        'routines': routines,
        if (restSince != null) 'restSince': restSince!.toIso8601String(),
      };

  /// Reads a saved game; anything broken or unknown is left out.
  factory Game.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const Game();
    final st = j['stamps'], mv = j['moved'], pl = j['played'], rc = j['recent'], rt = j['routines'], rest = j['restSince'], ck = j['checkedDay'];
    Map<String, int> days(dynamic m) => {
          if (m is Map)
            for (final e in m.entries)
              if (e.key is String && Days.parse(e.key as String) != null && e.value is int && (e.value as int) > 0) e.key as String: math.min(e.value as int, 86400),
        };
    return Game(
      settings: Settings.fromJson(j['settings'] is Map ? (j['settings'] as Map).cast<String, dynamic>() : const {}),
      guide: Guide.values.asNameMap()[j['guide']],
      stamps: {
        if (st is Map)
          for (final e in st.entries)
            if (adventuresById.containsKey(e.key) && e.value is String && Days.parse(e.value as String) != null) e.key as String: e.value as String,
      },
      moved: days(mv),
      played: days(pl),
      checkedDay: ck is String && Days.parse(ck) != null ? ck : null,
      recent: [
        if (rc is List)
          for (final m in rc)
            if (m is String && movesById.containsKey(m)) m,
      ].take(maxRecent).toList(),
      routines: [
        if (rt is List)
          for (final r in rt)
            if (r is List)
              [
                for (final m in r)
                  if (m is String && movesById.containsKey(m)) m,
              ],
      ].where((r) => r.isNotEmpty).take(maxRoutines).toList(),
      restSince: rest is String ? DateTime.tryParse(rest) : null,
    );
  }
}
