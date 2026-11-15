import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

/// The music (design/sounds/make_sounds.py), each with a clear beat at its
/// own tempo; a move lasts a whole number of its bars (session.dart).
enum Music {
  home('music_home', 104),
  jungle('music_jungle', 100),
  zoo('music_zoo', 104),
  sea('music_sea', 96),
  rain('music_rain', 92),
  mountain('music_mountain', 100),
  party('music_party', 120),
  calm('music_calm', 64),
  rest('music_rest', 56);

  const Music(this.file, this.bpm);

  final String file;

  /// Beats a minute.
  final int bpm;

  Duration get beat => Duration(microseconds: 60000000 ~/ bpm);
}

/// Short sounds are named by their file in assets/sounds/ (design/sounds/README.md lists them).
abstract interface class Sounds {
  set music(bool on);
  set effects(bool on);

  void play(String sfx);

  /// [owner] (a screen) wants [music]; the one asked for last plays.
  void hold(Object owner, Music? music);

  void release(Object owner);
}

class MusicHolders {
  final _holders = <Object, Music?>{};

  void hold(Object owner, Music? music) {
    _holders.remove(owner);
    _holders[owner] = music;
  }

  void release(Object owner) => _holders.remove(owner);

  Music? get current => _holders.isEmpty ? null : _holders.values.last;
}

class SilentSounds implements Sounds {
  const SilentSounds();

  @override
  set music(bool on) {}

  @override
  set effects(bool on) {}

  @override
  void play(String sfx) {}

  @override
  void hold(Object owner, Music? music) {}

  @override
  void release(Object owner) {}
}

/// Remembers the sounds played (tests), keeping to the switches like the
/// real one: effects off plays nothing, music off holds no music.
class RecordingSounds implements Sounds {
  final played = <String>[];
  final _holders = MusicHolders();
  var musicOn = true, effectsOn = true;

  Music? get music => musicOn ? _holders.current : null;

  @override
  set music(bool on) => musicOn = on;

  @override
  set effects(bool on) => effectsOn = on;

  @override
  void play(String sfx) {
    if (effectsOn) played.add(sfx);
  }

  @override
  void hold(Object owner, Music? music) => _holders.hold(owner, music);

  @override
  void release(Object owner) => _holders.release(owner);
}

/// The one looping music player (audioplayers on the phone; tests give a
/// pretend one).
abstract interface class MusicLoop {
  Future<void> stop();
  Future<void> play(String file, double volume);
}

class _PlayerLoop implements MusicLoop {
  _PlayerLoop(this._ready);

  final Future<void> Function() _ready;
  AudioPlayer? _player;

  Future<AudioPlayer> _get() async {
    await _ready();
    var p = _player;
    if (p == null) {
      p = _player = AudioPlayer();
      await p.setReleaseMode(ReleaseMode.loop);
    }
    return p;
  }

  @override
  Future<void> stop() async => (await _get()).stop();

  @override
  Future<void> play(String file, double volume) async {
    final p = await _get();
    await p.setVolume(volume);
    await p.play(AssetSource('sounds/$file.wav'));
  }

  void dispose() => unawaited(_player?.dispose());
}

/// Plays through audioplayers: a pool per sound, one looping player for the
/// music; quiet while the app is in the background.
class SystemSounds implements Sounds {
  SystemSounds({MusicLoop? loop}) {
    _loop = loop ?? _PlayerLoop(_ready);
    _lifecycle = AppLifecycleListener(onHide: () => _setAway(true), onShow: () => _setAway(false));
  }

  static const _sfxVolume = 0.85, _musicVolume = 0.35;

  late final AppLifecycleListener _lifecycle;
  late final MusicLoop _loop;
  final _pools = <String, Future<AudioPool>>{};
  final _holders = MusicHolders();
  Future<void>? _setUp;

  /// The music wanted now, and the music the loop was last started with.
  Music? _playing, _sounding;

  /// Switches of the music, one after the other: a stop asked for while a
  /// start is still loading waits for it, so the music never starts after
  /// it was stopped (the 「停！」 of 動物舞會, a pause, the app hidden).
  Future<void> _switching = Future.value();
  var _music = true, _effects = true, _away = false;

  @override
  set music(bool on) {
    _music = on;
    _update();
  }

  @override
  set effects(bool on) => _effects = on;

  void _setAway(bool away) {
    _away = away;
    _update();
  }

  Future<void> _ready() => _setUp ??= AudioPlayer.global.setAudioContext(
        AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers, respectSilence: true).build(),
      );

  @override
  void play(String sfx) {
    if (!_effects || _away || sfx.isEmpty) return;
    unawaited(_play(sfx));
  }

  Future<void> _play(String sfx) async {
    try {
      await _ready();
      final pool = await (_pools[sfx] ??= AudioPool.createFromAsset(path: 'sounds/$sfx.wav', maxPlayers: 4));
      await pool.start(volume: _sfxVolume);
    } catch (_) {
      _pools.remove(sfx);
    }
  }

  @override
  void hold(Object owner, Music? music) {
    _holders.hold(owner, music);
    _update();
  }

  @override
  void release(Object owner) {
    _holders.release(owner);
    _update();
  }

  void _update() {
    final wanted = !_music || _away ? null : _holders.current;
    if (wanted == _playing) return;
    _playing = wanted;
    _switching = _switching.then((_) => _apply());
  }

  /// Makes the loop play what is wanted now (a later wish queues another).
  Future<void> _apply() async {
    final music = _playing;
    if (music == _sounding) return;
    try {
      await _loop.stop();
      _sounding = null;
      if (music == null) return;
      await _loop.play(music.file, _musicVolume);
      _sounding = music;
    } catch (_) {
      _sounding = null;
    }
  }

  void dispose() {
    _lifecycle.dispose();
    final loop = _loop;
    if (loop is _PlayerLoop) loop.dispose();
  }
}
