import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/strings.dart';
import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../core/providers.dart';
import '../../core/sounds.dart';
import '../parent/parent_gate.dart';

/// The play time is up (docs/design.md 「休息」): the animals lie down for a
/// nap, and the child is sent off to move for real: 「換你去做了！」 「關掉螢幕，
/// 去外面走一走、跳一跳吧！」 Only a parent (through the gate) or an hour's
/// wait lets play go on.
class RestScreen extends ConsumerStatefulWidget {
  const RestScreen({super.key});

  @override
  ConsumerState<RestScreen> createState() => _RestScreenState();
}

class _RestScreenState extends ConsumerState<RestScreen> with HushOnLeave {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(windDownProvider.notifier).set(false);
      sfx(ref, 'night');
      speak(ref, '${Strings.restTitle}${Strings.restLine}');
    });
  }

  Future<void> _parent() async {
    if (!await showParentGate(context, pass: false) || !mounted) return;
    ref.read(gameProvider.notifier).change((g) => g.playOn());
    ref.read(sessionStartProvider.notifier).restart();
    context.go('/');
  }

  @override
  Widget build(BuildContext context) => WithMusic(
        music: Music.rest,
        child: Scaffold(
          body: DecoratedBox(
            decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Felt.night1, Felt.night2])),
            child: Stack(fit: StackFit.expand, children: [
              const Art('scenes/rest', fit: BoxFit.cover, alignment: Alignment.bottomCenter),
              SafeArea(
                child: LayoutBuilder(builder: (context, box) {
                  final w = wide(box);
                  final text = Container(
                    padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
                    decoration: feltBox(Felt.paper, radius: 26),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text(Strings.restTitle, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      const Text(Strings.restLine, textAlign: TextAlign.center, style: TextStyle(fontSize: 22, height: 1.4)),
                      const SizedBox(height: 8),
                      Text(Strings.restNote, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, height: 1.4, color: Felt.inkSoft.withValues(alpha: .9))),
                    ]),
                  );
                  final sleeper = Stack(clipBehavior: Clip.none, children: [
                    GuideView(size: math.min(box.maxWidth, box.maxHeight) * (w ? .5 : .55), pose: 'sleep'),
                    Positioned(right: 0, top: 0, child: Bob(amount: 4, child: Text('Z z z', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: .9))))),
                  ]);
                  return Stack(children: [
                    if (w)
                      Row(children: [
                        Expanded(child: Center(child: sleeper)),
                        Expanded(child: Center(child: Padding(padding: const EdgeInsets.all(16), child: text))),
                      ])
                    else
                      Column(children: [
                        Padding(padding: const EdgeInsets.fromLTRB(20, 40, 20, 10), child: text),
                        Expanded(child: Center(child: sleeper)),
                      ]),
                    Positioned(
                      right: 16,
                      bottom: 14,
                      child: Semantics(
                        container: true,
                        button: true,
                        label: Strings.parent,
                        excludeSemantics: true,
                        onTap: _parent,
                        child: Pressable(
                          onTap: _parent,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: feltBox(Colors.white.withValues(alpha: .9), radius: 22, shadow: false),
                            child: const Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.lock_outline_rounded, color: Felt.inkSoft, size: 20),
                              SizedBox(width: 6),
                              Text(Strings.parent, style: TextStyle(fontSize: 16, color: Felt.inkSoft)),
                            ]),
                          ),
                        ),
                      ),
                    ),
                  ]);
                }),
              ),
            ]),
          ),
        ),
      );
}
