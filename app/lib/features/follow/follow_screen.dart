import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app.dart';
import '../../app/figures.dart';
import '../../app/strings.dart';
import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../core/adventures.dart';
import '../../core/game.dart';
import '../../core/guides.dart';
import '../../core/moves.dart';
import '../../core/providers.dart';
import '../../core/screen.dart';
import '../../core/session.dart';
import '../../core/sounds.dart';

/// Where the moves come from.
enum FollowSource { adventure, routine, calm }

/// What the screen is doing for the step it is on (docs/design.md 「跟著做」).
enum Phase {
  /// The animal's call and 「換青蛙跳囉！」 (about four seconds).
  look,

  /// Moving with the music for a whole number of bars.
  move,

  /// The music has run out but the parent asked for 「做好了！」 first.
  wait,

  /// 「呼——喘口氣」 (three seconds).
  breathe,

  /// The go is over.
  end,
}

/// 跟著做: an adventure, a 自己排 routine, or 慢慢伸展 on its own. A big
/// pom-pom animal does the move on the beat (on the left, or on top when the
/// phone stands upright); the card for the grown-up says how, shows a child
/// doing it, and counts up along with the music. The app cannot see the
/// child: the next move comes when the music for this one ends, or when
/// 「做好了！」 is tapped (it means only 「next」).
class FollowScreen extends ConsumerStatefulWidget {
  const FollowScreen({super.key, required this.source, this.adventure});

  final FollowSource source;
  final String? adventure;

  @override
  ConsumerState<FollowScreen> createState() => _FollowScreenState();
}

class _FollowScreenState extends ConsumerState<FollowScreen> with HushOnLeave {
  late final Plan _plan;
  late final ScreenControl _screen;
  late final AppLifecycleListener _life;
  var _i = 0;
  var _phase = Phase.look;
  var _beat = 0, _lit = 0;
  var _paused = false;
  var _inhale = false;
  var _breaths = 0;
  Timer? _timer;
  Later? _later;
  var _windingDown = false;

  /// Running for a moment after the screen moved on to 「喘口氣」 or to the
  /// next animal: a 「做好了！」 then is the same tap as the one before (or
  /// came as the music ran out), so it does not skip on a second time.
  Timer? _tapGuard;
  static const _sameTap = Duration(milliseconds: 800);

  PlanStep get _step => _plan.steps[_i];
  Settings get _s => ref.read(gameProvider).settings;
  Music get _music => _step.stretch || widget.source == FollowSource.calm ? Music.calm : _plan.music;

