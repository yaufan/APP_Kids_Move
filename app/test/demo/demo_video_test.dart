// Records a demo video of 動物動一動 being played on a phone lying on its side
// (the 「小電視」 way): a scripted child and parent (a white dot where the
// finger is) with a caption under the screen; the music and sounds the app
// asked for are written down and mixed in afterwards by tools/demo_audio.py.
//
//   flutter test test/demo/demo_video_test.dart --dart-define=DEMO=true
//   python3 ../tools/demo_audio.py
//
// Needs ffmpeg; writes build/demo/demo.mp4, chapters.txt and sounds.txt.
// Skipped in normal test runs.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:animal_moves/app/app.dart';
import 'package:animal_moves/core/game.dart';
import 'package:animal_moves/core/providers.dart';
import 'package:animal_moves/core/screen.dart';
import 'package:animal_moves/core/sounds.dart';
import 'package:animal_moves/core/store.dart';
import 'package:animal_moves/core/voice.dart';
import 'package:animal_moves/features/parent/parent_gate.dart';

import '../helpers.dart' show loadFonts;

const _phone = Size(844, 390);
const _captionHeight = 84.0;
const _fps = 10;
const _demo = bool.fromEnvironment('DEMO');

/// The music and the sounds asked for, with the frame they were asked at.
class _Recording implements Sounds {
  _Recording(this.frame);

  final int Function() frame;
  final lines = <String>[];
  final _holders = MusicHolders();
  Music? _playing;

  @override
  set music(bool on) {}

  @override
  set effects(bool on) {}

  @override
  void play(String sfx) => lines.add('${frame()} sfx $sfx');

  @override
  void hold(Object owner, Music? music) {
    _holders.hold(owner, music);
    _changed();
  }

  @override
  void release(Object owner) {
    _holders.release(owner);
    _changed();
  }

  void _changed() {
    final now = _holders.current;
    if (now == _playing) return;
    _playing = now;
    lines.add('${frame()} music ${now?.file ?? '-'}');
  }
}

