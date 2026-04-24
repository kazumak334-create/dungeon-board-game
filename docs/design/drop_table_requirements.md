# ドロップテーブルシステム 要件定義書

**作成日**: 2026-04-12
**参照企画書**: `C:\Users\kazum\dungeon-board-game\docs\design\drop_table_system.md`
**対応タスク**: roadmap.md #12「ドロップテーブル実装（進行度別）」
**ステータス**: architectによる要件定義（承認待ち）

---

## 0. 事前調査サマリ

### 現状の実装状況（重要）
- `GameSession.run_depth` 変数は定義済み（GameSession.gd:47）。勝利時に+1加算済み（Result.gd:469-472）
- `RARITY_WEIGHTS_EARLY / MID / LATE` 3段階重みは **既に定義済み**（Result.gd:26-28）
- ステージ境界は **既に `<=3` / `<=7` / `8+` で企画書と一致**（Result.gd:105-110）
- `elite_injected_in_battle` フラグは定義済み（GameSession.gd:66）。EnemyPlacementHelper.gdで設定済み
- `elite_injected_in_battle == true` 時の **選択肢+1は実装済み**（Result.gd:127-129）
- ただし、**エリート時のステージ+1参照は未実装**（現状は選択肢数のみ増える）
- 既存重み値と企画書値は **乖離あり** —— 企画書値に差し替える必要がある
- 報酬画面に **ブースト可視化UIは未実装**（アイコン等なし）
- ボス戦は別経路（`_generate_boss_artifact_choices()`）で既に分離済み。ドロップテーブル対象外の要件を既に満たす

### 企画書とのギャップ一覧

| 項目 | 企画書 | 現状実装 | 対応要否 |
|---|---|---|---|
| 主軸＝run_depth | run_depth | run_depth | 既存流用 |
| 境界値 0-3 / 4-7 / 8+ | 一致 | 一致 | 不要 |
| 重み値（早期） | 65/30/5/0/0/0 | 60/25/10/4/1/0 | **差し替え必要** |
| 重み値（中期） | 40/40/17/3/0/0 | 30/35/20/10/4/1 | **差し替え必要** |
| 重み値（後期） | 20/35/30/12/2.5/0.5 | 10/25/30/20/10/5 | **差し替え必要** |
| ボス戦は別枠 | 別枠 | 別関数で分離済 | 不要 |
| エリート時ステージ+1 | 要 | なし | **新規実装** |
| 選択肢+1（エリート時） | 要 | あり | 既存流用 |
| ブースト可視化アイコン | 要 | なし | **新規実装** |
| godレアリティ | MVPでは0%可 | 0 / 0 / 5 | **0に統一** |

### ファイルサイズ現状（予防的チェック）

| ファイル | 現在行数 | 想定追加行数 | 予測合計 | 判定 |
|---|---|---|---|---|
| Result.gd | 507 | +30〜40 | 〜540 | **要注意（500超・軽微な分割を検討）** |
| GameSession.gd | 109 | 0 | 109 | OK |
| EnemyPlacementHelper.gd | 67 | 0 | 67 | OK |

**Result.gd分割方針**:
- 重み決定・テーブル参照ロジックは新規ヘルパー `scripts/RewardTable.gd`（新規）に抽出する
- Result.gdは呼び出し側に徹し、純増を +15行以内に抑える
- この分割により Result.gd は将来の報酬ロジック追加にも対応可能になる

---

## 1. 実装概要

run_depth を主軸とした 3 ステージ構成のレアリティ重みテーブルに、企画書値を適用する。エリート混入戦闘時は参照ステージを 1 段階繰り上げる「ステージ+1」ロジックを追加する。ブースト発生時は報酬画面に専用アイコンを 1 個表示し、3 秒で伝わる形にする。ボス戦は既存のアーティファクト経路を維持し、ドロップテーブルの対象外とする。

**核となる一文の実装**:
「深く潜るほど良いカードが出る。エリートを倒すと 1 段階先のテーブルが引ける。ボスは既存のアーティファクト報酬で別枠」

---

## 2. データ構造定義

### 2-1. レアリティ重みテーブル（企画書値・MVP版）

`scripts/RewardTable.gd` 内に定数として定義する。

```
const RARITY_WEIGHTS_EARLY = {"common": 65, "uncommon": 30, "rare": 5,  "epic": 0,  "legend": 0,   "god": 0}
const RARITY_WEIGHTS_MID   = {"common": 40, "uncommon": 40, "rare": 17, "epic": 3,  "legend": 0,   "god": 0}
const RARITY_WEIGHTS_LATE  = {"common": 20, "uncommon": 35, "rare": 30, "epic": 12, "legend": 2,   "god": 0}
```

