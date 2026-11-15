# 動物動一動

給 **2～5 歲**的小朋友，在台灣，國語為主：跟著動物動身體。手機立在桌上像一台小電視，一隻大大的動物做一個動作（青蛙跳、黑熊爬、紅鶴單腳站、螃蟹走……），小朋友用整個身體跟著學；**螢幕只是教練**。

- 設計：[docs/design.md](docs/design.md)，草圖在 `docs/mockups/`。
- 和「畫畫小鎮」「字母寵物」「動物小餐廳」「小卡認天下」「想一想樂園」「眼尖尖大挑戰」「迷宮小冒險」「小小生活家」「小小音樂家」「心情小屋」「晚安小鎮」「安全小隊」「ㄅㄆㄇ小火車」是兄弟 APP：同一個作者、同一套技術、不同畫風。
- 不連網、不定位、沒有廣告、沒有帳號。

## 下載（Android）
- 最新版：[Releases](https://github.com/yaufan/APP_Kids_Move/releases/latest)，一般手機下載 `animal-moves-版本-arm64.apk`。
- 用手機掃描 [docs/download-qr.png](docs/download-qr.png)。

## 目前進度
- 0.1.0（測試版）：第一次的兩個問題、選帶路的動物（6 隻）、首頁、先看看四周、五個小冒險、29 個動作（三個難度、安靜模式、每個動作的音效）、動物舞會（含大人當 DJ）、自己排、慢慢伸展（呼吸小花）、休息時間、家長關卡和家長模式、九首曲子和音效、APP 圖示。毛球毛根風，橫的直的都可以。版本紀錄在 [CHANGELOG.md](CHANGELOG.md)。

## 程式和素材在哪裡
- `app/`：Flutter 程式。`lib/core/` 是動作（`moves.dart`）、冒險（`adventures.dart`）、帶路的動物（`guides.dart`）、一次的順序和時間（`session.dart`）、設定和紀錄（`game.dart`）、聲音、語音、螢幕保持亮著、存檔；`lib/app/` 是路由和休息時間、毛球偶的動畫（`figures.dart`）和共用的元件；`lib/features/` 是每個畫面。
- `design/art/`：用 Python 畫的圖（毛球毛根風），`python3 build.py all` 全部重畫，`fluttercheck` 用真的 flutter_svg 比對；`icon.py` 是 APP 圖示。約定在 `docs/art.md`。
- `design/sounds/make_sounds.py`：合成全部的音樂和聲音（`README.md` 有每個檔）。
- 測試：在 `app/` 裡 `flutter test`；完整流程 `flutter test test/flow_test.dart`，截圖在 `app/build/screenshots/`；示範影片 `flutter test test/demo/demo_video_test.dart --dart-define=DEMO=true`，再 `python3 tools/demo_audio.py`。

## 授權
- 非商業使用授權：自己、家人使用，或學校、非營利團體的教學，都可以免費使用、修改、分享，要註明出處。
- 商業用途（販賣、收費、廣告、上架）要先取得作者書面同意。也不可以拿來訓練 AI。
- 細節見 [LICENSE](LICENSE)；別人做的部分（字型）見 [NOTICE.md](NOTICE.md)。
