# 警戒システム 通常戦闘影響 要件定義書

**作成日**: 2026-04-12
**参照企画書**: `C:\Users\kazum\dungeon-board-game\docs\design\alert_level_combat_impact.md`
**ステータス**: architectによる要件定義（修正版・承認待ち）

---

## 0. 事前調査サマリ

### 現状の実装状況（重要）
- `GameSession.alert_level` 変数は定義済み（GameSession.gd:65）
- **戦闘マス選択時の `alert_level += 1` 処理が未実装**（MapSelect.gd `_on_node_clicked()` に該当コードなし）
- レストマス（-2）の処理も未実装（レストノード自体が未実装の可能性あり。roadmap.mdに記載なし）
- **その他ノード（イベント・宝箱・ショップ等）の -1 処理も未実装**
- Event.gdでは `alert_level` 増減の仕組みあり（Event.gd:168-171）
- EnemyAI.gdは通常戦では `alert_level` を一切参照していない（_build_enemy_deck / ボス戦 _build_boss_deck のみ参照）
- Main.gd `_place_enemy_initial_units()` は `enemy_deck` 内の全ユニットを順に配置するだけで、配置数制御・警戒考慮なし
- `enemy_pools` は Act別（"1"/"2"/"3"）のみ定義、ランク別・エリート用プールは未定義
- ボス戦の `alert_level_buffs` / `enemy_deck_id_phase2_lv4/lv5` は箱実装（データ未定義、roadmap Phase3#5参照）

### ファイルサイズ現状（予防的チェック）
| ファイル | 現在行数 | 想定追加行数 | 予測合計 | 判定 |
|---|---|---|---|---|
| EnemyAI.gd | 251 | +60〜80 | 〜330 | OK（500以下） |
| Main.gd | 874 | +40〜60 | 〜930 | **800超・要分割** |
| MapSelect.gd | 270 | +30 | 〜300 | OK |
| CardDB.gd | - | +5 | 軽微 | OK |

**Main.gd分割方針**: 敵配置強化ロジック（Lv1-2の初期配置調整、Lv4+エリート混入）は `scripts/EnemyPlacementHelper.gd`（新規）に外出しする。Main.gdは呼び出し1行のみ。

---

## 1. 概要

警戒レベル（`GameSession.alert_level`）の通常戦闘への影響を実装する。
本質的役割：**「マップで戦闘を踏むか迂回するかを悩ませる」**。
核は「Lv3で敵デッキが質的変化・Lv4でエリート混入・それ以外は初期配置の厚みで表現」。

---

## 2. Phase 3 / Phase 4 切り分け

| 機能 | 優先度 | Phase | 理由 |
|---|---|---|---|
| A. 戦闘マス選択時 `alert_level += 1` 実装 | 最優先 | **Phase 3** | これがないと企画自体が成立しない前提条件 |
| A-2. その他ノード選択時 `alert_level -= 1` 実装 | 最優先 | **Phase 3** | 企画書3章の変動ルール必須要素 |
| B. Lv3での敵デッキランク切替（弱→中間ランク） | S | **Phase 3** | 企画書の「核となる一文」の前半。MVP必須 |
| C. Lv1-2 初期配置強化（前列厚み） | A | **Phase 3** | Lv0→Lv3の断絶防止、MVP必須 |
| D. Lv4+ エリート混入 | A | **Phase 3** | 戦闘狂ルート存在意義。MVP必須 |
| E. マップノードの警告マーク表示 | B | **Phase 3** | 3秒ルール必須 |
| F. エリート混入時の報酬強化（選択肢+1） | A | **Phase 3** | Dと対で意味を持つ |
| G. Lv2での敵タイプ比率変化（弱ランク内攻撃型増加） | C | **Phase 4** | 企画書で「MVPでは削ってよい」と明示 |
| H. Lv5+ 専用演出（炎・警告音） | 低 | **Phase 4** | 見た目の磨き。MVP後 |
| I. ホバーツールチップ「警戒Lv3：強化された敵が出現」 | 低 | **Phase 4** | アイコンで伝われば最低限可 |
| J. 中間ランクプール（弱→中）のデータ定義 | S | **Phase 3**（Bの前提） | Bを成立させるデータ |
| K. エリート用ユニットプール定義 | A | **Phase 3**（Dの前提） | Dを成立させるデータ |

