import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/strings.dart';
import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../core/moves.dart';
import '../../core/providers.dart';

/// The first time the app opens, two questions for the grown-up
/// (docs/design.md 「已經決定的事」 8): how old the child is (the level), and
/// whether to turn on quiet mode (no thumping jumps, for an apartment or the
/// evening). Both can be changed later in parent mode.
class HelloScreen extends ConsumerStatefulWidget {
  const HelloScreen({super.key});

  @override
  ConsumerState<HelloScreen> createState() => _HelloScreenState();
}

class _HelloScreenState extends ConsumerState<HelloScreen> {
  Level? _level;
  bool? _quiet;

  void _next() {
    final level = _level, quiet = _quiet;
    if (level == null || quiet == null) return;
    ref.read(gameProvider.notifier).settings((s) => s.copyWith(level: level, quiet: quiet, asked: true));
    context.go('/guide');
  }

  Widget _choice(String label, bool on, VoidCallback tap) => Semantics(
        container: true,
        button: true,
        selected: on,
        label: label,
        excludeSemantics: true,
        onTap: tap,
        child: Pressable(
          onTap: tap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: feltBox(on ? Felt.yellow : Colors.white, radius: 18, width: on ? 3.5 : 2.5),
            child: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    const note = TextStyle(fontSize: 15, height: 1.5, color: Felt.inkSoft);
    final age = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text(Strings.helloAge, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.4)),
      const SizedBox(height: 10),
      Wrap(spacing: 10, runSpacing: 10, children: [
        for (final l in Level.values) _choice(Strings.levelLine(l), _level == l, () => setState(() => _level = l)),
      ]),
    ]);
    final quiet = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text(Strings.helloQuiet, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.4)),
      const SizedBox(height: 10),
      Wrap(spacing: 10, runSpacing: 10, children: [
        _choice(Strings.quietOn, _quiet == true, () => setState(() => _quiet = true)),
        _choice(Strings.quietOff, _quiet == false, () => setState(() => _quiet = false)),
      ]),
    ]);
    return Scaffold(
      backgroundColor: Felt.parentBg,
      body: SafeArea(
        child: LayoutBuilder(builder: (context, box) {
          final w = wide(box);
          final body = <Widget>[
            Row(children: [
              const Icon(Icons.family_restroom_rounded, color: Felt.inkSoft, size: 30),
              const SizedBox(width: 10),
              const Text(Strings.helloTitle, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
              const Spacer(),
              PillButton(label: Strings.next, icon: Icons.arrow_forward_rounded, onTap: _level != null && _quiet != null ? _next : null, height: 52),
            ]),
            const SizedBox(height: 16),
            if (w)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: age), const SizedBox(width: 24), Expanded(child: quiet)])
            else ...[age, const SizedBox(height: 22), quiet],
            const SizedBox(height: 18),
            const Text(Strings.helloNote, style: note),
          ];
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView(padding: const EdgeInsets.all(20), children: body),
            ),
          );
        }),
      ),
    );
  }
}
