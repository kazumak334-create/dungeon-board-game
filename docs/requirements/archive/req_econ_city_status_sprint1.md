STATUS: 廃止（→ 対応する REQUIREMENTS_SPRINT_{N}.md を参照）

# Sprint 1: 都市ステータス基盤

ステータス: 実装リソース（一時）
対応Sprint: Sprint 1
参照設計書:
- docs/econ/population_satisfaction_food_system_design.md
- docs/econ/panel_resource_system_design.md
- docs/econ/sprint_plan_population_satisfaction_food.md §5
統合先: docs/requirements/REQUIREMENTS_V0_2_MVP.md（Sprint 1 セクション）
更新日: 2026-05-03

---

## 目的

人口・食料値・満足度を通常資源とは別に管理できる「都市ステータス」基盤を構築する。
小麦と食料値を分離し、後続Sprintで使用するデータ構造・ゲッター・初期化処理を整える。

本Sprintはデータ構造のみ（実処理はSprint 2以降で追加）。

---

## 実装対象クラス・関数

### 拡張対象
- `scripts/econ_mvp/EconEconomy.gd`
  - 都市ステータス用フィールドの追加
  - 初期化処理 `initialize_v0_2()` への都市ステータス初期化追加
  - 満足度段階算出ゲッター `get_satisfaction_stage()` 新規追加
  - 表示人口ゲッター `get_display_population()` 新規追加

### 追加フィールド（EconEconomyに追加）

| フィールド名 | 型 | 初期値 | 用途 |
|---|---|---|---|
| `population_float` | float | 1.0 | 内部小数人口（既存`population_used: int`は維持して併存） |
| `population_cap` | int | 既存維持 | 人口上限（住宅で増加） |
| `food_value` | int | 0 | 食料値（小麦とは別管理） |
| `satisfaction_value` | float | 60.0 | 満足値（0〜100%） |
| `satisfaction_slope` | float | 0.0 | 満足値傾き（%/秒） |
| `satisfaction_stage` | String | "satisfied" | 満足度段階文字列キャッシュ |
| `military_power` | float | 既存維持 | 兵力 |
| `building_efficiency_modifier` | float | 1.0 | 建物効率補正（Sprint 5で使用） |
| `food_shortage_count` | int | 0 | 食料不足カウント |

### 既存フィールドとの関係

| 既存 | 扱い |
|---|---|
| `food: int` | 既存維持（後方互換）。Sprint 2で`food_value`へ移行を検討 |
| `wheat: int` | 既存維持（通常資源としての小麦） |
| `satisfaction: int` | 既存維持。`satisfaction_value: float`を新規追加し並存。Sprint 4で完全移行 |
| `population_used: int` | 既存維持。`population_float`を新規追加し並存。Sprint 3で同期処理追加 |

---

## 仕様

### 1. 人口の小数管理

- 内部値：`population_float: float`（小数）
- 表示値：`floor(population_float)`（整数）
- 下限：`max(1, floor(population_float))`
- 上限：`min(population_float, float(population_cap))`

### 2. 食料値

- 型：`int`
- 初期値：0
- 上限なし（MVPでは食料値最大保有上限は設けない／設計書 §14.1 残論点）
- 下限：0

### 3. 満足値

- 型：`float`
- 初期値：60.0
- 範囲：0.0 〜 100.0（クランプ）
- リアルタイム更新：`satisfaction_value = clamp(satisfaction_value + satisfaction_slope * delta, 0.0, 100.0)`
- 本Sprintでは更新処理は実装しない。フィールドのみ用意。

### 4. 満足度段階の算出（5段階）

| 満足値 | 段階キー | 表示名 |
|---:|---|---|
| 0〜19% | `decline` | 衰退 |
| 20〜39% | `dissatisfied` | 不満 |
| 40〜59% | `stable` | 安定 |
| 60〜79% | `satisfied` | 満足 |
| 80〜100% | `prosperity` | 繁栄 |

