# ユニットスプライト・カードイラスト生成業務フロー

作成日: 2026-04-14  
対象: 65体のユニット（盤面スプライト48×48 + カードイラスト180×180）  
生成手段: Gemini 2.0 Flash 画像生成  
一貫性担保: 種族シード方式 + 共通プロンプト90%

---

## 前提条件

### 参照ドキュメント
- `visual_spec_critical.md` - 技術仕様
- `gemini_sprite_generation_strategy.md` - 生成戦略
- `cards.json` - カードデータ（65体の定義）

### 一貫性担保の3原則
1. **種族シード方式**: アンカー個体をreference imageとして全生成に使用
2. **共通プロンプト90%**: スプライトとイラストで同じベースプロンプト使用
3. **同一セッション生成**: 種族内は同日・連続生成でスタイル揺れ防止

---

## フェーズ0: 事前準備（1日）

### 0-1. visual_hints.json作成（1時間）
**担当**: 人間  
**成果物**: `tools/sprite_gen/data/visual_hints.json`

65体全てに個体差別化記述を追加。

```json
{
  "slime": {
    "hint": "simple cyan gel blob, basic form, faintly glowing core"
  },
  "paralyze_slime": {
    "hint": "yellow electric slime, lightning bolt patterns, crackling energy"
  },
  ...
}
```

**品質基準**:
- 各ヒントは20-30単語
- 種族の特徴を残しつつ個体差を明確に
- 英語で記述（Geminiプロンプトに直接使用）

---

### 0-2. スクリプト実装（4時間）
**担当**: 実装者  
**成果物**: `tools/sprite_gen/` 配下のPythonスクリプト

実装ファイル:
```
tools/sprite_gen/
├── config.py              # APIキー・パレット定義
├── prompt_builder.py      # プロンプト組み立て
├── gemini_client.py       # Gemini API呼び出し
├── generate.py            # メイン生成ループ
├── selector_server.py     # Flask選定UI
├── postprocess.py         # 後処理（リサイズ・背景除去）
└── data/
    ├── visual_hints.json
    ├── anchors/           # アンカー画像格納先
    ├── output/            # 生成結果（候補全て）
    ├── selections.json    # 選定結果
    └── final/             # 後処理完了版
```

**テスト**: 1体のダミー生成で動作確認

---

### 0-3. プロンプトテンプレート確定（2時間）
**担当**: 人間 + 実装者  
**成果物**: `prompt_builder.py`内のテンプレート

グローバルスタイル（全65体共通）:
```
STYLE: pixel art, 16-bit JRPG style, clean outline, centered composition,
flat solid background (#1a1a2e dark navy), no text, no UI, no shadow on ground,
SETTING: bio-digital laboratory experiment, synthetic lifeform, data-ghost,
glitch particles, faint cyan circuit lines, SF horror aesthetic
```

種族別テンプレート:
- スライム: `gelatinous, translucent, liquid core, floating data fragments, cyan/violet palette`
- 獣: `quadruped, synthetic fur, exposed circuit joints, bio-mechanical, orange/bone palette`
- アンデッド: `skeletal, tattered cloth, glitching silhouette, corrupted wisps, purple/green palette`

末尾切替（スプライト/イラスト）:
- スプライト: `full body, side-facing, 48x48 pixel sprite, chunky pixels, minimal detail`
- イラスト: `bust-up 3/4 view, 180x180, detailed pixel shading, expressive core`

**確認**: スライム1体でスプライト+イラストを3パターン生成してスタイル確認

---

## フェーズ1: アンカー確立（1日）

### 1-1. アンカー候補選定（10分）
**担当**: 人間  
**成果物**: アンカー対象ユニットリスト

各種族の代表1体を選定:
- スライム: `slime`（基本スライム）
- 獣: `wolf`（ウルフ）
- アンデッド: `skeleton`（スケルトン）

**基準**: コモンで特徴が素直、個体差が少ない

---

### 1-2. アンカー生成（6時間）
**担当**: 実装者  
**成果物**: 各種族アンカー画像（6枚: 3種族×2種類）

各アンカーを**10パターン**生成:
- スライムスプライト × 10
- スライムイラスト × 10
- ウルフスプライト × 10
- ウルフイラスト × 10
- スケルトンスプライト × 10
- スケルトンイラスト × 10

