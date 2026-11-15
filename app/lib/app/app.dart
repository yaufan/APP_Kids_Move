import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/adventures.dart';
import '../core/providers.dart';
import '../features/build/build_screen.dart';
import '../features/follow/follow_screen.dart';
import '../features/guide/guide_screen.dart';
import '../features/hello/hello_screen.dart';
import '../features/home/home_screen.dart';
import '../features/parent/parent_gate.dart';
import '../features/parent/parent_screen.dart';
import '../features/party/party_screen.dart';
import '../features/rest/rest_screen.dart';
import '../features/space/space_screen.dart';
import 'strings.dart';
import 'theme.dart';

/// The screens where a child is moving: they need 「先看看四周」 first, and
/// when the play time is up they finish the move and the stretch before
/// resting (docs/design.md 「休息」).
bool movingPath(String path) => path.startsWith('/go/') || path == '/run' || path == '/party' || path == '/calm';

final routerProvider = Provider<GoRouter>((ref) {
  final resting = ref.read(gameProvider).resting(ref.read(clockProvider)());
  final router = GoRouter(
    initialLocation: resting ? '/rest' : '/',
    // Always start here, whatever page another app asks the phone to open.
    overridePlatformDefaultLocation: true,
    redirect: (_, state) {
      final at = state.matchedLocation;
      if (at == '/parent') return ParentPass.take() ? null : '/';
      if (at == '/rest') return null;
      final g = ref.read(gameProvider);
      final s = g.settings;
      if (!s.asked) return at == '/hello' ? null : '/hello';
      if (g.guide == null) return at == '/guide' ? null : '/guide';
      if (at.startsWith('/go/')) {
        final a = adventuresById[state.pathParameters['id']];
        if (a == null || !s.opens(a)) return '/';
      }
      if ((at == '/build' || at == '/run') && !s.buildOpen) return '/';
      if (at == '/run' && ref.read(draftProvider).isEmpty) return '/build';
      if (movingPath(at) && g.checkDue(ref.read(clockProvider)(), passed: ref.read(spaceOkProvider))) {
        return Uri(path: '/space', queryParameters: {'next': state.uri.toString()}).toString();
      }
      if (at == '/space' && !movingPath(Uri.parse(state.uri.queryParameters['next'] ?? '/').path)) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
      GoRoute(path: '/hello', builder: (_, _) => const HelloScreen()),
      GoRoute(path: '/guide', builder: (_, _) => const GuideScreen()),
      GoRoute(path: '/space', builder: (_, s) => SpaceScreen(next: s.uri.queryParameters['next'] ?? '/')),
      GoRoute(path: '/go/:id', builder: (_, s) => FollowScreen(key: ValueKey(s.uri.toString()), source: FollowSource.adventure, adventure: s.pathParameters['id'])),
      GoRoute(path: '/run', builder: (_, _) => const FollowScreen(source: FollowSource.routine)),
      GoRoute(path: '/calm', builder: (_, _) => const FollowScreen(source: FollowSource.calm)),
      GoRoute(path: '/party', builder: (_, _) => const PartyScreen()),
      GoRoute(path: '/build', builder: (_, _) => const BuildScreen()),
      GoRoute(path: '/rest', builder: (_, _) => const RestScreen()),
      GoRoute(path: '/parent', builder: (_, _) => const ParentScreen()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

/// A go is over: home, or straight to the rest if the play time ran out
/// while the child was moving.
void finishGo(WidgetRef ref, BuildContext context) {
  if (ref.read(windDownProvider)) {
    ref.read(windDownProvider.notifier).set(false);
    ref.read(gameProvider.notifier).change((g) => g.rest(ref.read(clockProvider)()));
    GoRouter.of(context).go('/rest');
  } else {
    GoRouter.of(context).go('/');
  }
}

class MovesApp extends ConsumerWidget {
  const MovesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(gameProvider.select((g) => g.settings));
    ref.read(soundsProvider)
      ..music = settings.music
      ..effects = settings.sounds;
    return MaterialApp.router(
      title: Strings.appName,
      debugShowCheckedModeBanner: false,
      theme: FeltTheme.light(),
      locale: const Locale('zh', 'TW'),
      supportedLocales: const [Locale('zh', 'TW')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: ref.watch(routerProvider),
      builder: (_, child) => RestGuard(child: child ?? const SizedBox()),
    );
  }
}

/// Keeps the parent's play time (docs/design.md 「每次玩多久」). When the
/// minutes they set are up, a child in the middle of moving finishes the
/// move and the slow stretch first ([windDownProvider], at most
/// [windDownMost]); then the animals sleep and the child is sent off to move
/// for real. An hour later (or when a parent says so) play can go on. Away
/// from the app for ten minutes counts as a rest; time in parent mode is not
/// the child's play time, and neither is time with the app in the
/// background; a phone clock moved back gives no extra time. It also counts
/// the minutes for parent mode: played, and 「跟著動」 (on a moving screen,
/// not paused). A change of screen or of the pause is counted the moment it
/// happens, not on the next check.
class RestGuard extends ConsumerStatefulWidget {
  const RestGuard({super.key, required this.child});

  final Widget child;

  static const check = Duration(seconds: 2);
  static const awayIsRest = Duration(minutes: 10);

  /// Seconds are saved this often.
  static const saveEvery = 30;

  /// The longest a go may go on (not paused) after the play time ran out:
  /// finishing the move and the stretch takes about two minutes, so this is
  /// only reached by going round again and again; then it is the rest.
  static const windDownMost = Duration(minutes: 3);

  @override
  ConsumerState<RestGuard> createState() => _RestGuardState();
}

class _RestGuardState extends ConsumerState<RestGuard> {
  Timer? _timer;
  AppLifecycleListener? _life;
  late final GoRouter _router;
  DateTime? _away;

  /// When parent mode was opened (in sight), and parent-mode time not given
  /// back to the child yet.
  DateTime? _parentSince;
  var _parentFor = Duration.zero;

  /// Milliseconds played and followed, not saved yet.
  var _played = 0, _moved = 0;

  /// When the time counted next began, and whether it is play and
  /// 「跟著動」 (looked at again whenever the screen, the pause or the app
  /// being in sight changes).
  late DateTime _from;
  var _playing = false, _moving = false;

  /// The phone's clock at the last check (to notice it moved back).
  late DateTime _seen;

  /// Milliseconds moving (not paused) since the play time ran out.
  var _windingFor = 0;

  DateTime get _now => ref.read(clockProvider)();

  String get _path => _router.routerDelegate.currentConfiguration.isEmpty ? '' : _router.state.matchedLocation;

  @override
  void initState() {
    super.initState();
    ref.read(sessionStartProvider);
    _router = ref.read(routerProvider);
    _from = _seen = _now;
    _router.routerDelegate.addListener(_changed);
    ref.listenManual(pausedProvider, (_, _) => _changed());
    _startTimer();
    _life = AppLifecycleListener(
      onHide: () {
        _changed();
        _away = _now;
        _look();
        _save();
      },
      onShow: () {
        final away = _away, now = _now;
        _away = null;
        if (away != null) {
          final session = ref.read(sessionStartProvider.notifier);
          final d = now.difference(away);
          if (d >= RestGuard.awayIsRest) {
            session.restart();
          } else {
            // A few minutes in the background are not play time either.
            session.pause(d);
          }
        }
        _from = now;
        _look();
        _startTimer();
        _check();
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _life?.dispose();
    _router.routerDelegate.removeListener(_changed);
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(RestGuard.check, (_) => _tick());
  }

  /// What the time from now on is: play, 「跟著動」, parent mode.
  void _look() {
    final path = _path, now = _now;
    final parent = path.startsWith('/parent');
    if (parent && _away == null) {
      _parentSince ??= now;
    } else if (_parentSince != null) {
      final d = now.difference(_parentSince!);
      if (d > Duration.zero) _parentFor += d;
      _parentSince = null;
    }
    _playing = _away == null && path.isNotEmpty && !parent && path != '/rest' && path != '/hello' && path != '/guide';
    _moving = _playing && movingPath(path) && !ref.read(pausedProvider);
  }

  void _count(int ms) {
    if (_playing) _played += ms;
    if (_moving) {
      _moved += ms;
      if (ref.read(windDownProvider)) _windingFor += ms;
    }
  }

  /// The screen, the pause or the app being in sight changed: the bit of
  /// time since the last count goes to what was being done until now (by the
  /// phone's clock, at most one check long), and counting starts afresh.
  void _changed() {
    if (!mounted) return;
    final now = _now;
    final ms = now.difference(_from).inMilliseconds.clamp(0, RestGuard.check.inMilliseconds);
    _count(ms);
    _from = now;
    _look();
    _startTimer();
  }

  void _tick() {
    if (!mounted) return;
    _count(RestGuard.check.inMilliseconds);
    _from = _now;
    _look();
    if (_played >= RestGuard.saveEvery * 1000) _save();
    _check();
  }

  void _save() {
    final p = _played ~/ 1000, m = _moved ~/ 1000;
    if (p <= 0 && m <= 0) return;
    _played -= p * 1000;
    _moved -= m * 1000;
    final now = _now;
    ref.read(gameProvider.notifier).change((g) => g.playedFor(now, p).followed(now, m));
  }

  void _check() {
    if (!mounted) return;
    final now = _now;
    final session = ref.read(sessionStartProvider.notifier);
    // A phone clock moved back: the sitting moves back with it, so the
    // minutes already played still count.
    if (now.isBefore(_seen)) session.back(_seen.difference(now));
    _seen = now;
    if (_parentFor > Duration.zero) {
      session.pause(_parentFor);
      _parentFor = Duration.zero;
    }
    // Looked at again when the app is back in sight.
    if (_away != null) return;
    final g = ref.read(gameProvider);
    final path = _path;
    if (path.startsWith('/parent')) return;
    if (g.restSince != null) {
      if (g.resting(now)) {
        if (path != '/rest') _router.go('/rest');
        return;
      }
      ref.read(gameProvider.notifier).change((g) => g.playOn());
      session.restart();
      if (path == '/rest') _router.go('/');
      return;
    }
    if (path == '/rest' || path == '/hello' || path == '/guide') return;
    final winding = ref.read(windDownProvider);
    if (!winding) _windingFor = 0;
    if (now.difference(ref.read(sessionStartProvider)) >= Duration(minutes: g.settings.minutes)) {
      if (movingPath(path) && _windingFor < RestGuard.windDownMost.inMilliseconds) {
        // Finish the move and the stretch first (the screen goes to the rest).
        if (!winding) ref.read(windDownProvider.notifier).set(true);
        return;
      }
      _save();
      ref.read(windDownProvider.notifier).set(false);
      ref.read(gameProvider.notifier).change((g) => g.rest(now));
      _router.go('/rest');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
