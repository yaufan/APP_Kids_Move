import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app.dart';
import '../../app/figures.dart';
import '../../app/strings.dart';
import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../core/game.dart';
import '../../core/moves.dart';
import '../../core/providers.dart';
import '../../core/screen.dart';
import '../../core/session.dart';
import '../../core/sounds.dart';

enum PartyPhase { intro, dance, freeze, end }

/// 動物舞會 (docs/design.md 「動物舞會」): dance freely while the music plays;
/// when it really stops, 「停！」 and everyone keeps still (小小), or becomes
/// an animal (中, 大 counting to five), counted up, never down. Nobody is
/// ever 「out」: the app cannot see who moved. With a grown-up joining in,
/// they are the DJ: holding the stage stops the music, letting go starts it.
class PartyScreen extends ConsumerStatefulWidget {
  const PartyScreen({super.key});

  @override
  ConsumerState<PartyScreen> createState() => _PartyScreenState();
}

class _PartyScreenState extends ConsumerState<PartyScreen> with HushOnLeave {
  late final List<Freeze> _freezes;
  late final bool _dj;
  late final ScreenControl _screen;
  late final AppLifecycleListener _life;
  var _phase = PartyPhase.intro;

  /// Beats danced (the stops not counted), and beats shown.
  var _danced = 0, _beat = 0;
  var _next = 0;
  Freeze? _frozen;
  var _lit = 0;
  var _paused = false;
  var _windingDown = false;

  /// The grown-up's finger holding the music (only the first one counts).
  int? _djFinger;
  Timer? _timer;
  Later? _later;

  @override
  void initState() {
    super.initState();
    final s = ref.read(gameProvider).settings;
    _dj = s.together;
    _freezes = partyPlan(s, ref.read(randomProvider));
    _screen = ref.read(screenProvider);
    _screen.keepOn(true);
    _life = AppLifecycleListener(onHide: () {
      if (mounted && !_paused && _phase != PartyPhase.end) _pause();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(spaceOkProvider.notifier).set(false);
      ref.read(pausedProvider.notifier).set(false);
      _intro();
    });
  }

  @override
  void dispose() {
    _stop();
    _life.dispose();
    _screen.keepOn(false);
    super.dispose();
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _later?.cancel();
    _later = null;
  }

  void _intro() {
    setState(() => _phase = PartyPhase.intro);
    sfx(ref, 'party');
    _later = Later(const Duration(seconds: 2), _dance, after: speak(ref, _dj ? '${Strings.partyHello}${Strings.djLine}' : Strings.partyHello));
  }

  void _dance() {
    if (!mounted) return;
    _stop();
    setState(() {
      _phase = PartyPhase.dance;
      _frozen = null;
      _lit = 0;
    });
    _timer = Timer.periodic(Music.party.beat, (_) => _onBeat());
  }

  void _onBeat() {
    if (!mounted || _paused || _phase != PartyPhase.dance) return;
    setState(() {
      _danced++;
      _beat++;
    });
    if (_danced % 4 == 0) sfx(ref, 'clap');
    final windDown = ref.read(windDownProvider);
    if (_danced >= partyBeats || (windDown && _danced % 16 == 0)) return _end();
    if (!_dj && _next < _freezes.length && _danced >= _freezes[_next].atBeat) {
      _freeze(_freezes[_next++]);
    }
  }