```gdscript
func get_satisfaction_stage() -> String:
    var v: float = satisfaction_value
    if v < 20.0: return "decline"
    if v < 40.0: return "dissatisfied"
    if v < 60.0: return "stable"
    if v < 80.0: return "satisfied"
    return "prosperity"
```

### 5. 表示人口ゲッター

```gdscript
func get_display_population() -> int:
    return max(1, int(floor(population_float)))
```

### 6. 初期化処理

`initialize_v0_2()` の末尾に以下を追加：

```gdscript
population_float = 1.0
food_value = 0
satisfaction_value = 60.0
satisfaction_slope = 0.0
satisfaction_stage = "satisfied"
building_efficiency_modifier = 1.0
food_shortage_count = 0
```

---

## 実装手順

1. `EconEconomy.gd` に上記フィールドを追加（既存フィールドの直下に追加し、コメントで「Sprint 1: 都市ステータス基盤（§5）」と明示）
2. `get_satisfaction_stage()` を追加
3. `get_display_population()` を追加
4. `initialize_v0_2()` に都市ステータス初期化を追加
5. デバッグ用 print を追加
   ```
   print("[EconEconomy] CityStatus init: pop=%.2f food=%d sat=%.1f stage=%s" % [population_float, food_value, satisfaction_value, get_satisfaction_stage()])
   ```
6. `bash check_syntax.sh` を実行してエラー0件を確認

---

## 完了条件

- [ ] 都市ステータスが通常資源とは別フィールドとして保持されている
- [ ] `population_float`が小数で保持されている
- [ ] `get_display_population()`が`floor`値（最低1）を返す
- [ ] `food_value`, `satisfaction_value`, `satisfaction_slope`, `food_shortage_count` が独立して保持されている
- [ ] `get_satisfaction_stage()` が満足値から正しい段階キーを返す（5段階）
- [ ] `initialize_v0_2()` で全フィールドが初期化される
- [ ] check_syntax.sh エラー0件
- [ ] 起動時にデバッグprintで都市ステータスが表示される

---

## 制約・注意事項

- 既存フィールド（`food`, `wheat`, `satisfaction`, `population_used`）は削除しない。後方互換のため並存させる
- 本Sprintでは「データ構造のみ」を実装。リアルタイム更新処理（人口増減・満足値傾き計算等）はSprint 2-4で実装する
- 用語統一ルール（CLAUDE.md）に従い、フィールド名は設計書（population/food_value/satisfaction_value/satisfaction_slope）と一致させる
- `building_efficiency_modifier` は Sprint 5 で使用するためフィールドのみ用意

---

## 関連する既存コード

- `EconEconomy.gd:1-380` 全体構造
- `EconEconomy.gd:22-25` 既存の`resources/food/satisfaction/military_power`定義
- `EconEconomy.gd:193-201` 既存の`get_happiness_state()`（4段階）
  - Sprint 4 完了後に5段階の `get_satisfaction_stage()` へ統一する想定（本Sprintでは並存）
- `EconEconomy.gd:362-379` 既存`initialize_v0_2()`

---

## 3. 土地パネル基盤実装

参照企画書:
- sprint_plan_updated_with_land_panel.md
- sprint1_land_panel_base_design.md

### 実装内容

- [ ] 26列×13行の盤面データ構造を新規追加（`EconGrid` 拡張または `EconLandPanel.gd` 新規）
- [ ] 自拠点初期位置を `col=2, row=7` に固定
- [ ] 土地パネル1枚あたりのデータ構造を定義
  - `pos: Vector2i`（座標）
  - `resources: Dictionary`（資源タイプ → 値）
  - `special_tag: String`（"none" / "spice" / "sulfur"）
  - `terrain_type: String`（"grassland" / "forest" / "rocky" / "desert" / "wetland" / "wasteland"）
  - `category: String`（"single" / "composite"）
  - `distance_band: String`（"near" / "mid" / "far"）
