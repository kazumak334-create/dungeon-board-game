# Gemini 2.0 Flash ユニット量産戦略

作成日: 2026-04-14  
策定: planning Agent (Opus)

---

## 戦略概要

65体のユニットスプライト（48×48）とカードイラスト（180×180）を**種族シード方式**で量産する。

### 核心メカニズム：アンカー個体
1. 各種族の**参照個体（アンカー）**を最初に高品質生成
2. 以降の全生成でアンカー画像を`reference image`として入力
3. Geminiに「このスタイル・質感・配色を踏襲せよ」と指示
4. 種族内一貫性が自動的に担保される

### 同一キャラ性の保持
- スプライトとイラストは**共通プロンプト90% + 末尾のみ切替**
- 同一プロンプト＋解像度指定違い → 同一キャラに見える

### MVP検証
獣21体で先行テスト → 採用率50%未満なら戦略見直し

---

## プロンプト設計

### 共通グローバルスタイル（全65体に固定付与）

```
STYLE: pixel art, 16-bit JRPG style, clean outline, centered composition,
flat solid background (#1a1a2e dark navy), no text, no UI, no shadow on ground,
SETTING: bio-digital laboratory experiment, synthetic lifeform, data-ghost,
glitch particles, faint cyan circuit lines, SF horror aesthetic
```

**重要**: この10行を全プロンプトの冒頭に必ず挿入。世界観ブレを防ぐ最大の要。

---

### 種族別ベーステンプレート

| 種族 | コアキーワード | カラーパレット | シルエット特徴 |
|------|---------------|---------------|---------------|
| **スライム** | gelatinous, translucent, liquid core, floating data fragments inside | cyan #00e5ff / violet #7b2cbf | 丸・不定形・下部広がり |
| **獣** | quadruped, synthetic fur, exposed circuit joints, bio-mechanical | orange #ff6b35 / bone #e8dcc4 | 四足・鋭角・筋肉質 |
| **アンデッド** | skeletal, tattered cloth, glitching silhouette, corrupted data wisps | purple #4a0e4e / sickly green #7fb069 | 縦長・欠損・煙状 |
| **ボス** | oversized, asymmetric, multiple cores, crown of light | 種族色+gold #ffd60a | 画面占有・威圧感 |

---

### スプライト / イラスト切替

**共通本文**: グローバルスタイル + 種族テンプレ + 個体固有記述（visual_hints.jsonから取得）

**末尾のみ差替**:

#### スプライト用末尾
```
full body, side-facing pose, 48x48 pixel sprite, 
large chunky pixels, minimal detail, readable silhouette at tiny size
```

#### イラスト用末尾
```
bust-up 3/4 view portrait, 180x180, detailed pixel shading, 
expressive face/core, dramatic lighting
```

---

### プロンプト組み立て例

#### スライム基本体のスプライト
```
STYLE: pixel art, 16-bit JRPG style, clean outline, centered composition,
flat solid background (#1a1a2e dark navy), no text, no UI, no shadow on ground,
SETTING: bio-digital laboratory experiment, synthetic lifeform, data-ghost,
glitch particles, faint cyan circuit lines, SF horror aesthetic

SUBJECT: gelatinous slime, translucent cyan gel, liquid core visible,
floating data fragments inside, simple rounded shape,
pale blue with violet highlights

full body, side-facing pose, 48x48 pixel sprite, 
large chunky pixels, minimal detail, readable silhouette at tiny size
```

---

## 生成フロー

### フェーズA: アンカー確立（最重要・時間をかける）

#### 1. アンカー候補選定
各種族の代表1体を選定（コモンで特徴が素直なもの）:
- スライム: `slime`（基本スライム）
- 獣: `wolf`（ウルフ）
- アンデッド: `skeleton`（スケルトン）
- ボス: 各ボス個別

#### 2. アンカー生成
- 各代表を**10パターン**生成（スプライト10+イラスト10）
- 人間が1枚ずつ厳選
- 選定画像を固定: `anchors/{race}_sprite.png`, `anchors/{race}_illust.png`

#### 3. 以降の全生成でアンカーを参照
Gemini APIの`reference image`機能で添付

---

### フェーズB: MVP検証（獣21体）

#### 順序の理由
獣が最も記号性が強く、フロー検証に適する。

#### 処理フロー（各ユニット）
1. `cards.json`から`name/race/rarity`取得
2. `visual_hints.json`から個体固有記述取得
3. プロンプト組み立て
4. アンカー画像同梱してGemini API呼び出し
5. **3パターン生成**（スプライト3+イラスト3=計6枚）
6. `output/beast/{unit_name}/sprite_{1,2,3}.png`に保存