**生成条件**:
- 同一プロンプト
- 1パターン生成ごとに1秒待機（API制限対策）
- 全パターンを保存

---

### 1-3. アンカー選定（2時間）
**担当**: 人間  
**成果物**: `data/anchors/` に6枚

10パターンから最良の1枚を選定:
- `slime_sprite.png`
- `slime_illust.png`
- `wolf_sprite.png`
- `wolf_illust.png`
- `skeleton_sprite.png`
- `skeleton_illust.png`

**選定基準**:
1. 種族の特徴が最も明確
2. 世界観との整合性が高い
3. スプライトとイラストが同一キャラに見える

**重要**: この6枚が全生成のreference imageになるため、時間をかけて厳選

---

## フェーズ2: MVP検証（2日）

### 2-1. 獣21体生成（1日）
**担当**: 実装者  
**成果物**: `output/beast/` 配下に21体×6枚（スプライト3+イラスト3）

```bash
cd tools/sprite_gen
python generate.py --race beast --patterns 3
```

**生成条件**:
- アンカー画像（wolf_sprite.png, wolf_illust.png）をreference imageとして使用
- 各ユニットを3パターン生成
- 同一種族は連続生成（スタイル揺れ防止）
- 10体生成ごとにアンカーと並べて退行チェック

**所要時間**: 約6-8時間（API速度次第）

---

### 2-2. MVP選定（4時間）
**担当**: 人間  
**成果物**: `selections.json` + 選定済み画像

Flask選定UIで3パターンから1枚選定:
```bash
python selector_server.py
# ブラウザでhttp://localhost:5000にアクセス
# 1/2/3キー押下で選択
```

**選定基準**（3項目のみ）:
1. 種族の特徴が3秒で分かるか
2. アンカーと同じ世界観か
3. スプライトとイラストが同一キャラに見えるか

**記録**: 選定結果を`selections.json`に保存

---

### 2-3. MVP判定（1時間）
**担当**: 人間  
**成果物**: 続行/見直し判断

採用率を計算:
```
採用率 = 選定できたユニット数 / 21体
```

**判定基準**:
- **採用率 ≥ 50%**: フェーズ3へ続行
- **採用率 < 50%**: アンカー差替またはプロンプト調整

**採用率30%未満の場合**: 種族アンカーを差替（1-2から再実施）

---

## フェーズ3: 本番量産（3日）

### 3-1. スライム24体生成（1日）
**手順**: フェーズ2-1と同様

```bash
python generate.py --race slime --patterns 3
```

---

### 3-2. アンデッド15体生成（0.5日）
**手順**: フェーズ2-1と同様

```bash
python generate.py --race undead --patterns 3
```

---

### 3-3. ボス専用5体生成（0.5日）
**手順**: フェーズ2-1と同様

```bash
python generate.py --race boss --patterns 5
```

**注意**: ボスは5パターン生成（通常より多い）

---

### 3-4. 全体選定（1日）
**手順**: フェーズ2-2と同様

スライム24体 + アンデッド15体 + ボス5体 = 44体を選定

---

## フェーズ4: 後処理（1日）

### 4-1. 自動後処理（2時間）
**担当**: 実装者  
**成果物**: `data/final/` 配下に65体×2種類

```bash
python postprocess.py
```

**処理内容**:
1. 背景除去（色キー #1a1a2e）
2. リサイズ（Nearest Neighbor）
   - スプライト: 48×48
   - イラスト: 180×180
3. パレット量子化（16色）
4. アウトライン補正
5. 透過PNG出力

---

### 4-2. 品質チェック（2時間）
**担当**: 人間  
**成果物**: 修正リスト

自動チェック（足切り）:
- ファイルサイズ < 5KB → リジェネ
- 主要色が種族パレットから大幅乖離（ΔE > 40）→ リジェネ
- 背景色以外の面積 < 20% → リジェネ

目視チェック:
- 48×48で識別可能か
- 180×180で詳細が見えるか
- スプライトとイラストが対応しているか

**リジェネ対象**: 最大5体程度を想定

---

### 4-3. リジェネ（2時間）
**担当**: 実装者  
**成果物**: 修正版画像

問題のあるユニットのみ3パターン追加生成→再選定→後処理

