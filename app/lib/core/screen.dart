import 'package:flutter/services.dart';

/// Keeps the screen on while a child follows an animal (docs/design.md
/// 「跟著做」): a flag on the app's own window (Android) or the idle timer
/// (iOS), no permission. MainActivity.kt and AppDelegate.swift answer it.
abstract interface class ScreenControl {
  Future<void> keepOn(bool on);
}

class SystemScreen implements ScreenControl {
  static const _channel = MethodChannel('animal_moves/screen');

  @override
  Future<void> keepOn(bool on) async {
    try {
      await _channel.invokeMethod<void>('keepOn', on);
    } catch (_) {}
  }
}

/// Remembers what was asked (tests).
class RecordingScreen implements ScreenControl {
  var awake = false;

  @override
  Future<void> keepOn(bool on) async => awake = on;
}
