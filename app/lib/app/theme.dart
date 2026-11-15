import 'package:flutter/material.dart';

/// The app's colours (docs/art.md 「顏色」): calm felt backgrounds so the
/// animals stand out, a green 「做好了！」 and an orange pause everywhere,
/// deep plum words (never pure black).
abstract final class Felt {
  static const ink = Color(0xFF3A2E3F);
  static const inkSoft = Color(0xFF7D7088);
  static const cream = Color(0xFFFFF8EC);
  static const paper = Color(0xFFFFFDF7);
  static const line = Color(0xFFE9DFCF);
  static const done = Color(0xFF3FB55B);
  static const pause = Color(0xFFFF9A3C);
  static const stamp = Color(0xFFE8473F);
  static const yellow = Color(0xFFFFD24A);
  static const sky = Color(0xFFBFE6F7);
  static const lilac = Color(0xFFD9CCF2);
  static const mint = Color(0xFFCDEFD6);
  static const pink = Color(0xFFF7B6CF);
  static const blue = Color(0xFF5DA9E9);
  static const calm1 = Color(0xFFE6E0F5);
  static const calm2 = Color(0xFFDDF1E4);
  static const night1 = Color(0xFF3B3F78);
  static const night2 = Color(0xFF7A6BB0);
  static const parentBg = Color(0xFFF4F2EE);

  /// The darker edge of something in [c].
  static Color edge(Color c) => Color.lerp(c, ink, .42)!;
}

abstract final class FeltTheme {
  /// jf open 粉圓 (OFL): a rounded typeface made in Taiwan.
  static const font = 'Huninn';

  static ThemeData light() {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Felt.done, surface: Felt.cream),
      scaffoldBackgroundColor: Felt.cream,
      fontFamily: font,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
    return base.copyWith(textTheme: base.textTheme.apply(bodyColor: Felt.ink, displayColor: Felt.ink, fontFamily: font));
  }
}
