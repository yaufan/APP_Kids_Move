import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/strings.dart';
import '../../app/theme.dart';
import '../../app/version.dart';
import '../../app/widgets.dart';
import '../../core/game.dart';
import '../../core/moves.dart';
import '../../core/providers.dart';

/// Parent mode (after the gate, docs/design.md 「家長模式」): the level, the
/// play time, the safety settings (quiet mode, a small space, the check,
/// which moves), 「做好了！」, a grown-up joining in, the week's minutes of
/// following and what was trained, the voice and sounds, the guide, the
/// full version.
class ParentScreen extends ConsumerWidget {
  const ParentScreen({super.key});

  static const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = ref.watch(gameProvider);
    final s = g.settings;
    final game = ref.read(gameProvider.notifier);
    final now = ref.read(clockProvider)();

    Widget section(String title, List<Widget> children, {Key? key}) => Padding(
          key: key,
          padding: const EdgeInsets.only(bottom: 16),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 15, color: Felt.inkSoft, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ...children,
              ]),
            ),
          ),
        );

    Widget toggle(String label, bool value, void Function(bool)? set, {Key? key, String? note}) => SwitchListTile(
          key: key,
          contentPadding: EdgeInsets.zero,
          title: Text(label, style: const TextStyle(fontSize: 17)),
          subtitle: note == null ? null : Text(note, style: const TextStyle(fontSize: 13, color: Felt.inkSoft, height: 1.4)),
          value: value,
          onChanged: set,
        );

    Widget chips<T>(List<T> values, T selected, String Function(T) label, void Function(T) pick, String keyOf) => Wrap(spacing: 8, runSpacing: 8, children: [
          for (final v in values)
            ChoiceChip(
              key: ValueKey('$keyOf-${v is Enum ? v.name : v}'),
              label: Text(label(v), style: const TextStyle(fontSize: 16)),
              selected: v == selected,
              onSelected: (_) => pick(v),
              selectedColor: const Color(0xFFFFE3B8),
              showCheckmark: false,
            ),
        ]);

    const note = TextStyle(fontSize: 14, height: 1.5, color: Felt.inkSoft);
    final week = Days.week(now);
    final most = [for (final d in week) g.movedOn(d)].fold(60, (a, b) => a > b ? a : b);
    final skills = <Skill, int>{};
    for (final id in g.recent) {
      for (final sk in movesById[id]!.skills) {
        skills[sk] = (skills[sk] ?? 0) + 1;
      }
    }

    return Scaffold(
      backgroundColor: Felt.parentBg,
      appBar: AppBar(
        backgroundColor: Felt.parentBg,
        title: const Text(Strings.parentTitle),
        leading: IconButton(icon: const Icon(Icons.close_rounded), tooltip: Strings.back, onPressed: () => context.go('/')),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
            section(Strings.levelTitle, [
              chips(Level.values, s.level, Strings.levelLine, (v) => game.settings((x) => x.copyWith(level: v)), 'level'),
              const SizedBox(height: 10),
              const Text(Strings.levelNote, style: note),
            ]),
            section(Strings.playTime, [
              chips(Settings.minuteChoices, s.minutes, Strings.minutes, (v) => game.settings((x) => x.copyWith(minutes: v)), 'minutes'),
              const SizedBox(height: 10),
              const Text(Strings.playTimeNote, style: note),
              if (g.resting(now)) ...[
                const SizedBox(height: 10),
                const Text(Strings.resting, style: TextStyle(fontSize: 16)),
                const SizedBox(height: 6),
                FilledButton(
                  key: const ValueKey('play-on'),
                  onPressed: () {
                    game.change((g) => g.playOn());
                    ref.read(sessionStartProvider.notifier).restart();
                    context.go('/');
                  },
                  child: const Text(Strings.playOn),
                ),
              ],
            ]),
            section(Strings.weekTitle, [
              SizedBox(
                key: const ValueKey('week'),
                height: 130,
                child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  for (final d in week)
                    Expanded(
                      child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                        Text('${(g.movedOn(d) / 60).round()}', style: const TextStyle(fontSize: 13, color: Felt.inkSoft)),
                        const SizedBox(height: 2),
                        Container(
                          height: 80 * g.movedOn(d) / most + 2,
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(color: d == week.last ? Felt.done : Felt.mint, borderRadius: BorderRadius.circular(6)),
                        ),
                        const SizedBox(height: 4),
                        Text(_weekdays[Days.parse(d)!.weekday - 1], style: const TextStyle(fontSize: 14)),
                      ]),
                    ),
                ]),
              ),
              const SizedBox(height: 8),
              Text(Strings.todayPlayed((g.playedOn(week.last) / 60).round()), style: const TextStyle(fontSize: 15)),
              const SizedBox(height: 4),
              const Text(Strings.weekNote, style: note),
            ]),
            section(Strings.skillsTitle, [
              if (skills.isEmpty)
                const Text(Strings.nothingYet, style: note)
              else
                Wrap(spacing: 8, runSpacing: 6, children: [
                  for (final e in (skills.entries.toList()..sort((a, b) => b.value - a.value))) Chip(label: Text('${e.key.zh} ×${e.value}', style: const TextStyle(fontSize: 15))),
                ]),
              if (g.recent.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(g.recent.take(10).map((id) => movesById[id]!.zh).join('、'), style: note),
              ],
            ]),
            section(Strings.safetyTitle, [
              toggle(Strings.quiet, s.quiet, (v) => game.settings((x) => x.copyWith(quiet: v)), key: const ValueKey('quiet'), note: Strings.quietNote),
              toggle(Strings.smallSpace, s.smallSpace, (v) => game.settings((x) => x.copyWith(smallSpace: v)), key: const ValueKey('small-space'), note: Strings.smallSpaceNote),
              toggle(Strings.checkDaily, s.checkDaily, (v) => game.settings((x) => x.copyWith(checkDaily: v)), key: const ValueKey('check-daily'), note: Strings.checkDailyNote),
              toggle(Strings.mustTap, s.mustTap, (v) => game.settings((x) => x.copyWith(mustTap: v)), key: const ValueKey('must-tap'), note: Strings.mustTapNote),
              toggle(Strings.togetherTitle, s.together, (v) => game.settings((x) => x.copyWith(together: v)), key: const ValueKey('together'), note: Strings.togetherNote),
            ]),
            section(Strings.movesTitle, key: const ValueKey('moves'), [
              const Text(Strings.movesNote, style: note),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                OutlinedButton(
                  key: const ValueKey('no-jumps'),
                  onPressed: () => game.settings((x) => x.copyWith(off: {...x.off, for (final m in moves) if (m.jump) m.id})),
                  child: const Text(Strings.noJumps),
                ),
                OutlinedButton(
                  key: const ValueKey('no-floor'),
                  onPressed: () => game.settings((x) => x.copyWith(off: {...x.off, for (final m in moves) if (m.floor) m.id})),
                  child: const Text(Strings.noFloor),
                ),
                OutlinedButton(key: const ValueKey('all-on'), onPressed: () => game.settings((x) => x.copyWith(off: const {})), child: const Text(Strings.allOn)),
              ]),
              const SizedBox(height: 4),
              for (final m in moves)
                SwitchListTile(
                  key: ValueKey('move-${m.id}'),
                  contentPadding: EdgeInsets.zero,
                  secondary: SizedBox(width: 48, height: 48, child: Art(poseArt(m, m.species, 'a'))),
                  title: Text('${m.zh}（${m.species.zh}）', style: const TextStyle(fontSize: 17)),
                  subtitle: Text('${Strings.moveLine(m)}\n${Strings.moveNote(m)}', style: const TextStyle(fontSize: 13, color: Felt.inkSoft, height: 1.4)),
                  isThreeLine: true,
                  value: !s.off.contains(m.id),
                  onChanged: (on) => game.settings((x) => x.copyWith(off: on ? ({...x.off}..remove(m.id)) : {...x.off, m.id})),
                ),
            ]),
            section(Strings.voiceTitle, [
              toggle(Strings.voice, s.voice, (v) => game.settings((x) => x.copyWith(voice: v)), key: const ValueKey('voice')),
              toggle(Strings.slow, s.slow, (v) => game.settings((x) => x.copyWith(slow: v)), key: const ValueKey('slow')),
              toggle(Strings.music, s.music, (v) => game.settings((x) => x.copyWith(music: v)), key: const ValueKey('music')),
              toggle(Strings.effects, s.sounds, (v) => game.settings((x) => x.copyWith(sounds: v)), key: const ValueKey('effects')),
              const Text(Strings.volumeNote, style: note),
            ]),
            section(Strings.guideTitle, [
              Row(children: [
                const GuideView(size: 64),
                const SizedBox(width: 12),
                Expanded(child: Text(g.guide?.zh ?? '', style: const TextStyle(fontSize: 18))),
                OutlinedButton.icon(
                  key: const ValueKey('change-guide'),
                  onPressed: () {
                    game.change((g) => g.copyWith(clearGuide: true));
                    context.go('/guide');
                  },
                  icon: const Icon(Icons.pets_rounded),
                  label: const Text(Strings.changeGuide),
                ),
              ]),
            ]),
            if (g.routines.isNotEmpty)
              section(Strings.routinesTitle, [
                for (final r in g.routines) Text('${Strings.routineName(movesById[r.first]!.species.zh)}：${r.map((id) => movesById[id]!.zh).join('、')}', style: const TextStyle(fontSize: 15, height: 1.5)),
                const SizedBox(height: 6),
                OutlinedButton(key: const ValueKey('clear-routines'), onPressed: () => game.change((g) => g.copyWith(routines: const [])), child: const Text(Strings.clearRoutines)),
              ]),
            section(Strings.fullVersion, [
              const Text(Strings.fullNote, style: note),
              toggle(Strings.fullSwitch, s.full, (v) => game.settings((x) => x.copyWith(full: v)), key: const ValueKey('full')),
            ]),
            section(Strings.about, [
              const Text(Strings.privacy, style: TextStyle(fontSize: 15, height: 1.5)),
              const SizedBox(height: 6),
              Text(Strings.version(appVersion), style: note),
            ]),
          ]),
        ),
      ),
    );
  }
}
