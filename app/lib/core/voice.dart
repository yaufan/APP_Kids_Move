import 'package:flutter/widgets.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Reads things out in Taiwanese Mandarin: short, clear lines, because the
/// phone is across the room (docs/design.md 「語音」). Each guide speaks at
/// its own pitch.
abstract interface class Voice {
  /// Says [zh]; [slow] for a slower voice. Completes when it has been said
  /// (or cut off by the next line).
  Future<void> say(String zh, {bool slow = false, double pitch = 1.15});
  Future<void> stop();
}

class SystemVoice implements Voice {
  /// Quiet while the app is out of sight: what was being said stops, and nothing new is said
  /// until it is back.
  SystemVoice() {
    _life = AppLifecycleListener(
      onHide: () {
        _hidden = true;
        stop();
      },
      onShow: () => _hidden = false,
    );
  }

  late final AppLifecycleListener _life;
  var _hidden = false;
  Future<FlutterTts>? _ready;
  double? _rate, _pitch;

  /// Counts the lines asked for (and stops): a line still waiting for the engine when a newer one
  /// (or a stop) comes is dropped, so lines never come out of order or over each other at start.
  var _turn = 0;

  /// The engine, set up once (every line waits for the same setting up).
  Future<FlutterTts> _engine() => _ready ??= () async {
        try {
          final tts = FlutterTts();
          await tts.awaitSpeakCompletion(true);
          await tts.setLanguage('zh-TW');
          return tts;
        } catch (_) {
          _ready = null;
          rethrow;
        }
      }();

  @override
  Future<void> say(String zh, {bool slow = false, double pitch = 1.15}) async {
    final turn = ++_turn;
    if (_hidden) return;
    try {
      final tts = await _engine();
      if (turn != _turn) return;
      await tts.stop();
      if (turn != _turn) return;
      final rate = slow ? 0.34 : 0.46;
      if (rate != _rate) {
        _rate = rate;
        await tts.setSpeechRate(rate);
      }
      if (pitch != _pitch) {
        _pitch = pitch;
        await tts.setPitch(pitch);
      }
      if (turn != _turn || _hidden) return;
      if (zh.isNotEmpty) await tts.speak(zh);
    } catch (_) {
      // No speech engine (tests, or a phone without one): the pictures, the
      // sounds and the words on screen are enough.
    }
  }

  void dispose() => _life.dispose();

  @override
  Future<void> stop() async {
    _turn++;
    final ready = _ready;
    if (ready == null) return;
    try {
      await (await ready).stop();
    } catch (_) {}
  }
}

class SilentVoice implements Voice {
  const SilentVoice();

  @override
  Future<void> say(String zh, {bool slow = false, double pitch = 1.15}) async {}

  @override
  Future<void> stop() async {}
}

/// Remembers what was said, at what pitch, and how often it was stopped (tests).
class RecordingVoice implements Voice {
  final said = <String>[];
  final pitches = <double>[];
  var stops = 0;

  @override
  Future<void> say(String zh, {bool slow = false, double pitch = 1.15}) async {
    said.add(zh);
    pitches.add(pitch);
  }

  @override
  Future<void> stop() async => stops++;
}
