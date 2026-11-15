/// The moves (docs/design.md 「動作表」): 29 animal moves, each with how to do
/// it at the three levels, its quiet version, what it trains and how it is
/// shown. The app never knows whether a child did a move (no camera, no
/// sensors), so nothing here ever says 「做對了」: the lines only say what the
/// animal does and invite the child to join in.
library;

/// 小小 (2 to 3), 中 (3 to 4) or 大 (4 to 5): docs/design.md 「難度」.
enum Level {
  small('小小', '2～3 歲'),
  mid('中', '3～4 歲'),
  big('大', '4～5 歲');

  const Level(this.zh, this.ages);

  final String zh;
  final String ages;

  /// How far 「一起數」 goes.
  int get countTo => const [3, 4, 5][index];

  /// About how long one move goes on (the music's bars are fitted to it).
  int get moveSeconds => const [18, 25, 34][index];

  /// How many cards 自己排 takes.
  int get maxCards => const [4, 6, 8][index];
}

/// What a move trains (shown in parent mode, 「練到什麼」).
enum Skill {
  balance('平衡'),
  jump('跳'),
  midline('跨中線'),
  core('核心'),
  strength('手腳的力氣'),
  rhythm('節奏'),
  flexible('柔軟'),
  control('慢慢控制'),
  breath('呼吸和放鬆'),
  body('認識身體');

  const Skill(this.zh);

  final String zh;
}

/// The curriculum's three kinds of basic movement (教保課綱「身體動作與健康」).
enum Kind {
  stability('穩定性動作'),
  locomotor('移動性動作'),
  manipulative('操作性動作');

  const Kind(this.zh);

  final String zh;
}

/// How the whole animal moves on screen between its two poses.
enum Motion { hop, bounce, sway, shuffle, crawl, swim, slow, still, flap, stretch, wiggle }

/// The animals (design/art/animals.py draws each).
enum Species {
  frog('青蛙'),
  rabbit('兔子'),
  kangaroo('袋鼠'),
  bear('台灣黑熊'),
  crab('螃蟹'),
  penguin('企鵝'),
  duck('鴨子'),
  leopardcat('石虎'),
  deer('梅花鹿'),
  elephant('大象'),
  snake('蛇'),
  worm('蚯蚓'),
  fish('小魚'),
  bird('小鳥'),
  magpie('台灣藍鵲'),
  salmon('櫻花鉤吻鮭'),
  flamingo('紅鶴'),
  giraffe('長頸鹿'),
  sloth('樹懶'),
  starfish('海星'),
  jellyfish('水母'),
  octopus('章魚'),
  seaturtle('海龜'),
  monkey('台灣獼猴'),
  squirrel('松鼠'),
  lion('獅子'),
  tortoise('烏龜'),
  butterfly('蝴蝶'),
  pangolin('穿山甲');

  const Species(this.zh);

  final String zh;
}

class Move {
  const Move({
    required this.id,
    required this.zh,
    required this.species,
    required this.how,
    this.quiet,
    required this.invites,
    this.quietInvites,
    required this.skills,
    required this.kind,
    required this.caution,
    this.jump = false,
    this.floor = false,
    this.travels = false,
    this.stretch = false,
    required this.motion,
    this.quietMotion,
    required this.call,
    required this.beat,
  });

  final String id;

  /// Its name (青蛙跳).
  final String zh;
  final Species species;

  /// How to do it: 小小, 中, 大.
  final List<String> how;

  /// The quiet-mode version (null: the same move, it makes no thumps).
  final String? quiet;

  /// Said every few bars while the child moves.
  final List<String> invites;
  final List<String>? quietInvites;

  final List<Skill> skills;
  final Kind kind;

  /// For parents (parent mode's list).
  final String caution;

  /// Jumps (quiet mode swaps it; a parent can turn every jump off at once).
  final bool jump;

  /// On the floor: on knees, on the tummy or sitting (a parent can turn these off).
  final bool floor;

