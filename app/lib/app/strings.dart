import '../core/moves.dart';

/// Every word on screen and every line said (one place to check them: the
/// app never says whether a move was done well, docs/design.md
/// 「最重要的規則」; test/rules_test.dart looks for such words).
abstract final class Strings {
  static const appName = '動物動一動';

  // ---- first time
  static const helloTitle = '給爸爸媽媽';
  static const helloAge = '小朋友幾歲？（動作的難度，以後可以在家長模式改）';
  static const helloQuiet = '住公寓、或是晚上玩嗎？\n安靜模式會把「跳」的動作換成不會咚咚響的（例如青蛙跳變成蹲下、站起來）。';
  static const quietOn = '打開安靜模式';
  static const quietOff = '不用，可以跳';
  static const helloNote = '這個 APP 不連網、不要任何權限，也看不到小朋友：它只是教練，小朋友跟著動。';
  static const next = '下一步';
  static const pickGuide = '選一隻動物，帶你去動一動！';
  static String levelLine(Level l) => '${l.zh}（${l.ages}）';

  // ---- home
  static const home = '回首頁';
  static const parent = '家長';
  static const whereToGo = '今天想去哪裡動一動？';
  static const party = '動物舞會';
  static const build = '自己排';
  static const calm = '慢慢伸展';
  static const been = '去過了';
  static const fullOnly = '完整版才有喔，請爸爸媽媽看看。';
  static String card(int moves, int minutes) => '$moves 個動作・約 $minutes 分鐘';

  // ---- 先看看四周
  static const spaceTitle = '動之前，先看看四周';
  static const space = [
    '推開桌子椅子，找一塊空空的地方。',
    '不在床上、沙發上跳，離樓梯遠遠的。',
    '光腳丫，或穿止滑襪。',
    '手機立在桌上，不要放在地上。',
  ];
  static const spin = '手張開，轉一圈，碰不到東西就可以！';
  static const ready = '準備好了！';
  static const readyLine = '準備好了，就按「準備好了！」';

  // ---- follow
  static const done = '做好了！';
  static const again = '再一次';
  static const pause = '暫停';
  static const paused = '休息一下';
  static const goOn = '繼續';
  static const likeThis = '像這樣';
  static const countTogether = '一起數';
  static const breather = '喘口氣';
  static const phew = '呼——喘口氣。';
  static const tapWhenDone = '做好了，就按綠色的「做好了！」';
  static const breatheIn = '吸氣——';
  static const breatheOut = '吐氣——';
  static String turn(String hi, String name, String how) => '$hi換$name囉！$how';
  static String together(String how) => '和爸爸媽媽一起，$how';
  static String thanks(String name) => '謝謝你陪$name！';
  static const allThanks = '謝謝你陪我們！';
  static const calmDone = '身體安靜下來了。';
  static const toRest = '去休息';
  static const stretchNow = '最後，慢慢伸展。';

  // ---- 動物舞會
  static const partyHello = '音樂響，就跳舞！音樂停，就不動！';
  static const stop = '停！';
  static const freeze = '不動！';
  static String become(String animal) => '變成$animal！';
  static const dance = '動起來！';
  static const bow = '謝謝你一起跳舞！大家鞠躬！';
  static const dj = '大人按住這裡，音樂就停；放開，音樂再響。';
  static const djLine = '大人當 DJ：按住，音樂就停！';
  static const end = '結束';

  // ---- 自己排
  static const myRoutine = '我的體操';
  static const pickCards = '點動物卡，排出自己的體操！';
  static const random = '隨便來一個';
  static const start = '開始！';
  static const save = '存起來';
  static const saved = '存好的體操';
  static const lastIsStretch = '最後一定是慢慢伸展';
  static const full = '排滿了！按「開始！」吧。';
  static String needMore(int n) => '再選 $n 張動物卡。';
  static String routineName(String animal) => '$animal那一套';
  static String added(String name) => '$name！';

  // ---- rest
  static const restTitle = '換你去做了！';
  static const restLine = '關掉螢幕，去外面走一走、跳一跳吧！';
  static const restNote = 'WHO 建議 1～4 歲每天至少 180 分鐘各種活動，跑跑跳跳最好在真的地方。';