---

## 3. 実装対象ファイルと変更箇所（Phase 3分のみ）

### 3-1. データ定義

#### `data/cards.json`
**変更箇所**: `enemy_pools` セクション（行170付近）をランク別構造に拡張

**新構造（要件）**:
```
"enemy_pools": {
    "act1_weak":   [ ... 既存のAct1プール相当 ... ],
    "act1_mid":    [ ... 弱→中の中間ランク ... ],    // 新規：Lv3切替用
    "act2_mid":    [ ... 既存のAct2プール相当 ... ],
    "act2_strong": [ ... 中→強の中間ランク ... ],    // 新規
    "act3_strong": [ ... 既存のAct3プール相当 ... ],
    "act3_peak":   [ ... 強ランク+α ... ]             // 新規
},
"elite_pools": {
    "act1": [ ... Act1用エリート候補 ... ],
    "act2": [ ... Act2用エリート候補 ... ],
    "act3": [ ... Act3用エリート候補 ... ]
}
```

**後方互換**: 既存の `"1"/"2"/"3"` キーは残すか、`act1_weak` 等へ一括リネームしてCardDB.gd読み込み側で吸収。**推奨：リネーム方式**（シンプル）。

**注意事項**:
- ユニット名は既存 `CardDB.UNITS` に登録済みのものに限る
- 中間ランクユニットが足りない場合は既存プール流用でよい（バランス調整はPhase 4）

---

### 3-2. CardDB.gd

**変更箇所**: 行15付近 `ENEMY_POOLS` 読み込み

**要件**:
- `ENEMY_POOLS` を新構造に対応
- 新規変数 `ELITE_POOLS: Dictionary = {}` を追加
- `_ready()` で `ELITE_POOLS = data.get("elite_pools", {})` を追加

---

### 3-3. EnemyAI.gd

**変更箇所**: `_build_enemy_deck()`（行32-58）

**要件**:
1. 通常戦（非ボス）の場合、プールキーを警戒レベルで動的決定
2. プールキー決定ロジック（純粋関数として切り出し推奨）

**プールキー決定表**（Phase 3）:
| Act | alert_level | pool_key |
|---|---|---|
| 1 | 0-2 | `act1_weak` |
| 1 | 3-4 | `act1_mid` |
| 1 | 5+ | `act1_mid`（Lv5+も中間継続） |
| 2 | 0-2 | `act2_mid` |
| 2 | 3-4 | `act2_strong` |
| 2 | 5+ | `act2_strong` |
| 3 | 0-2 | `act3_strong` |
| 3 | 3+ | `act3_peak` |

**関数シグネチャ（新規 private関数）**:
```
func _select_pool_key(act: int, alert: int) -> String
```

**注意事項**:
- エリート混入（Lv4+）は `_build_enemy_deck()` 内で直接やらず、**Main.gd の初期配置フェーズで行う**（責任分界）
- `print` ログに pool_key と alert_level を含める

---

### 3-4. Main.gd（分割あり）

**変更箇所**: `_place_enemy_initial_units()`（行303-）

**要件**:
1. 新規ヘルパー `EnemyPlacementHelper.gd`（後述）に配置強化ロジックを委譲
2. Main.gd本体の変更は **呼び出し1行追加** のみに抑える

**変更内容**:
```
# 既存: enemy_ai.enemy_deck から全ユニット配置
# 変更後: 配置前に EnemyPlacementHelper でデッキを加工
var helper = preload("res://scripts/EnemyPlacementHelper.gd").new()
helper.apply_alert_modifiers(enemy_ai.enemy_deck, GameSession.alert_level, GameSession.current_act)
# その後は既存の配置ループをそのまま使用
```

