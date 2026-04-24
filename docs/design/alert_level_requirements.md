# 警戒システム 通常戦闘影響 要件定義書

**作成日**: 2026-04-12
**最終更新**: 2026-04-20
**参照企画書**: `C:\Users\kazum\dungeon-board-game\docs\design\alert_level_combat_impact.md`
**ステータス**: 新仕様対応完了（警戒MAX=3、エリート廃止）

---

## 0. 事前調査サマリ

### 現状の実装状況（重要）
- `GameSession.alert_level` 変数は定義済み（GameSession.gd:65）
- **Phase 3 #27で警戒MAX=3実装済み** (`MapSelect.gd` 142-143行)
- **MapSelect.gdで戦闘+1/イベント-1実装済み** (169-181行)
- EnemyAI.gd `_build_enemy_deck()` は Act別基本プール選択のみ（alert_level参照なし）
- Main.gd `_place_enemy_initial_units()` は基本配置のみ（alert依存なし）
- `enemy_pools` は Act別（"1"/"2"/"3"）のみ定義、**警戒段階別プールは未定義**
- ボス戦の alert_level 考慮は実装済み（alert=3でphase2移行）

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

**新仕様の核**:
- **警戒MAX=3**（ボスのみ到達）
- 通常戦は 0→1→2 で段階的強化
- エリート混入システム廃止
- 敵デッキは alert_level に応じて 3段階（weak / enhanced1 / enhanced2）
- ボス戦は alert 1-2 で通常ボス、alert 3 で強化ボス

---

## 2. Phase 切り分け（新仕様）

**Phase 3完了済み**:
- A. 戦闘マス選択時 `alert_level += 1` 実装 ✅
- A-2. その他ノード選択時 `alert_level -= 1` 実装 ✅
- E. マップノードの警告マーク表示 ✅

**Phase 4必須**:
- B. 警戒段階別敵デッキプール定義（weak / enhanced1 / enhanced2）
- C. EnemyAI.gd デッキ選択ロジック実装（alert_level 参照）
- D. マップ警告マーク改善（alert 1=黄!, 2=橙!!, 3=赤!!!）

**Phase 4オプション**:
- F. 警戒3専用演出（点滅・警告音）
- G. ホバーツールチップ詳細化

---

## 3. 実装対象ファイルと変更箇所（Phase 4）

### 3-1. データ定義

#### `data/cards.json`
**変更箇所**: `enemy_pools` セクション（行170付近）を警戒段階別構造に拡張

**新構造（要件）**:
```
"enemy_pools": {
    "act1_weak":      [ ... 既存のAct1プール相当 ... ],
    "act1_enhanced1": [ ... alert=1 強化デッキ ... ],   // 新規
    "act1_enhanced2": [ ... alert=2 強化デッキ ... ],   // 新規
    "act2_weak":      [ ... 既存のAct2プール相当 ... ],
    "act2_enhanced1": [ ... alert=1 強化デッキ ... ],
    "act2_enhanced2": [ ... alert=2 強化デッキ ... ],
    "act3_weak":      [ ... 既存のAct3プール相当 ... ],
    "act3_enhanced1": [ ... alert=1 強化デッキ ... ],
    "act3_enhanced2": [ ... alert=2 強化デッキ ... ]
}
```

**注意事項**:
- **enhanced3はボス専用**。通常戦では使用しない（alert=3は通常戦で到達不可）
- ユニット名は既存 `CardDB.UNITS` に登録済みのものに限る
- 強化デッキが未定義の場合は一時的に weak 流用可（バランス調整後に差し替え）

---

### 3-2. CardDB.gd

**変更箇所**: 行15付近 `ENEMY_POOLS` 読み込み

**要件**:
- `ENEMY_POOLS` を新構造（alert段階別）に対応
- 既存コードは変更不要（キー名が増えるだけ）

---

### 3-3. EnemyAI.gd

**変更箇所**: `_build_enemy_deck()`（行32-58）

**要件**:
1. 通常戦（非ボス）の場合、プールキーを警戒レベルで動的決定
2. プールキー決定ロジック（純粋関数として切り出し推奨）

