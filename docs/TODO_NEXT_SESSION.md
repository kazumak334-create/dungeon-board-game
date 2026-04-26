# 次回セッションのTODO

作成日: 2026-04-10

---

## 画像生成作業（未完了）

### 実行待ちコマンド

**事前準備**：
1. ライブラリインストール：`pip install google-genai Pillow python-dotenv`
2. `.env` ファイル作成（プロジェクトルート）：
   ```
   GEMINI_API_KEY=あなたのAPIキー
   ```
3. APIキー取得：https://aistudio.google.com/apikey

**高優先度背景4枚**：
```bash
cd C:\Users\kazum\dungeon-board-game

# 1. タイトル背景
python tools/generate_image.py --prompt "地下遺構の入口、石造りの扉、灰色の霧、松明の光、ダークファンタジー、細密画風、モノクロ基調" --name "title_bg" --style dark_fantasy

# 2. 素材選択背景
python tools/generate_image.py --prompt "地下遺構内部、素材保管庫、石造りの部屋、錬金術台、灰色の霧、松明の光、ダークファンタジー、細密画風" --name "material_select_bg" --style dark_fantasy

# 3. マップ選択背景
python tools/generate_image.py --prompt "地下遺構のマップ、羊皮紙風、古びた地図、根の迷宮の回廊、ダークファンタジー、細密画風" --name "map_select_bg" --style dark_fantasy

# 4. バトル背景
python tools/generate_image.py --prompt "地下遺構の戦闘フィールド、石造りの回廊、灰色の霧、松明の光、ダークファンタジー、細密画風、モノクロ基調" --name "battle_bg" --style dark_fantasy
```

**中優先度（ノードアイコン6種）**：
```bash
python tools/generate_image.py --prompt "戦闘アイコン、剣と盾、赤系統、ダークファンタジー、細密画風" --name "node_battle" --style icon
python tools/generate_image.py --prompt "エリート戦闘アイコン、王冠と剣、金色、ダークファンタジー、細密画風" --name "node_elite" --style icon
python tools/generate_image.py --prompt "素材採集アイコン、宝箱、緑系統、ダークファンタジー、細密画風" --name "node_gather" --style icon
python tools/generate_image.py --prompt "ショップアイコン、コイン、黄色系統、ダークファンタジー、細密画風" --name "node_shop" --style icon
python tools/generate_image.py --prompt "イベントアイコン、問いかけ、紫系統、ダークファンタジー、細密画風" --name "node_event" --style icon
python tools/generate_image.py --prompt "ボスアイコン、ドクロと王冠、赤と金、ダークファンタジー、細密画風" --name "node_boss" --style icon
```

**詳細リスト**：
- 全画面別グラフィック素材リスト：Designer agentの出力参照（前回セッション末尾）
- 合計40+素材の詳細プロンプト記載済み

---

## Phase 2完了状況

### ✅ 完了
- スキルツリー実装（6階層ランダム生成）
- 敵スケーリングシステム（Act別プール）
- 警戒レベルシステム設計
- UI/UX精査・改善
- GAME_DESIGN.md確立

### 次のステップ
- **Phase 3**: マップシステム実装（警戒レベル統合）
- 既にMapGeneratorの骨格実装済み
- 警戒レベルをノード選択に連動させる

---

## 現在のブランチ

- ブランチ: `feature/phase3-map-v2`
- 最新コミット: `833d4e3` (Gemini画像生成スクリプト追加)
- Phase 2完了、Phase 3準備完了

---

## 参考ファイル

- `docs/GAME_DESIGN.md`: 設計の Single Source of Truth
- `docs/roadmap.md`: Phase別タスク一覧
- `tools/README_GENERATE_IMAGE.md`: 画像生成手順
- `docs/story/world_setting.md`: 世界観設定

---

## 注意事項

- `.env` ファイルは `.gitignore` に含まれている（コミット禁止）
- 生成画像は `assets/generated/` に保存される
- スクリプトは日本語プロンプト対応済み