**ファイルサイズ対策**: この変更でMain.gdの純増は+5行程度に抑える。

---

### 3-5. EnemyPlacementHelper.gd（**新規ファイル**）

**ファイル**: `scripts/EnemyPlacementHelper.gd`
**推定行数**: 80〜120行

**責務**:
- 警戒レベルに応じた敵デッキ加工（初期配置強化・エリート混入）

**関数シグネチャ**:
```
class_name EnemyPlacementHelper
extends RefCounted

# エントリポイント
func apply_alert_modifiers(enemy_deck: Array, alert: int, act: int) -> void

# Lv1-2: 前列/中列の埋まり確保（デッキが不足していれば弱ランクから補充）
func _ensure_front_row_filled(enemy_deck: Array, act: int) -> void
func _ensure_middle_row_unit(enemy_deck: Array, act: int) -> void

# Lv4+: エリート混入
func _inject_elite_unit(enemy_deck: Array, act: int, is_guaranteed: bool) -> void

# ヘルパー：弱ランクプールからユニット1体生成
func _create_unit_from_pool_entry(entry: Dictionary) -> Object
```

**処理フロー**:
```
apply_alert_modifiers(deck, alert, act):
    if alert >= 1:
        _ensure_front_row_filled(deck, act)      # 前列(col指定)が埋まるよう補充
    if alert >= 2:
        _ensure_middle_row_unit(deck, act)        # 中列(row=1想定)1体追加
    if alert >= 4:
        var guaranteed = (alert >= 5)
        var chance_roll = randf() < ELITE_CHANCE_LV4  # = 0.5
        if guaranteed or chance_roll:
            _inject_elite_unit(deck, act, guaranteed)
```

**定数**（ファイル先頭）:
```
const ELITE_CHANCE_LV4: float = 0.5  # 企画書9-2で定数化要請あり
const ALERT_LV3_THRESHOLD: int = 3
const ALERT_LV4_THRESHOLD: int = 4
const ALERT_LV5_THRESHOLD: int = 5
```

**注意事項**:
- "前列が埋まる" の定義：col 0/1/2 の少なくとも1列について「その列のユニットが1体もない」状態を解消する（既存のenemy_deckに不足していたら補充する）
- 盤面配置は既存の `_place_enemy_initial_units()` が行うので、このヘルパーは **デッキ内容の編集のみ**
- エリートユニットは `CardDB.ELITE_POOLS[act_key]` から1体ランダム選択
- エリートユニットの `assigned_col` は 0〜2 のランダムでよい

---

### 3-6. MapSelect.gd

**変更箇所1**: `_on_node_clicked()`（行243-）

**要件**:
- `battle` ノード選択時: `GameSession.alert_level += 1`
- `elite` ノード選択時: `GameSession.alert_level += 1`
- `boss` ノード選択時: 変化なし（現状維持）
- **`event` / `treasure` / `shop` / その他ノード選択時**: `GameSession.alert_level = max(0, GameSession.alert_level - 1)`

**追加位置**: `match node_type:` の各ブロック先頭（battle_typeやシーン遷移設定の直前）

**具体的な実装例**:
```gdscript
match node_type:
    "battle", "elite":
        GameSession.alert_level += 1
        # 既存のbattle_type設定やシーン遷移処理...
    "event", "treasure", "shop":
        GameSession.alert_level = max(0, GameSession.alert_level - 1)
        # 既存のシーン遷移処理...
    "boss":
        # 変化なし
```

**変更箇所2**: `_draw_nodes()`（行152-）

**要件**:
- 戦闘ノード（battle/elite）描画時、`GameSession.alert_level` に応じた警告マーク追加
- 警告マークは既存のノード円の右上（相対位置 Vector2(35, -5)）にLabel配置

