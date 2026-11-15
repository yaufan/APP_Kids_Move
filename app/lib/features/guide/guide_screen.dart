import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/strings.dart';
import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../core/guides.dart';
import '../../core/providers.dart';

/// The child picks the animal that leads the way (docs/design.md
/// 「已經決定的事」 9): six Taiwanese animals, only a look and a voice, no
/// name to type. Parent mode can let the child pick again.
class GuideScreen extends ConsumerStatefulWidget {
  const GuideScreen({super.key});

  @override
  ConsumerState<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends ConsumerState<GuideScreen> with HushOnLeave {
  Guide? _picked;
  Later? _later;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) speak(ref, Strings.pickGuide);
    });
  }

  @override
  void dispose() {
    _later?.cancel();
    super.dispose();
  }

  void _pick(Guide g) {
    if (_picked != null) return;
    setState(() => _picked = g);
    ref.read(gameProvider.notifier).change((x) => x.copyWith(guide: g));
    sfx(ref, g.call);
    _later = Later(const Duration(milliseconds: 1800), () {
      if (mounted) context.go('/');
    }, after: speak(ref, g.hello));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Scene(
          'scenes/home',
          child: SafeArea(
            child: LayoutBuilder(builder: (context, box) {
              final w = wide(box);
              final cols = w ? 3 : 2;
              final rows = 6 ~/ cols;
              final cell = ((box.maxHeight - 90) / rows - 12).clamp(80.0, (box.maxWidth - 40) / cols - 12);
              return Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: feltBox(Felt.paper, radius: 20),
                    child: const Text(Strings.pickGuide, textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: [
                      for (final g in Guide.values)
                        Semantics(
                          key: ValueKey('guide-${g.name}'),
                          container: true,
                          button: true,
                          label: g.zh,
                          excludeSemantics: true,
                          onTap: () => _pick(g),
                          child: Pressable(
                            onTap: () => _pick(g),
                            sound: null,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: cell * 1.1,
                              height: cell,
                              padding: const EdgeInsets.all(6),
                              decoration: feltBox(_picked == g ? Felt.yellow : Felt.paper, radius: 24, width: _picked == g ? 4 : 3),
                              child: Column(children: [
                                Expanded(child: GuideView(guide: g, size: cell * .78, pose: _picked == g ? 'wave' : 'idle')),
                                Text(g.zh, style: TextStyle(fontSize: (cell * .14).clamp(14, 22).toDouble(), fontWeight: FontWeight.w700)),
                              ]),
                            ),
                          ),
                        ),
                    ]),
                  ),
                ),
              ]);
            }),
          ),
        ),
      );
}
