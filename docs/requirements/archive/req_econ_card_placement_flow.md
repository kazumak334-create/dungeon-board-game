STATUS: 廃止（→ 対応する REQUIREMENTS_SPRINT_{N}.md を参照）

# Econ MVP v0.2 カード配置フロー 要件定義書

**更新日:** 2026-05-03（初版）
**ステータス:** 実装リソース（一時）／実装後に `docs/requirements/REQUIREMENTS_V0_2_MVP.md` へ統合して削除
**対象:** scripts/econ_mvp/EconMain.gd（`_place_building_from_card()`）／scripts/econ_mvp/EconBattle.gd（`play_card_to_cell()` 系）

**関連ドキュメント:**
- `docs/requirements/REQUIREMENTS_V0_2_MVP.md`（v0.2 上位要件）
- `docs/requirements/req_econ_draw_hand_circulation.md` §4.4.3（配置時3ステップ）／§8.5（人口計算）／§8.6（建物破壊時）
- `docs/requirements/req_econ_parameter_architecture.md`（パラメータ集約・疎結合方針）
- `docs/meta/adr/001_econ_spawn_centralized.md`（EconBattle 一元化規約）

---

## 修正履歴

| 日付 | 版 | 修正内容 | 修正者 |
|------|----|---------|------|
| 2026-05-03 | v0.1（初版） | `_place_building_from_card()` における事前チェック・消費・登録・人口割当・除外の5ステップ統一フローを定義 | Architect |

---

## 1. 概要

現状、`EconMain._place_building_from_card()` は「建物生成・配置」「カード除外」までは動作しているが、**リソース充足チェック・消費／人口充足チェックが呼び出されていない**。一方で `EconEconomy.can_afford_card()`／`consume_resources()`／`calculate_population_cap()`／`population_used` 管理は既に実装済み（参考: `EconBattle.play_card_to_cell()` は §4.4.3 の3ステップを正しく実装）。

本要件定義書は、`_place_building_from_card()` を `EconBattle.play_card_to_cell()` と等価な順序で動作させるための呼び出し順・失敗時処理を定義する。**新規ロジックは追加せず、既存メソッドの呼び出しを正しい順序で並べる**ことが目的（KISS 原則）。

---

## 2. 実装対象

| ファイル | 関数 | 現在行 | 想定追加行 | 概算 |
|---------|------|-------|----------|------|
| scripts/econ_mvp/EconMain.gd | `_place_building_from_card()` | 1208-1274（67行） | 約25行（事前チェック2件＋消費1件＋ログ） | 92行 |
| scripts/econ_mvp/EconMain.gd | `_input()`（呼び出し元） | 1156-1176 | 0（変更なし） | - |

**ファイル全体の現在行数（EconMain.gd）:** 約1300行 → 追加後 約1325行（**500行超えだが 800行を大きく超過済み**。本タスクでは追加のみ・分割は別タスクで扱う／詳細は `req_econ_parameter_architecture.md` §4 の優先度参照）。

---

## 3. データ構造

新規データ構造は追加しない。以下の既存構造を利用する。

### 3.1 入力（呼出元から渡る）
- `cell: Vector2i` — 配置先セル（既存）
- `btype_str: String` — 建物タイプ文字列（既存）
- `_selected_card_idx: int` — 手札インデックス（EconMain メンバ・既存）
- `_battle.deck_manager.hand[idx]: Dictionary` — カードデータ（cards_econ.json 由来）

### 3.2 カード Dictionary の参照キー（cards_econ.json 既存スキーマ）
| キー | 型 | 用途 |
|------|---|------|
| `cost` | Dictionary | `economy.can_afford_card(card)`／`economy.consume_resources(card)` の入力 |
| `population_required` | int | 人口充足チェックに使用（`population_used + N <= population_cap`） |
| `population_supply` | int | HOUSE 等が供給する人口上限（v0.2 では HOUSE のみ非0） |
| `building_type` | String | 既存 `btype_map` でEnum変換 |
| `hp` | int | 建物 HP の初期値（任意：現状未使用なら無視可） |
| `name` | String | ログ出力用 |