**警告マーク仕様**:
| alert_level | マーク | 色 | フォントサイズ |
|---|---|---|---|
| 0 | 非表示 | - | - |
| 1-2 | `!` | `Color(1.0, 0.9, 0.3)` 黄 | 16 |
| 3-4 | `!!` | `Color(1.0, 0.5, 0.2)` 橙 | 18 |
| 5+ | `!!!` | `Color(1.0, 0.2, 0.2)` 赤 | 20 |

- Phase 3 MVP では**静的テキスト**で十分（点滅・炎演出はPhase 4）
- elite ノードは常に `★` + 上記警告マーク併記

**関数シグネチャ**:
```
func _add_alert_marker(parent_pos: Vector2, alert: int) -> void
```

---

### 3-7. 報酬システム（エリート混入時の選択肢+1）

**変更箇所**: バトル結果→報酬画面のカード選択肢数決定箇所

**調査要件**（Phase 3実装前に確認）:
- 報酬画面ファイル名と現在の選択肢決定ロジックを特定する必要あり（`Result.gd` 相当）
- 本要件定義の段階では **「エリートが混入した戦闘だったか」をGameSessionに記録する変数が必要**

**新規変数（GameSession.gd）**:
```
var elite_injected_in_battle: bool = false
```

- EnemyPlacementHelper.gd の `_inject_elite_unit()` 内で `GameSession.elite_injected_in_battle = true` を設定
- バトル開始時（Main.gd `_ready` 付近）に `false` へリセット
- 報酬画面で `true` なら選択肢数 +1

---

### 3-8. Act遷移時の警戒レベルリセット

**変更箇所**: `scripts/BossReward.gd` の `_on_continue()`

**要件**:
- Act遷移時（ボス戦クリア後）に `GameSession.alert_level = 0` を設定
- `GameSession.current_act += 1` の直後に配置

**理由**:
- 各Actは独立した警戒レベルで開始すべき
- Act1で蓄積した警戒がAct2に持ち越されるとバランスが崩れる

---

## 4. 実装順序と依存関係

```
[1] 前提実装（他の全ての前提）
    ├─ MapSelect.gd: 戦闘マスクリック時 alert_level+=1
    ├─ MapSelect.gd: その他ノード選択時 alert_level-=1（下限0）
    └─ GameSession.gd: elite_injected_in_battle 追加

[2] データ層
    └─ cards.json: enemy_pools ランク別リネーム / elite_pools 新規定義
       └─ CardDB.gd: ELITE_POOLS 読み込み追加

[3] ロジック層
    ├─ EnemyAI.gd: _select_pool_key() 追加・_build_enemy_deck() 改修
    └─ EnemyPlacementHelper.gd 新規作成
       └─ Main.gd: _place_enemy_initial_units() に helper 呼び出し1行追加

[4] UI層
    └─ MapSelect.gd: _add_alert_marker() 追加

[5] 報酬連携
    └─ 報酬画面（要調査）: elite_injected_in_battle 参照、選択肢+1
```

**依存チェーン**:
- [2] は [3] の前提
- [1] は全ての動作確認の前提（警戒レベルが上がらないと何もテストできない）
- [4] と [5] は [3] 完了後に独立で実装可

**推奨スプリント分割**:
- **Sprint A**: [1] + [2]（データとトリガーの準備、1セッション）
- **Sprint B**: [3]（ロジック本体、1-2セッション）
- **Sprint C**: [4] + [5]（UI・報酬、1セッション）

---

## 5. 制約・注意事項

### 核となる体験との整合性（YESマンチェック済み）
- 観戦中の操作追加なし ✅
- 3秒ルール違反なし（アイコン・色で伝達）✅
- 足し算チェック：企画書記載の要素のみ実装、独自追加なし ✅
- 廃止済み設計との抵触なし ✅