  @override
  void initState() {
    super.initState();
    final s = ref.read(gameProvider).settings;
    _plan = switch (widget.source) {
      FollowSource.adventure => adventurePlan(adventuresById[widget.adventure]!, s),
      FollowSource.routine => routinePlan(ref.read(draftProvider), s),
      FollowSource.calm => calmPlan(s, ref.read(clockProvider)()),
    };
    _screen = ref.read(screenProvider);
    _screen.keepOn(true);
    _life = AppLifecycleListener(onHide: () {
      if (mounted && !_paused && _phase != Phase.end) _pause();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // 「先看看四周」 was for this go; the next one asks again.
      ref.read(spaceOkProvider.notifier).set(false);
      ref.read(pausedProvider.notifier).set(false);
      _start(0);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _later?.cancel();
    _tapGuard?.cancel();
    _life.dispose();
    _screen.keepOn(false);
    super.dispose();
  }

  void _guardTaps() {
    _tapGuard?.cancel();
    _tapGuard = Timer(_sameTap, () {});
  }

  void _stopAll() {
    _timer?.cancel();
    _timer = null;
    _later?.cancel();
    _later = null;
  }

  // ---------------------------------------------------------------- the steps
  void _start(int i) {
    _stopAll();
    _guardTaps();
    final step = _plan.steps[i];
    setState(() {
      _i = i;
      _phase = Phase.look;
      _beat = 0;
      _lit = 0;
      _inhale = false;
      _breaths = 0;
    });
    final s = _s;
    if (step.move != breathe) ref.read(gameProvider.notifier).change((g) => g.did(step.move.id));
    sfx(ref, step.move.call);
    final guide = ref.read(gameProvider).guide ?? Guide.macaque;
    final how = step.move.howFor(s.level, quietMode: s.quiet);
    final buf = StringBuffer();
    if (step.stretch && widget.source != FollowSource.calm) buf.write(Strings.stretchNow);
    if (step.move == breathe) {
      buf.write(how);
    } else {
      if (s.level != Level.small && step.story != null) buf.write(step.story);
      buf.write(Strings.turn(guide.hi, step.name, s.together ? Strings.together(how) : how));
      if (s.level == Level.big) buf.write('${step.name}，${step.move.why}。');
    }
    _later = Later(const Duration(milliseconds: 3200), _moveStart, after: speak(ref, buf.toString()));
  }

  int get _total {
    if (_step.stretch) return 0;
    return moveBeats(_s.level, _music.bpm);
  }

  void _moveStart() {
    if (!mounted) return;
    _stopAll();
    setState(() {
      _phase = Phase.move;
      _beat = 0;
      _lit = 0;
    });
    if (_step.stretch) {
      _breathCycle();
      return;
    }
    _timer = Timer.periodic(_music.beat, (_) => _onBeat());
  }

  void _onBeat() {
    if (!mounted || _paused) return;
    // The play time ran out: the move's music is over, so the screen does not
    // wait for 「做好了！」 (on to the slow stretch, then the rest).
    if (_phase == Phase.wait && ref.read(windDownProvider)) return _breathe();
    final m = _step.move;
    setState(() {
      _beat++;
      if (_phase == Phase.move && _beat % beatsPerCount == 0) _lit = _lit % _s.level.countTo + 1;
    });
    if (_phase != Phase.move) return;
    if (_beat.isOdd) {
      sfx(ref, m.beat);
    } else {
      sfx(ref, 'count');
    }
    if (_beat % 8 == 0 && _beat < _total) {
      final lines = m.invitesFor(quietMode: _s.quiet);
      speak(ref, lines[(_beat ~/ 8 - 1) % lines.length]);
    }
    if (_beat >= _total) {
      if (_s.mustTap && !ref.read(windDownProvider)) {
        setState(() => _phase = Phase.wait);
        speak(ref, Strings.tapWhenDone);
      } else {
        _breathe();
      }
    }
  }

  /// The slow stretch at the end: the flower opens (breathe in, four
  /// seconds) and closes (breathe out), three times.
  void _breathCycle() {
    if (!mounted || _paused) return;
    if (_breaths >= breaths * 2) {
      _finish();
      return;
    }
    final inhale = _breaths.isEven;
    setState(() {
      _inhale = inhale;
      _breaths++;
      _beat++;
      _lit = (_breaths + 1) ~/ 2;
    });
    sfx(ref, inhale ? 'breath_in' : 'breath_out');
    if (_breaths <= 2 || _s.level == Level.small) speak(ref, inhale ? Strings.breatheIn : Strings.breatheOut);
    _later = Later(inhale ? breathIn : breathOut, _breathCycle);
  }

  void _breathe() {
    _stopAll();
    if (_step.stretch) {
      _finish();
      return;
    }
    _guardTaps();
    setState(() => _phase = Phase.breathe);
    sfx(ref, 'breath');
    _later = Later(const Duration(seconds: 3), _next, after: speak(ref, '${Strings.thanks(_step.name)}${Strings.phew}'));
  }

  void _next() {
    if (!mounted) return;
    final last = _plan.steps.length - 1;
    if (_i >= last) return _finish();
    // The play time ran out: straight to the slow stretch.
    if (ref.read(windDownProvider)) return _start(last);
    _start(_i + 1);
  }

  void _finish() {
    _stopAll();
    if (!mounted) return;
    setState(() => _phase = Phase.end);
    _screen.keepOn(false);
    final now = ref.read(clockProvider)();
    final a = _plan.adventure;
    if (a != null) ref.read(gameProvider.notifier).change((g) => g.stamp(a, now));
    sfx(ref, 'done');
    final guide = ref.read(gameProvider).guide ?? Guide.macaque;
    final line = widget.source == FollowSource.calm ? Strings.calmDone : '${Strings.allThanks}${guide.cheer}';
    final said = speak(ref, line);
    if (ref.read(windDownProvider)) _restSoon(said);
  }

  /// The go is over and the play time has run out: to the rest in a moment.
  void _restSoon([Future<void>? said]) {
    setState(() => _windingDown = true);
    _later = Later(const Duration(seconds: 5), () {
      if (mounted) finishGo(ref, context);
    }, after: said);
  }

  // ---------------------------------------------------------------- the buttons
  void _done() {
    if (_tapGuard?.isActive ?? false) return;
    switch (_phase) {
      case Phase.look:
      case Phase.move:
      case Phase.wait:
        _breathe();
      case Phase.breathe:
        _stopAll();
        _next();
      case Phase.end:
        break;
    }
  }

  /// 「再一次」 (not once the play time has run out: that would never end).
  bool get _canAgain => (_phase == Phase.move || _phase == Phase.wait) && !ref.read(windDownProvider);

  void _again() {
    if (!_canAgain) return;
    _moveStart();
  }

  void _pause() {
    _stopAll();
    ref.read(voiceProvider).stop();
    _screen.keepOn(false);
    ref.read(pausedProvider.notifier).set(true);
    setState(() => _paused = true);
  }

  void _resume() {
    _screen.keepOn(true);
    ref.read(pausedProvider.notifier).set(false);
    setState(() => _paused = false);
    switch (_phase) {
      case Phase.look:
        _start(_i);
      case Phase.move:
      case Phase.wait:
        if (_step.stretch) {
          _breaths = 0;
          _breathCycle();
        } else {
          _moveStart();
        }
      case Phase.breathe:
        _next();
      case Phase.end:
        break;
    }
  }

  void _home() {
    _stopAll();
    ref.read(pausedProvider.notifier).set(false);
    finishGo(ref, context);
  }

  // ---------------------------------------------------------------- drawing
  @override
  Widget build(BuildContext context) {
    final s = ref.watch(gameProvider.select((g) => g.settings));
    // The time ran out while the 「謝謝你陪我們！」 panel was up: rest after all.
    ref.listen(windDownProvider, (_, on) {
      if (on && _phase == Phase.end && !_windingDown) _restSoon();
    });
    ref.watch(windDownProvider);
    final step = _step;
    final calm = widget.source == FollowSource.calm || step.stretch;
    return WithMusic(
      music: _paused ? null : _music,
      child: Scaffold(
        backgroundColor: calm ? Felt.calm1 : Felt.cream,
        body: SafeArea(
          child: Stack(children: [
            LayoutBuilder(builder: (context, box) {
              final w = wide(box);
              final stage = _stage(step, s, calm, w);
              final card = _card(step, s, w);
              if (w) {
                return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(flex: 2, child: stage),
                  SizedBox(width: (box.maxWidth / 3).clamp(270.0, 420.0), child: card),
                ]);
              }
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(flex: 11, child: stage), Expanded(flex: 9, child: card)]);
            }),
            KeyedSubtree(key: ValueKey('follow-${_phase.name}-$_i'), child: const SizedBox.shrink()),
            if (_paused) _pausePanel(),
            if (_phase == Phase.end)
              DonePanel(
                title: widget.source == FollowSource.calm ? Strings.calmDone : Strings.allThanks,
                top: _plan.adventure == null ? null : Row(mainAxisSize: MainAxisSize.min, children: const [Bob(amount: 3, child: GuideView(size: 100, pose: 'wave')), SizedBox(width: 6), SizedBox(width: 70, height: 70, child: Art('ui/stamp'))]),
                actions: [PillButton(label: _windingDown ? Strings.toRest : Strings.home, icon: Icons.home_rounded, onTap: _home, color: Felt.done)],
              ),
          ]),
        ),
      ),
    );
  }

  Widget _stage(PlanStep step, Settings s, bool calm, bool w) {
    final m = step.move;
    final moving = !_paused && (_phase == Phase.move || _phase == Phase.wait);
    final animal = m == breathe
        ? const Bob(amount: 6, child: GuideView(size: 260, pose: 'idle'))
        : PoseView(
            key: ValueKey('pose-${step.pose('a')}'),
            a: step.pose('a'),
            b: step.pose('b', quiet: s.quiet),
            beat: _beat,
            beatLength: step.stretch ? breathIn : _music.beat,
            motion: m.motionFor(quietMode: s.quiet),
            moving: moving,
            fast: step.fast,
          );
    return LayoutBuilder(builder: (context, box) {
      final flower = step.stretch ? (w ? box.maxHeight * .42 : box.maxWidth * .36) : 0.0;
      return Scene(
        calm ? 'scenes/calm' : _plan.scene,
        child: Stack(children: [
          Positioned(
            left: box.maxWidth * .06,
            right: box.maxWidth * .06 + (step.stretch ? flower * .8 : 0),
            top: 64,
            bottom: box.maxHeight * .04,
            child: Semantics(label: step.name, child: animal),
          ),
          if (step.stretch && _phase != Phase.look)
            Positioned(right: 10, bottom: box.maxHeight * .12, child: BreathFlower(key: const ValueKey('flower'), open: _inhale, size: flower)),
          Positioned(
            left: 10,
            right: 10,
            top: 8,
            child: Row(children: [
              RoundButton(label: Strings.pause, icon: Icons.pause_rounded, onTap: _pause, size: 56, color: calm ? Felt.line : Felt.pause, sound: null),
              const SizedBox(width: 10),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: feltBox(Felt.paper.withValues(alpha: .92), radius: 18, width: 2.5),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Flexible(child: Text(_plan.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                    const SizedBox(width: 10),
                    Flexible(child: StepDots(total: _plan.steps.length, at: _i, size: 14)),
                  ]),
                ),
              ),
            ]),
          ),
          if (_phase == Phase.look || _phase == Phase.breathe)
            Positioned(
              left: 10,
              bottom: 8,
              right: box.maxWidth * .25,
              child: GuideSays(
                text: _phase == Phase.look ? '換${step.name}囉！' : Strings.phew,
                size: (box.maxHeight * .24).clamp(56.0, 120.0),
                textSize: 20,
                pose: _phase == Phase.look ? 'wave' : 'idle',
              ),
            ),
        ]),
      );
    });
  }

  Widget _card(PlanStep step, Settings s, bool w) {
    final m = step.move;
    final kid = m == breathe ? null : PoseView(a: kidArt(m, 'a'), b: kidArt(m, 'b', quiet: s.quiet), beat: _beat, beatLength: step.stretch ? breathIn : _music.beat, motion: Motion.still, moving: _phase == Phase.move || _phase == Phase.wait, fast: step.fast, amount: .3);
    final big = TextStyle(fontSize: w ? 26 : 28, fontWeight: FontWeight.w700, height: 1.2);
    return Container(
      margin: EdgeInsets.fromLTRB(w ? 0 : 10, w ? 10 : 6, 10, 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: feltBox(Felt.paper, radius: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(step.name, key: const ValueKey('move-name'), maxLines: 1, overflow: TextOverflow.ellipsis, style: big),
        const SizedBox(height: 2),
        Text(m.howFor(s.level, quietMode: s.quiet), maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, height: 1.35, color: Felt.inkSoft)),
        const SizedBox(height: 6),
        Expanded(
          child: LayoutBuilder(builder: (context, box) => Row(children: [
            if (kid != null) ...[
              Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text(Strings.likeThis, style: TextStyle(fontSize: 13, color: Felt.inkSoft)),
                const SizedBox(height: 2),
                SizedBox.square(
                  dimension: (box.maxHeight - 22).clamp(0.0, box.maxWidth * .5),
                  child: Container(decoration: feltBox(Colors.white, radius: 16, shadow: false, width: 2), padding: const EdgeInsets.all(4), child: kid),
                ),
              ]),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (step.stretch && _phase != Phase.look) ...[
                  Text(_inhale ? Strings.breatheIn : Strings.breatheOut, style: big.copyWith(color: Felt.edge(Felt.blue))),
                  const SizedBox(height: 4),
                  CountDots(count: breaths, lit: _lit, size: 30),
                ] else ...[
                  const Text(Strings.countTogether, style: TextStyle(fontSize: 13, color: Felt.inkSoft)),
                  const SizedBox(height: 4),
                  CountDots(count: s.level.countTo, lit: _phase == Phase.move || _phase == Phase.wait ? _lit : 0, size: 30),
                ],
              ]),
            ),
          ])),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: AnimatedScale(
              scale: _phase == Phase.wait ? 1.06 : 1,
              duration: const Duration(milliseconds: 300),
              child: PillButton(label: Strings.done, onTap: _phase == Phase.end ? null : _done, height: 60, expand: true, color: Felt.done),
            ),
          ),
          const SizedBox(width: 8),
          Opacity(
            opacity: _canAgain ? 1 : .45,
            child: RoundButton(label: Strings.again, icon: Icons.replay_rounded, onTap: _canAgain ? _again : null, size: 52),
          ),
        ]),
      ]),
    );
  }

  Widget _pausePanel() => Container(
        color: Felt.ink.withValues(alpha: .4),
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: feltBox(Felt.paper, radius: 28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const GuideView(size: 90, pose: 'idle'),
            const Text(Strings.paused, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            PillButton(label: Strings.goOn, icon: Icons.play_arrow_rounded, onTap: _resume, height: 62, color: Felt.done),
            const SizedBox(height: 10),
            PillButton(label: Strings.home, icon: Icons.home_rounded, onTap: _home, height: 48, color: Colors.white),
          ]),
        ),
      );
}
