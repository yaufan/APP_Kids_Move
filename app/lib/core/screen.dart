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

/// The screens that want the screen kept on (先看看四周, a go, the party): it
/// stays on while any of them does, so a screen going away (after the next
/// one came) never lets it sleep under the next one.
class ScreenAwake {
  ScreenAwake(this._control);

  final ScreenControl _control;
  final _owners = <Object>{};
  bool? _on;

  void keepOn(Object owner, bool on) {
    on ? _owners.add(owner) : _owners.remove(owner);
    final want = _owners.isNotEmpty;
    if (want == _on) return;
    _on = want;
    _control.keepOn(want);
  }
}

/// Remembers what was asked (tests).
class RecordingScreen implements ScreenControl {
  var awake = false;

  @override
  Future<void> keepOn(bool on) async => awake = on;
}