### 不採用（企画書7章の廃案リストを順守）
- HP/ATK倍率スケーリング: **実装しない**
- プレイヤー側デバフ: **実装しない**
- 戦闘中ルール追加: **実装しない**
- 警戒Lv別隠し特殊能力: **実装しない**

### データ整合性
- `CardDB.UNITS` に存在しないユニット名を `enemy_pools` / `elite_pools` に書かない
- Act別プールのリネームは CardDB.gd 側で一括対応するか、互換マップを用意する（変更範囲最小化のため後者推奨）

### GAME_DESIGN.md との整合性
- GAME_DESIGN.md 190-201行（敵ランクと警戒Lv対応表）と完全一致させる
- Lv4 エリート混入50%、Lv5+ 確定（260-261行）と一致
- エリート混入時「カード選択肢+1」（262行）と一致

### 未確定事項（CEO判断要）
1. **Lv1で本当にデッキ内容を変えないか?** 企画書9-1：案A（配置のみ）推奨 → **要定義：CEO承認をもって確定**
2. **エリート混入確率（Lv4=50%）** 定数化で対応（`ELITE_CHANCE_LV4`）→ バランス調整で後日可変
3. **レストマス未実装問題**: 企画前提の「-2」の入口がまだない → roadmap.md の別タスクとして管理必要（本要件には含めない）

---

## 6. テストポイント（新規追加）

Phase 3 実装後の動作確認項目：

| テストケース | 期待動作 | 確認箇所 |
|---|---|---|
| 戦闘ノード選択3回 | alert_level = 3 になる | MapSelect.gd / GameSession |
| 宝箱ノード選択（alert_level=2の状態） | alert_level = 1 に下がる | MapSelect.gd |
| ショップノード選択（alert_level=1の状態） | alert_level = 0 に下がる | MapSelect.gd |
| イベントノード選択（alert_level=0の状態） | alert_level = 0 のまま（下限） | MapSelect.gd |
| 戦闘→宝箱→イベント→戦闘 | 1→0→0→1 の順で変動 | MapSelect.gd |
| alert_level=3で戦闘開始 | 敵デッキが act1_mid プールから生成 | EnemyAI.gd |
| alert_level=4で戦闘開始（複数回） | エリートが50%程度の確率で出現 | EnemyPlacementHelper.gd |
| alert_level=5で戦闘開始 | エリート確定出現 | EnemyPlacementHelper.gd |
| マップ画面で alert_level=1 | 戦闘ノードに黄色の`!`マーク表示 | MapSelect._draw_nodes() |
| マップ画面で alert_level=3 | 戦闘ノードに橙色の`!!`マーク表示 | MapSelect._draw_nodes() |
| マップ画面で alert_level=5 | 戦闘ノードに赤色の`!!!`マーク表示 | MapSelect._draw_nodes() |
| エリート混入戦勝利後 | カード報酬選択肢が4択（通常3択） | 報酬画面（要調査） |
| Act1ボス撃破→Act2開始 | alert_level = 0 にリセット | BossReward.gd |

---

## 7. roadmap.md 反映案

**追記先**: `### Phase 3: マップシステム+ショップ/ボス拡張` テーブル末尾

```markdown
| 22 | 警戒レベル戦闘影響（MVP） | 高 | ✅ | ✅ | 未着手 | 2026-04-12企画・要件定義完了（alert_level_combat_impact.md, alert_level_requirements.md）。Lv3敵ランク切替/Lv1-2配置強化/Lv4+エリート混入/マップ警告マーク/報酬選択肢+1の5本立て。Lv2タイプ比率変化はPhase4送り |
| 23 | 戦闘マス選択時 alert_level+=1 実装 | 高 | ✅ | ✅ | 未着手 | #22の前提。MapSelect.gd _on_node_clicked() に1行追加。現状トリガー未実装 |
| 24 | ランク別 enemy_pools データ定義 | 高 | ✅ | ✅ | 未着手 | #22の前提。act1_weak/act1_mid/act2_mid/act2_strong/act3_strong/act3_peak/elite_pools_* をcards.jsonに定義 |
```

