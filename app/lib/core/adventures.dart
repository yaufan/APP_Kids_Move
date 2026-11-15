import 'moves.dart';
import 'sounds.dart';

/// One move in an adventure, from the level it starts at (小小 does fewer).
class Step {
  const Step(this.move, this.story, {this.from = Level.small, this.species, this.name, this.fast = false, this.quietStory});

  final String move;

  /// What it is in the story (「跳過荷葉，去找香蕉！」).
  final String story;

  /// The story in quiet mode, when [story] asks for a jump (「蹲在荷葉上！」).
  final String? quietStory;
  final Level from;

  /// Another animal doing the same move (蚯蚓扭扭 is 蛇扭扭 done by a worm).
  final Species? species;
  final String? name;

  /// Faster frames (「小魚游快一點」).
  final bool fast;
}

/// A little adventure (docs/design.md 「小冒險」): a warm-up, moves in a
/// story, and a slow stretch at the end.
class Adventure {
  const Adventure({
    required this.id,
    required this.zh,
    required this.story,
    required this.color,
    required this.music,
    required this.steps,
    required this.stretch,
    required this.free,
    required this.lead,
  });

  final String id;
  final String zh;
  final String story;

  /// Its card's colour (0xAARRGGBB).
  final int color;
  final Music music;
  final List<Step> steps;

  /// The slow stretch at the end.
  final String stretch;

  /// In the free version.
  final bool free;

  /// The animal on its card.
  final Species lead;

  /// The background (assets/art/scenes/).
  String get scene => 'scenes/$id';
}

const adventures = <Adventure>[
  Adventure(
    id: 'jungle',
    zh: '叢林探險',
    story: '去叢林找香蕉',
    color: 0xFF8FD18A,
    music: Music.jungle,
    free: true,
    lead: Species.frog,
    steps: [
      Step('giraffe', '先伸伸懶腰，看看香蕉在哪裡！'),
      Step('monkey', '猴子摸摸，準備出發！', from: Level.mid),
      Step('frog', '跳過荷葉！', quietStory: '蹲在荷葉上！'),
      Step('bear', '爬過山洞！'),
      Step('snake', '鑽過草叢！', from: Level.big),
      Step('elephant', '大象來了，踩踩踩！'),
      Step('flamingo', '站在石頭上，找到香蕉了！'),
    ],
    stretch: 'tortoise',
  ),
  Adventure(
    id: 'zoo',
    zh: '去動物園',
    story: '一間一間看動物',
    color: 0xFFFFD77A,
    music: Music.zoo,
    free: true,
    lead: Species.penguin,
    steps: [
      Step('penguin', '第一間，企鵝館！'),
      Step('kangaroo', '袋鼠在跳高！', quietStory: '袋鼠在伸高高！'),
      Step('giraffe', '長頸鹿在吃樹葉！'),
      Step('elephant', '大象在散步！'),
      Step('flamingo', '紅鶴在池子邊！'),
      Step('monkey', '猴子山到了！', from: Level.mid),
      Step('sloth', '樹懶在樹上，慢慢的。', from: Level.mid),
      Step('lion', '最後是好笑的獅子！', from: Level.big),
    ],
    stretch: 'butterfly',
  ),
  Adventure(
    id: 'sea',
    zh: '海底世界',
    story: '潛到海底找朋友',
    color: 0xFF8CD3F0,
    music: Music.sea,
    free: false,
    lead: Species.fish,
    steps: [
      Step('fish', '噗通！潛到海裡！'),
      Step('crab', '沙灘上的螃蟹！'),
      Step('octopus', '章魚在石頭旁邊。', from: Level.mid),
      Step('starfish', '海星在發亮！'),
      Step('seaturtle', '跟海龜一起划！'),
      Step('fish', '小魚游快一點！', from: Level.big, fast: true),
      Step('jellyfish', '水母飄過來了。'),
    ],
    stretch: 'tortoise',
  ),
  Adventure(
    id: 'rain',
    zh: '下雨天',
    story: '下雨了，動物們跑回家',
    color: 0xFFA9C3E0,
    music: Music.rain,
    free: false,
    lead: Species.duck,
    steps: [
      Step('frog', '跳過水窪！', quietStory: '蹲在水窪邊！'),
      Step('duck', '鴨子在雨裡走！'),
      Step('snake', '蚯蚓鑽出來了！', from: Level.mid, species: Species.worm, name: '蚯蚓扭扭'),
      Step('bunny', '兔子跳過水窪！', from: Level.big, quietStory: '兔子踮腳看水窪！'),
      Step('squirrel', '松鼠撿果子回家！'),
      Step('bird', '小鳥飛回家！'),
      Step('flamingo', '紅鶴站在石頭上躲雨。'),
    ],
    stretch: 'rainbow',
  ),
  Adventure(
    id: 'mountain',
    zh: '台灣山林',
    story: '認識台灣山裡的動物',
    color: 0xFFB5DDA0,
    music: Music.mountain,
    free: false,
    lead: Species.leopardcat,
    steps: [
      Step('tiptoe', '石虎躡手躡腳，噓！'),
      Step('bear', '台灣黑熊爬過來！'),
      Step('deer', '梅花鹿跨過小溪！', quietStory: '梅花鹿大步走過小溪！'),
      Step('bird', '台灣藍鵲飛過山谷！', species: Species.magpie, name: '台灣藍鵲飛'),
      Step('salmon', '櫻花鉤吻鮭往上游！', from: Level.mid),
      Step('monkey', '台灣獼猴摸摸！'),
      Step('pangolin', '穿山甲捲成一顆球。', from: Level.big),
    ],
    stretch: 'catarch',
  ),
];

final adventuresById = {for (final a in adventures) a.id: a};