**備考**:
- 後期 legend は企画書値 2.5 + god 0.5 のところを、**MVPでは legend=2 / god=0 に丸める**（godカード未実装のため）
- godカード実装時に legend=2.5 / god=0.5 へ戻せるよう、コメントで意図を残す
- 合計は 100 になるように調整する（Early=100, Mid=100, Late=99 → Lateは uncommon+1 等で100化。最終値はCEO承認後に確定）

### 2-2. ステージ定数

```
const STAGE_EARLY = 0
const STAGE_MID   = 1
const STAGE_LATE  = 2

const STAGE_EARLY_MAX_DEPTH: int = 3   # run_depth <= 3 → Early
const STAGE_MID_MAX_DEPTH:   int = 7   # run_depth <= 7 → Mid
# それ以上は Late
```

### 2-3. ブーストフラグ（既存流用）

- `GameSession.elite_injected_in_battle: bool`（既存）
  - `true` の時は「ステージ+1」と「選択肢+1」の両方を適用する
  - 既存のリセット箇所はそのまま

---

## 3. 実装箇所（ファイル × 関数）

### 3-1. `scripts/RewardTable.gd` （**新規作成**）

**ファイル**: `C:\Users\kazum\dungeon-board-game\scripts\RewardTable.gd`
**推定行数**: 60〜80行
**責務**: run_depth・エリートフラグからステージとレアリティ重みを決定する純粋ロジック層

```
class_name RewardTable
extends RefCounted

# レアリティ重み定数（上記 2-1 参照）
const RARITY_WEIGHTS_EARLY = { ... }
const RARITY_WEIGHTS_MID   = { ... }
const RARITY_WEIGHTS_LATE  = { ... }

# ステージ境界
const STAGE_EARLY_MAX_DEPTH: int = 3
const STAGE_MID_MAX_DEPTH:   int = 7

# run_depth からベースステージを決定（0=Early, 1=Mid, 2=Late）
static func base_stage(run_depth: int) -> int

# エリート混入時はステージ+1（上限: Late）
static func effective_stage(run_depth: int, elite_injected: bool) -> int

# ステージインデックスから重み Dictionary を取得
static func weights_for_stage(stage: int) -> Dictionary

# 便利メソッド: 一発で重みを取得
static func get_weights(run_depth: int, elite_injected: bool) -> Dictionary

# ブーストが発生しているか（UI表示判定用）
static func is_boosted(run_depth: int, elite_injected: bool) -> bool
```

**関数仕様**:

- `base_stage(run_depth)`:
  - `run_depth <= 3` → `STAGE_EARLY`
  - `run_depth <= 7` → `STAGE_MID`
  - それ以外 → `STAGE_LATE`

- `effective_stage(run_depth, elite_injected)`:
  - `base = base_stage(run_depth)`
  - `if elite_injected: return min(base + 1, STAGE_LATE)`
  - `else: return base`

- `is_boosted(run_depth, elite_injected)`:
  - ベースステージより実効ステージが上なら `true`（すなわち `elite_injected and base_stage != STAGE_LATE`）

**注意事項**:
- 静的メソッドのみ（状態を持たない）。テスト容易性を確保
- ユニットテスト不要（MVPではResult.gdからの動作確認で代替可）

---

### 3-2. `scripts/Result.gd` （変更）

**変更箇所1**: 定数削除（行25-28）

- `RARITY_WEIGHTS_EARLY / MID / LATE` を削除
- 代わりに `const RewardTableClass = preload("res://scripts/RewardTable.gd")` を先頭に追加

**変更箇所2**: `_generate_card_choices()` の重み選択ロジック（行103-110）

**変更前**:
```
if GameSession.run_depth <= 3:
    weights = RARITY_WEIGHTS_EARLY
elif GameSession.run_depth <= 7:
    weights = RARITY_WEIGHTS_MID
else:
    weights = RARITY_WEIGHTS_LATE
```

**変更後**:
```
var weights: Dictionary = RewardTableClass.get_weights(GameSession.run_depth, GameSession.elite_injected_in_battle)
```

- これで **ステージ+1ロジックが有効化される**
- 既存の `_weighted_pick()` 関数は無変更

**変更箇所3**: ブースト可視化アイコン追加（`_build_ui()` 内、カード選択ラベル "── カードを1枚選べ ──" の横）

