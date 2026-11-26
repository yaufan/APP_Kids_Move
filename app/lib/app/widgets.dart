import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/guides.dart';
import '../core/moves.dart';
import '../core/providers.dart';
import '../core/sounds.dart';
import '../core/voice.dart';
import 'strings.dart';
import 'theme.dart';

/// A drawing from assets/art/ (nothing at all if it is missing).
class Art extends StatelessWidget {
  const Art(this.path, {super.key, this.fit = BoxFit.contain, this.alignment = Alignment.center});

  /// Under assets/art/, without ".svg" (moves/frog_a).
  final String path;
  final BoxFit fit;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) =>
      SvgPicture.asset('assets/art/$path.svg', fit: fit, alignment: alignment, excludeFromSemantics: true, errorBuilder: (_, _, _) => const SizedBox.expand());
}

/// The screen that spoke last (its WidgetRef), so a screen going away
/// hushes only its own line, never the next screen's first one.
Object? _speaker;

/// Says [text] in the guide's voice (if the parent left the voice on).
/// Completes when the line has been said (or cut off by the next one).
Future<void> speak(WidgetRef ref, String text) {
  final g = ref.read(gameProvider);
  if (!g.settings.voice) return Future.value();
  _speaker = ref;
  return ref.read(voiceProvider).say(text, slow: g.settings.slow, pitch: (g.guide ?? Guide.macaque).pitch);
}

/// A screen that stops its own voice when the child leaves it, so a line
/// does not go on over the next screen (and never cuts the next one off).
mixin HushOnLeave<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  late final Voice _hush;
  late final Object _me;

  @override
  void initState() {
    super.initState();
    _hush = ref.read(voiceProvider);
    _me = ref;
  }

  @override
  void dispose() {
    if (identical(_speaker, _me)) {
      _speaker = null;
      _hush.stop();
    }
    super.dispose();
  }
}

/// Runs [then] after [min], and not before the line [after] has been said
/// (at most [atMost] of waiting for it), so a slow voice is not cut off by
/// the next step; [cancel] stops it.
class Later {
  Later(Duration min, VoidCallback then, {Future<void>? after, Duration atMost = const Duration(seconds: 10)}) : _then = then {
    _timer = Timer(min, () {
      _timeUp = true;
      _fire();
    });
    if (after == null) {
      _heard = true;
    } else {
      after.timeout(atMost).then((_) => _hear(), onError: (_) => _hear());
    }
  }

  final VoidCallback _then;
  late final Timer _timer;
  var _timeUp = false, _heard = false, _over = false;

  void _hear() {
    _heard = true;
    _fire();
  }

  void _fire() {
    if (_over || !_timeUp || !_heard) return;
    _over = true;
    _then();
  }

  void cancel() {
    _over = true;
    _timer.cancel();
  }
}

/// The phone's back key (or back gesture) never closes the app, which would
/// end a go halfway: it does what the screen's own button does ([onBack]:
/// home, or pause while moving), or nothing at all on the home screen and
/// at the rest.
class BackKey extends StatelessWidget {
  const BackKey({super.key, this.onBack, required this.child});

  final VoidCallback? onBack;
  final Widget child;

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) onBack?.call();
        },
        child: child,
      );
}

/// Plays a sound (its soft version in quiet mode).
void sfx(WidgetRef ref, String name) => ref.read(soundsProvider).play(soundFor(name, quiet: ref.read(gameProvider).settings.quiet));

/// Shrinks a little while pressed and fires when the finger lifts on it
/// (raw pointer events: a touch counts at once, no gesture to wait for).
/// Only the first finger counts; a cancelled touch, or a finger that slid
/// away (scrolling the cards), does nothing.
class Pressable extends ConsumerStatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.sound = 'tap'});

  final Widget child;
  final VoidCallback? onTap;
  final String? sound;

  @override
  ConsumerState<Pressable> createState() => _PressableState();
}

class _PressableState extends ConsumerState<Pressable> {
  int? _pointer;
  Offset _from = Offset.zero;

  /// A finger that slides further than this is scrolling a list, not tapping.
  static const slop = 24.0;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: enabled
          ? (e) {
              // Two fingers in the same frame: still only the first one.
              if (_pointer != null) return;
              setState(() {
                _pointer = e.pointer;
                _from = e.position;
              });
            }
          : null,
      onPointerMove: (e) {
        if (e.pointer == _pointer && (e.position - _from).distance > slop) setState(() => _pointer = null);
      },
      onPointerCancel: (e) {
        if (e.pointer == _pointer) setState(() => _pointer = null);
      },
      onPointerUp: (e) {
        if (e.pointer != _pointer) return;
        setState(() => _pointer = null);
        final box = context.findRenderObject() as RenderBox?;
        if (!enabled || box == null || !(Offset.zero & box.size).inflate(12).contains(e.localPosition)) return;
        final s = widget.sound;
        if (s != null) sfx(ref, s);
        widget.onTap!();
      },
      child: AnimatedScale(scale: _pointer != null ? 0.93 : 1, duration: const Duration(milliseconds: 90), child: widget.child),
    );
  }
}