  /// Needs room to go somewhere (left out when the space is small).
  final bool travels;

  /// A slow stretch (the end of every adventure).
  final bool stretch;

  final Motion motion;
  final Motion? quietMotion;

  /// Its signature sound, once as the move starts.
  final String call;

  /// Its own sound on the beat while it is done (design/sounds/README.md).
  final String beat;

  String howFor(Level l, {bool quietMode = false}) => quietMode && quiet != null ? quiet! : how[l.index];

  List<String> invitesFor({bool quietMode = false}) => quietMode && quietInvites != null ? quietInvites! : invites;

  Motion motionFor({bool quietMode = false}) => quietMode && quietMotion != null ? quietMotion! : motion;

  /// 大 adds why: 「紅鶴單腳站，練平衡。」
  String get why => '練${skills.first.zh}';
}

const moves = <Move>[
  Move(
    id: 'frog',
    zh: '青蛙跳',
    species: Species.frog,
    how: ['蹲下來，再站起來，呱！', '蹲低低，手碰地，跳起來！', '蹲低低，往前連跳三下！'],
    quiet: '蹲下來，站起來，呱！',
    invites: ['跳到荷葉上！', '再跳一次！'],
    quietInvites: ['蹲低低，站起來！', '呱！再一次！'],
    skills: [Skill.jump, Skill.strength],
    kind: Kind.locomotor,
    caution: '手先碰地，落地膝蓋彎彎。',
    jump: true,
    motion: Motion.hop,
    quietMotion: Motion.bounce,
    call: 'frog',
    beat: 'boing',
  ),
  Move(
    id: 'bunny',
    zh: '兔子跳',
    species: Species.rabbit,
    how: ['雙腳併攏，小小跳。', '雙腳併攏，跳跳跳！', '往前、往後、往左、往右跳！'],
    quiet: '踮腳尖，彈一彈。',
    invites: ['小兔子跳跳跳！', '耳朵豎起來，再跳！'],
    quietInvites: ['踮腳尖，彈一彈！', '耳朵豎起來！'],
    skills: [Skill.jump, Skill.rhythm],
    kind: Kind.locomotor,
    caution: '腳併攏，輕輕落地。',
    jump: true,
    motion: Motion.hop,
    quietMotion: Motion.bounce,
    call: 'bunny',
    beat: 'hop',
  ),
  Move(
    id: 'kangaroo',
    zh: '袋鼠跳高',
    species: Species.kangaroo,
    how: ['牽著大人的手，往上跳！', '手伸高高，往上跳！', '往上跳，手碰天空！'],
    quiet: '踮腳尖，手伸高高。',
    invites: ['跳高高！', '袋鼠跳，再一次！'],
    quietInvites: ['踮腳尖，伸高高！', '手碰天空！'],
    skills: [Skill.jump, Skill.strength],
    kind: Kind.locomotor,
    caution: '小小可以牽大人的手；落地膝蓋彎彎。',
    jump: true,
    motion: Motion.hop,
    quietMotion: Motion.stretch,
    call: 'kangaroo',
    beat: 'boing',
  ),
  Move(
    id: 'bear',
    zh: '黑熊爬',
    species: Species.bear,
    how: ['手和膝蓋著地，慢慢爬。', '手腳著地，屁股翹高高，往前爬！', '屁股翹高高，爬過去再爬回來！'],
    invites: ['爬過山洞！', '黑熊慢慢爬！'],
    skills: [Skill.core, Skill.strength],
    kind: Kind.locomotor,
    caution: '膝蓋著地也可以；地上不要有玩具。',
    floor: true,
    travels: true,
    motion: Motion.crawl,
    call: 'bear',
    beat: 'shuffle',
  ),
  Move(
    id: 'crab',
    zh: '螃蟹走',
    species: Species.crab,
    how: ['蹲著，手當鉗子，橫著走。', '蹲低低，喀喀喀，往旁邊走！', '坐下來，手腳撐起來，肚子朝上橫著走！'],
    invites: ['喀喀喀，往旁邊走！', '鉗子夾一夾！'],
    skills: [Skill.core, Skill.strength],
    kind: Kind.locomotor,
    caution: '大的版本要坐在地上，手撐好再走。',
    floor: true,
    travels: true,
    motion: Motion.shuffle,
    call: 'crab',
    beat: 'click',
  ),
  Move(
    id: 'penguin',
    zh: '企鵝搖搖走',
    species: Species.penguin,
    how: ['手貼身體，搖搖擺擺走。', '腳跟靠近，小碎步搖搖走！', '小碎步走過去，再轉身走回來！'],
    invites: ['搖搖擺擺！', '啪噠啪噠走！'],
    skills: [Skill.balance],
    kind: Kind.locomotor,
    caution: '小碎步，慢慢走。',
    travels: true,
    motion: Motion.sway,
    call: 'penguin',
    beat: 'pitter',
  ),
  Move(
    id: 'duck',
    zh: '鴨子走',
    species: Species.duck,
    how: ['蹲低低，走兩步。', '蹲低低，手當翅膀，走三步！', '蹲著走四步，呱呱呱！'],
    invites: ['呱呱呱，蹲著走！', '翅膀拍一拍！'],
    skills: [Skill.strength, Skill.balance],
    kind: Kind.locomotor,
    caution: '走幾步就站起來休息。',
    travels: true,
    motion: Motion.shuffle,
    call: 'duck',
    beat: 'pitter',
  ),
  Move(
    id: 'tiptoe',
    zh: '石虎躡手躡腳',
    species: Species.leopardcat,
    how: ['踮腳尖，輕輕走。', '踮腳尖慢慢走，不要出聲音。', '踮腳尖走過去，停！再走！'],
    invites: ['噓，輕輕走。', '石虎踮腳尖。'],
    skills: [Skill.balance, Skill.control],
    kind: Kind.locomotor,
    caution: '本來就很安靜，晚上也可以玩。',
    travels: true,
    motion: Motion.slow,
    call: 'shh',
    beat: 'tiptoe',
  ),
  Move(
    id: 'deer',
    zh: '梅花鹿跨跳',
    species: Species.deer,
    how: ['大步大步走。', '跨過小溪！一腳、再一腳。', '踏併步跳，噠噠、噠噠！'],
    quiet: '大步大步走。',
    invites: ['跨過小溪！', '噠噠、噠噠！'],
    quietInvites: ['大步走！', '一腳、再一腳！'],
    skills: [Skill.rhythm, Skill.strength],
    kind: Kind.locomotor,
    caution: '左右腳輪流；地方小就原地跨。',
    jump: true,
    travels: true,
    motion: Motion.hop,
    quietMotion: Motion.shuffle,
    call: 'deer',
    beat: 'leap',
  ),
  Move(
    id: 'elephant',
    zh: '大象踩踩',
    species: Species.elephant,
    how: ['兩手合起來當鼻子，踏踏腳。', '重重踏步，鼻子左右甩！', '踏四步，鼻子甩到左邊，再甩到右邊！'],
    quiet: '慢慢踏，輕輕踩，鼻子甩一甩。',
    invites: ['咚、咚、大象來了！', '鼻子甩一甩！'],
    quietInvites: ['輕輕踩，鼻子甩一甩。', '大象慢慢走。'],
    skills: [Skill.rhythm, Skill.midline, Skill.strength],
    kind: Kind.locomotor,
    caution: '手合起來當鼻子，甩過身體的中間。',
    motion: Motion.sway,
    call: 'elephant',
    beat: 'stomp',
  ),
  Move(
    id: 'snake',
    zh: '蛇扭扭',
    species: Species.snake,
    how: ['趴在地上，扭一扭。', '肚子貼地，扭著往前！', '扭過去，再扭回來！'],
    invites: ['嘶，扭一扭！', '肚子貼地，扭扭扭！'],
    skills: [Skill.core, Skill.body],
    kind: Kind.locomotor,
    caution: '趴在乾淨的地板或軟墊上。',
    floor: true,
    travels: true,
    motion: Motion.wiggle,
    call: 'hiss',
    beat: 'wiggle',
  ),
  Move(
    id: 'fish',
    zh: '小魚游',
    species: Species.fish,
    how: ['兩手合起來，往前游。', '手往前游，身體左右扭。', '游快一點！再慢下來。'],
    invites: ['小魚游游游！', '游到海草旁邊！'],
    skills: [Skill.rhythm, Skill.flexible],
    kind: Kind.locomotor,
    caution: '站著就可以，身體扭一扭。',
    motion: Motion.swim,
    call: 'bubbles',
    beat: 'swish',
  ),
  Move(
    id: 'bird',
    zh: '小鳥飛',
    species: Species.bird,
    how: ['手大大地拍，像翅膀。', '拍拍翅膀，慢慢轉一圈。', '拍翅膀，小跑步飛一小段！'],
    quiet: '站著拍拍翅膀。',
    invites: ['拍拍翅膀！', '飛高高！'],
    skills: [Skill.strength, Skill.rhythm],
    kind: Kind.locomotor,
    caution: '轉圈最多慢慢轉一圈，不會暈。',
    travels: true,
    motion: Motion.flap,
    call: 'tweet',
    beat: 'flap',
  ),
  Move(
    id: 'salmon',
    zh: '櫻花鉤吻鮭往上游',
    species: Species.salmon,
    how: ['原地踏步，手划一划。', '踏步往上游，左手、右手划！', '踏步，右手划到左邊，左手划到右邊！'],
    invites: ['往上游！', '左手、右手，划划划！'],
    skills: [Skill.rhythm, Skill.midline],
    kind: Kind.locomotor,
    caution: '原地踏步就好。',
    motion: Motion.swim,
    call: 'splash',
    beat: 'swish',
  ),
  Move(
    id: 'flamingo',
    zh: '紅鶴單腳站',
    species: Species.flamingo,
    how: ['抬一隻腳一下下，可以扶牆。', '單腳站，一起數到三！', '單腳站數到五，換另一隻腳！'],
    invites: ['一隻腳，站站看。', '換另一隻腳！'],
    skills: [Skill.balance],
    kind: Kind.stability,
    caution: '小小可以扶牆或牽大人的手。',
    motion: Motion.still,
    call: 'flamingo',
    beat: 'wobble',
  ),
  Move(
    id: 'giraffe',
    zh: '長頸鹿伸高高',
    species: Species.giraffe,
    how: ['手往上伸，高高的！', '踮腳尖，手伸到天花板！', '踮腳尖伸高高，數到五再放下。'],
    invites: ['伸高高，吃樹葉！', '再伸高一點！'],
    skills: [Skill.flexible, Skill.balance],
    kind: Kind.stability,
    caution: '暖身用，慢慢伸。',
    motion: Motion.stretch,
    call: 'giraffe',
    beat: 'stretch',
  ),
  Move(
    id: 'sloth',
    zh: '樹懶慢動作',
    species: Species.sloth,
    how: ['慢慢走，慢慢抬手。', '超慢超慢地走。', '超慢地抬腳、抬手，比樹懶還慢！'],
    invites: ['慢——慢——來。', '比樹懶還慢。'],
    skills: [Skill.control],
    kind: Kind.locomotor,
    caution: '越慢越好，練的是控制自己。',
    motion: Motion.slow,
    call: 'sloth',
    beat: 'slowdrum',
  ),
  Move(
    id: 'starfish',
    zh: '海星開合',
    species: Species.starfish,
    how: ['手腳張開變星星，再收回來。', '張開，收！張開，收！', '開合跳！跳開、跳回來。'],
    quiet: '不跳，手腳張開、收回來。',
    invites: ['變成一顆星星！', '張開，收！'],
    skills: [Skill.rhythm, Skill.strength],
    kind: Kind.stability,
    caution: '大的版本是開合跳；安靜模式只張開不跳。',
    jump: true,
    motion: Motion.bounce,
    quietMotion: Motion.stretch,
    call: 'sparkle',
    beat: 'open',
  ),
  Move(
    id: 'jellyfish',
    zh: '水母飄飄',
    species: Species.jellyfish,
    how: ['手軟軟的，上下飄。', '手飄飄，膝蓋輕輕彎。', '飄到左邊，飄到右邊，軟軟的。'],
    invites: ['軟軟的，飄飄飄。', '水母慢慢飄。'],
    skills: [Skill.breath, Skill.rhythm],
    kind: Kind.stability,
    caution: '放鬆的動作。',
    motion: Motion.sway,
    call: 'jelly',
    beat: 'bloop',
  ),
  Move(
    id: 'octopus',
    zh: '章魚扭扭',
    species: Species.octopus,
    how: ['坐下來，扭扭手。', '扭扭手、扭扭腳！', '扭扭手、扭扭腳、扭扭屁股！'],
    invites: ['扭扭手！', '扭扭腳！'],
    skills: [Skill.body],
    kind: Kind.stability,
    caution: '坐在地上做。',
    floor: true,
    motion: Motion.wiggle,
    call: 'octopus',
    beat: 'wiggle',
  ),
  Move(
    id: 'seaturtle',
    zh: '海龜划水',
    species: Species.seaturtle,
    how: ['趴著，手腳划一划。', '趴著，手腳抬起來划！', '像超人一樣，手腳抬高高划！'],
    invites: ['划划水！', '手腳抬起來！'],
    skills: [Skill.core],
    kind: Kind.stability,
    caution: '趴在軟墊上；累了就休息。',
    floor: true,
    motion: Motion.swim,
    call: 'seaturtle',
    beat: 'swish',
  ),
  Move(
    id: 'monkey',
    zh: '猴子摸摸',
    species: Species.monkey,
    how: ['拍拍頭、肩膀、膝蓋！', '摸摸頭、摸摸肚子、摸摸膝蓋！', '右手摸左膝蓋，左手摸右膝蓋！'],
    invites: ['摸摸頭！', '摸摸膝蓋！'],
    skills: [Skill.midline, Skill.body],
    kind: Kind.stability,
    caution: '大的版本手越過身體的中間。',
    motion: Motion.bounce,
    call: 'monkey',
    beat: 'pat',
  ),
  Move(
    id: 'squirrel',
    zh: '松鼠撿果子',
    species: Species.squirrel,
    how: ['蹲下來撿果子，放進口袋。', '左邊撿果子，放到右邊口袋！', '左邊撿、右邊放，再換邊！'],
    invites: ['撿一顆果子！', '放進口袋！'],
    skills: [Skill.midline, Skill.strength],
    kind: Kind.manipulative,
    caution: '假裝撿東西，不用道具。',
    motion: Motion.bounce,
    call: 'squirrel',
    beat: 'pick',
  ),
  Move(
    id: 'lion',
    zh: '獅子哈',
    species: Species.lion,
    how: ['嘴巴張大，哈——', '跪坐，手張開，哈——！', '跪坐，手張開，舌頭伸出來，哈——吐氣！'],
    invites: ['張大嘴巴，哈——', '好笑的獅子，哈——'],
    skills: [Skill.breath],
    kind: Kind.stability,
    caution: '好笑的獅子，不是兇的獅子；練的是吐氣。',
    floor: true,
    motion: Motion.still,
    call: 'lion',
    beat: 'ha',
  ),
  Move(
    id: 'tortoise',
    zh: '烏龜伸展',
    species: Species.tortoise,
    how: ['縮成一顆球，再把頭伸出來。', '跪坐縮起來，慢慢伸出頭和手。', '縮成球，數到三，慢慢伸出來。'],
    invites: ['慢慢伸出來。', '縮回殼裡。'],
    skills: [Skill.flexible, Skill.breath],
    kind: Kind.stability,
    caution: '慢慢做，讓身體安靜下來。',
    floor: true,
    stretch: true,
    motion: Motion.slow,
    call: 'turtle',
    beat: 'stretch',
  ),
  Move(
    id: 'catarch',
    zh: '石虎伸懶腰',
    species: Species.leopardcat,
    how: ['手和膝蓋著地，背拱高高。', '背拱高高，再放下。', '背拱高高，吐氣；背放平，吸氣。'],
    invites: ['背拱高高。', '慢慢放下。'],
    skills: [Skill.flexible, Skill.breath],
    kind: Kind.stability,
    caution: '貓咪拱背；慢慢做。',
    floor: true,
    stretch: true,
    motion: Motion.slow,
    call: 'meow',
    beat: 'stretch',
  ),
  Move(
    id: 'butterfly',
    zh: '蝴蝶坐',
    species: Species.butterfly,
    how: ['坐下來，腳底對腳底。', '腳底對腳底，膝蓋上下拍！', '膝蓋拍拍，身體慢慢往前彎。'],
    invites: ['蝴蝶拍拍翅膀。', '慢慢的，輕輕的。'],
    skills: [Skill.flexible],
    kind: Kind.stability,
    caution: '坐著做，不用壓膝蓋。',
    floor: true,
    stretch: true,
    motion: Motion.flap,
    call: 'flutter',
    beat: 'flutter',
  ),
  Move(
    id: 'pangolin',
    zh: '穿山甲捲捲',
    species: Species.pangolin,
    how: ['坐著抱膝蓋，縮成球。', '抱膝縮成球，數到三，打開！', '縮成球數到三，打開，再縮起來。'],
    invites: ['捲成一顆球。', '慢慢打開。'],
    skills: [Skill.flexible, Skill.control],
    kind: Kind.stability,
    caution: '坐著抱膝，不要滾來滾去。',
    floor: true,
    stretch: true,
    motion: Motion.slow,
    call: 'pangolin',
    beat: 'roll',
  ),
  Move(
    id: 'rainbow',
    zh: '彩虹彎彎',
    species: Species.frog,
    how: ['手舉高高，彎到旁邊。', '手舉高，往左彎，往右彎。', '像彩虹一樣，慢慢彎到左邊，再彎到右邊。'],
    invites: ['彎成一道彩虹。', '慢慢彎過去。'],
    skills: [Skill.flexible],
    kind: Kind.stability,
    caution: '站著慢慢彎，不要往後彎。',
    stretch: true,
    motion: Motion.sway,
    call: 'rainbow',
    beat: 'stretch',
  ),
];

final movesById = {for (final m in moves) m.id: m};

/// Thumpy sounds and their soft versions for quiet mode (an apartment, or
/// the evening): docs/design.md 「安靜模式」.
const softSounds = {
  'boing': 'boing_soft',
  'hop': 'hop_soft',
  'stomp': 'stomp_soft',
  'leap': 'leap_soft',
  'freeze': 'freeze_soft',
  'elephant': 'elephant_soft',
  'kangaroo': 'kangaroo_soft',
};

/// [sfx], or its soft version in quiet mode.
String soundFor(String sfx, {required bool quiet}) => quiet ? softSounds[sfx] ?? sfx : sfx;

/// The art of a move's two poses (assets/art/moves/): `frog_a`, or with
/// another animal doing it, `snake-worm_a`.
String poseArt(Move m, Species s, String frame) => s == m.species ? 'moves/${m.id}_$frame' : 'moves/${m.id}-${s.name}_$frame';

/// The child showing how a person does it (assets/art/kids/).
String kidArt(Move m, String frame) => 'kids/${m.id}_$frame';

/// The moves with a second animal (art is drawn for these pairs only).
const alsoDoneBy = {'snake': [Species.worm], 'bird': [Species.magpie]};
