import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/strings.dart';
import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../core/providers.dart';
import '../../core/sounds.dart';

/// 「動之前，先看看四周」 (docs/design.md 「安全」 1): before every go (or the
/// first each day, if the parent chose), the guide reads each card out and
/// it is ticked; the child spins with arms out to check for room; then
/// 「準備好了！」 starts the go.
class SpaceScreen extends ConsumerStatefulWidget {
  const SpaceScreen({super.key, required this.next});

  /// Where to go once ready (a moving screen).
  final String next;

  @override
  ConsumerState<SpaceScreen> createState() => _SpaceScreenState();
}

class _SpaceScreenState extends ConsumerState<SpaceScreen> with HushOnLeave {
  static const _art = ['safety/clear', 'safety/nobed', 'safety/feet', 'safety/phone'];

  /// How many lines have been read (the four cards, then the spin).
  var _read = 0;
  Later? _later;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      sfx(ref, 'look');
      _say();
    });
  }

  void _say() {
    if (!mounted) return;
    final lines = [...Strings.space, Strings.spin, Strings.readyLine];
    if (_read >= lines.length) return;
    final line = _read == 0 ? '${Strings.spaceTitle}。${lines[0]}' : lines[_read];
    _later = Later(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      if (_read < 5) sfx(ref, 'tick');
      setState(() => _read++);
      _say();
    }, after: speak(ref, line));
  }

  @override
  void dispose() {
    _later?.cancel();
    super.dispose();
  }

  void _ready() {
    _later?.cancel();
    ref.read(spaceOkProvider.notifier).set(true);
    ref.read(gameProvider.notifier).change((g) => g.checked(ref.read(clockProvider)()));
    context.go(widget.next);
  }

  Widget _card(int i, double size) {
    final done = _read > i;
    return Container(
      key: ValueKey('space-$i'),
      width: size,
      padding: const EdgeInsets.all(8),
      decoration: feltBox(done ? Felt.mint : Felt.paper, radius: 18, width: _read == i ? 4 : 3, edge: _read == i ? Felt.pause : null),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Stack(children: [
          SizedBox(width: size * .8, height: size * .55, child: Art(_art[i])),
          if (done) Positioned(right: 0, top: 0, width: size * .22, height: size * .22, child: const Art('ui/check')),
        ]),
        const SizedBox(height: 4),
        Text(Strings.space[i], textAlign: TextAlign.center, style: TextStyle(fontSize: (size * .085).clamp(12, 18).toDouble(), height: 1.3, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => WithMusic(
        music: Music.home,
        child: Scaffold(
          body: Scene(
            'scenes/home',
            child: SafeArea(
              child: LayoutBuilder(builder: (context, box) {
                final w = wide(box);
                final spin = Column(mainAxisSize: MainAxisSize.min, children: [
                  Expanded(
                    child: Stack(alignment: Alignment.center, children: [
                      const Art('safety/spin'),
                      if (_read > 4) const Positioned(right: 0, top: 0, width: 46, height: 46, child: Art('ui/check')),
                    ]),
                  ),
                  Text(Strings.spin, textAlign: TextAlign.center, style: TextStyle(fontSize: w ? 17 : 19, fontWeight: FontWeight.w700, color: _read == 4 ? Felt.edge(Felt.pause) : Felt.ink)),
                ]);
                final ready = PillButton(label: Strings.ready, icon: Icons.check_rounded, onTap: _ready, height: w ? 58 : 66, sound: 'ready');
                final title = TopBar(title: Strings.spaceTitle, onHome: () => context.go('/'));
                if (w) {
                  final size = ((box.maxHeight - 90) / 2 - 10).clamp(90.0, box.maxWidth * .22);
                  return Column(children: [
                    title,
                    Expanded(
                      child: Row(children: [
                        Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(16, 4, 8, 8), child: Column(children: [Expanded(child: spin), const SizedBox(height: 6), ready]))),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
                          child: SizedBox(
                            width: size * 2 + 12,
                            child: Wrap(spacing: 12, runSpacing: 10, children: [for (var i = 0; i < 4; i++) _card(i, size)]),
                          ),
                        ),
                      ]),
                    ),
                  ]);
                }
                final size = ((box.maxWidth - 44) / 2).clamp(100.0, 260.0);
                return Column(children: [
                  title,
                  Expanded(child: Padding(padding: const EdgeInsets.all(8), child: spin)),
                  Wrap(spacing: 12, runSpacing: 10, alignment: WrapAlignment.center, children: [for (var i = 0; i < 4; i++) _card(i, size)]),
                  const SizedBox(height: 14),
                  ready,
                  const SizedBox(height: 16),
                ]);
              }),
            ),
          ),
        ),
      );
}