- 位置: 現行の pick_label（position=Vector2(0,210), size=Vector2(1280,25)）の右隣にアイコン Label を追加
- `RewardTableClass.is_boosted(GameSession.run_depth, GameSession.elite_injected_in_battle)` が `true` の時のみ表示

**アイコン仕様**:
| 項目 | 値 |
|---|---|
| テキスト | `★ BOOSTED` |
| フォントサイズ | 14 |
| 色 | `Color(1.0, 0.85, 0.3)` 金 |
| 位置 | Vector2(820, 210) |
| サイズ | Vector2(200, 25) |
| horizontal_alignment | HORIZONTAL_ALIGNMENT_LEFT |

**新規関数**:
```
func _add_boost_icon() -> void
```
- `_build_ui()` 内の pick_label 追加直後から呼び出す
- ブースト条件に合致しない場合は何もしない

**変更箇所4**: ログ出力

- 重み選択直後に `print("[Result] run_depth=%d elite=%s stage=%d" % [...])` を出力
- デバッグ時に参照ステージが明確になる

---

### 3-3. `scripts/GameSession.gd` （変更なし）

- `run_depth` / `elite_injected_in_battle` は既存。追加フィールドなし
- 企画書10-1「run_depth変数は既存か？」の回答 → **既存。流用する**

---

### 3-4. `scripts/EnemyPlacementHelper.gd` （変更なし）

- `elite_injected_in_battle = true` の設定は既に実装済み（行42）
- 本要件では追加変更不要

---

### 3-5. ボス戦経路（変更なし）

- `_generate_boss_artifact_choices()` は既存のまま
- 呼び出し条件 `if GameSession.battle_type == "boss"` は変更しない
- ドロップテーブルはボス戦に介入しない（企画書7章）

---

## 4. Sprint 分割

### Sprint A（最小実装）— 1セッション

**目的**: 企画書値に差し替え、ステージ+1を有効化する（可視化は後）

**タスク**:
1. `scripts/RewardTable.gd` を新規作成
   - 定数 3 本、静的メソッド 5 本
2. `scripts/Result.gd` 変更
   - 既存 `RARITY_WEIGHTS_*` 定数削除
   - `_generate_card_choices()` を `RewardTable.get_weights(...)` 呼び出しに差し替え
3. `bash tools/ci/tools/ci/check_syntax.sh` 実行

**完了条件**:
- 通常戦（非エリート）で run_depth が 0-3 / 4-7 / 8+ の時に重みが切り替わる
- エリート混入戦でステージが 1 段階繰り上がる（ログで確認）
- 構文エラーなし
- 選択肢+1は既存ロジックのまま機能する

---

### Sprint B（警戒統合検証）— 同セッション可

**目的**: エリート混入戦での挙動を実ランで確認する（データ検証のみ・コード変更なし）

**タスク**:
1. TestSession.gd にシナリオ追加（任意）
   - `run_depth=0, elite_injected=true` → 中期テーブル参照を検証
   - `run_depth=8, elite_injected=true` → 後期テーブル（上限）を検証
2. 実ラン検証: 警戒 Lv4+ の戦闘を踏んでエリート混入 → 勝利 → 報酬画面で参照ステージがログに出ることを確認

**完了条件**:
- ログ `[Result] run_depth=X elite=true stage=Y` が期待通りに出力される
- コード変更が発生しない（= Sprint A で正しく組めている）

**Note**: Sprint B で不具合が見つかれば Sprint A に戻る

---

### Sprint C（可視化）— 1セッション

**目的**: ブーストを 3 秒で伝える

**タスク**:
1. `Result.gd` に `_add_boost_icon()` 関数を追加
2. `_build_ui()` から呼び出し
3. `bash tools/ci/tools/ci/check_syntax.sh` 実行

**完了条件**:
- エリート混入戦の報酬画面に `★ BOOSTED` アイコンが表示される
- 非エリート戦では非表示
- 後期（run_depth≥8）でエリート混入時も表示される（企画書の通り「実効ステージがベースと同じ」なら非表示が正しいが、**企画書10-4 の判断次第**）

**未確定事項（CEO判断）**:
- 後期（ベースLate）でエリート混入した場合、ステージは繰り上がらない（上限）。このとき BOOSTED アイコンを出すか？
  - 推奨案A: 出さない（実効ステージが変わらないので嘘にならない）
  - 代替案B: 出す（エリート戦闘である事実は伝わる）
  - **architect推奨: 案A**。理由：3秒ルール上「BOOSTED = 良くなってる」と直感される。実際にテーブルが同じなら出さないほうが誠実