#### 採用率判定（重要）
獣21体完了時点で採用率を計算:
- **採用率≧50%**: 続行
- **採用率<50%**: 戦略見直し（アンカー差替・プロンプト調整）

---

### フェーズC: 量産（残り44体）

#### 順序
スライム24体 → アンデッド15体 → ボス5体

#### 種族内統一の担保
- **同一種族は同日・同セッションで一気に生成**
- プロンプトエンジニアリング揺れ防止
- 10体生成ごとに最初の1体と並べて退行チェック

---

### フェーズD: 選定・後処理

#### 選定UI
Python + Flask で簡易ビューア作成:
- 候補6枚（スプライト3+イラスト3）を並べて表示
- `1/2/3`キー押下で選択
- 選定結果を`selections.json`に記録

#### 自動後処理パイプライン
```
raw PNG（512×512等の生成サイズ）
  ↓
背景除去（色キー #1a1a2e）
  ↓
リサイズ（Nearest Neighbor）
  - スプライト: 48×48
  - イラスト: 180×180
  ↓
パレット量子化（16色）
  ↓
アウトライン補正
  ↓
完成PNG（透過背景）
```

---

## 品質管理

### 自動チェック（足切り）

以下の条件でリジェネ判定:
- ファイルサイズ < 5KB → 生成失敗疑い
- 主要色が種族パレットから大幅乖離（ΔE > 40）
- 背景色以外の面積 < 20% → 被写体小さすぎ

### 目視チェック（3項目のみ）

チェックリストを3項目に絞る:
- [ ] 種族の特徴が3秒で分かるか
- [ ] アンカーと同じ世界観か
- [ ] スプライトとイラストが同一キャラに見えるか

**3項目全てNG**: 種族内全体の再生成を疑う（アンカー差替検討）

### リジェネ基準

- 個体レベル: 6枚中1枚も採用できない → 3パターン追加生成
- 種族レベル: 採用率<30% → アンカー差替
- プロジェクトレベル: 全体採用率<40% → プロンプト全面見直し

---

## 実装スクリプト設計

### ファイル構成

```
tools/sprite_gen/
├── config.py              # APIキー・パレット定義・パス設定
├── prompt_builder.py      # プロンプト組み立てロジック
├── gemini_client.py       # Gemini API呼び出し・リトライ・rate limit
├── generate.py            # メイン: cards.json読込→ループ生成
├── selector_server.py     # Flask選定UI
├── postprocess.py         # 背景除去・リサイズ・パレット量子化
└── data/
    ├── anchors/           # 種族アンカー画像（8枚: 4種族×2種類）
    ├── visual_hints.json  # ユニット別の追加記述（手動作成）
    ├── output/            # 生成結果（候補全て保存）
    ├── selections.json    # 選定結果（どの候補を採用したか）
    └── final/             # 後処理完了版（Godotに配置）
```

---

### visual_hints.json（新規作成・手動）

`cards.json`は汚さず、別ファイルで個体差別化記述を管理。

#### サンプル
```json
{
  "slime": {
    "hint": "simple cyan gel blob, basic form, faintly glowing core"
  },
  "paralyze_slime": {
    "hint": "yellow electric slime, lightning bolt patterns, crackling energy"
  },
  "heat_slime": {
    "hint": "orange-red molten slime, flame wisps rising, lava texture"
  },
  "wolf": {
    "hint": "lean gray wolf, glowing orange eyes, exposed spine circuit"
  },
  "tiger": {
    "hint": "striped orange predator, mechanical jaw, fierce pose"
  },
  "skeleton": {
    "hint": "white bone humanoid, tattered purple robe, hollow eye sockets"
  }
}
```

**作成時間**: 65行、約1時間で記述可能。

---

### generate.py 擬似コード

```python
import json
from pathlib import Path
from gemini_client import GeminiClient
from prompt_builder import build_prompt

# 設定読み込み
units = json.load(open("data/cards.json"))["units"]
hints = json.load(open("data/visual_hints.json"))
client = GeminiClient(api_key=os.getenv("GEMINI_API_KEY"))

# 種族ごとにループ
for race in ["beast", "slime", "undead", "boss"]:
    anchor_sprite = Path(f"data/anchors/{race}_sprite.png").read_bytes()
    anchor_illust = Path(f"data/anchors/{race}_illust.png").read_bytes()
    
    # 種族内のユニットをループ
    race_units = [u for u in units.items() if u[1]["race"] == race]
    
    for unit_name, unit_data in race_units:
        hint = hints.get(unit_name, {}).get("hint", "")
        
        # スプライト生成
        for i in range(3):
            prompt = build_prompt(
                race=race,
                hint=hint,
                variant="sprite"
            )
            img = client.generate_image(
                prompt=prompt,
                reference_image=anchor_sprite
            )
            save_path = f"data/output/{race}/{unit_name}/sprite_{i}.png"
            Path(save_path).parent.mkdir(parents=True, exist_ok=True)
            with open(save_path, "wb") as f:
                f.write(img)
            
            print(f"Generated {save_path}")
            time.sleep(1)  # rate limit
        
        # イラスト生成（同様のループ）
        # ...
```

