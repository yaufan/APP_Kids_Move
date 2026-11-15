import 'package:animal_moves/core/game.dart';
import 'package:animal_moves/core/providers.dart';
import 'package:animal_moves/features/parent/parent_gate.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Every screen lays out without overflowing on a phone and a tablet, upright
/// and on its side (docs/design.md 「畫面和玩法」: both ways round).
void main() {
  for (final MapEntry(key: name, value: (size, ratio)) in {'phone': phone, 'phone wide': phoneWide, 'tablet': tablet, 'tablet wide': tabletWide}.entries) {
    testWidgets('every screen fits ($name)', (tester) async {
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
}