---

## フェーズ5: Godot統合（1日）

### 5-1. ファイル配置（10分）
**担当**: 実装者  
**成果物**: Godotプロジェクトに配置

```bash
cp data/final/*_sprite.png res://assets/cards/units/
cp data/final/*_illust.png res://assets/cards/units/
```

**命名規則**:
- スプライト: `{unit_id}.png`（例: `slime.png`）
- イラスト: `{unit_id}_card.png`（例: `slime_card.png`）

---

### 5-2. 表示確認（4時間）
**担当**: 実装者  
**成果物**: 表示確認レポート

全65体をGodotで表示確認:
- バトル画面（盤面スプライト）
- DeckPrep画面（カードイラスト）
- 種族ごとの統一感
- スプライトとイラストの対応

**確認項目**:
- [ ] 全65体が正しく表示される
- [ ] 48×48で識別可能
- [ ] 180×180で詳細が見える
- [ ] 種族の統一感がある
- [ ] スプライトとイラストが同一キャラに見える

---

### 5-3. 微調整（2時間）
**担当**: 実装者  
**成果物**: 最終版アセット

表示確認で問題があった場合:
- 色調補正
- サイズ微調整
- 個別リジェネ（最大3体）

---

## 品質管理

### 一貫性チェックリスト（各フェーズで確認）

**種族内一貫性**:
- [ ] 同一種族のユニットが同じ色調・スタイルか
- [ ] アンカーとの乖離が小さいか
- [ ] 10体生成ごとに退行チェック実施

**スプライト↔イラスト一貫性**:
- [ ] 同一ユニットのスプライトとイラストが対応しているか
- [ ] 色・形状・特徴が一致しているか

**世界観一貫性**:
- [ ] グローバルスタイルが反映されているか
- [ ] SF horror aesthetic（実験体・データの残骸）が表現されているか

---

## リスク対策

### リスク1: 採用率が低い（< 50%）
**対策**:
1. アンカー個体を変更（別のコモンユニット）
2. プロンプトの調整（種族テンプレート見直し）
3. 生成パターン数を5に増やす

---

### リスク2: 種族内でスタイルが揺れる
**対策**:
1. 同一種族は同日・連続生成
2. 10体ごとにアンカーと並べて確認
3. 乖離が大きい場合は即座にアンカー差替

---

### リスク3: スプライトとイラストが別キャラに見える
**対策**:
1. 共通プロンプトの割合を95%に引き上げ
2. アンカー選定時にスプライト↔イラストの対応を重視
3. visual_hintsの記述を同一にする

---

## タイムライン（実作業10.5日）

| フェーズ | 作業内容 | 所要時間 | 累計 |
|---------|---------|---------|------|
| 0 | 事前準備 | 1日 | 1日 |
| 1 | アンカー確立 | 1日 | 2日 |
| 2 | MVP検証（獣21体） | 2日 | 4日 |
| **判定ゲート** | 続行/見直し | 0.5日 | 4.5日 |
| 3 | 本番量産（44体） | 3日 | 7.5日 |
| 4 | 後処理 | 1日 | 8.5日 |
| 5 | Godot統合 | 1日 | 9.5日 |
| 予備 | 微調整・リジェネ | 1日 | 10.5日 |

**カレンダー換算**: 週末＋平日夜運用で3-4週間

---

## 成果物チェックリスト

### 最終成果物
- [ ] `res://assets/cards/units/*.png` - 65体の盤面スプライト（48×48）
- [ ] `res://assets/cards/units/*_card.png` - 65体のカードイラスト（180×180）
- [ ] `tools/sprite_gen/data/visual_hints.json` - 個体差別化記述
- [ ] `tools/sprite_gen/data/selections.json` - 選定履歴
- [ ] `tools/sprite_gen/data/anchors/` - アンカー画像6枚

### ドキュメント
- [ ] 生成ログ（log.jsonl）
- [ ] 採用率レポート
- [ ] 品質チェック結果

---

## 次のアクション

1. **visual_hints.json作成開始**（30分でサンプル10体）
2. **スクリプト雛形実装**（1時間でgenerate.py基本構造）
3. **プロンプトテスト**（スライム1体で3パターン生成）

上記3つを完了したら、フェーズ1（アンカー確立）に進む。