**追記先**: `### Phase 4: コンテンツ量産` テーブル末尾

```markdown
| N | 警戒レベル磨き込み | 低 | ✅ | 未着手 | 未着手 | Lv2弱ランク内攻撃型比率変化、Lv5+専用演出（炎・点滅・警告音）、ホバーツールチップ詳細化 |
```

**CHANGELOG.md 想定エントリ**（実装後）:
```markdown
### 2026-04-XX
- feat: 警戒レベル通常戦闘影響MVP実装（Phase3 タスク#22,23,24完了）
  - Lv3で敵デッキが中間ランクプールへ切替
  - Lv1-2で敵初期配置を段階的に強化
  - Lv4でエリート50%混入、Lv5+で確定混入
  - マップノードに警戒レベル連動警告マーク表示
  - エリート混入戦闘はカード報酬選択肢+1
  - その他ノード（イベント・宝箱・ショップ）選択時に警戒レベル-1
```

---

## 8. 完了定義

Phase 3実装完了の判定条件：

1. 戦闘ノードを踏むたびに `alert_level` が上がる
2. その他ノード（イベント・宝箱・ショップ等）を踏むたびに `alert_level` が下がる（下限0）
3. Lv0の戦闘とLv3の戦闘で、DeckPrep開幕時に見える敵盤面の顔ぶれが明確に違う
4. Lv4以上の戦闘でエリートユニットが出現することがある
5. マップ画面で警告マークが警戒レベルに応じて変化する
6. エリート混入戦勝利時、カード報酬選択肢が4択になる（通常は3択想定）
7. `bash check_syntax.sh` がクリーン
8. CEO視覚確認で「マップで戦闘を踏むか迂回するか悩む」体験が成立

---

## 関連ファイルパス（絶対パス）

- 企画書: `C:\Users\kazum\dungeon-board-game\docs\design\alert_level_combat_impact.md`
- 設計文書: `C:\Users\kazum\dungeon-board-game\docs\GAME_DESIGN.md`
- 変更対象:
  - `C:\Users\kazum\dungeon-board-game\data\cards.json`
  - `C:\Users\kazum\dungeon-board-game\scripts\CardDB.gd`
  - `C:\Users\kazum\dungeon-board-game\scripts\EnemyAI.gd`
  - `C:\Users\kazum\dungeon-board-game\scripts\Main.gd`
  - `C:\Users\kazum\dungeon-board-game\scripts\MapSelect.gd`
  - `C:\Users\kazum\dungeon-board-game\scripts\GameSession.gd`
- 新規作成:
  - `C:\Users\kazum\dungeon-board-game\scripts\EnemyPlacementHelper.gd`
- roadmap更新対象: `C:\Users\kazum\dungeon-board-game\docs\roadmap.md`

---

## 補足：architectからCEOへの報告事項

1. **Main.gdが874行**のため、敵配置強化ロジックは独立ファイル `EnemyPlacementHelper.gd` に切り出す設計にしました（企画書にない分割判断ですが、CLAUDE.mdのファイルサイズ指針に基づく予防的対応）。
2. **戦闘マスを踏むと+1の処理自体が未実装**です。企画書は前提扱いですが、実装漏れなので要件に含めました（タスク#23）。
3. **レストノード-2の処理**は実装以前にレストノード自体がroadmapに存在しません。本要件のスコープ外とし、別途企画起こし推奨。
4. **未確定事項3点**（Lv1デッキ不変か／Lv4混入率50%妥当性／Lv6上限）はCEO承認時に回答してください。
5. **新規追加：その他ノード（イベント・宝箱・ショップ等）選択時の -1 処理**を3-6節MapSelect.gd変更箇所1に追加しました。企画書3章の変動ルール表（43-46行）に基づきます。
