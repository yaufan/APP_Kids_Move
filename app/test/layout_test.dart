import 'package:animal_moves/app/strings.dart';
import 'package:animal_moves/app/widgets.dart';
import 'package:animal_moves/core/game.dart';
import 'package:animal_moves/core/providers.dart';
import 'package:animal_moves/features/parent/parent_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Every screen lays out without overflowing on a phone and a tablet, upright
/// and on its side (docs/design.md 「畫面和玩法」: both ways round).
void main() {
  for (final MapEntry(key: name, value: (size, ratio)) in {'phone': phone, 'phone wide': phoneWide, 'tablet': tablet, 'tablet wide': tabletWide, 'small phone': smallPhone, 'small phone wide': smallPhoneWide}.entries) {
    testWidgets('every screen fits ($name)', (tester) async {
      // The small phone has its status bar and buttons, as a real one.
      if (size == smallPhone.$1) tester.view.padding = const FakeViewPadding(top: 72, bottom: 144);
      if (size == smallPhoneWide.$1) tester.view.padding = const FakeViewPadding(top: 72, bottom: 72);
      final app = await TestApp.start(tester, game: const Game(), size: size, ratio: ratio);
      expect(app.location, '/hello');
      app.change((g) => g.withSettings(g.settings.copyWith(asked: true)));
      app.go('/guide');
      await app.settle(600);
      expect(app.location, '/guide');
      app.change((g) => ready);
      for (final at in ['/', '/space?next=/party', '/build']) {
        app.go(at);
        await app.settle(800);
        expect(app.location, at.split('?').first, reason: at);
      }
      for (final at in ['/go/jungle', '/run', '/calm', '/party']) {
        if (at == '/run') app.container.read(draftProvider.notifier).set(['frog', 'bear', 'flamingo']);
        app.container.read(spaceOkProvider.notifier).set(true);
        app.go(at);
        await app.settle(800);
        expect(app.location, at, reason: at);
        await app.play(6);
      }
      app.go('/');
      await app.settle(600);
      ParentPass.grant();
      app.go('/parent');
      await app.settle(800);
      expect(app.location, '/parent');
      app.change((g) => g.rest(app.now));
      app.go('/rest');
      await app.settle(800);
      expect(app.location, '/rest');
      await app.end();
    });
  }

  for (final MapEntry(key: name, value: (size, ratio, least)) in {'small phone': (smallPhone.$1, smallPhone.$2, 90.0), 'phone': (phone.$1, phone.$2, 140.0), 'small phone wide': (smallPhoneWide.$1, smallPhoneWide.$2, 80.0)}.entries) {
    testWidgets('the 「像這樣」 picture is big enough to see across the room ($name), and the home screen\'s buttons and guide fit', (tester) async {
      if (size == smallPhone.$1) tester.view.padding = const FakeViewPadding(top: 72, bottom: 144);
      if (size == smallPhoneWide.$1) tester.view.padding = const FakeViewPadding(top: 72, bottom: 72);
      await tester.runAsync(loadFonts);
      final app = await TestApp.start(tester, game: ready, size: size, ratio: ratio);
      final screen = Offset.zero & (tester.view.physicalSize / tester.view.devicePixelRatio);
      await shoot(tester, 'layout', 'home_${name.replaceAll(' ', '_')}');
      for (final label in [Strings.party, Strings.build, Strings.calm]) {
        expect(screen.contains(tester.getRect(find.bySemanticsLabel(label)).bottomRight - const Offset(1, 1)), isTrue, reason: label);
      }
      expect(screen.contains(tester.getRect(find.byType(GuideSays)).bottomRight - const Offset(1, 1)), isTrue, reason: 'the guide is on screen');
      await app.goMoving('/go/jungle');
      await app.play(4);
      final pic = tester.getRect(find.byKey(const ValueKey('like-this')));
      expect(pic.shortestSide, greaterThanOrEqualTo(least), reason: 'the picture of a child doing it');
      await shoot(tester, 'layout', 'follow_${name.replaceAll(' ', '_')}');
      await app.end();
    });
  }
}