---

## 5. テストポイント

### 5-1. ユニット動作確認（TestSession または手動）

| ケース | run_depth | elite_injected | 期待参照ステージ | 期待選択肢数 |
|---|---|---|---|---|
| 早期・通常 | 0 | false | Early | 3 |
| 早期・エリート | 2 | true | Mid | 4 |
| 中期・通常 | 5 | false | Mid | 3 |
| 中期・エリート | 7 | true | Late | 4 |
| 後期・通常 | 8 | false | Late | 3 |
| 後期・エリート | 10 | true | Late（上限） | 4 |
| 境界値 Early/Mid | 3 | false | Early | 3 |
| 境界値 Early/Mid | 4 | false | Mid | 3 |
| 境界値 Mid/Late | 7 | false | Mid | 3 |
| 境界値 Mid/Late | 8 | false | Late | 3 |

### 5-2. 視覚確認（ユーザー実施）

1. 警戒 Lv0 通常戦勝利後、報酬画面で BOOSTED アイコンが **出ない** こと
2. 警戒 Lv4+ 通常戦でエリート混入して勝利後、BOOSTED アイコンが **出る** こと（run_depth 0-7 のとき）
3. ボス戦勝利後はアーティファクト 3 択が出て、重みテーブルロジックは通らないこと（ログで確認）
4. run_depth 加算が既存通り動くこと（カード選択・スキップ両方で +1）

### 5-3. 境界条件・例外

- `run_depth == -1` 等の異常値: `base_stage()` は負値で Early 扱いになる（`<=3` で true）。致命的ではないが、ログにワーニングを出すか CEO 判断
  - **推奨: ワーニング不要**。GameSession.reset() で 0 に戻るので通常発生しない
- `elite_injected_in_battle` のリセットタイミング: 次バトル開始時にどこでリセットされているか要確認
  - Main.gd `_ready()` 付近でリセットされている前提。されていない場合は **Sprint A で追加必要**（別途調査）

### 5-4. 構文・回帰

- `bash tools/ci/tools/ci/check_syntax.sh` クリーン
- 既存の `TestSession.gd` シナリオ 2（run_depth 加算）が引き続きパスする

---

## 6. 制約・注意事項

### 核となる体験との整合性（YESマンチェック済み）
- 観戦フェーズに介入しない ✓（報酬画面のみ）
- 3秒ルール順守 ✓（アイコン1個で表現）
- 足し算チェック: 企画書記載の要素のみ実装、独自追加なし ✓
- 廃止済み設計との抵触なし ✓

### 不採用（企画書9章の廃案リストを順守）
- run_depth 以外の主軸: **使わない**
- レアリティ 5 段階以上への細分化: **しない**
- プレイヤースキル値動的調整: **しない**
- Pity System: **しない**
- カード種別別テーブル: **しない**
- ボス戦へのドロップテーブル適用: **しない**
- 警戒 Lv1-3 での報酬優遇: **しない**（Lv4+ のエリート混入時のみ）

### GAME_DESIGN.md との整合性
- 178-183行「Act進行とrun_depth」と一致
- ドロップレアリティ重み判定に run_depth を使う方針と一致

### 既存実装との整合性
- Result.gd のアーティファクト `reward_choices` 効果（行131-137）は本変更で壊さない
- エリート +1 と アーティファクト `reward_choices` +N は **加算** で共存

### 未確定事項（CEO判断要）
1. **後期でエリート混入時に BOOSTED アイコンを出すか**
   - architect推奨: **出さない**（実効ステージが変わらないため）
2. **重み合計が100になっていないケースの丸め**
   - architect推奨: Late の uncommon を 35 → 36 に調整（計100）
3. **godレアリティを 0.5% として有効化するか**
   - architect推奨: **0% のまま**（godカード未実装のため）
4. **`elite_injected_in_battle` の次バトル開始時リセット箇所**
   - 未確認。Sprint A 実装前に `Main.gd _ready()` を調査し、未実装なら追加する

### 報告事項（architect → CEO）
1. **Result.gd がすでに 507 行あります**。本要件で純増を最小化するため `RewardTable.gd` に重み決定ロジックを切り出しました（企画書には無い分割判断ですが、CLAUDE.md のファイルサイズ指針に基づく予防的対応）。
2. **既存の重み値が企画書と乖離しており差し替えが必要** です。既存値のほうがバランス取れている可能性があるため、差し替え時にバランス調整メモを残します。
3. **エリート時ステージ+1ロジックは現状未実装** でした。選択肢+1のみ実装済みで、企画書の半分だけ実装されている状態です。本要件で完結させます。
4. **境界値（3/7）は企画書と既存実装で既に一致** していました。変更不要です。