---

### Gemini API呼び出し注意点

#### リトライ戦略
```python
def generate_image(self, prompt, reference_image, max_retries=3):
    for attempt in range(max_retries):
        try:
            response = self.model.generate_content([
                {"text": prompt},
                {"inline_data": {"mime_type": "image/png", "data": reference_image}}
            ])
            return response.image
        except Exception as e:
            if attempt == max_retries - 1:
                raise
            wait_time = 2 ** attempt
            time.sleep(wait_time)
```

#### ログ記録
全プロンプト＋生成結果IDを`log.jsonl`に追記（再現性のため）:
```json
{"timestamp": "2026-04-14T12:34:56", "unit": "wolf", "variant": "sprite", "candidate": 1, "prompt": "...", "result_id": "abc123"}
```

---

## タイムライン

### 前提
- 作業者: 1名
- 作業時間: 週末中心＋平日夜
- 並列作業なし

### 作業スケジュール

| フェーズ | 作業内容 | 所要時間 |
|----------|---------|---------|
| **準備** | visual_hints.json作成（65行）<br>スクリプト実装（5ファイル） | 1日 |
| **アンカー確立** | 4種族×10パターン生成<br>人間が厳選 | 1日 |
| **MVP検証** | 獣21体生成＋選定＋後処理<br>採用率評価 | 2日 |
| **判定ゲート** | 続行/見直し決定 | 0.5日 |
| **量産1** | スライム24体 | 2日 |
| **量産2** | アンデッド15体 | 1.5日 |
| **ボス** | 5体（丁寧に） | 1.5日 |
| **統合** | Godot導入・表示確認・微調整 | 1日 |
| **合計** | | **約10.5日（実作業）** |

### カレンダー換算
週末＋平日夜運用で **3〜4週間**。

---

## リスク対策

| リスク | 影響度 | 対策 |
|--------|--------|------|
| Gemini出力ブレが大きい | 高 | アンカー画像必須化<br>同日一括生成<br>3パターン選定 |
| ピクセルアートが不得手 | 中 | 高解像度生成→後処理で縮小<br>パレット量子化 |
| 特定種族が崩れる | 高 | MVP検証で早期発見<br>アンカー差替で軌道修正 |
| ボスが凡庸 | 中 | ボス5体のみ10パターン生成<br>人力修正前提 |
| APIコスト膨張 | 低 | 1体=6枚×65=390枚<br>Flash画像生成は安価だが上限アラート設定 |
| 全く使い物にならない | 高 | MVP判定ゲートで即座に判断<br>**フォールバック禁止**（アセットストアは却下） |

### フォールバック禁止
アセットストアは有料のため使用しない。採用率が低い場合の対策:
1. アンカー個体を変更
2. プロンプトの全面見直し
3. 生成パターン数を5に増やす
4. 最悪の場合、Phase 5を延期してプレースホルダー運用

---

## 補足資料

### 参考: 削った案

以下の案は検討したが採用せず:

#### ControlNet / LoRA学習方式
- **利点**: 一貫性最強
- **欠点**: 学習データ作成に数日、Gemini単体では不可
- **判断**: MVP段階では過剰

#### 65体全て10パターン生成
- **利点**: 選択肢が増える
- **欠点**: 650枚×2=1300枚選定で人間が疲弊
- **判断**: 3パターンで十分、アンカーで底上げ

#### cards.jsonにvisual_hintフィールド追加
- **利点**: データ一元化
- **欠点**: 本体スキーマを汚す
- **判断**: 別ファイル化（visual_hints.json）

---

## 次のアクション

### 即座に実行
1. **visual_hints.jsonのサンプル作成** - 10体分（30分）
2. **アンカー用ユニット選定** - 4体決定（10分）
3. **スクリプト雛形作成** - generate.py基本構造（1時間）

### 1週間以内
4. **アンカー確立** - 獣アンカー10パターン生成・選定（1日）
5. **MVP実施** - 獣5体でフロー検証（半日）
6. **判定** - 続行可否決定

### 本格実装
7. **獣21体完走** - MVP成功後に全体量産開始
8. **他種族展開** - スライム→アンデッド→ボス
