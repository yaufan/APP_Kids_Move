# 圖和程式的約定（動物動一動）

畫風是**毛球毛根風**（`docs/design.md`「選 B 之後怎麼畫」）：每隻動物像幼兒園的勞作，毛線球當身體和頭、毛根（扭扭棒）當手腳、會轉的大眼睛、不織布剪的嘴巴耳朵。全部的圖用 Python 畫成 SVG（`design/art/`），APP 用 flutter_svg 顯示。字**不畫在圖裡**：APP 用字型（jf open 粉圓）寫。

## 怎麼畫（`design/art/kit.py`）
- **毛球** `pom`：外面一圈粗粗的深色、有點凹凸的輪廓（遠遠看形狀很清楚），裡面一圈細細的毛（同色），身體是圓圓的明暗（左上亮），上面幾根淡淡的纖維。毛只是細細一圈，不是幾百根毛。
- **毛根** `cleaner`：深色的外框、本來的顏色、中間淡一點的線，和一段一段斜斜的扭紋。手腳每一段的角度用 `limb`（0 是往下、90 往右、180 往上）。
- **會轉的大眼睛** `googly`：深色的邊、白色、大大的黑眼珠（滾到看的方向）、一個亮點；睡覺時是一條彎彎的線。
- **不織布** `felt`：平平的顏色加上剪邊（嘴巴、耳朵裡面、鳥嘴、殼、斑點）。
- 背景是安靜的淡色不織布（`scenes.py`），動物永遠是畫面上最深、最鮮豔的東西。
- flutter_svg 畫不出來的東西都不用：`<filter>`、`<mask>`、`<clipPath>`、`<style>`、`<text>`、`<image>`、`<pattern>`。`python3 build.py check` 檢查規則，`python3 build.py fluttercheck` 用真的 flutter_svg 和 Chromium 各畫一次比對。
- 每個檔案小於 70 KB；同樣的程式畫兩次，檔案一模一樣。

## 檔案和位置（APP 用的名字要和這裡一樣）
| 檔案 | 大小（viewBox） | APP 怎麼用 |
|---|---|---|
| `moves/<動作>_<a\|b>.svg` | 300 × 240 | 每個動作兩個姿勢（`animals.py` 的 `MOVES`），地板在 y = 222。APP 照拍子換姿勢，再加上整隻跳、搖、爬、游（`lib/app/figures.dart` 的 `PoseView`）。換一隻動物做同一個動作：`snake-worm_a.svg`（蚯蚓扭扭）、`bird-magpie_a.svg`（台灣藍鵲飛） |
| `kids/<動作>_<a\|b>.svg` | 160 × 160 | 「像這樣」：小朋友示範人的做法（`kids.py`），地板在 y = 150 |
| `guides/<帶路動物>_<idle\|wave\|sleep>.svg` | 240 × 240 | 六隻帶路的動物（`guides.py`）：站著、揮手（換動作的時候）、睡覺（休息畫面） |
| `scenes/<home,jungle,zoo,sea,rain,mountain,party,calm,rest>.svg` | 400 × 250 | 背景，從下面對齊填滿；直的時候左右會被切掉，重要的東西不放邊邊 |
| `safety/<clear,nobed,feet,phone,spin>.svg` | 200 × 150（spin 200 × 160） | 「先看看四周」的四張卡和轉一圈的小朋友 |
| `ui/<party,build,calm,lock,stamp,check,flower_open,flower_closed>.svg` | 160 × 160 | 首頁三個大按鈕、鎖、「去過了」的章、打勾、呼吸小花（開、合） |

## 顏色
- 「做好了！」一律綠色 `#3FB55B`、「暫停」一律橘色 `#FF9A3C`；字和眼珠是深紫 `#2F2436`（不用純黑）；背景奶油色 `#FFF8EC`。
- 每個冒險的卡片：叢林綠、動物園黃、海底藍、下雨天灰藍、台灣山林淺綠（`lib/core/adventures.dart`）。

## APP 圖示
`python3 design/art/icon.py preview 輸出.png` 看大圖、手機裁切和兄弟 APP 放在一起的樣子；`export` 寫進 Android（含 adaptive）和 iOS。
綠色毛球青蛙舉起雙手跳起來，下面一片荷葉，藍天和草地。