### 3.3 既存メソッド呼出インターフェース
| メソッド | 引数 | 戻り値 | 用途 |
|---------|------|--------|------|
| `EconEconomy.can_afford_card(card: Dictionary)` | カード辞書 | bool | リソース充足チェック |
| `EconEconomy.consume_resources(card: Dictionary)` | カード辞書 | void | リソース消費（resources/wood/stone/sulfur/food/iron/cotton 全て同期） |
| `EconEconomy.calculate_population_cap()` | なし | int | HOUSE 効果込みで再計算 |
| `EconBattle.register_player_building(b: EconBuilding)` | 建物 | void | player_buildings 追加 + grid 子化（ADR-001） |
| `EconDeckManager.exclude_card_at(idx: int)` | 手札 idx | Dictionary | 手札から除外配列へ移動 |

---

## 4. 実装詳細

### 4.1 フロー全体図

```
_place_building_from_card(cell, btype_str)
    │
    ├─ [Step 0] btype_map 検証 ─失敗→ ログ／関数終了（手札変動なし）
    │
    ├─ [Step 1] 事前チェック（3項目）
    │     ├─ 1-A: 自建物半径3hex 内チェック（既存）
    │     ├─ 1-B: 手札インデックス有効性チェック（_selected_card_idx）
    │     ├─ 1-C: economy.can_afford_card(card) ★新規呼出
    │     └─ 1-D: economy.population_used + pop_req <= economy.population_cap ★新規呼出
    │           いずれか失敗→ ログ／関数終了（手札変動なし）
    │
    ├─ [Step 2] リソース消費 ★新規呼出
    │     economy.consume_resources(card)
    │
    ├─ [Step 3] 建物生成・配置（既存コードそのまま）
    │     EconBuilding.new() → setup() → position 設定
    │     unit_produced / building_destroyed シグナル接続
    │     _battle.register_player_building(b)
    │
    ├─ [Step 4] 人口割当 ★新規呼出
    │     economy.population_used += card.population_required
    │     HOUSE のとき: economy.population_cap = economy.calculate_population_cap()
    │
    └─ [Step 5] カード除外（既存コードそのまま）
          _battle.deck_manager.exclude_card_at(_selected_card_idx)
          _selected_card_idx = -1
          ログ出力
```

成功パス: Step 0 → 1 → 2 → 3 → 4 → 5（全完走）。
失敗パス: Step 0 または Step 1 で `return`。**Step 2 以降に到達した時点で配置は確定とみなす**（途中失敗時のロールバックは行わない＝ KISS）。

### 4.2 Step 0: btype_map 検証（既存・変更なし）

```gdscript
if not btype_map.has(btype_str):
    _add_log("Unknown building type: %s" % btype_str)
    return
```

**注意:** `btype_map` の管理場所は別要件 `req_econ_parameter_architecture.md` §3.2 で議論する。本要件では既存ローカル定義のまま使用。

### 4.3 Step 1: 事前チェック（配置前）

#### 1-A: 自建物半径3hex 内チェック（既存・現行どおり）
```gdscript
var in_range := false
for pb in _battle.player_buildings:
    if pb.is_alive and _grid.hex_distance(cell, pb.grid_pos) <= 3:
        in_range = true
        break
if not in_range:
    _add_log("自建物から半径3hex以内にのみ建設できます")
    return
```

#### 1-B: 手札インデックス有効性チェック（新規）
```gdscript
if _selected_card_idx < 0 or _battle.deck_manager == null:
    _add_log("手札選択が無効です")
    return
if _selected_card_idx >= _battle.deck_manager.hand.size():
    _add_log("手札インデックス範囲外: %d" % _selected_card_idx)
    return
var card: Dictionary = _battle.deck_manager.hand[_selected_card_idx]
```

#### 1-C: リソース充足チェック（新規）
```gdscript
if _economy != null and not _economy.can_afford_card(card):
    _add_log("資源不足: %s（必要 %s）" % [btype_str, str(card.get("cost", {}))])
    return
```

**メッセージ仕様:** `"資源不足: <btype_str>（必要 <cost dict>）"`。
将来的に「木材不足」のような個別メッセージに切り替えたい場合は別要件で扱う（KISS：今は1メッセージで十分）。

