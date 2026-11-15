# 給 Claude 的專案規則（動物動一動）

這份是這個專案的「記憶」。每個在這個專案裡工作的 Claude 都要照著做。它是「畫畫小鎮」（https://github.com/yaufan/APP_Kids_Paint）、「字母寵物」（https://github.com/yaufan/APP_Kids_Paint_for_learning_writing）、「動物小餐廳」（https://github.com/yaufan/APP_Kids_Cook）、「小卡認天下」（https://github.com/yaufan/APP_Kids_Card_Game）、「想一想樂園」（https://github.com/yaufan/APP_Kids_Brainstorming）、「眼尖尖大挑戰」（https://github.com/yaufan/APP_Kids_FalseCharge）、「迷宮小冒險」（https://github.com/yaufan/APP_Kids_maze）「小小生活家」（https://github.com/yaufan/APP_Kids_live_circ）、「小小音樂家」（https://github.com/yaufan/APP_Kids_Music）、「心情小屋」（https://github.com/yaufan/APP_Kids_Feelings）、「晚安小鎮」（https://github.com/yaufan/APP_Kids_Goodnight）、「安全小隊」（https://github.com/yaufan/APP_Kids_Safety）和「ㄅㄆㄇ小火車」（https://github.com/yaufan/APP_Kids_Bopomofo）的兄弟 APP，技術和流程照那邊（畫風不同），這裡寫這個專案自己的事。程式的架構最接近ㄅㄆㄇ小火車和安全小隊（Python 畫 SVG、ParentPass、休息時間、原始手指事件、等語音念完才往下），螢幕保持亮著照晚安小鎮；有疑問先看那邊怎麼做。

## 和使用者合作
- **一律用繁體中文回覆**，用白話說明，少用技術名詞；要用的話順便解釋。
- 使用者用手機上的 Claude App 看對話，**打不開 artifact 連結**。圖片、影片、聲音、QR code 都用傳檔案的方式（SendUserFile）給。
- 設計階段：每個想法都畫成草圖（`docs/mockups/`）傳給使用者看，再問。
- 之後每做完一版：給示範影片片段、手機截圖、下載 QR code（和畫畫小鎮一樣）。
- 有要使用者決定的事，列出選項和我的建議，再問。
- 不要開 pull request，除非使用者要求。用了網路搜尋，回覆最後附「Sources:」和連結。

## 這個 APP
- 給 **2～5 歲**的小朋友，在台灣，國語為主：跟著動物動身體。手機立在桌上像一台小電視，一隻大大的動物做一個動作（青蛙跳、黑熊爬、紅鶴單腳站、螃蟹走……），小朋友用整個身體跟著學；**螢幕只是教練**。
- **APP 看不到小朋友**（沒有相機、沒有感應器），所以永遠不說「做對了」「好標準」；換下一個只看音樂和時間，「做好了！」只是「下一個」。
- 內容：五個小冒險（叢林探險、去動物園、海底世界、下雨天、台灣山林，每個最後慢慢伸展）、29 個動作（三個難度＋安靜模式的版本＋每個動作自己的音效）、動物舞會（跳舞木頭人，停的時候變動物；大人當 DJ）、自己排（點卡片排體操，存 6 套）、慢慢伸展（呼吸小花）。
- 安全：每次開始動之前都有「先看看四周」（推開桌椅、不在床上跳、光腳丫、手機立在桌上）；安靜模式（第一次打開時問家長）、地方小、可以關掉某些動作，家長關掉的永遠不會再出現。
- 三個難度：小小（2～3 歲）、中（3～4 歲）、大（4～5 歲）：動作數、每個動作幾秒、一起數到幾、動作的版本都不同。
- 帶路的動物小朋友自己選（台灣獼猴、石虎、台灣黑熊、台灣藍鵲、梅花鹿、穿山甲），家長模式可以換。
- 畫風：**毛球毛根風**，只做一種（毛線球身體、毛根手腳、會轉的大眼睛；輪廓粗、對比強，毛只是細細一圈邊，2 公尺外也看得清楚）。要和兄弟 APP 的畫風**不一樣**。
- 畫面**橫的直的都可以**：橫的是桌上小電視（動物左、卡片右），直的動物在上、卡片在下。冒險和舞會的時候螢幕保持亮著（視窗旗標，不要權限）。
- 每次玩多久由家長設定（預設 15 分鐘），時間到了做完現在的動作和最後的伸展才休息，說「換你去做了！」「關掉螢幕，去外面走一走、跳一跳吧」。
- 免費版：叢林探險、去動物園、動物舞會、慢慢伸展和全部的安全設定；完整版：海底世界、下雨天、台灣山林、自己排。購買只在家長模式。
- 技術名稱：Flutter 專案 `animal_moves`、applicationId `com.yaufan.animalmoves`、APK `animal-moves-版本-arm64.apk`、簽章環境變數 `ANIMAL_MOVES_KEYSTORE`（密碼 `ANIMAL_MOVES_KEYSTORE_PASSWORD`）。
- 資安：不接受別的 APP 傳來的頁面（`flutter_deeplinking_enabled` 關掉、`overridePlatformDefaultLocation`），家長模式只能從家長關卡進去（`ParentPass`），不要任何權限。
- 不連網、不定位、沒有廣告、沒有帳號。以後上架要收費：免費下載一部分，一次買斷完整版，購買只在家長模式（要過家長關卡）。
- 每個動作都要有音效，全部用程式合成。
- 授權：非商業使用（`LICENSE`），中英文版本；別人做的部分（字型）在 `NOTICE.md`。
- 名稱：動物動一動。GitHub：https://github.com/yaufan/APP_Kids_Move