**プールキー決定表（新仕様）**:
| Act | alert_level | pool_key |
|---|---|---|
| 1 | 0 | `act1_weak` |
| 1 | 1 | `act1_enhanced1` |
| 1 | 2 | `act1_enhanced2` |
| 2 | 0 | `act2_weak` |
| 2 | 1 | `act2_enhanced1` |
| 2 | 2 | `act2_enhanced2` |
| 3 | 0 | `act3_weak` |
| 3 | 1 | `act3_enhanced1` |
| 3 | 2 | `act3_enhanced2` |

**注意**:
- **alert=3は通常戦で到達不可**（MAX=3はボス前まで到達しない設計）
- ボス戦は別ロジック（既存の `_build_boss_deck()` で alert考慮済み）

**関数シグネチャ（新規 private関数）**:
```gdscript
func _select_pool_key(act: int, alert: int) -> String
```

**実装例**:
```gdscript
func _select_pool_key(act: int, alert: int) -> String:
    var suffix = ""
    match alert:
        0: suffix = "_weak"
        1: suffix = "_enhanced1"
        2: suffix = "_enhanced2"
        _: suffix = "_enhanced2"  # フォールバック（通常は到達しない）
    return "act" + str(act) + suffix
```

---

### 3-4. Main.gd

**変更箇所**: なし（既存の配置ロジックで十分）

**理由**:
- 警戒レベルに応じた敵の強さは **デッキ選択時点** で決まる（EnemyAI.gd）
- エリート混入システム廃止により配置時の追加ロジック不要
- 既存の `_place_enemy_initial_units()` は変更不要

---

### 3-5. MapSelect.gd

**変更箇所1**: `_on_node_clicked()`（行169-181）

**現状**: **Phase 3 #27で実装済み** ✅
- `battle` ノード選択時: `alert_level += 1`（MAX=3で上限）
- `event` / `treasure` / `shop` / その他ノード選択時: `alert_level -= 1`（下限0）
- `boss` ノード選択時: 変化なし

**変更箇所2**: `_draw_nodes()`（行152-）

**現状**: 基本的な警告マーク実装済み（Phase 3 #27）

**Phase 4改善要件**:
- 警告マーク視認性向上（サイズ・色調整）

**警告マーク仕様（新仕様）**:
| alert_level | マーク | 色 | フォントサイズ |
|---|---|---|---|
| 0 | 非表示 | - | - |
| 1 | `!` | `Color(1.0, 0.9, 0.3)` 黄 | 16 |
| 2 | `!!` | `Color(1.0, 0.5, 0.2)` 橙 | 18 |
| 3 | `!!!` | `Color(1.0, 0.2, 0.2)` 赤 | 20 |

**Phase 4オプション**:
- 点滅アニメーション（alert=3のみ）
- 警告音（alert=3到達時）

---

### 3-6. Act遷移時の警戒レベルリセット

**変更箇所**: `scripts/BossReward.gd` の `_on_continue()`

**要件**:
- Act遷移時（ボス戦クリア後）に `GameSession.alert_level = 0` を設定
- `GameSession.current_act += 1` の直後に配置

**理由**:
- 各Actは独立した警戒レベルで開始すべき
- Act1で蓄積した警戒がAct2に持ち越されるとバランスが崩れる

---

## 4. 実装順序と依存関係（新仕様）

```
[Phase 3完了済み]
    ✅ MapSelect.gd: 戦闘マスクリック時 alert_level+=1（MAX=3）
    ✅ MapSelect.gd: その他ノード選択時 alert_level-=1（下限0）
    ✅ MapSelect.gd: 基本的な警告マーク表示

[Phase 4必須]
    [1] データ層
        └─ cards.json: enemy_pools 警戒段階別プール定義
           (act1/2/3_weak, act1/2/3_enhanced1, act1/2/3_enhanced2)

    [2] ロジック層
        └─ EnemyAI.gd: _select_pool_key() 追加・_build_enemy_deck() 改修
           (alert_level 参照してプール選択)

    [3] UI層
        └─ MapSelect.gd: 警告マーク視認性向上（色・サイズ調整）

[Phase 4オプション]
    [4] 演出層
        ├─ MapSelect.gd: alert=3時の点滅アニメーション
        └─ MapSelect.gd: alert=3到達時の警告音
```