---

## 7. 実装順序と依存関係

```
[1] RewardTable.gd 新規作成（独立）
     └─ 完了後
[2] Result.gd 変更（定数削除・呼び出し差し替え）
     └─ Sprint A 完了
[3] ログ検証（Sprint B）
     └─ 動作OK確認後
[4] Result.gd _add_boost_icon() 追加（Sprint C）
     └─ 視覚確認
[5] CEO承認・コミット
```

依存: [2] は [1] の完了に依存。[4] は [2] と独立（先に [4] を書くことも可能だが、推奨順は上記）

---

## 8. roadmap.md 反映案

**更新対象**: roadmap.md 行72

**変更前**:
```
| 12 | ドロップテーブル実装 | 中 | ✅ | 未着手 | 未着手 | run_depth連動レアリティ重み |
```

**変更後（要件定義完了時点）**:
```
| 12 | ドロップテーブル実装（進行度別） | 中 | ✅ | ✅ | 未着手 | 2026-04-12 企画・要件定義完了（drop_table_system.md, drop_table_requirements.md）。既存RARITY_WEIGHTS_*を企画値に差替え＋RewardTable.gd新設＋エリート時ステージ+1＋BOOSTEDアイコン追加。godはMVPでは0% |
```

**CHANGELOG.md 想定エントリ（実装後）**:
```
### 2026-04-XX
- feat: ドロップテーブル実装 MVP（Phase3 タスク#12完了）
  - run_depth 3段階レアリティ重みを企画書値に差し替え
  - RewardTable.gd 新設（重み決定ロジックを分離）
  - エリート混入戦でステージ+1参照（警戒システム統合点）
  - 報酬画面に BOOSTED アイコン追加（3秒ルール対応）
  - ボス戦のアーティファクト経路は不変
```

---

## 9. 完了定義

roadmap #12 完了の判定条件:

1. run_depth 0-3 / 4-7 / 8+ で通常戦の重みが切り替わる（ログで確認）
2. 警戒 Lv4+ でエリート混入した通常戦の報酬が、ベースより 1 段階上のテーブルから抽選される
3. エリート混入戦の報酬画面に BOOSTED アイコンが 3 秒以内に視認できる
4. ボス戦の報酬は既存通りアーティファクト 3 択を維持している
5. `bash tools/ci/tools/ci/check_syntax.sh` クリーン
6. CEO 視覚確認で「深く潜るほど良いカードが出る」体験が成立

---

## 関連ファイルパス（絶対パス）

- 企画書: `C:\Users\kazum\dungeon-board-game\docs\design\drop_table_system.md`
- 設計文書: `C:\Users\kazum\dungeon-board-game\docs\GAME_DESIGN.md`
- 要件定義書（本ファイル・保存先）: `C:\Users\kazum\dungeon-board-game\docs\design\drop_table_requirements.md`
- 変更対象:
  - `C:\Users\kazum\dungeon-board-game\scripts\Result.gd`
- 新規作成:
  - `C:\Users\kazum\dungeon-board-game\scripts\RewardTable.gd`
- 参考（変更なし）:
  - `C:\Users\kazum\dungeon-board-game\scripts\GameSession.gd`
  - `C:\Users\kazum\dungeon-board-game\scripts\EnemyPlacementHelper.gd`
- roadmap 更新対象: `C:\Users\kazum\dungeon-board-game\docs\roadmap.md`

---

## architect からの重要メモ

- 本要件は **既存実装が企画書の 60% 程度まで進んでいた** ことを踏まえた差分実装要件です。ゼロから作るわけではありません
- Sprint A だけで MVP としての最小要件（ステージ+1）は満たせます。Sprint C は「3秒ルール必須」ですが分離可能です
- CEO 承認時は未確定事項 4 点（BOOSTEDアイコン範囲 / Late重み丸め / god有効化 / エリートフラグリセット箇所）に回答してください

---

**備考**: 本要件定義書は指示通り `docs/design/drop_table_requirements.md` への保存を意図していますが、architect 権限では Write 禁止のため全文を本返信で提供しました。CEO 承認後、implementer がこのファイルを保存するか、CEO が直接ファイル化してください。