void main() {
  testWidgets('demo video', skip: !_demo, (tester) async {
    await tester.runAsync(loadFonts);
    tester.view.physicalSize = Size(_phone.width * 3, (_phone.height + _captionHeight) * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    var frameCount = 0;
    var now = DateTime(2026, 11, 15, 10);
    final track = _Recording(() => frameCount);
    final finger = ValueNotifier<Offset?>(null);
    final caption = ValueNotifier<String>('');
    final key = GlobalKey();
    final store = MemoryStore();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Column(children: [
          SizedBox.fromSize(
            size: _phone,
            child: MediaQuery(
              data: const MediaQueryData(size: _phone, devicePixelRatio: 3, padding: EdgeInsets.only(left: 24)),
              child: Stack(children: [
                ProviderScope(
                  overrides: [
                    storeProvider.overrideWithValue(store),
                    savedGameProvider.overrideWithValue(const Game()),
                    soundsProvider.overrideWithValue(track),
                    voiceProvider.overrideWithValue(const SilentVoice()),
                    screenProvider.overrideWithValue(RecordingScreen()),
                    randomProvider.overrideWithValue(math.Random(3)),
                    clockProvider.overrideWithValue(() => now),
                  ],
                  child: const MovesApp(),
                ),
                IgnorePointer(child: ValueListenableBuilder(valueListenable: finger, builder: (_, at, _) => _Finger(at))),
              ]),
            ),
          ),
          SizedBox(
            width: _phone.width,
            height: _captionHeight,
            child: ColoredBox(
              color: const Color(0xFF3FB55B),
              child: Center(
                child: ValueListenableBuilder(
                  valueListenable: caption,
                  builder: (_, text, _) => Text(text, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Huninn', color: Colors.white, fontSize: 17, height: 1.35)),
                ),
              ),
            ),
          ),
        ]),
      ),
    ));

    final rec = (await tester.runAsync(() => _Recorder.start(key)))!;
    final marks = <String>[];
    void mark(String name) => marks.add('$name $frameCount');
    Future<void> frames(int n) async {
      for (var i = 0; i < n; i++) {
        frameCount++;
        await tester.runAsync(() async {
          await rec.capture();
          await Future<void>.delayed(const Duration(milliseconds: 15));
        });
        await tester.pump(const Duration(milliseconds: 1000 ~/ _fps));
      }
    }

    Future<void> seconds(double s) => frames((s * _fps).round());
    Future<void> touch(Offset at) async {
      finger.value = at;
      await frames(2);
      await tester.tapAt(at);
      await frames(2);
      finger.value = null;
    }

    Offset at(String l) => tester.getCenter(find.bySemanticsLabel(l).last);
    Future<void> label(String l) async {
      final f = find.bySemanticsLabel(l);
      if (f.evaluate().isEmpty || !tester.getRect(f.last).overlaps(Offset.zero & _phone)) {
        await tester.scrollUntilVisible(f, 120, scrollable: find.byType(Scrollable).first);
        await frames(3);
      }
      await touch(at(l));
    }
    Future<void> tapKey(String id) => touch(tester.getCenter(find.byKey(ValueKey(id)).last));

    String phase() {
      for (final p in ['look', 'move', 'wait', 'breathe', 'end']) {
        for (var i = 0; i < 12; i++) {
          if (find.byKey(ValueKey('follow-$p-$i')).evaluate().isNotEmpty) return p;
        }
      }
      return '';
    }

    Future<void> until(String p, {double most = 40}) async {
      for (var t = 0.0; phase() != p && t < most; t += .5) {
        await seconds(.5);
      }
    }

    final now0 = now;

    // The first time: the grown-up's two questions, the child's guide.
    mark('start');
    caption.value = '動物動一動：2～5 歲跟著動物動身體\n手機立在桌上像小電視，APP 看不到小朋友，只是教練';
    await seconds(3.5);
    caption.value = '第一次打開，先問家長：小朋友幾歲？\n住公寓或晚上玩，要不要「安靜模式」？';
    await label('中（3～4 歲）');
    await seconds(1);
    await label('不用，可以跳');
    await seconds(1.5);
    await label('下一步');
    caption.value = '小朋友自己選帶路的動物（六隻台灣動物）\n每一隻有自己的樣子、叫聲和說話的聲音';
    await seconds(3);
    await label('小石虎');
    await seconds(3);

    mark('home');
    caption.value = '首頁：五個小冒險，還有動物舞會、自己排、慢慢伸展\n今天去過的冒險會蓋「去過了」（不是分數）';
    await seconds(4.5);

    // 先看看四周.
    mark('space');
    caption.value = '每次開始動之前：先看看四周\n語音一條一條念，念到的打勾';
    await label('叢林探險');
    await seconds(6);
    caption.value = '推開桌椅、不在床上跳、光腳丫、手機立在桌上\n手張開轉一圈，碰不到東西就可以！';
    await seconds(5);
    await label('準備好了！');

    // 叢林探險.
    mark('jungle');
    caption.value = '「喵嗚～換長頸鹿伸高高囉！」\n每個動作先有動物的招牌聲，沒看螢幕也知道換了';
    await until('move');
    caption.value = '大大的毛球動物跟著拍子動；右邊給大人看：\n怎麼做、小朋友示範「像這樣」、一起數（往上數）';
    await seconds(7);
    caption.value = '按「做好了！」只是「下一個」\nAPP 看不到小朋友，所以從來不說「做對了」';
    await label('做好了！');
    await until('move');
    caption.value = '猴子摸摸：摸摸頭、摸摸肚子、摸摸膝蓋\n每個動作有自己的音效，跟著拍子響';
    await seconds(6);
    await label('做好了！');
    await until('move');
    caption.value = '青蛙跳：「呱—啵嚶」\n（安靜模式：變成蹲下、站起來，不會咚咚響）';
    await seconds(6);
    caption.value = '音樂放完就自己往下一個（家長也可以設定一定要按）\n黑熊爬、大象踩踩、紅鶴單腳站……';
    for (var i = 0; i < 3; i++) {
      await label('做好了！');
      await until('move');
      await seconds(2.5);
    }
    await label('做好了！');

    mark('stretch');
    caption.value = '最後一定是慢慢伸展：烏龜伸展\n讓身體和心情安靜下來';
    await until('move');
    caption.value = '小花打開的時候吸氣，合起來的時候吐氣\n（4 秒吸、4 秒吐，做三次）';
    await seconds(12);
    await label('做好了！');
    caption.value = '「謝謝你陪我們！」沒有星星、沒有分數\n冒險卡蓋上「去過了」的章';
    await seconds(3.5);
    await label('回首頁');
    await seconds(2.5);

    // 動物舞會.
    mark('party');
    caption.value = '動物舞會（跳舞木頭人）：音樂響就隨便跳！';
    await label('動物舞會');
    await seconds(1.5);
    await label('準備好了！');
    await seconds(3);
    caption.value = '音樂真的停下來：「停！變成紅鶴！」\n一起數（往上數）；沒有人會出局';
    for (var t = 0; t < 40 && find.byKey(const ValueKey('party-freeze')).evaluate().isEmpty; t++) {
      await seconds(.5);
    }
    await seconds(5);
    caption.value = '數完音樂再響；大人也可以當 DJ（按住螢幕音樂就停）';
    await seconds(4);
    await label('暫停');
    await seconds(1);
    await label('回首頁');
    await seconds(1.5);

    // 自己排.
    mark('build');
    caption.value = '自己排：點動物卡排出自己的體操（只要點，不用拖）\n最後一格一定是慢慢伸展';
    await label('自己排');
    await seconds(2);
    await tapKey('card-frog');
    await seconds(1.2);
    await tapKey('card-bear');
    await seconds(1.2);
    caption.value = '「隨便來一個」幫忙選一張；可以存 6 套\n（用第一隻動物當名字，不用打字）';
    await label('隨便來一個');
    await seconds(1.5);
    await label('存起來');
    await seconds(2.5);
    await label('開始！');
    await seconds(1);
    await label('準備好了！');
    await until('move');
    await seconds(3);
    await label('暫停');
    await seconds(1);
    await label('回首頁');
    await seconds(1.5);

    // Parent mode.
    mark('parent');
    caption.value = '家長答對題目，才能進家長模式';
    const digits = {'零': 0, '一': 1, '二': 2, '三': 3, '四': 4, '五': 5, '六': 6, '七': 7, '八': 8, '九': 9};
    Future<void> gate() async {
      final parts = (find.textContaining('加').evaluate().first.widget as Text).data!.split(' ');
      for (final d in '${digits[parts[0]]! + digits[parts[2]]!}'.split('')) {
        await touch(tester.getCenter(find.byKey(ValueKey('gate-key-$d'))));
        await frames(3);
      }
    }

    await label('家長');
    await seconds(1.2);
    await gate();
    await seconds(1.5);
    caption.value = '家長模式：難度、玩幾分鐘、這一週跟著動了幾分鐘\n（APP 不知道小朋友有沒有真的動，所以叫「跟著動」）';
    await seconds(4);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await seconds(3);
    caption.value = '安全：安靜模式、地方小、先看看四周、要哪些動作\n家長關掉的動作不會再出現';
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await seconds(4);
    await touch(tester.getCenter(find.byIcon(Icons.close_rounded)));
    await seconds(1.5);

    // Rest.
    mark('rest');
    now = now0.add(const Duration(minutes: 15, seconds: 1));
    caption.value = '家長設定的時間到了（預設 15 分鐘）\n「換你去做了！關掉螢幕，去外面走一走、跳一跳吧！」';
    await seconds(6);
    caption.value = '';
    mark('end');
    await seconds(0.5);
    expect(ParentPass.take(), isFalse);
    await tester.runAsync(() async {
      await rec.finish();
      File('build/demo/chapters.txt').writeAsStringSync('${marks.join('\n')}\n');
      File('build/demo/sounds.txt').writeAsStringSync('fps $_fps\nframes $frameCount\n${track.lines.join('\n')}\n');
    });
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  }, timeout: const Timeout(Duration(minutes: 40)));
}

