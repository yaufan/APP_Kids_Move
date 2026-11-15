import 'dart:io';

import 'package:animal_moves/core/adventures.dart';
import 'package:animal_moves/core/guides.dart';
import 'package:animal_moves/core/moves.dart';
import 'package:animal_moves/core/session.dart';
import 'package:animal_moves/core/sounds.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every picture and sound the program asks for exists (docs/art.md,
/// design/sounds/README.md), and no picture uses what flutter_svg cannot draw.
void main() {
  bool has(String path) => File('assets/art/$path.svg').existsSync();

  test('every move has its two poses and a child showing how', () {
    final wanted = [
      for (final m in moves)
        for (final f in ['a', 'b']) ...[poseArt(m, m.species, f), kidArt(m, f)],
      for (final e in alsoDoneBy.entries)
        for (final s in e.value)
          for (final f in ['a', 'b']) poseArt(movesById[e.key]!, s, f),
      // Quiet mode's versions with the feet down.
      for (final id in quietPoses) poseArt(movesById[id]!, movesById[id]!.species, 'b', quiet: true),
      for (final id in quietKids) kidArt(movesById[id]!, 'b', quiet: true),
    ];
    expect(quietKids.every((id) => kidArt(movesById[id]!, 'b', quiet: true) != kidArt(movesById[id]!, 'b')), isTrue);
    expect(quietKids, containsAll([for (final m in moves) if (m.jump && m.id != 'starfish') m.id]), reason: 'every jump that leaves the floor has a quiet child');
    expect([for (final p in wanted) if (!has(p)) p], isEmpty, reason: 'draw these in design/art/');
    final drawn = Directory('assets/art/moves').listSync().length;
    expect(drawn, wanted.where((p) => p.startsWith('moves/')).length, reason: 'no pose left over');
  });

  test('every guide, scene, safety card and icon the screens ask for is drawn', () {
    final wanted = [
      for (final g in Guide.values)
        for (final p in ['idle', 'wave', 'sleep']) g.art(p),
      for (final a in adventures) a.scene,
      for (final s in ['home', 'party', 'calm', 'rest']) 'scenes/$s',
      for (final s in ['clear', 'nobed', 'feet', 'phone', 'spin']) 'safety/$s',
      for (final u in ['party', 'build', 'calm', 'lock', 'stamp', 'check', 'flower_open', 'flower_closed']) 'ui/$u',
    ];
    expect([for (final p in wanted) if (!has(p)) p], isEmpty);
  });

  test('no picture uses what flutter_svg cannot draw, and none is too big', () {
    final bad = <String>[];
    var n = 0;
    for (final f in Directory('assets/art').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.svg')) continue;
      n++;
      final text = f.readAsStringSync();
      if (f.lengthSync() > 70 * 1024) bad.add('${f.path} too big');
      for (final no in ['<filter', '<mask', '<clipPath', '<style', 'style=', '<text', '<image', '<pattern', 'mix-blend']) {
        if (text.contains(no)) bad.add('${f.path} uses $no');
      }
      if (!text.trimRight().endsWith('</svg>')) bad.add('${f.path} is cut off');
    }
    expect(n, greaterThan(150));
    expect(bad, isEmpty);
  });

  test('every sound the app plays is there, and nothing else', () {
    final wanted = <String>{
      for (final m in moves) ...[m.call, m.beat],
      breathe.call,
      breathe.beat,
      ...softSounds.values,
      for (final g in Guide.values) g.call,
      for (final m in Music.values) m.file,
      'tap', // every Pressable's own
      'breath_out', // the flower closing (follow_screen.dart)
    };
    final played = RegExp(r"""(?:sfx\(ref, |sound: )'([a-z_]+)'""");
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      for (final m in played.allMatches(f.readAsStringSync())) {
        wanted.add(m.group(1)!);
      }
    }
    final files = {for (final f in Directory('assets/sounds').listSync()) f.uri.pathSegments.last.replaceAll('.wav', '')};
    expect(wanted.difference(files), isEmpty, reason: 'a sound the code plays that is not made');
    expect(files.difference(wanted), isEmpty, reason: 'a sound made that nothing plays');
  });

  test('the font is there with its licence', () {
    expect(File('assets/fonts/jf-openhuninn-2.1.ttf').existsSync(), isTrue);
    expect(File('assets/fonts/OFL-jf-openhuninn.txt').existsSync(), isTrue);
  });
}