**依存チェーン**:
- [2] は [1] の前提（プールが定義されていないとデッキ生成不可）
- [3] は [2] 完了後に独立で実装可
- [4] は最後の磨き込み（MVP不要）

**推奨スプリント分割**:
- **Sprint A**: [1]（データ定義、1セッション）
- **Sprint B**: [2]（ロジック本体、1セッション）
- **Sprint C**: [3] + [4]（UI改善・演出、1セッション）

---

## 5. 制約・注意事項（新仕様）

### 核となる体験との整合性
- 観戦中の操作追加なし ✅
- 3秒ルール違反なし（警告マークで伝達）✅
- 足し算チェック：企画書記載の要素のみ実装 ✅
- 廃止済み設計との抵触なし ✅

### 不採用（新仕様で削除）
- HP/ATK倍率スケーリング: **実装しない**
- プレイヤー側デバフ: **実装しない**
- 戦闘中ルール追加: **実装しない**
- 警戒Lv別隠し特殊能力: **実装しない**
- **エリート混入システム**: **廃止**
- **エリート報酬強化**: **廃止**

### データ整合性
- `CardDB.UNITS` に存在しないユニット名を `enemy_pools` に書かない
- 強化デッキ未定義の場合は一時的に weak プール流用可（警告を出す）

### GAME_DESIGN.md との整合性
- 警戒MAX=3（ボスのみ到達）
- 通常戦は 0→1→2 で推移
- ボス戦は alert 1-2 で通常ボス、alert 3 で強化ボス

### 確定事項
1. **警戒MAX=3**: ボス前の通常戦で最大2まで上昇
2. **エリート廃止**: エリートノード・エリート混入・エリート報酬は全て削除
3. **3段階強化**: weak / enhanced1 / enhanced2 の3段階敵デッキ

---

## 6. テストポイント（新仕様）

Phase 4 実装後の動作確認項目：

| テストケース | 期待動作 | 確認箇所 |
|---|---|---|
| **Phase 3完了済み（確認のみ）** |||
| 戦闘ノード選択3回 | alert_level = 3 になる（上限） | MapSelect.gd / GameSession |
| 宝箱ノード選択（alert_level=2の状態） | alert_level = 1 に下がる | MapSelect.gd |
| ショップノード選択（alert_level=1の状態） | alert_level = 0 に下がる | MapSelect.gd |
| イベントノード選択（alert_level=0の状態） | alert_level = 0 のまま（下限） | MapSelect.gd |
| 戦闘→宝箱→イベント→戦闘 | 1→0→0→1 の順で変動 | MapSelect.gd |
| マップ画面で alert_level=1 | 戦闘ノードに黄色の`!`マーク表示 | MapSelect._draw_nodes() |
| マップ画面で alert_level=2 | 戦闘ノードに橙色の`!!`マーク表示 | MapSelect._draw_nodes() |
| マップ画面で alert_level=3 | 戦闘ノードに赤色の`!!!`マーク表示 | MapSelect._draw_nodes() |
| Act1ボス撃破→Act2開始 | alert_level = 0 にリセット | BossReward.gd |
| **Phase 4新規実装** |||
| alert_level=0で戦闘開始 | 敵デッキが act1_weak プールから生成 | EnemyAI.gd |
| alert_level=1で戦闘開始 | 敵デッキが act1_enhanced1 プールから生成 | EnemyAI.gd |
| alert_level=2で戦闘開始 | 敵デッキが act1_enhanced2 プールから生成 | EnemyAI.gd |
| Act2 alert_level=2で戦闘開始 | 敵デッキが act2_enhanced2 プールから生成 | EnemyAI.gd |
| 警戒0→1→2で3戦 | 敵の強さが段階的に変化（視認可能） | DeckPrep画面 |

---

## 7. roadmap.md 反映案（新仕様）

**Phase 3完了済み**:
- タスク#27: 警戒レベルMAX=3実装（MapSelect.gd）
- タスク#27: 戦闘+1/イベント-1実装（MapSelect.gd）
- タスク#27: 警告マーク基本実装（MapSelect.gd）

