import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/strings.dart';
import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../core/moves.dart';
import '../../core/providers.dart';
import '../../core/session.dart';
import '../../core/sounds.dart';

/// 自己排 (docs/design.md 「自己排」): tap an animal card and it goes into
/// the next place of 「我的體操」; tap a card in the row to take it out. Only
/// tapping, no dragging, so 2-year-olds can do it. The last place is always
/// the slow stretch. 「隨便來一個」 picks a card (not a prize draw: every card
/// is already there). Up to six routines are kept, named after their first
/// animal. Only moves a parent left on are offered.
class BuildScreen extends ConsumerStatefulWidget {
  const BuildScreen({super.key});

  static const minCards = 3;

  @override
  ConsumerState<BuildScreen> createState() => _BuildScreenState();
}

class _BuildScreenState extends ConsumerState<BuildScreen> with HushOnLeave {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Cards a parent has turned off since are taken out of the row.
      _set(ref.read(draftProvider));
      speak(ref, Strings.pickCards);
    });
  }

  List<String> get _row => ref.read(draftProvider);

  void _set(List<String> ids) {
    final s = ref.read(gameProvider).settings;
    ref.read(draftProvider.notifier).set([
      for (final id in ids)
        if (movesById[id] case final m? when s.allows(m) && !m.stretch) id,
    ].take(s.level.maxCards).toList());
  }

  void _add(Move m) {
    final max = ref.read(gameProvider).settings.level.maxCards;
    if (_row.length >= max) {
      speak(ref, Strings.full);
      return;
    }
    sfx(ref, 'card');
    _set([..._row, m.id]);
    speak(ref, Strings.added(m.zh));
  }

  void _remove(int i) {
    sfx(ref, 'pop');
    _set([..._row]..removeAt(i));
  }

  void _random() {
    final s = ref.read(gameProvider).settings;
    if (_row.length >= s.level.maxCards) {
      speak(ref, Strings.full);
      return;
    }
    final m = randomCard(s, _row, ref.read(randomProvider));
    if (m == null) return;
    sfx(ref, 'dice');
    _set([..._row, m.id]);
    speak(ref, Strings.added(m.zh));
  }

  void _start() {
    if (_row.length < BuildScreen.minCards) {
      speak(ref, Strings.needMore(BuildScreen.minCards - _row.length));
      return;
    }
    context.go('/run');
  }

  void _save() {
    if (_row.isEmpty) return;
    sfx(ref, 'stamp');
    ref.read(gameProvider.notifier).change((g) => g.save(_row));
    speak(ref, Strings.routineName(movesById[_row.first]!.species.zh));
  }

  @override
  Widget build(BuildContext context) {
    final g = ref.watch(gameProvider);
    final s = g.settings;
    final row = ref.watch(draftProvider);
    final cards = buildCards(s);
    final end = stretchFor('tortoise', s);
    return WithMusic(
      music: Music.home,
      child: Scaffold(
        body: Scene(
          'scenes/home',
          child: SafeArea(
            child: LayoutBuilder(builder: (context, box) {
              final w = wide(box);
              final slot = w ? (box.maxHeight * .24).clamp(64.0, 120.0) : ((box.maxWidth - 40) / 5).clamp(56.0, 110.0);
              final slots = Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                for (var i = 0; i < s.level.maxCards; i++)
                  i < row.length
                      ? _Card(key: ValueKey('slot-$i'), move: movesById[row[i]]!, size: slot, onTap: () => _remove(i), label: '拿掉${movesById[row[i]]!.zh}')
                      : Container(key: ValueKey('empty-$i'), width: slot, height: slot * 1.15, decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: Felt.edge(Felt.line), width: 2.5), color: Colors.white.withValues(alpha: .5)), alignment: Alignment.center, child: Text('${i + 1}', style: TextStyle(fontSize: slot * .3, color: Felt.inkSoft))),
                Icon(Icons.arrow_forward_rounded, color: Felt.inkSoft, size: slot * .3),
                Opacity(
                  opacity: .85,
                  child: end == null
                      ? SizedBox(width: slot, height: slot * 1.15, child: const Art('ui/flower_open'))
                      : _Card(key: const ValueKey('slot-end'), move: end, size: slot, label: Strings.lastIsStretch),
                ),
              ]);
              final buttons = Wrap(spacing: 10, runSpacing: 8, alignment: WrapAlignment.center, children: [
                PillButton(label: Strings.random, icon: Icons.casino_rounded, onTap: _random, height: 50, color: Felt.yellow, sound: null),
                PillButton(label: Strings.save, icon: Icons.bookmark_add_rounded, onTap: row.isEmpty ? null : _save, height: 50, color: Colors.white, sound: null),
                PillButton(label: Strings.start, icon: Icons.play_arrow_rounded, onTap: _start, height: 56, color: Felt.done),
              ]);
              final saved = g.routines.isEmpty
                  ? const SizedBox.shrink()
                  : Wrap(spacing: 8, runSpacing: 6, children: [
                      for (var i = 0; i < g.routines.length; i++)
                        Semantics(
                          key: ValueKey('routine-$i'),
                          container: true,
                          button: true,
                          label: Strings.routineName(movesById[g.routines[i].first]!.species.zh),
                          excludeSemantics: true,
                          onTap: () => _set(g.routines[i]),
                          child: Pressable(
                            onTap: () => _set(g.routines[i]),
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
                              decoration: feltBox(Felt.paper, radius: 20, width: 2),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                SizedBox(width: 34, height: 34, child: Art(poseArt(movesById[g.routines[i].first]!, movesById[g.routines[i].first]!.species, 'a'))),
                                const SizedBox(width: 4),
                                Text(Strings.routineName(movesById[g.routines[i].first]!.species.zh), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                              ]),
                            ),
                          ),
                        ),
                    ]);
              final grid = GridView.extent(
                key: const ValueKey('grid'),
                maxCrossAxisExtent: w ? 110 : 120,
                childAspectRatio: 1 / 1.15,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                padding: const EdgeInsets.all(10),
                children: [for (final m in cards) _Card(key: ValueKey('card-${m.id}'), move: m, size: 110, onTap: () => _add(m))],
              );
              final head = TopBar(title: Strings.build, onHome: () => context.go('/'));
              final rowBox = Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                padding: const EdgeInsets.all(8),
                decoration: feltBox(Felt.paper.withValues(alpha: .92), radius: 20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  const Text(Strings.myRoutine, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  SingleChildScrollView(scrollDirection: Axis.horizontal, child: slots),
                ]),
              );
              if (w) {
                return Column(children: [
                  head,
                  rowBox,
                  Expanded(
                    child: Row(children: [
                      Expanded(child: grid),
                      SizedBox(
                        width: (box.maxWidth * .3).clamp(220.0, 360.0),
                        child: SingleChildScrollView(padding: const EdgeInsets.all(8), child: Column(children: [buttons, const SizedBox(height: 10), saved])),
                      ),
                    ]),
                  ),
                ]);
              }
              return Column(children: [
                head,
                rowBox,
                const SizedBox(height: 8),
                buttons,
                if (g.routines.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(10, 8, 10, 0), child: saved),
                Expanded(child: grid),
              ]);
            }),
          ),
        ),
      ),
    );
  }
}

/// An animal card: the animal in its first pose and the move's name.
class _Card extends StatelessWidget {
  const _Card({super.key, required this.move, required this.size, this.onTap, this.label});

  final Move move;
  final double size;
  final VoidCallback? onTap;
  final String? label;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        button: onTap != null,
        label: label ?? move.zh,
        excludeSemantics: true,
        onTap: onTap,
        child: Pressable(
          onTap: onTap,
          sound: null,
          child: Container(
            width: size,
            height: size * 1.15,
            padding: EdgeInsets.all(size * .05),
            decoration: feltBox(Colors.white, radius: size * .16, width: 2.5),
            child: Column(children: [
              Expanded(child: Art(poseArt(move, move.species, 'a'))),
              Text(move.zh, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: (size * .14).clamp(11, 16).toDouble(), fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );
}