  void _freeze(Freeze f) {
    _stop();
    setState(() {
      _phase = PartyPhase.freeze;
      _frozen = f;
      _lit = 0;
    });
    sfx(ref, 'freeze');
    final pose = f.pose;
    if (pose != null) ref.read(gameProvider.notifier).change((g) => g.did(pose.id));
    speak(ref, '${Strings.stop}${pose == null ? Strings.freeze : Strings.become(pose.species.zh)}');
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _paused) return;
      if (_lit < f.seconds) {
        setState(() => _lit++);
        sfx(ref, 'count');
        return;
      }
      // The grown-up holding the music decides when it goes on.
      if (_djFinger != null) return;
      _resume();
    });
  }

  void _resume() {
    _stop();
    sfx(ref, 'go');
    speak(ref, Strings.dance);
    _dance();
  }

  void _end() {
    _stop();
    setState(() => _phase = PartyPhase.end);
    _screen.keepOn(false);
    sfx(ref, 'bow');
    final said = speak(ref, Strings.bow);
    if (ref.read(windDownProvider)) _restSoon(said);
  }

  /// The party is over and the play time has run out: to the rest in a moment.
  void _restSoon([Future<void>? said]) {
    setState(() => _windingDown = true);
    _later = Later(const Duration(seconds: 5), () {
      if (mounted) finishGo(ref, context);
    }, after: said);
  }

  // ---- the grown-up as DJ (raw pointer events; the first finger only)
  void _djDown(PointerDownEvent e) {
    if (!_dj || _djFinger != null || _paused || _phase != PartyPhase.dance) return;
    _djFinger = e.pointer;
    final s = ref.read(gameProvider).settings;
    final poses = [for (final id in freezePoses) if (!s.off.contains(id)) movesById[id]!];
    final pose = s.level == Level.small || poses.isEmpty ? null : poses[ref.read(randomProvider).nextInt(poses.length)];
    _freeze(Freeze(_danced, s.level.countTo, pose));
  }

  void _djUp(PointerEvent e) {
    if (e.pointer != _djFinger) return;
    _djFinger = null;
    if (_phase == PartyPhase.freeze && !_paused) _resume();
  }

  void _pause() {
    _stop();
    _djFinger = null;
    ref.read(voiceProvider).stop();
    _screen.keepOn(false);
    ref.read(pausedProvider.notifier).set(true);
    setState(() => _paused = true);
  }

  void _unpause() {
    _screen.keepOn(true);
    ref.read(pausedProvider.notifier).set(false);
    setState(() => _paused = false);
    switch (_phase) {
      case PartyPhase.intro:
        _intro();
      case PartyPhase.dance:
      case PartyPhase.freeze:
        _dance();
      case PartyPhase.end:
        break;
    }
  }

  void _home() {
    _stop();
    ref.read(pausedProvider.notifier).set(false);
    finishGo(ref, context);
  }

  @override
  Widget build(BuildContext context) {
    // The time ran out while the bow panel was up: rest after all.
    ref.listen(windDownProvider, (_, on) {
      if (on && _phase == PartyPhase.end && !_windingDown) _restSoon();
    });
    final settings = ref.watch(gameProvider.select((g) => g.settings));
    final playing = !_paused && _phase == PartyPhase.dance;
    return WithMusic(
      music: playing ? Music.party : null,
      child: Scaffold(
        backgroundColor: Felt.lilac,
        body: SafeArea(
          child: Stack(fit: StackFit.expand, children: [
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: _djDown,
                onPointerUp: _djUp,
                onPointerCancel: _djUp,
                child: Scene('scenes/party', child: LayoutBuilder(builder: (context, box) => _stage(box, settings))),
              ),
            ),
            Positioned(
              left: 10,
              top: 8,
              child: RoundButton(label: Strings.pause, icon: Icons.pause_rounded, onTap: _pause, size: 56, color: Felt.pause, sound: null),
            ),
            Positioned(
              top: 10,
              left: 80,
              right: 80,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  decoration: feltBox(Felt.paper, radius: 18),
                  child: const Text(Strings.party, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
            if (_dj)
              Positioned(
                left: 16,
                right: 16,
                bottom: 8,
                child: IgnorePointer(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: feltBox(Felt.paper.withValues(alpha: .9), radius: 16, shadow: false),
                      child: const Text(Strings.dj, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ),
            KeyedSubtree(key: ValueKey('party-${_phase.name}'), child: const SizedBox.shrink()),
            if (_paused)
              Container(
                color: Felt.ink.withValues(alpha: .4),
                alignment: Alignment.center,
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: feltBox(Felt.paper, radius: 28),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text(Strings.paused, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 14),
                    PillButton(label: Strings.goOn, icon: Icons.play_arrow_rounded, onTap: _unpause, height: 62),
                    const SizedBox(height: 10),
                    PillButton(label: Strings.home, icon: Icons.home_rounded, onTap: _home, height: 48, color: Colors.white),
                  ]),
                ),
              ),
            if (_phase == PartyPhase.end)
              DonePanel(
                title: Strings.bow,
                actions: [PillButton(label: _windingDown ? Strings.toRest : Strings.home, icon: Icons.home_rounded, onTap: _home)],
              ),
          ]),
        ),
      ),
    );
  }

  Widget _stage(BoxConstraints box, Settings s) {
    final w = wide(box);
    final frozen = _phase == PartyPhase.freeze;
    final pose = _frozen?.pose;
    final dancing = _phase == PartyPhase.dance && !_paused;
    // Only animals whose move a parent left on dance.
    final on = partyDancers(s);
    Widget dancer(int i) {
      if (i >= on.length) return const SizedBox.shrink();
      final m = movesById[on[i]]!;
      return PoseView(
        key: ValueKey('dancer-${m.id}'),
        a: poseArt(m, m.species, 'a', quiet: s.quiet),
        b: poseArt(m, m.species, 'b', quiet: s.quiet),
        beat: _beat + i,
        beatLength: Music.party.beat,
        motion: i.isEven ? Motion.bounce : Motion.sway,
        moving: dancing,
        amount: .8,
      );
    }

    final floor = Padding(
      padding: EdgeInsets.fromLTRB(12, 70, 12, _dj ? 44 : 12),
      child: on.isEmpty
          ? const Center(child: Bob(amount: 6, child: GuideView(size: 220)))
          : w
              ? Row(children: [for (var i = 0; i < on.length; i++) Expanded(child: dancer(i))])
              : Column(children: [
                  Expanded(child: Row(children: [Expanded(child: dancer(0)), Expanded(child: dancer(1))])),
                  if (on.length > 2) Expanded(child: Row(children: [Expanded(child: dancer(2)), Expanded(child: dancer(3))])),
                ]),
    );
    if (!frozen) return floor;
    final count = CountDots(count: _frozen!.seconds, lit: _lit, size: w ? 36 : 40);
    final sign = Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 6),
      decoration: feltBox(Felt.stamp, radius: 26),
      child: Text(Strings.stop, style: TextStyle(fontSize: w ? 46 : 54, fontWeight: FontWeight.w700, color: Colors.white)),
    );
    final what = Text(pose == null ? Strings.freeze : Strings.become(pose.species.zh), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700));
    final big = pose == null
        ? Opacity(opacity: .55, child: floor)
        : PoseView(key: ValueKey('freeze-${pose.id}'), a: poseArt(pose, pose.species, 'a'), b: poseArt(pose, pose.species, 'a'), beat: 0, beatLength: const Duration(seconds: 1), moving: false);
    return Container(
      key: const ValueKey('freeze'),
      color: Felt.paper.withValues(alpha: .35),
      padding: const EdgeInsets.fromLTRB(12, 70, 12, 12),
      child: w
          ? Row(children: [
              Expanded(child: big),
              Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [sign, const SizedBox(height: 10), what, const SizedBox(height: 12), count])),
            ])
          : Column(children: [sign, const SizedBox(height: 8), what, Expanded(child: big), count, const SizedBox(height: 10)]),
    );
  }
}