class _Finger extends StatelessWidget {
  const _Finger(this.at);

  final Offset? at;

  @override
  Widget build(BuildContext context) {
    final p = at;
    if (p == null) return const SizedBox.expand();
    return Stack(children: [
      Positioned(
        left: p.dx - 22,
        top: p.dy - 22,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.55),
            border: Border.all(color: const Color(0xFF4A3B32).withValues(alpha: 0.5), width: 3),
          ),
        ),
      ),
    ]);
  }
}

/// Streams frames of [key]'s boundary into ffmpeg.
class _Recorder {
  _Recorder(this._key, this._ffmpeg);

  final GlobalKey _key;
  final Process _ffmpeg;

  static Future<_Recorder> start(GlobalKey key) async {
    Directory('build/demo').createSync(recursive: true);
    final size = Size(_phone.width * 2, (_phone.height + _captionHeight) * 2);
    final ffmpeg = await Process.start('ffmpeg', [
      '-y', '-loglevel', 'error',
      '-f', 'rawvideo', '-pix_fmt', 'rgba', '-s', '${size.width.toInt()}x${size.height.toInt()}', '-r', '$_fps', '-i', '-',
      '-vf', 'fps=30', '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '24', '-movflags', '+faststart', 'build/demo/demo_silent.mp4',
    ]);
    ffmpeg.stderr.listen(stderr.add);
    return _Recorder(key, ffmpeg);
  }

  Future<void> capture() async {
    final boundary = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    _ffmpeg.stdin.add(bytes!.buffer.asUint8List());
    await _ffmpeg.stdin.flush();
  }

  Future<void> finish() async {
    await _ffmpeg.stdin.flush();
    await _ffmpeg.stdin.close();
    final code = await _ffmpeg.exitCode;
    if (code != 0) throw StateError('ffmpeg failed ($code)');
  }
}
