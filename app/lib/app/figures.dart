import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/moves.dart';
import 'widgets.dart';

/// A pom-pom puppet doing a move (docs/design.md 「技術」): its two poses
/// (design/art/animals.py) switch on the beat like stop-motion, and the
/// whole puppet hops, sways, crawls or swims with the music. Both poses are
/// laid out all the time, so switching never waits for a picture to load.
class PoseView extends StatefulWidget {
  const PoseView({
    super.key,
    required this.a,
    required this.b,
    required this.beat,
    required this.beatLength,
    this.motion = Motion.still,
    this.moving = true,
    this.fast = false,
    this.amount = 1,
  });

  /// The two poses (paths under assets/art/).
  final String a, b;

  /// The beat count: each change is a new beat.
  final int beat;
  final Duration beatLength;
  final Motion motion;

  /// False: stands in the first pose, breathing a little.
  final bool moving;

  /// Two poses a beat instead of one.
  final bool fast;

  /// How big the whole-body motion is (1: the full stage, less for small views).
  final double amount;

  @override
  State<PoseView> createState() => _PoseViewState();
}

class _PoseViewState extends State<PoseView> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.beatLength)..forward();

  @override
  void didUpdateWidget(PoseView old) {
    super.didUpdateWidget(old);
    if (old.beatLength != widget.beatLength) _c.duration = widget.beatLength;
    if (old.beat != widget.beat) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Which pose shows at [t] (0..1) of the beat.
  bool _second(double t) {
    if (!widget.moving) return false;
    final slow = widget.motion == Motion.slow || widget.motion == Motion.still;
    if (widget.fast) return (widget.beat * 2 + (t >= .5 ? 1 : 0)).isOdd;
    return slow ? (widget.beat ~/ 2).isOdd : widget.beat.isOdd;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth, h = box.maxHeight;
        return AnimatedBuilder(
          animation: _c,
          builder: (_, _) {
            final t = _c.value;
            final second = _second(t);
            final k = widget.amount;
            final phase = (widget.beat + t) * math.pi;
            var dx = 0.0, dy = 0.0, rot = 0.0, sx = 1.0, sy = 1.0;
            if (widget.moving) {
              switch (widget.motion) {
                case Motion.hop:
                  if (second) dy = -math.sin(math.pi * t) * h * .16 * k;
                  if (!second) sy = 1 - .04 * math.sin(math.pi * t);
                case Motion.bounce:
                  dy = -math.sin(math.pi * t).abs() * h * .04 * k;
                case Motion.sway:
                  rot = math.sin(phase) * .07 * k;
                case Motion.shuffle:
                  dx = math.sin(phase / 2) * w * .07 * k;
                  dy = -math.sin(math.pi * t).abs() * h * .015 * k;
                case Motion.crawl:
                  dx = math.sin(phase / 4) * w * .06 * k;
                  dy = -math.sin(math.pi * t).abs() * h * .012 * k;
                case Motion.swim:
                  dy = math.sin(phase) * h * .03 * k;
                  rot = math.cos(phase) * .04 * k;
                case Motion.slow:
                  dy = math.sin(phase / 2) * h * .012 * k;
                case Motion.still:
                  sx = sy = 1 + .012 * math.sin(phase);
                  rot = math.sin(phase / 2) * .015 * k;
                case Motion.flap:
                  dy = -math.sin(math.pi * t) * h * .035 * k;
                case Motion.stretch:
                  sy = 1 + .035 * math.sin(math.pi * t) * k;
                case Motion.wiggle:
                  rot = math.sin(phase * 2) * .05 * k;
                  dx = math.sin(phase) * w * .02 * k;
              }
            } else {
              sx = sy = 1 + .01 * math.sin(phase);
            }
            return Transform.translate(
              offset: Offset(dx, dy),
              child: Transform(
                alignment: Alignment.bottomCenter,
                transform: Matrix4.diagonal3Values(sx, sy, 1),
                child: Transform.rotate(
                  angle: rot,
                  alignment: Alignment.bottomCenter,
                  child: Stack(fit: StackFit.expand, children: [
                    Opacity(opacity: second ? 0 : 1, child: Art(widget.a)),
                    Opacity(opacity: second ? 1 : 0, child: Art(widget.b)),
                  ]),
                ),
              ),
            );
          },
        );
      });
}

/// The breathing flower (docs/design.md 「慢慢伸展」): it opens while the
/// child breathes in (four seconds) and closes while they breathe out.
class BreathFlower extends StatelessWidget {
  const BreathFlower({super.key, required this.open, this.size = 160});

  /// Opening (breathing in) or closing.
  final bool open;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: AnimatedScale(
          scale: open ? 1 : .62,
          duration: const Duration(seconds: 4),
          curve: Curves.easeInOut,
          child: Stack(fit: StackFit.expand, children: [
            AnimatedOpacity(opacity: open ? 0 : 1, duration: const Duration(seconds: 3), child: const Art('ui/flower_closed')),
            AnimatedOpacity(opacity: open ? 1 : 0, duration: const Duration(seconds: 3), child: const Art('ui/flower_open')),
          ]),
        ),
      );
}