#### 1-D: 人口充足チェック（新規）
```gdscript
if _economy != null:
    var pop_req: int = card.get("population_required", 0)
    if _economy.population_used + pop_req > _economy.population_cap:
        _add_log("人口上限超過: %s（必要+%d, 残り%d）" % [
            btype_str, pop_req,
            _economy.population_cap - _economy.population_used
        ])
        return
```

### 4.4 Step 2: リソース消費（配置確定時）

タイミング: **建物生成（`EconBuilding.new()`）の直前**。
理由: 生成後に消費すると、Step 3 でエラーが起きた際にリソースだけ減ってしまう（v0.2 ではここまで深いロールバック対応はしないが、配置確定の意思決定をリソース消費とまとめておく）。

```gdscript
if _economy != null:
    _economy.consume_resources(card)
```

`consume_resources()` は内部で `resources` 辞書と `wood/stone/sulfur/food/iron/cotton` フィールドを同期する（既存仕様）。本要件で追加処理は不要。

### 4.5 Step 3: 建物生成・配置（既存・変更なし）

```gdscript
var b := EconBuilding.new()
b.setup(btype, cell, true)
b.position = _grid.hex_to_pixel(cell.x, cell.y)
b.unit_produced.connect(...)         # 既存ラムダ
b.building_destroyed.connect(...)    # 既存ラムダ
_battle.register_player_building(b)  # ADR-001 準拠
```

**注意:** `register_player_building()` は ADR-001 で **EconBattle のみが配列操作を担当する**規約。`_place_building_from_card()` から `_battle.player_buildings.append(b)` を直接呼ぶことは禁止。

### 4.6 Step 4: 人口割当（自動）

```gdscript
if _economy != null:
    _economy.population_used += card.get("population_required", 0)
    # HOUSE 配置時は population_cap 自動再計算
    if btype == EconBuilding.BuildingType.HOUSE:
        _economy.population_cap = _economy.calculate_population_cap()
        print("[EconMain] HOUSE placed: pop_cap recalculated -> ", _economy.population_cap)
```

**設計判断:**
- `population_used` の加算は EconMain 側で行う（EconBattle.play_card_to_cell() と同じパターン）。
- HOUSE 破壊時の `population_cap` 減算は `building_destroyed` シグナル経由で `EconMain._place_building_from_card()` 内のラムダ（既存）または `EconBattle._create_building_from_card()` 内のラムダで処理（既存実装でカバー済み）。
- `population_supply` はカード辞書から参照可能だが、**HOUSE Lv別の人口上限は `calculate_population_cap()` が建物リストから集計するためカード値は使わない**（疎結合：単一の真実のソース＝建物リスト）。

### 4.7 Step 5: カード除外（既存・変更なし）

```gdscript
_add_log("%s placed at (%d,%d)" % [btype_str, cell.x, cell.y])
if _selected_card_idx >= 0 and _battle.deck_manager != null:
    _battle.deck_manager.exclude_card_at(_selected_card_idx)
    _selected_card_idx = -1
```

`exclude_card_at()` は内部で `hand.remove_at(idx)` → `excluded.append(card)` を行う（既存）。

---

## 5. 失敗時の処理フロー

### 5.1 失敗ケース一覧

| ケース | 検出箇所 | ログ出力テンプレ | 副作用 |
|-------|--------|---------------|-------|
| 不明な building_type | Step 0 | `Unknown building type: <btype_str>` | なし |
| 手札 idx 無効 | Step 1-B | `手札選択が無効です` または `手札インデックス範囲外: <idx>` | なし |
| 範囲外配置 | Step 1-A | `自建物から半径3hex以内にのみ建設できます` | なし |
| リソース不足 | Step 1-C | `資源不足: <btype_str>（必要 <cost>）` | なし |
| 人口超過 | Step 1-D | `人口上限超過: <btype_str>（必要+N, 残りM）` | なし |

### 5.2 共通原則
- **手札は変動しない**（exclude_card_at は呼ばない）。
- **リソースも変動しない**（consume_resources は呼ばない）。
- **`_selected_card_idx` も変更しない**（`_selected_card_btype` のみ呼出元 `_input()` 1174行で `""` クリアされる）。
- ログは `_add_log()` で 1 行のみ出力。例外送出はしない（v0.2 のゲームプレイ中断を避ける）。

