import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'core/game.dart';
import 'core/providers.dart';
import 'core/screen.dart';
import 'core/sounds.dart';
import 'core/store.dart';
import 'core/voice.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Both ways round (docs/design.md 「畫面和玩法」): on its side like a little
  // TV on the table, or upright.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
    DeviceOrientation.portraitUp,
  ]);
  final store = FileStore(await getApplicationSupportDirectory());
  final saved = Game.fromJson(await store.read());
  runApp(ProviderScope(
    overrides: [
      storeProvider.overrideWithValue(store),
      savedGameProvider.overrideWithValue(saved),
      soundsProvider.overrideWithValue(SystemSounds()),
      voiceProvider.overrideWithValue(SystemVoice()),
      screenProvider.overrideWithValue(SystemScreen()),
    ],
    child: const MovesApp(),
  ));
}