  // ---- parent gate
  static const callParent = '請爸爸媽媽來';
  static const parentGateTitle = '家長確認';
  static String gateQuestion(String a, String b) => '$a 加 $b 等於多少？';
  static const gateRules = '大人算出來，才能進家長模式。';
  static const wrongAnswer = '不對喔，換一題。';
  static String gateWait(int s) => '請等 $s 秒再試。';
  static const backspace = '刪掉';
  static const cancel = '取消';

  // ---- parent mode
  static const parentTitle = '家長模式';
  static const back = '回去';
  static const levelTitle = '難度';
  static const levelNote = '小小：動作最簡單、平衡可以扶牆，一個冒險 5 個動作，一個動作約 18 秒；中：6～7 個、約 25 秒；大：7～8 個、約 34 秒，加上換邊和連續的動作。';
  static const playTime = '每次玩幾分鐘';
  static const playTimeNote = '時間到了，會做完現在的動作和最後的伸展才休息；休息一小時，或家長在這裡解開。家長模式的時間不算。';
  static const resting = '現在是休息時間。';
  static const playOn = '再玩一次';
  static const safetyTitle = '安全';
  static const quiet = '安靜模式';
  static const quietNote = '跳的動作換成不會咚咚響的，咚咚響的音效也換成軟軟的（住公寓、晚上）。';
  static const smallSpace = '地方小';
  static const smallSpaceNote = '只做原地的動作，要爬、要走的動作換成別的。';
  static const checkDaily = '「先看看四周」每天只看第一次';
  static const checkDailyNote = '關著：每次開始動之前都看一次（建議）。';
  static const mustTap = '一定要按「做好了！」才往下';
  static const mustTapNote = '關著：音樂放完自己往下，按了可以提早。';
  static const togetherTitle = '大人一起做';
  static const togetherNote = '語音說「和爸爸媽媽一起」，動物舞會可以大人當 DJ。';
  static const movesTitle = '要哪些動作';
  static const movesNote = '關掉的動作不會出現在冒險、舞會和自己排裡；冒險會換成別的動作或跳過。';
  static const noJumps = '關掉全部跳的';
  static const noFloor = '關掉全部要趴、跪、坐在地上的';
  static const allOn = '全部打開';
  static String moveLine(Move m) => '${m.how[1]}　練到：${m.skills.map((s) => s.zh).join('、')}（${m.kind.zh}）';
  static String moveNote(Move m) => '注意：${m.caution}${m.quiet == null ? '' : '　安靜模式：${m.quiet}'}';
  static const weekTitle = '這一週跟著動了幾分鐘';
  static const weekNote = '算的是在跟著做、動物舞會、慢慢伸展的畫面，沒有暫停的時間。APP 不知道小朋友有沒有真的動，所以叫「跟著動」。WHO：1～4 歲每天至少 180 分鐘各種活動，這裡只是一小部分。';
  static String todayPlayed(int min) => '今天打開玩了 $min 分鐘。';
  static const skillsTitle = '最近練到什麼';
  static const nothingYet = '還沒有動過。';
  static const voiceTitle = '聲音';
  static const voice = '語音';
  static const slow = '念慢一點';
  static const music = '音樂';
  static const effects = '音效';
  static const volumeNote = '手機在房間的另一邊時，請把手機音量開大，或接家裡的藍牙喇叭。';
  static const guideTitle = '帶路的動物';
  static const changeGuide = '讓小朋友重新選';
  static const routinesTitle = '存好的體操';
  static const clearRoutines = '全部刪掉';
  static const fullVersion = '完整版';
  static const fullNote = '免費：叢林探險、去動物園、動物舞會、慢慢伸展和全部的安全設定。完整版：海底世界、下雨天、台灣山林、自己排。（測試期間全部打開。）';
  static const fullSwitch = '完整版（測試用）';
  static const about = '關於';
  static const privacy = '不連網、不定位、沒有廣告、沒有帳號、不要任何權限（沒有相機、麥克風、動作感應器）。只存設定、自己排的體操和每天跟著動的分鐘數，都只在這支手機裡。';
  static String version(String v) => '版本 $v';
  static String minutes(int m) => '$m 分鐘';
}
