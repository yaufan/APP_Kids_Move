import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/strings.dart';
import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../core/adventures.dart';
import '../../core/guides.dart';
import '../../core/moves.dart';
import '../../core/providers.dart';
import '../../core/session.dart';
import '../../core/sounds.dart';
import '../parent/parent_gate.dart';

/// The home screen (docs/design.md 「首頁」): the five adventure cards (a red
/// 「去過了」 stamp on the ones finished today: not a score), the three big
/// buttons (動物舞會、自己排、慢慢伸展), the parent's lock, and the guide.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with HushOnLeave {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final g = ref.read(gameProvider).guide ?? Guide.macaque;
      speak(ref, '${g.hi}${Strings.whereToGo}');
    });
  }

  void _locked() => speak(ref, Strings.fullOnly);

  void _adventure(Adventure a) {
    if (!ref.read(gameProvider).settings.opens(a)) return _locked();
    context.go('/go/${a.id}');
  }

  Future<void> _parent() async {
    if (!await showParentGate(context) || !mounted) return;
    context.go('/parent');
  }

  /// The animal on an adventure's card.
  static String leadArt(Adventure a) {
    final step = a.steps.firstWhere((s) => (s.species ?? movesById[s.move]!.species) == a.lead, orElse: () => a.steps.first);
    final m = movesById[step.move]!;
    return poseArt(m, step.species ?? m.species, 'a');
  }

  @override
  Widget build(BuildContext context) {
    final g = ref.watch(gameProvider);
    final now = ref.read(clockProvider)();
    final s = g.settings;
    return WithMusic(
      music: Music.home,
      child: Scaffold(
        body: Scene(
          'scenes/home',
          child: SafeArea(
            child: LayoutBuilder(builder: (context, box) {
              final w = wide(box);
              Widget cardsOf(double cardH) => SizedBox(
                    height: cardH,
                    child: ListView(
                      key: const ValueKey('cards'),
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        for (final a in adventures)
                          Padding(
                            padding: const EdgeInsets.only(right: 14),
                            child: _AdventureCard(
                              adventure: a,
                              height: cardH - 8,
                              steps: adventurePlan(a, s).steps.length,
                              stamped: g.stamped(a.id, now),
                              locked: !s.opens(a),
                              onTap: () => _adventure(a),
                            ),
                          ),
                      ],
                    ),
                  );
              // Upright, two big buttons a row (smaller on a narrow phone, so
              // three rows never push the guide off a 360 × 640 screen).
              final labels = [Strings.party, Strings.build, Strings.calm];
              var btnH = w ? (box.maxHeight * .17).clamp(52.0, 76.0) : 64.0;
              if (!w) {
                final room = box.maxWidth - 24;
                double two(double h) => _BigButton.widthFor(context, labels[0], h) + _BigButton.widthFor(context, labels[2], h) + 12;
                while (btnH > 48 && two(btnH) > room) {
                  btnH -= 2;
                }
              }
              final big = [
                _BigButton(label: Strings.party, art: 'ui/party', color: Felt.lilac, height: btnH, onTap: () => context.go('/party')),
                _BigButton(label: Strings.build, art: 'ui/build', color: Felt.mint, height: btnH, locked: !s.buildOpen, onTap: s.buildOpen ? () => context.go('/build') : _locked),
                _BigButton(label: Strings.calm, art: 'ui/calm', color: Felt.calm1, height: btnH, onTap: () => context.go('/calm')),
              ];
              final buttons = Wrap(spacing: 12, runSpacing: 10, alignment: WrapAlignment.center, children: big);
              final buttonRow = Row(mainAxisSize: MainAxisSize.min, children: [for (final b in big) Padding(padding: const EdgeInsets.only(right: 12), child: b)]);
              final top = Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
                child: Row(children: [
                  Semantics(
                    container: true,
                    button: true,
                    label: Strings.parent,
                    excludeSemantics: true,
                    onTap: _parent,
                    child: Pressable(
                      onTap: _parent,
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: feltBox(Colors.white.withValues(alpha: .9), radius: 25, shadow: false),
                        child: const Icon(Icons.lock_outline_rounded, color: Felt.inkSoft),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 6),
                        decoration: feltBox(Felt.stamp, radius: 22),
                        child: const Text(Strings.appName, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 2)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 60),
                ]),
              );
              // Upright, the cards take what the buttons and the guide leave
              // (at most four tenths of the screen).
              final perRow = w ? 3 : (labels.map((l) => _BigButton.widthFor(context, l, btnH)).fold(0.0, (a, b) => a + b) + 24 <= box.maxWidth - 24 ? 3 : 2);
              final rows = (labels.length + perRow - 1) ~/ perRow;
              final guideSize = !w && box.maxHeight < 640 ? 76.0 : 92.0;
              final fixed = 62 + 10 + 16 + rows * btnH + (rows - 1) * 10 + guideSize + 12 + 8;
              final cards = cardsOf(math.min(box.maxHeight * .4, math.max(150.0, box.maxHeight - fixed)));
              final guide = GuideSays(text: Strings.whereToGo, size: w ? box.maxHeight * .2 : guideSize, textSize: 16, onTap: () => speak(ref, Strings.whereToGo));
              if (w) {
                final bottom = btnH + 14;
                return Column(children: [
                  top,
                  Expanded(child: LayoutBuilder(builder: (context, b) => Align(alignment: Alignment.topLeft, child: SizedBox(height: b.maxHeight - 6, child: cardsOf(b.maxHeight - 6))))),
                  SizedBox(
                    height: bottom,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Expanded(child: Align(alignment: Alignment.bottomLeft, child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.bottomLeft, child: buttonRow))),
                        const SizedBox(width: 8),
                        ConstrainedBox(constraints: BoxConstraints(maxWidth: box.maxWidth * .26), child: GuideSays(text: Strings.whereToGo, size: bottom - 8, textSize: 15, onTap: () => speak(ref, Strings.whereToGo))),
                      ]),
                    ),
                  ),
                ]);
              }
              return Column(children: [
                top,
                const SizedBox(height: 10),
                cards,
                const SizedBox(height: 16),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: buttons),
                const Spacer(),
                Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: Align(alignment: Alignment.centerRight, child: guide)),
              ]);
            }),
          ),
        ),
      ),
    );
  }
}