- [ ] 通常資源6種の定数定義
  - `wood`（木）
  - `resin`（樹脂）
  - `stone`（石）
  - `iron`（鉄鉱石）
  - `wheat`（小麦）
  - `cotton`（綿花）
- [ ] 距離帯計算関数 `calculate_distance_band(pos: Vector2i, base_pos: Vector2i) -> String`
  - マンハッタン距離 = `abs(pos.x - base_pos.x) + abs(pos.y - base_pos.y)`
  - 0〜4 → `"near"`
  - 5〜10 → `"mid"`
  - 11以上 → `"far"`
- [ ] 距離帯別の資源値レンジ生成関数 `generate_resource_value(distance_band: String) -> int`
  - `near`: 1〜3
  - `mid`: 1〜4
  - `far`: 2〜5
- [ ] 単一資源パネル生成（1パネル＝1資源タイプ）
- [ ] 複合資源パネル生成（1パネル＝2〜3資源タイプ）
- [ ] 特殊タグ保持（"spice" / "sulfur" / "none"。本Sprintでは保持のみ。効果はSprint 2以降）
- [ ] 地形タイプ6種の保持（"grassland" / "forest" / "rocky" / "desert" / "wetland" / "wasteland"。本Sprintでは保持のみ）
- [ ] 初期保証ロジック `apply_initial_guarantee(panels: Array)`
  - 距離4以内（`near`帯）に以下を最低1枚ずつ保証
    - 木（wood）2以上の単一パネル 1枚
    - 石（stone）2以上の単一パネル 1枚
    - 小麦（wheat）2以上の単一パネル 1枚
    - 複合資源パネル 1枚
- [ ] 土地パネル生成のエントリ関数 `generate_initial_land_panels() -> Array`
  - 全マスをループして各マスに土地パネルを生成
  - 自拠点座標 `(2, 7)` には土地パネルを配置しない（または基地パネル扱い）
  - 初期保証ロジックを最後に適用

### 完了条件

1. 26×13 = 338マス分の盤面データが保持される
2. 自拠点が `col=2, row=7` に配置される
3. 6種通常資源が定数として定義されている
4. マンハッタン距離による距離帯判定が機能する（0-4=near, 5-10=mid, 11+=far）
5. 距離帯ごとに資源値レンジが正しく適用される
6. 単一資源パネル・複合資源パネルが両方生成される
7. 特殊タグ（spice/sulfur）が一定確率で付与され、データ構造として保持される
8. 地形タイプ6種が一定確率で付与され、データ構造として保持される
9. 初期保証ロジックにより、距離4以内に4種類のパネルが必ず存在する
10. ゲーム起動時にパネル生成ログが出力される（位置・距離・距離帯・資源・タグ・地形）
11. check_syntax.sh エラー0件

### 制約・注意事項

- 本Sprintでは「データ構造の生成・保持のみ」。建物との接続・消費判定は Sprint 2 以降
- 特殊タグ・地形タイプは保持するのみで、ゲーム効果は Sprint 2 以降に実装
- 既存の `EconGrid` 内部配列・フィールドへの直接代入は禁止（CLAUDE.md 疎結合ルール）。新規メソッドを追加して経由する
- 自拠点位置 `(2, 7)` は定数化する（`const BASE_INITIAL_POS := Vector2i(2, 7)`）

---

## 4. 資源値開示・初期化・配置ルール

参照企画書:
- sprint_plan_updated_with_land_panel.md（資源値開示ルール追記分）
- sprint1_land_panel_base_design.md

### 4.1 資源値開示ルール

- 各土地パネルに開示状態フラグ `revealed: bool` を保持する（初期値 `false`）
- 自建物（自拠点・配置済み建物）から **マンハッタン距離3以内** のパネルは資源値を開示
  - 開示判定式：`abs(pos.x - building.pos.x) + abs(pos.y - building.pos.y) <= 3`