### 5.3 UI 反応
v0.2 では「ログ表示 + 手札がそのまま残る」のみで十分（KISS）。
将来的にトースト通知や不足リソースの赤点滅等を行う場合は別要件で扱う。

---

## 6. 制約・注意事項

### 6.1 既存コードとの整合性
- 本要件の実装は **`EconBattle.play_card_to_cell()`（行47-73）の動作と等価** になる。両者は将来統合する余地があるが、v0.2 では `_place_building_from_card()` 経路（マウスクリック→`_input()`→建物配置）が主であり、`play_card_to_cell()` は AI 側もしくはテスト用途。本要件では現行の `_place_building_from_card()` を主実装とし、`play_card_to_cell()` には触れない（KISS）。
- `register_player_building()` 経由の登録は ADR-001 準拠。配列直接操作は禁止。

### 6.2 GAME_DESIGN.md／設計原則との整合性
- リソース消費を「配置確定時の即時消費」としている（`req_econ_draw_hand_circulation.md` §4.4.3 ステップ1 と一致）。
- 人口は「`population_used`／`population_cap` の単一管理」（CLAUDE.md：用語統一・疎結合）。
- 失敗時に手札・リソース・人口いずれも変動しないことで「介入を仕込んで答え合わせを観戦する」の信頼性を担保。

### 6.3 KISS チェック
- 新フィールド追加: なし
- 新クラス追加: なし
- 新シグナル追加: なし
- 新メソッド追加: なし（既存メソッド呼出のみ）
- 引き算: 失敗時のロールバック機構を意図的に持たない（Step 1 で全件チェック完了後に Step 2 以降に進むため不要）

### 6.4 用語整合性（CLAUDE.md 用語統一ルール）
| 用語 | コード／ドキュメント |
|------|------------------|
| population_used | EconEconomy.population_used（実値・整数） |
| population_cap | EconEconomy.population_cap（上限・整数） |
| population_required | cards_econ.json 内 / カード辞書 |
| population_supply | cards_econ.json 内 / カード辞書（HOUSE のみ非0、本要件では参照しない） |
| consume_resources | EconEconomy.consume_resources(card)（既存メソッド名・維持） |
| can_afford_card | EconEconomy.can_afford_card(card)（既存メソッド名・維持） |

---

## 7. 実装パターン（参考コードスニペット）

```gdscript
func _place_building_from_card(cell: Vector2i, btype_str: String) -> void:
    # v0.2 手札カードから建物を配置（§4.4.3 / req_econ_card_placement_flow.md §4）

    # ---- Step 0: btype_map 検証 ----
    var btype_map: Dictionary = {
        "BARRACKS":        EconBuilding.BuildingType.BARRACKS,
        # ... (既存どおり)
    }
    if not btype_map.has(btype_str):
        _add_log("Unknown building type: %s" % btype_str)
        return
    var btype: int = int(btype_map[btype_str])

    # ---- Step 1-A: 配置範囲チェック（既存）----
    var in_range := false
    for pb in _battle.player_buildings:
        if pb.is_alive and _grid.hex_distance(cell, pb.grid_pos) <= 3:
            in_range = true
            break
    if not in_range:
        _add_log("自建物から半径3hex以内にのみ建設できます")
        return

    # ---- Step 1-B: 手札 idx 有効性 ----
    if _selected_card_idx < 0 or _battle.deck_manager == null:
        _add_log("手札選択が無効です")
        return
    if _selected_card_idx >= _battle.deck_manager.hand.size():
        _add_log("手札インデックス範囲外: %d" % _selected_card_idx)
        return
    var card: Dictionary = _battle.deck_manager.hand[_selected_card_idx]

    # ---- Step 1-C: リソース充足 ----
    if _economy != null and not _economy.can_afford_card(card):
        _add_log("資源不足: %s（必要 %s）" % [btype_str, str(card.get("cost", {}))])
        return

    # ---- Step 1-D: 人口充足 ----
    if _economy != null:
        var pop_req: int = card.get("population_required", 0)
        if _economy.population_used + pop_req > _economy.population_cap:
            _add_log("人口上限超過: %s（必要+%d, 残り%d）" % [
                btype_str, pop_req,
                _economy.population_cap - _economy.population_used
            ])
            return

    # ---- Step 2: リソース消費 ----
    if _economy != null:
        _economy.consume_resources(card)

    # ---- Step 3: 建物生成・配置（既存コードそのまま）----
    var b := EconBuilding.new()
    b.setup(btype, cell, true)
    b.position = _grid.hex_to_pixel(cell.x, cell.y)
    b.unit_produced.connect(func(pos: Vector2i, utype: int):
        # 既存ラムダのまま
        pass
    )
    b.building_destroyed.connect(func(building: Node):
        _battle._on_building_destroyed(building)
        if btype == EconBuilding.BuildingType.HOUSE and _economy != null:
            _economy.population_cap = _economy.calculate_population_cap()
            print("[EconMain] HOUSE destroyed: pop_cap -> ", _economy.population_cap)
    )
    _battle.register_player_building(b)

    # ---- Step 4: 人口割当 ----
    if _economy != null:
        _economy.population_used += card.get("population_required", 0)
        if btype == EconBuilding.BuildingType.HOUSE:
            _economy.population_cap = _economy.calculate_population_cap()
            print("[EconMain] HOUSE placed: pop_cap -> ", _economy.population_cap)

    # ---- Step 5: カード除外 ----
    _add_log("%s placed at (%d,%d)" % [btype_str, cell.x, cell.y])
    _battle.deck_manager.exclude_card_at(_selected_card_idx)
    _selected_card_idx = -1
```