/// A piece of felt: a soft colour, a thick darker edge, a little shadow.
BoxDecoration feltBox(Color color, {double radius = 22, bool shadow = true, Color? edge, double width = 3}) => BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: edge ?? (color.computeLuminance() > .85 ? Felt.line : Felt.edge(color)), width: width),
      boxShadow: shadow ? [BoxShadow(color: Felt.ink.withValues(alpha: .15), offset: const Offset(2, 4), blurRadius: 2)] : null,
    );

/// A round button with an icon.
class RoundButton extends StatelessWidget {
  const RoundButton({super.key, required this.label, required this.icon, this.onTap, this.size = 52, this.color = Colors.white, this.sound = 'tap'});

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color color;
  final String? sound;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        button: true,
        label: label,
        excludeSemantics: true,
        onTap: onTap,
        child: Pressable(
          onTap: onTap,
          sound: sound,
          child: Container(
            width: size,
            height: size,
            decoration: feltBox(color, radius: size / 2),
            child: Icon(icon, size: size * 0.56, color: color == Colors.white ? Felt.ink : Colors.white),
          ),
        ),
      );
}

/// A wide button with a word.
class PillButton extends StatelessWidget {
  const PillButton({super.key, required this.label, this.onTap, this.color = Felt.done, this.icon, this.height = 58, this.sound = 'tap', this.expand = false});

  final String label;
  final VoidCallback? onTap;
  final Color color;
  final IconData? icon;
  final double height;
  final String? sound;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final light = color.computeLuminance() > .6;
    final fg = light ? Felt.ink : Colors.white;
    return Semantics(
      container: true,
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Pressable(
        onTap: onTap,
        sound: sound,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: onTap == null ? .5 : 1,
          child: Container(
            height: height,
            padding: EdgeInsets.symmetric(horizontal: height * 0.38),
            decoration: feltBox(color, radius: height / 2),
            child: Row(mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
              if (icon != null) ...[Icon(icon, size: height * 0.46, color: fg), SizedBox(width: height * .12)],
              Flexible(
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: height * 0.38, fontWeight: FontWeight.w700, color: fg)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// A speech bubble (tap to hear it again).
class Bubble extends StatelessWidget {
  const Bubble({super.key, required this.text, this.onTap, this.size = 18});

  final String text;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        button: onTap != null,
        label: text,
        excludeSemantics: true,
        onTap: onTap,
        child: Pressable(
          onTap: onTap,
          sound: null,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: size * .85, vertical: size * .5),
            decoration: feltBox(Felt.paper, radius: size * 1.2, width: 2.5),
            child: Text(text, style: TextStyle(fontSize: size, fontWeight: FontWeight.w700, color: Felt.ink, height: 1.3)),
          ),
        ),
      );
}

/// The guide the child picked, in a pose (idle, wave, sleep).
class GuideView extends ConsumerWidget {
  const GuideView({super.key, this.size = 90, this.pose = 'idle', this.guide});

  final double size;
  final String pose;
  final Guide? guide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = guide ?? ref.watch(gameProvider.select((g) => g.guide)) ?? Guide.macaque;
    return SizedBox(width: size, height: size, child: Art(g.art(pose)));
  }
}

/// The guide with something to say beside it.
class GuideSays extends StatelessWidget {
  const GuideSays({super.key, required this.text, this.onTap, this.size = 84, this.pose = 'wave', this.textSize = 18});

  final String text;
  final VoidCallback? onTap;
  final double size;
  final String pose;
  final double textSize;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Bob(amount: 3, child: GuideView(size: size, pose: pose)),
        const SizedBox(width: 6),
        Flexible(child: Bubble(text: text, onTap: onTap, size: textSize)),
      ]);
}

/// Plays [music] while this is on screen.
class WithMusic extends ConsumerStatefulWidget {
  const WithMusic({super.key, required this.music, required this.child});

  final Music? music;
  final Widget child;

  @override
  ConsumerState<WithMusic> createState() => _WithMusicState();
}

class _WithMusicState extends ConsumerState<WithMusic> {
  late final Sounds _sounds = ref.read(soundsProvider);