- 一度 `revealed = true` に遷移したら **永続的に表示** し、`hidden` への逆遷移は不可
- 建物が破壊されても、その建物によって開示済みになったパネルは開示状態を保持する

#### データ構造拡張

土地パネル1枚あたりのデータ構造（§3で定義済み）に以下を追加：

| フィールド | 型 | 初期値 | 用途 |
|---|---|---|---|
| `revealed` | bool | false | 資源値開示状態（一度trueになったら不可逆） |

### 4.2 初期化範囲

- ゲーム開始時、自拠点 `(col=2, row=7)` から **マンハッタン距離3以内** のパネルを `revealed = true` に設定
- 初期化処理は `generate_initial_land_panels()` の末尾、もしくは別関数 `apply_initial_reveal(panels: Array, base_pos: Vector2i)` で実施

#### 処理擬似コード

```gdscript
func apply_initial_reveal(panels: Array, base_pos: Vector2i) -> void:
    for panel in panels:
        var dist: int = abs(panel.pos.x - base_pos.x) + abs(panel.pos.y - base_pos.y)
        if dist <= 3:
            panel.revealed = true
```

### 4.3 建物配置ルール

建物配置可能条件は以下の **AND条件**：

1. **自建物隣接**：自拠点または配置済み建物の上下左右4方向のいずれかに隣接（既存ルール）
2. **資源値開示済み**：配置先パネルの `revealed == true`（新規追加）

- いずれか一方でも満たさなければ配置不可
- 隣接判定式：`(abs(dx) + abs(dy) == 1)` で4方向のいずれかに自建物がある
- 配置時に新たな建物が生まれたら、その建物から距離3以内のパネルを `revealed = true` へ遷移させる（建物増加に伴う段階的開示）

#### 配置判定関数（要件）

```gdscript
func can_place_building(target_pos: Vector2i) -> bool:
    var panel: Dictionary = get_panel_at(target_pos)
    if not panel.get("revealed", false):
        return false  # 未開示パネルには配置不可
    if not is_adjacent_to_own_building(target_pos):
        return false  # 自建物隣接でなければ配置不可
    return true
```

### 4.4 UI表示ルール

- 資源値未開示パネル（`revealed == false`）のUI表示は **「?」** とする
  - 資源タイプ・資源値・特殊タグ・地形タイプはすべて「?」で隠す
- 資源値開示済みパネル（`revealed == true`）は通常通り資源値を表示
- 開示状態の遷移時にUI更新シグナルを発火（描画キャッシュの再構築用）

### 4.5 完了条件

- [ ] 土地パネルに `revealed: bool` フィールドが追加されている（初期値 false）
- [ ] ゲーム開始時、自拠点(col=2, row=7)から距離3以内のパネルが `revealed = true` に初期化される
- [ ] 建物配置時に「自建物隣接」AND「資源値開示済み」の両条件を満たすパネルのみ配置可能
- [ ] 建物配置後、その建物から距離3以内のパネルが `revealed = true` へ遷移する
- [ ] 一度 `revealed = true` になったパネルは `false` へ戻らない（建物破壊時も維持）
- [ ] 未開示パネルのUI表示が「?」となる
- [ ] 開示済みパネルのUI表示は通常通り資源値・タグ・地形が表示される
- [ ] check_syntax.sh エラー0件

### 4.6 制約・注意事項

- 「マンハッタン距離」は §3 の `calculate_distance_band` と同じ式（`abs(dx) + abs(dy)`）を使用
- 開示処理は建物配置／自拠点初期化の2つのトリガーから呼び出される共通関数として実装すること
- 既存の `EconGrid` 内部配列・フィールドへの直接代入は禁止（CLAUDE.md 疎結合ルール）。`reveal_panels_around(pos: Vector2i, radius: int)` 等のメソッドを経由する
- Sprint 2以降の建物（農村・食堂・製粉所等）の配置にも本ルールが適用される
