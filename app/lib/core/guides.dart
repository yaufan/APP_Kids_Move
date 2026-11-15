/// The guide the child picks the first time (docs/design.md 「已經決定的事」
/// 9): six Taiwanese animals, each with its own look (assets/art/guides/),
/// call, voice pitch and way of talking. The moves are still shown by many
/// different animals; the guide announces them and cheers.
enum Guide {
  macaque('小獼猴', '台灣獼猴', 'monkey', 1.25, '吱吱！', '吱吱！我是小獼猴，我們一起動一動！', '吱吱，身體熱熱的嗎？'),
  leopardcat('小石虎', '石虎', 'meow', 1.15, '喵嗚～', '喵嗚～我是小石虎，耳朵後面有白點點！', '喵嗚～謝謝你陪我們！'),
  bear('小黑熊', '台灣黑熊', 'bear', .9, '嗚哈！', '嗚哈！我是小黑熊，胸口有白色的月亮！', '嗚哈！流汗了嗎？'),
  magpie('小藍鵲', '台灣藍鵲', 'magpie', 1.35, '嘎嘎！', '嘎嘎！我是小藍鵲，有長長的藍尾巴！', '嘎嘎！我們動得好開心！'),
  deer('小梅花鹿', '梅花鹿', 'deer', 1.2, '呦呦！', '呦呦！我是小梅花鹿，身上有白點點！', '呦呦！心跳得快快的嗎？'),
  pangolin('小穿山甲', '穿山甲', 'pangolin', 1.05, '咕嚕咕嚕！', '咕嚕咕嚕！我是小穿山甲，會捲成一顆球！', '咕嚕咕嚕，好好玩喔！');

  const Guide(this.zh, this.species, this.call, this.pitch, this.hi, this.hello, this.cheer);

  /// What it is called (小獼猴).
  final String zh;
  final String species;

  /// Its call (a sound in assets/sounds/).
  final String call;

  /// How high the phone's voice speaks for it.
  final double pitch;

  /// A short word it says before announcing a move.
  final String hi;

  /// What it says when picked.
  final String hello;

  /// A cheer at the end of an adventure (thanks and fun, never 「做對了」).
  final String cheer;

  /// Its pictures: idle, wave or sleep.
  String art(String pose) => 'guides/${name}_$pose';
}