class _AdventureCard extends StatelessWidget {
  const _AdventureCard({required this.adventure, required this.height, required this.steps, required this.stamped, required this.locked, required this.onTap});

  final Adventure adventure;
  final double height;
  final int steps;
  final bool stamped;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final a = adventure;
    final w = height * .82;
    return Semantics(
      key: ValueKey('adventure-${a.id}'),
      container: true,
      button: true,
      label: a.zh,
      excludeSemantics: true,
      onTap: onTap,
      child: Pressable(
        onTap: onTap,
        child: Container(
          width: w,
          height: height,
          decoration: feltBox(Color(a.color), radius: 24),
          child: Stack(children: [
            Positioned.fill(
              child: Column(children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(21)),
                    child: Stack(fit: StackFit.expand, children: [
                      Opacity(opacity: .85, child: Art(a.scene, fit: BoxFit.cover, alignment: Alignment.bottomCenter)),
                      Padding(padding: EdgeInsets.all(height * .05), child: Art(_HomeScreenState.leadArt(a))),
                    ]),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(8, height * .03, 8, height * .04),
                  child: Column(children: [
                    Text(a.zh, maxLines: 1, style: TextStyle(fontSize: (height * .1).clamp(15, 26).toDouble(), fontWeight: FontWeight.w700)),
                    Text(Strings.card(steps, (steps * 0.9).round().clamp(2, 9)), maxLines: 1, style: TextStyle(fontSize: (height * .06).clamp(11, 15).toDouble(), color: Felt.ink.withValues(alpha: .75))),
                  ]),
                ),
              ]),
            ),
            if (stamped)
              Positioned(
                right: 6,
                top: 6,
                child: Transform.rotate(
                  angle: -.25,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(border: Border.all(color: Felt.stamp, width: 3), borderRadius: BorderRadius.circular(10), color: Colors.white.withValues(alpha: .7)),
                    child: const Text(Strings.been, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Felt.stamp)),
                  ),
                ),
              ),
            if (locked)
              Positioned(left: 8, top: 8, width: height * .16, height: height * .16, child: const Art('ui/lock')),
          ]),
        ),
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({required this.label, required this.art, required this.color, required this.height, required this.onTap, this.locked = false});

  static TextStyle _style(double height) => TextStyle(fontSize: height * .34, fontWeight: FontWeight.w700);

  /// How wide a button [height] high with [label] is.
  static double widthFor(BuildContext context, String label, double height) {
    final text = TextPainter(
      text: TextSpan(text: label, style: DefaultTextStyle.of(context).style.merge(_style(height))),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    return height * (.12 + .84 + .1 + .3) + text.width + 1;
  }

  final String label;
  final String art;
  final Color color;
  final double height;
  final VoidCallback onTap;
  final bool locked;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        button: true,
        label: label,
        excludeSemantics: true,
        onTap: onTap,
        child: Pressable(
          onTap: onTap,
          child: Container(
            height: height,
            padding: EdgeInsets.fromLTRB(height * .12, height * .08, height * .3, height * .08),
            decoration: feltBox(color, radius: height / 2),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(width: height * .84, height: height * .84, child: Art(locked ? 'ui/lock' : art)),
              SizedBox(width: height * .1),
              Text(label, style: _style(height)),
            ]),
          ),
        ),
      );
}
