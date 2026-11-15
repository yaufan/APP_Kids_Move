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
/// move and the slow stretch first ([windDownProvider]); then the animals
/// sleep and the child is sent off to move for real. An hour later (or when
/// a parent says so) play can go on. Away from the app for ten minutes
/// counts as a rest; time in parent mode is not the child's play time, and
/// neither is time with the app in the background. It also counts the
/// minutes for parent mode: played, and 「跟著動」 (on a moving screen, not
/// paused).
class RestGuard extends ConsumerStatefulWidget {
  const RestGuard({super.key, required this.child});

  final Widget child;

  static const check = Duration(seconds: 2);
  static const awayIsRest = Duration(minutes: 10);

  /// Seconds are saved this often.
  static const saveEvery = 30;

  @override
  ConsumerState<RestGuard> createState() => _RestGuardState();
}

class _RestGuardState extends ConsumerState<RestGuard> {
  Timer? _timer;
  AppLifecycleListener? _life;
  DateTime? _away;

  /// When parent mode was opened (its time is given back to the child).
  DateTime? _parentSince;
  var _played = 0, _moved = 0;

  @override
  void initState() {
    super.initState();
    ref.read(sessionStartProvider);
    _timer = Timer.periodic(RestGuard.check, (_) => _check());
    _life = AppLifecycleListener(
      onHide: () {
        _save();
        _away = ref.read(clockProvider)();
      },
      onShow: () {
        final away = _away;
        _away = null;
        if (away != null && ref.read(clockProvider)().difference(away) >= RestGuard.awayIsRest) ref.read(sessionStartProvider.notifier).restart();
        _check();
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _life?.dispose();
    super.dispose();
  }

  void _save() {
    if (_played <= 0 && _moved <= 0) return;
    final p = _played, m = _moved;
    _played = _moved = 0;
    final now = ref.read(clockProvider)();
    ref.read(gameProvider.notifier).change((g) => g.playedFor(now, p).followed(now, m));
  }

  void _check() {
    if (!mounted) return;
    final now = ref.read(clockProvider)();
    final g = ref.read(gameProvider);
    final router = ref.read(routerProvider);
    final path = router.state.matchedLocation;
    final setup = path == '/hello' || path == '/guide';
    // Not while the app is out of sight (its timer can go on in the background).
    final playing = _away == null && !path.startsWith('/parent') && path != '/rest' && !setup;
    if (playing) {
      _played += RestGuard.check.inSeconds;
      if (movingPath(path) && !ref.read(pausedProvider)) _moved += RestGuard.check.inSeconds;
      if (_played >= RestGuard.saveEvery) _save();
    }
    if (path.startsWith('/parent')) {
      _parentSince ??= now;
      return;
    }
    final parentSince = _parentSince;
    if (parentSince != null) {
      _parentSince = null;
      ref.read(sessionStartProvider.notifier).pause(now.difference(parentSince));
    }
    if (g.restSince != null) {
      if (g.resting(now)) {
        if (path != '/rest') router.go('/rest');
        return;
      }
      ref.read(gameProvider.notifier).change((g) => g.playOn());
      ref.read(sessionStartProvider.notifier).restart();
      if (path == '/rest') router.go('/');
      return;
    }
    if (path == '/rest' || setup) return;
    if (now.difference(ref.read(sessionStartProvider)) >= Duration(minutes: g.settings.minutes)) {
      if (movingPath(path)) {
        // Finish the move and the stretch first (the screen goes to the rest).
        if (!ref.read(windDownProvider)) ref.read(windDownProvider.notifier).set(true);
        return;
      }
      _save();
      ref.read(windDownProvider.notifier).set(false);
      ref.read(gameProvider.notifier).change((g) => g.rest(now));
      router.go('/rest');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
