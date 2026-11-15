import 'dart:io';

import 'package:animal_moves/core/game.dart';
import 'package:animal_moves/core/guides.dart';
import 'package:animal_moves/features/parent/parent_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Privacy, the parent gate, 「先看看四周」 and the free version
/// (docs/design.md 「安全和隱私」).
void main() {
  test('the app asks for no permissions and takes no links from other apps', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, isNot(contains('uses-permission')), reason: 'no internet, camera, microphone, sensors, location…');
    expect(manifest, contains('android:name="flutter_deeplinking_enabled" android:value="false"'));
    expect(manifest, contains('android:label="動物動一動"'));
    expect(manifest, isNot(contains('screenOrientation')), reason: 'both ways round');
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('<key>FlutterDeepLinkingEnabled</key>\n\t<false/>'));
    expect(plist, contains('<string>動物動一動</string>'));
    expect(plist, isNot(contains('UsageDescription')), reason: 'no camera, microphone, motion… prompts');
    expect(plist, contains('UIInterfaceOrientationLandscapeLeft'));
    expect(File('pubspec.yaml').readAsStringSync(), isNot(contains('source: system')));
    for (final p in ['camera', 'sensors', 'record', 'geolocator', 'http', 'firebase', 'google_mobile_ads']) {
      expect(File('pubspec.yaml').readAsStringSync(), isNot(contains('  $p')), reason: 'no $p');
    }
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('applicationId = "com.yaufan.animalmoves"'));
    expect(gradle, contains('System.getenv("ANIMAL_MOVES_KEYSTORE")'));
    expect(gradle, contains('System.getenv("ANIMAL_MOVES_KEYSTORE_PASSWORD")'));
    expect(gradle, contains('keyAlias = "kidspaint"'));
    final kotlin = File('android/app/src/main/kotlin/com/yaufan/animal_moves/MainActivity.kt').readAsStringSync();
    expect(kotlin, contains('FLAG_KEEP_SCREEN_ON'), reason: 'the screen stays on with a window flag, no permission');
  });

  testWidgets('parent mode and unknown pages cannot be opened without the gate', (tester) async {
    final app = await TestApp.start(tester);
    app.go('/parent');
    await app.settle();
    expect(app.location, '/', reason: 'no pass from the gate');
    ParentPass.grant();
    app.go('/parent');
    await app.settle();
    expect(app.location, '/parent', reason: 'right after the gate');
    app.go('/');
    await app.settle();
    app.go('/parent');
    await app.settle();
    expect(app.location, '/', reason: 'the pass is used up');
    app.go('/go/moon');
    await app.settle();
    expect(app.location, '/');
    app.go('/space?next=/parent');
    await app.settle();
    expect(app.location, '/', reason: '「先看看四周」 only leads to moving');
    await app.end();
  });

  testWidgets('the parent gate asks a sum written in characters and locks after three misses', (tester) async {
    final app = await TestApp.start(tester);
    await app.tapLabel('家長', ms: 600);
    expect(find.textContaining('加'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const ValueKey('gate-key-1')));
      await app.settle(100);
      await tester.tap(find.byKey(const ValueKey('gate-key-0')));
      await app.settle(100);
    }
    expect(find.textContaining('請等'), findsOneWidget);
    expect(app.location, '/');
    await app.end();
  });

  testWidgets('the first time: the grown-up\'s questions, then the child picks a guide', (tester) async {
    final app = await TestApp.start(tester, game: const Game());
    expect(app.location, '/hello');
    app.go('/party');
    await app.settle();
    expect(app.location, '/hello');
    app.change((g) => g.withSettings(g.settings.copyWith(asked: true)));
    app.go('/');
    await app.settle();
    expect(app.location, '/guide');
    app.change((g) => g.copyWith(guide: Guide.deer));
    app.go('/');
    await app.settle();
    expect(app.location, '/');
    await app.end();
  });

  testWidgets('every go starts with 「先看看四周」; with 「每天第一次」, once a day', (tester) async {
    final app = await TestApp.start(tester);
    for (final at in ['/go/jungle', '/party', '/calm']) {
      app.go(at);
      await app.settle();
      expect(app.location, '/space', reason: at);
      app.go('/');
      await app.settle();
    }
    app.go('/party');
    await app.settle();
    await app.tapLabel('準備好了！', ms: 600);
    expect(app.location, '/party');
    app.go('/');
    await app.settle();
    app.go('/party');
    await app.settle();
    expect(app.location, '/space', reason: 'every time');
    app.change((g) => g.withSettings(g.settings.copyWith(checkDaily: true)));
    app.go('/');
    await app.settle();
    app.go('/calm');
    await app.settle();
    expect(app.location, '/calm', reason: 'already looked around today');
    await app.end();
  });

  testWidgets('the free version: 叢林探險, 去動物園, 動物舞會 and 慢慢伸展; the rest is locked', (tester) async {
    final app = await TestApp.start(tester, game: ready.withSettings(const Settings(asked: true, full: false)));
    for (final at in ['/go/sea', '/go/rain', '/go/mountain', '/build', '/run']) {
      app.go(at);
      await app.settle();
      expect(app.location, '/', reason: at);
    }
    await app.tapLabel('海底世界');
    expect(app.location, '/');
    expect(app.voice.said.last, '完整版才有喔，請爸爸媽媽看看。');
    await app.tapLabel('自己排');
    expect(app.location, '/');
    for (final at in ['/go/jungle', '/go/zoo', '/party', '/calm']) {
      app.go(at);
      await app.settle();
      expect(app.location, '/space', reason: at);
      app.go('/');
      await app.settle();
    }
    await app.end();
  });

  testWidgets('the rest ends after an hour, and a clock moved back does not lock the app', (tester) async {
    final app = await TestApp.start(tester);
    app.change((g) => g.rest(app.now));
    await app.settle(2600);
    expect(app.location, '/rest');
    app.now = app.now.subtract(const Duration(hours: 3));
    await app.settle(2600);
    expect(app.location, '/', reason: 'the clock went back: counts as rested');
    expect(app.game.restSince, isNull);
    await app.end();
  });
}