**Phase 4追加タスク案**:

```markdown
| N | 警戒段階別敵デッキプール定義 | 高 | ✅ | 未着手 | 未着手 | cards.json に act1/2/3_weak, act1/2/3_enhanced1, act1/2/3_enhanced2 定義 |
| N+1 | 警戒レベル応じた敵デッキ選択実装 | 高 | ✅ | 未着手 | 未着手 | EnemyAI.gd _build_enemy_deck() に alert_level 参照ロジック追加 |
| N+2 | 警告マーク視認性向上 | 中 | ✅ | 未着手 | 未着手 | MapSelect.gd 警告マーク色・サイズ調整 |
| N+3 | 警戒3専用演出 | 低 | ✅ | 未着手 | 未着手 | 点滅アニメーション・警告音（オプション） |
```

**CHANGELOG.md 想定エントリ**（Phase 4実装後）:
```markdown
### 2026-04-XX
- feat: 警戒レベル段階別敵デッキ実装（Phase4 タスク#N,N+1完了）
  - alert 0=weak, 1=enhanced1, 2=enhanced2 の3段階敵デッキ
  - EnemyAI.gd に _select_pool_key() 追加（alert_level 参照）
  - エリート混入システム廃止
```

---

## 8. 完了定義（新仕様）

Phase 4実装完了の判定条件：

1. **データ層**: cards.json に 9種のプール（act1/2/3 × weak/enhanced1/enhanced2）が定義されている
2. **ロジック層**: EnemyAI.gd が alert_level を参照して適切なプールを選択する
3. **視認確認**: alert 0→1→2 で戦闘を開始すると敵の顔ぶれが明確に変化する
4. **上限確認**: 戦闘ノードを連続で踏んでも alert_level=3 で止まる（MAX=3）
5. **ボス戦確認**: alert 1-2 で通常ボス、alert 3 で強化ボス（既存実装）
6. **構文チェック**: `bash tools/ci/tools/ci/check_syntax.sh` がクリーン
7. **体験確認**: CEO視覚確認で「マップで戦闘を踏むか迂回するか悩む」体験が成立

**Phase 3完了済み項目（確認のみ）**:
- 戦闘ノードを踏むたびに `alert_level` が上がる（MAX=3）
- その他ノード（イベント・宝箱・ショップ等）を踏むたびに `alert_level` が下がる（下限0）
- マップ画面で警告マークが警戒レベルに応じて変化する

---

## 関連ファイルパス（絶対パス）

- 企画書: `C:\Users\kazum\dungeon-board-game\docs\design\alert_level_combat_impact.md`
- 設計文書: `C:\Users\kazum\dungeon-board-game\docs\GAME_DESIGN.md`
- Phase 4変更対象:
  - `C:\Users\kazum\dungeon-board-game\data\cards.json`
  - `C:\Users\kazum\dungeon-board-game\scripts\EnemyAI.gd`
  - `C:\Users\kazum\dungeon-board-game\scripts\MapSelect.gd`（警告マーク改善）
- Phase 3完了済み:
  - `C:\Users\kazum\dungeon-board-game\scripts\MapSelect.gd`（戦闘+1/イベント-1実装済み）
  - `C:\Users\kazum\dungeon-board-game\scripts\GameSession.gd`（alert_level定義済み）
- roadmap更新対象: `C:\Users\kazum\dungeon-board-game\docs\roadmap.md`

---

## 補足：architectからCEOへの報告事項（新仕様）

1. **Phase 3 #27で基礎実装完了済み**: 戦闘+1/イベント-1/警告マーク/MAX=3
2. **Phase 4で残タスク**: 敵デッキプール定義（cards.json）+ デッキ選択ロジック（EnemyAI.gd）
3. **エリート関連削除**: EnemyPlacementHelper.gd 新規作成不要、elite_pools定義不要、報酬強化不要
4. **ファイルサイズ対策不要**: Main.gd変更不要のため、分割判断自体が不要
5. **警戒MAX=3確定**: 通常戦で3到達不可、ボス前で最大2まで上昇