## GitHub Actions
- 工作流程（照小小生活家；第一次放上 main 前要先問）：
  - `app.yml`（App）：推到 `main` 而且改到 `app/**` 時跑分析、全部測試（含完整流程）、打包 APK，約 15～20 分鐘。
  - `release.yml`（Release）：推到 `main` 而且改到 `app/pubspec.yaml`、`CHANGELOG.md` 或它自己時，版本還沒發布過就打包三個 APK 放上 Releases，約 20 分鐘；版本沒變約 1 分鐘。
  - `cleanup.yml`：手動，刪舊的建置檔案，約 1 分鐘。
- 推工作分支（`claude/...`）不會啟動任何工作流程。
- 簽章：和畫畫小鎮用**同一把測試金鑰**（別名 `kidspaint`），Secrets 名稱一樣：`ANDROID_KEYSTORE_BASE64`、`ANDROID_KEYSTORE_PASSWORD`，要放在這個專案的 Actions → Secrets → Repository secrets。指紋 `TEST_KEY_SHA256` 寫在工作流程裡。以後上架要換成正式的上傳金鑰。
- 發新版本：`app/pubspec.yaml` 的 `version`、`app/lib/app/version.dart` 的預設值、`CHANGELOG.md` 最上面一段（`## 版本 …`）三個要一致（`test/version_test.dart` 檢查）。
- **任何會啟動 Actions 的動作，都要先問使用者，等使用者同意才做**，問的時候說清楚四件事：
  1. 會跑哪些工作流程。
  2. 這次大約用掉幾分鐘。
  3. 這個月目前用了多少。
  4. 跑完大約還剩多少。

  規則和畫畫小鎮的 `CLAUDE.md` 一樣；那個帳號每月 2,000 分鐘是所有私有專案共用的，Mac 主機的 1 分鐘算 10 分鐘。

## Git
- **發布新版本、做成可以安裝的 APK、給下載 QR code**：照 skill `release-kids-app`（`.claude/skills/release-kids-app/SKILL.md`），兄弟 APP 共用同一份。
- 在系統指定的 `claude/...` 工作分支上開發，commit 完就推這個分支。
- commit 訊息用英文寫清楚改了什麼和為什麼，結尾加系統要求的署名行。不要寫模型名稱。
- 不能 commit：金鑰、密碼、不公開的文件、`__pycache__`。

## 和畫畫小鎮共用的做法（開始寫程式時照著做）
- Flutter 3.47.8、Riverpod、flutter_svg、audioplayers、flutter_tts。存檔是一個 JSON 檔（`app/lib/core/store.dart`），沒有用 drift，所以本機跑測試**不用** sqlite 那段，直接 `flutter test`。
- 觸控：用原始的手指事件（`Listener`），手指一碰就畫。不要用拖曳手勢，它要移動 36 點才開始，小朋友短短的一筆會不見。
- 圖和聲音都用程式產生（SVG 用 Python 畫；聲音用 numpy 合成），不用別人的素材。
- 本機測試：在 `app/` 裡 `flutter test`（不含 `test/flow_test.dart`），`flutter analyze` 要零問題。以後加了 drift，才照畫畫小鎮的 `tools/run_tests.sh`（pubspec 的 sqlite 那段不能 commit）。
- 完整流程和截圖：`flutter test test/flow_test.dart`，截圖在 `app/build/screenshots/`。
- 示範影片（每一版都要給使用者）：在 `app/` 裡 `flutter test test/demo/demo_video_test.dart --dart-define=DEMO=true`（約 5～10 分鐘，要 ffmpeg），再在專案根目錄 `python3 tools/demo_audio.py` 把背景音樂和音效混進去。輸出 `app/build/demo/demo.mp4`；`chapters.txt` 是每一段開始的格數（每秒 10 格），用來剪新功能的片段。

## 目前的狀態（2026-11-15）
- 設計定案（`docs/design.md` 最後「已經決定的事」），0.1 開發中。
- GitHub 專案使用者還沒建；先在本機的 `claude/relaxed-albattani-6mbwpz` 分支 commit，建好後再推。
