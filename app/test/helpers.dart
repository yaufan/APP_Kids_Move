import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:animal_moves/app/app.dart';
import 'package:animal_moves/core/game.dart';
import 'package:animal_moves/core/guides.dart';
import 'package:animal_moves/core/providers.dart';
import 'package:animal_moves/core/screen.dart';
import 'package:animal_moves/core/sounds.dart';
import 'package:animal_moves/core/store.dart';
import 'package:animal_moves/core/voice.dart';

final shotKey = GlobalKey();

/// A game that has been set up: the first questions answered and a guide picked.
const ready = Game(settings: Settings(asked: true), guide: Guide.macaque);

/// Phone and tablet, upright and on their side (docs/design.md: both ways round).
const phone = (Size(1080, 2340), 2.75), phoneWide = (Size(2340, 1080), 2.75);
const tablet = (Size(1620, 2160), 2.0), tabletWide = (Size(2160, 1620), 2.0);

/// The app on a phone screen, starting from [game].
class TestApp {
  TestApp(this.tester, this.store, this.sounds, this.voice, this.screen);

  final WidgetTester tester;
  final MemoryStore store;
  final RecordingSounds sounds;
  final RecordingVoice voice;
  final RecordingScreen screen;
  DateTime now = DateTime(2026, 11, 15, 10);

  ProviderContainer get container => ProviderScope.containerOf(tester.element(find.byType(MovesApp)));
  Game get game => container.read(gameProvider);
  void change(Game Function(Game g) f) => container.read(gameProvider.notifier).change(f);

  static Future<TestApp> start(WidgetTester tester, {Game game = ready, Size size = const Size(2340, 1080), double ratio = 2.75, String at = '/', int seed = 1, RecordingVoice? voice}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = ratio;
    addTearDown(tester.view.reset);
    final store = MemoryStore();
    final app = TestApp(tester, store, RecordingSounds(), voice ?? RecordingVoice(), RecordingScreen());
    await tester.pumpWidget(RepaintBoundary(
      key: shotKey,
      child: ProviderScope(
        overrides: [
          storeProvider.overrideWithValue(store),
          savedGameProvider.overrideWithValue(game),
          randomProvider.overrideWithValue(math.Random(seed)),
          soundsProvider.overrideWithValue(app.sounds),
          voiceProvider.overrideWithValue(app.voice),
          screenProvider.overrideWithValue(app.screen),
          clockProvider.overrideWithValue(() => app.now),
        ],
        child: const MovesApp(),
      ),
    ));
    if (at != '/') app.go(at);
    await app.settle();
    return app;
  }

  void go(String location) => container.read(routerProvider).go(location);

  String get location => container.read(routerProvider).state.matchedLocation;

  /// Lets the pictures load and the screen move on [ms] milliseconds.
  Future<void> settle([int ms = 400]) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(Duration(milliseconds: ms ~/ 6));
    }
  }

  Future<void> tapLabel(String label, {int ms = 400}) async {
    await tester.tap(find.bySemanticsLabel(label).last, warnIfMissed: false);
    await settle(ms);
  }

  /// Scrolls a list until [label] shows, then taps it.
  Future<void> scrollTap(String label, {int ms = 400}) async {
    final f = find.bySemanticsLabel(label);
    if (f.evaluate().isEmpty || !tester.getRect(f.last).overlaps(Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio)) {
      await tester.scrollUntilVisible(f, 120, scrollable: find.byType(Scrollable).first);
      await settle(200);
    }
    await tapLabel(label, ms: ms);
  }

  /// Lets [seconds] of play go by, a beat at a time (timers fire, the screen moves on).
  Future<void> play(double seconds, {int step = 250}) async {
    for (var t = 0; t < seconds * 1000; t += step) {
      await tester.pump(Duration(milliseconds: step));
    }
    await settle(100);
  }

  /// Turns the device round (docs/design.md: portrait and landscape).
  Future<void> turn(Size size) async {
    tester.view.physicalSize = size;
    await settle(300);
  }

  /// What the follow screen is doing: 'look-0', 'move-2', 'breathe-1', 'end-6'... ('' elsewhere).
  String phase() {
    for (final p in ['look', 'move', 'wait', 'breathe', 'end']) {
      for (var i = 0; i < 12; i++) {
        if (find.byKey(ValueKey('follow-$p-$i')).evaluate().isNotEmpty) return '$p-$i';
      }
    }
    return '';
  }

  /// Opens a moving screen as if 「先看看四周」 was just gone through.
  Future<void> goMoving(String at, {int ms = 600}) async {
    container.read(spaceOkProvider.notifier).set(true);
    go(at);
    await settle(ms);
  }

  Future<void> end() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Real fonts for screenshots instead of the test font's boxes.
Future<void> loadFonts() async {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '/home/user/flutter';
  final fonts = {
    'MaterialIcons': ['$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'],
    'Huninn': ['assets/fonts/jf-openhuninn-2.1.ttf'],
    'Roboto': ['assets/fonts/jf-openhuninn-2.1.ttf'],
  };
  for (final MapEntry(key: family, value: paths) in fonts.entries) {
    final loader = FontLoader(family);
    for (final path in paths.where((p) => File(p).existsSync())) {
      loader.addFont(File(path).readAsBytes().then(ByteData.sublistView));
    }
    await loader.load();
  }
}

Future<void> shoot(WidgetTester tester, String device, String name) => tester.runAsync(() async {
      final boundary = shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      File('build/screenshots/$device/$name.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(png!.buffer.asUint8List());
    });

/// Holds a finger down on [finder] for [ms] milliseconds, frame by frame.
Future<void> hold(TestApp app, Finder finder, int ms) async {
  final g = await app.tester.startGesture(app.tester.getCenter(finder));
  await app.tester.pump(const Duration(milliseconds: 50));
  for (var t = 0; t < ms; t += 100) {
    await app.tester.pump(const Duration(milliseconds: 100));
  }
  await g.up();
  await app.tester.pump(const Duration(milliseconds: 50));
}

/// Drags a finger from [from] to [to] in small steps (raw pointer moves).
Future<void> dragFinger(TestApp app, Offset from, Offset to) async {
  final g = await app.tester.startGesture(from);
  await app.tester.pump(const Duration(milliseconds: 30));
  for (var i = 1; i <= 8; i++) {
    await g.moveTo(Offset.lerp(from, to, i / 8)!);
    await app.tester.pump(const Duration(milliseconds: 20));
  }
  await g.up();
  await app.tester.pump(const Duration(milliseconds: 30));
}
