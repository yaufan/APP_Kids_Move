# 動物動一動的圖

全部是 Python 畫的 SVG（毛球毛根風），約定在 [docs/art.md](../../docs/art.md)。

```
python3 build.py all                 # 全部重畫，再檢查
python3 build.py animals             # 只畫一個（animals、kids、guides、scenes、ui）
python3 build.py check               # flutter_svg 的規則
python3 build.py sheet 輸出.png moves # 把一個資料夾的圖排成一張看（要 Node.js 和 Playwright）
python3 build.py fluttercheck        # 用真的 flutter_svg 和 Chromium 各畫一次比對
python3 icon.py preview 輸出.png      # APP 圖示的預覽
python3 icon.py export               # APP 圖示寫進 Android 和 iOS
```

## 檔案
- `kit.py`：畫法（毛球、毛根、會轉的大眼睛、不織布）和檢查。
- `animals.py`：兩種骨架（正面站著的 `biped`、側面四隻腳的 `quad`）和其他自己畫的動物；`MOVES` 是每個動作的兩個姿勢。
- `kids.py`：「像這樣」的小朋友，每個動作兩個姿勢。
- `guides.py`：六隻帶路的動物（站著、揮手、睡覺）。
- `scenes.py`：背景。`ui.py`：首頁按鈕、鎖、章、打勾、呼吸小花、「先看看四周」的卡。`icon.py`：APP 圖示。

## 加一個動作
1. `app/lib/core/moves.dart` 加一個 `Move`。
2. `animals.py` 的 `MOVES` 加兩個姿勢（用現有動物的樣子，或寫一個新的 `xxx_look`），`kids.py` 的 `POSES` 也加兩個。
3. `python3 build.py all`，再 `python3 build.py fluttercheck`；`app/test/art_test.dart` 會檢查每個動作都有圖。