  @override
  void initState() {
    super.initState();
    _sounds.hold(this, widget.music);
  }

  @override
  void didUpdateWidget(WithMusic old) {
    super.didUpdateWidget(old);
    if (old.music != widget.music) _sounds.hold(this, widget.music);
  }

  @override
  void dispose() {
    _sounds.release(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// A gentle bob up and down.
class Bob extends StatefulWidget {
  const Bob({super.key, required this.child, this.phase = 0, this.amount = 4, this.period = 2400});

  final Widget child;
  final double phase;
  final double amount;
  final int period;

  @override
  State<Bob> createState() => _BobState();
}

class _BobState extends State<Bob> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: Duration(milliseconds: widget.period))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, child) => Transform.translate(offset: Offset(0, math.sin((_c.value + widget.phase) * 2 * math.pi) * widget.amount), child: child),
        child: widget.child,
      );
}

/// A background scene (assets/art/scenes/), filling the space from the bottom.
class Scene extends StatelessWidget {
  const Scene(this.path, {super.key, required this.child});

  final String path;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
        ColoredBox(color: Felt.cream, child: Art(path, fit: BoxFit.cover, alignment: Alignment.bottomCenter)),
        child,
      ]);
}

/// Is the space wider than tall (the 「小電視」 layout)?
bool wide(BoxConstraints c) => c.maxWidth > c.maxHeight;

/// The end of a go: a big card with what happened and where to go next.
class DonePanel extends StatelessWidget {
  const DonePanel({super.key, required this.title, required this.actions, this.top});

  final String title;
  final List<Widget> actions;
  final Widget? top;

  @override
  Widget build(BuildContext context) => Container(
        color: Felt.ink.withValues(alpha: .35),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(18),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              decoration: feltBox(Felt.paper, radius: 30),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                top ?? const Bob(amount: 3, child: GuideView(size: 110, pose: 'wave')),
                const SizedBox(height: 8),
                Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Felt.ink, height: 1.35)),
                const SizedBox(height: 8),
                for (final a in actions) Padding(padding: const EdgeInsets.only(top: 10), child: a),
              ]),
            ),
          ),
        ),
      );
}

/// 「一起數」: numbers lighting up one by one, counting up (never a countdown).
class CountDots extends StatelessWidget {
  const CountDots({super.key, required this.count, required this.lit, this.size = 34});

  final int count;

  /// How many are lit (0 to count).
  final int lit;
  final double size;

  @override
  Widget build(BuildContext context) => Wrap(spacing: size * .2, runSpacing: size * .2, children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            key: ValueKey('count-$i'),
            duration: const Duration(milliseconds: 150),
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < lit ? Felt.yellow : Colors.white,
              border: Border.all(color: i < lit ? Felt.edge(Felt.yellow) : Felt.line, width: 2.5),
            ),
            child: Text('${i + 1}', textScaler: TextScaler.noScaling, style: TextStyle(fontSize: size * .5, fontWeight: FontWeight.w700, color: i < lit ? Felt.ink : Felt.inkSoft)),
          ),
      ]);
}

/// The bar of little dots over an adventure: done ones ticked, the current
/// one is its animal.
class StepDots extends StatelessWidget {
  const StepDots({super.key, required this.total, required this.at, this.size = 18});

  final int total;
  final int at;
  final double size;

  @override
  Widget build(BuildContext context) => Wrap(spacing: size * .3, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
        for (var i = 0; i < total; i++)
          Container(
            width: i == at ? size * 1.5 : size,
            height: i == at ? size * 1.5 : size,
            decoration: BoxDecoration(shape: BoxShape.circle, color: i < at ? Felt.done : (i == at ? Felt.yellow : Colors.white), border: Border.all(color: Felt.edge(Felt.line), width: 2)),
            child: i < at ? Icon(Icons.check_rounded, size: size * .8, color: Colors.white) : null,
          ),
      ]);
}

/// The guide's line at the top of a screen, and a speaker to hear it again.
class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.title, this.onHome, this.trailing});

  final String title;
  final VoidCallback? onHome;
  final Widget? trailing;

  /// (The phone's back key does what the home button does.)
  @override
  Widget build(BuildContext context) => BackKey(
        onBack: onHome,
        child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Row(children: [
          if (onHome != null) RoundButton(label: Strings.home, icon: Icons.home_rounded, onTap: onHome, size: 50, color: Felt.stamp) else const SizedBox(width: 50),
          const SizedBox(width: 8),
          Expanded(
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                decoration: feltBox(Felt.paper, radius: 18),
                child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Felt.ink)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          trailing ?? const SizedBox(width: 50),
        ]),
      ),
      );
}