---

## 8. 検証方法

### 8.1 動作確認シナリオ（手動 QA）

| # | シナリオ | 操作 | 期待結果 |
|---|---------|------|---------|
| 1 | 正常配置（リソース充足・人口余裕） | 木材6/石3/食料0 持ちで HOUSE（cost wood=3）を配置 | 配置成功、wood -3、population_cap +10、手札除外 |
| 2 | リソース不足 | 木材1で HOUSE（cost wood=3）を配置試行 | ログ「資源不足: HOUSE...」、wood/手札/pop 変動なし |
| 3 | 人口上限超過 | population_used=49, population_cap=50, BARRACKS（pop_req=1）配置 → さらに BARRACKS 配置試行 | 1回目成功で pop_used=50、2回目はログ「人口上限超過...」、リソース・手札変動なし |
| 4 | 範囲外配置 | 自建物から hex_distance=4 の位置に配置試行 | ログ「自建物から半径3hex...」、リソース・手札変動なし |
| 5 | HOUSE 連続配置 | HOUSE×2 配置 | population_cap が 50 → 60 → 70 と増加 |
| 6 | HOUSE 破壊 | HOUSE 配置後に建物破壊 | population_cap が再計算され減少（既存挙動・回帰確認） |

### 8.2 自動チェック
- `bash check_syntax.sh` でパース・lint エラー0件
- ADR-001 違反検出（`_battle.player_buildings.append` 直接操作）が新規発生していないこと

### 8.3 ログ確認ポイント
配置成功時の標準ログ列：
```
[EconEconomy] consume_resources: { "wood": 3 }
[EconMain] HOUSE placed: pop_cap recalculated -> 60
HOUSE placed at (3,5)
[EconDeckManager] exclude_card_at: '住居', hand=N-1, excluded=M+1
```
このログ列が出ない場合は実行パスが想定外（CLAUDE.md「バグ修正前の実行パス確認」参照）。

---

## 9. 確定事項・繰越項目

### 9.1 v0.2 で確定
- リソース消費は配置確定の直前（Step 2）に1回のみ
- 失敗時は手札・リソース・人口いずれも変動しない
- `population_supply` のカード値は参照しない（建物リスト集計が真）

### 9.2 v0.3 以降に繰越
- 不足リソース個別表示（"木材不足"／"石材不足"）
- トースト通知・赤点滅 UI 反応
- `_place_building_from_card()` と `EconBattle.play_card_to_cell()` の統合
- HOUSE Lv2/Lv3 配置時の `population_cap` 増加幅再検証
