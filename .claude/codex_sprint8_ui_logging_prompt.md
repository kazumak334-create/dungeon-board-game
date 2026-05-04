# Codex Sprint 8 実装タスク：UI・ログ・デバッグ表示

## 背景

Sprint 8では、以下を実装します：

1. **都市ステータスUI（EconUI）** — 人口・食料・満足値等をHUDに表示
2. **イベントログ** — POP_CHANGE / SAT_SLOPE / POP_LOSS / LAND_PANEL_GEN / LAND_CARD_REWARD をLogManagerに出力
3. **土地パネルUI** — 盤面上に資源・タグ・地形を視覚化

参照：`docs/requirements/req_econ_logging_ui_sprint8.md`

---

## 実装対象

### 1. EconUI.gd（新規作成）

**ファイル：** `scripts/econ_mvp/EconUI.gd`

```gdscript
class_name EconUI
extends Control

var economy: EconEconomy = null

var _refresh_timer: float = 0.0
const REFRESH_INTERVAL: float = 0.5

# 8つのステータスラベル（動的生成）
var label_pop: Label
var label_food: Label
var label_shortage: Label
var label_sat: Label
var label_slope: Label
var label_stage: Label
var label_mil: Label
var label_eff: Label

func _ready() -> void:
	# VBoxContainer を作成
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)
	
	# 8つのラベルを動的生成
	label_pop = _create_label("人口")
	label_food = _create_label("食料値")
	label_shortage = _create_label("食料不足")
	label_sat = _create_label("満足値")
	label_slope = _create_label("傾き")
	label_stage = _create_label("段階")
	label_mil = _create_label("兵力")
	label_eff = _create_label("建物効率")
	
	for label in [label_pop, label_food, label_shortage, label_sat, label_slope, label_stage, label_mil, label_eff]:
		vbox.add_child(label)

func _create_label(prefix: String) -> Label:
	var label := Label.new()
	label.text = "%s: --" % prefix
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", 12)
	return label

func _process(delta: float) -> void:
	_refresh_timer += delta
	if _refresh_timer < REFRESH_INTERVAL:
		return
	_refresh_timer = 0.0
	update_status_display()

func update_status_display() -> void:
	if economy == null:
		return
	
	label_pop.text = "人口: %d / %d (内部 %.2f)" % [economy.get_display_population(), economy.population_cap, economy.population_float]
	label_food.text = "食料値: %d" % economy.food_value
	label_shortage.text = "食料不足: %d" % economy.food_shortage_count
	label_sat.text = "満足値: %.1f%%" % economy.satisfaction_value
	label_slope.text = "傾き: %+.2f%%/秒" % economy.satisfaction_slope
	label_stage.text = "段階: %s" % economy.get_satisfaction_stage()
	label_mil.text = "兵力: %.1f" % economy.military_power
	label_eff.text = "建物効率: ×%.2f" % economy.building_efficiency_modifier
```

**配置：** EconMain._ready() で以下を追加：

```gdscript
var econ_ui: EconUI = EconUI.new()
econ_ui.economy = _economy
econ_ui.position = Vector2(20, 20)
add_child(econ_ui)
```

---

### 2. LogManager 拡張

**ファイル：** `scripts/econ_mvp/LogManager.gd`

#### 変更内容

`_should_log()` 内で、新イベントタイプが DEBUG レベルで出力されるよう既存ロジックを確認：

```gdscript
func _should_log(event_type: String) -> bool:
	if not log_enabled:
		return false
	var basic_types := ["SNAPSHOT", "BATTLE_SUMMARY", "ANALYSIS_METRICS"]
	if log_level == "BASIC":
		return event_type in basic_types
	var verbose_types := ["RESOURCE_TICK", "HAPPINESS_TICK", "BUILDING_OPERATION", "SMITHY_EFFECT", "UI_ACTION"]
	if log_level == "DEBUG":
		return not (event_type in verbose_types)
	return true
```

**注：** `POP_CHANGE`, `SAT_SLOPE`, `POP_LOSS`, `LAND_PANEL_GEN`, `LAND_CARD_REWARD` は verbose_types に含めない → DEBUG レベルで出力される

---

### 3. EconEconomy 拡張

**ファイル：** `scripts/econ_mvp/EconEconomy.gd`

#### 3-1. update() メソッドの5秒tick末尾に以下を追加：

```gdscript
# 5秒tickの末尾（_tick_index % 10 == 0 の条件内）
if _tick_index % 10 == 0:
	# ログ出力：POP_CHANGE
	var growth_rate: float = _calculate_population_growth_rate()
	var decline_rate: float = _calculate_population_decline_rate()
	var decline_food: float = 0.04 if food_shortage_count > 0 else 0.0
	var decline_dissat: float = 0.04 if get_satisfaction_stage() == "dissatisfied" else 0.0
	var decline_decline_stage: float = 0.10 if get_satisfaction_stage() == "decline" else 0.0
	
	LogManager.log_event({
		"type": "POP_CHANGE",
		"time": _tick_index * TICK_INTERVAL,
		"population": population_float,
		"stage": get_satisfaction_stage(),
		"growth": growth_rate,
		"decline": decline_rate,
		"decline_food_shortage": decline_food,
		"decline_dissatisfied": decline_dissat,
		"decline_decline_stage": decline_decline_stage,
		"blocked_by_food": false,  # 今後実装
	})
	
	# ログ出力：SAT_SLOPE
	var breakdown: Dictionary = _get_satisfaction_slope_breakdown()
	LogManager.log_event({
		"type": "SAT_SLOPE",
		"time": _tick_index * TICK_INTERVAL,
		"satisfaction": satisfaction_value,
		"stage": get_satisfaction_stage(),
		"slope_total": satisfaction_slope,
		"base": breakdown.get("base", 0.0),
		"population_scale": breakdown.get("population_scale", 0.0),
		"population_growth": breakdown.get("population_growth", 0.0),
		"building": breakdown.get("building", 0.0),
		"food_shortage_penalty": breakdown.get("food_shortage_penalty", 0.0),
	})
```

#### 3-2. apply_charge_population_loss() / apply_defense_breakthrough_loss() メソッド内に POP_LOSS ログを追加：

```gdscript
# apply_charge_population_loss() 内
var before: float = population_float
# ...既存の population_float -= actual 処理...
LogManager.log_event({
	"type": "POP_LOSS",
	"time": _tick_index * TICK_INTERVAL,
	"cause": "charge",
	"loss": int(actual),
	"before": before,
	"after": population_float,
})

# apply_defense_breakthrough_loss() 内
var before: float = population_float
# ...既存の population_float -= actual 処理...
LogManager.log_event({
	"type": "POP_LOSS",
	"time": _tick_index * TICK_INTERVAL,
	"cause": "defense_breakthrough",
	"loss": int(actual),
	"before": before,
	"after": population_float,
})
```

#### 3-3. ヘルパー関数（既存か確認、ない場合は追加）

```gdscript
func _calculate_population_growth_rate() -> float:
	# 既存の成長計算式を関数化（現在のロジック確認）
	return 0.0  # 実装値を確認して代入

func _calculate_population_decline_rate() -> float:
	# 既存の減少計算式を関数化（現在のロジック確認）
	return 0.0  # 実装値を確認して代入

func _get_satisfaction_slope_breakdown() -> Dictionary:
	# 満足度傾きの5要因内訳を辞書で返す
	return {
		"base": 0.0,
		"population_scale": 0.0,
		"population_growth": 0.0,
		"building": 0.0,
		"food_shortage_penalty": 0.0,
	}
```

---

### 4. EconGrid 拡張

**ファイル：** `scripts/econ_mvp/EconGrid.gd`

#### generate_initial_land_panels() メソッド内で、各パネル生成時に LAND_PANEL_GEN ログを出力：

```gdscript
func generate_initial_land_panels() -> Array:
	land_panels.clear()
	_land_rng.seed = seed_value + 100
	var panels: Array = []
	base_panel_data = {
		"pos": BASE_INITIAL_POS,
		"resources": {},
		"special_tag": "none",
		"terrain_type": "grassland",
		"category": "base",
		"distance_band": "near",
	}
	for row in range(ROWS):
		for col in range(COLS):
			var pos := Vector2i(col, row)
			if pos == BASE_INITIAL_POS:
				continue
			var panel: Dictionary
			if _land_rng.randf() < 0.25:
				panel = generate_composite_resource_panel(pos)
			else:
				panel = generate_single_resource_panel(pos)
			panels.append(panel)
			land_panels[pos] = panel
			
			# ← ここで LAND_PANEL_GEN ログを出力
			var distance: int = absi(pos.x - BASE_INITIAL_POS.x) + absi(pos.y - BASE_INITIAL_POS.y)
			LogManager.log_event({
				"type": "LAND_PANEL_GEN",
				"pos": [pos.x, pos.y],
				"distance": distance,
				"distance_band": panel.get("distance_band", "unknown"),
				"category": panel.get("category", "unknown"),
				"resources": panel.get("resources", {}),
				"special_tag": panel.get("special_tag", "none"),
				"terrain_type": panel.get("terrain_type", "grassland"),
			})
	
	apply_initial_guarantee(panels)
	print("[EconGrid] land panels generated: panels=%d base=%s total_cells=%d" % [panels.size(), str(BASE_INITIAL_POS), panels.size() + 1])
	return panels
```

---

### 5. EconMain 拡張

**ファイル：** `scripts/econ_mvp/EconMain.gd`

#### 5-1. EconUI をシーンに追加：

_setup_econ_ui() メソッドを追加（または既存メソッドを拡張）：

```gdscript
func _setup_econ_ui() -> void:
	var econ_ui: EconUI = EconUI.new()
	econ_ui.economy = _economy
	econ_ui.position = Vector2(20, 20)
	add_child(econ_ui)
	print("[EconMain] EconUI added at (20, 20)")
```

_ready() メソッド内で呼び出し：

```gdscript
func _ready() -> void:
	_setup_grid()
	_setup_economy()
	_setup_battle()
	var vp := get_viewport().get_visible_rect().size
	const FOOTER_H := 180.0
	
	# UI を先に生成してHEADERの実際のサイズを取得
	_setup_ui(vp)
	_setup_econ_ui()  # ← 追加
	
	# ...以下既存ロジック...
```

#### 5-2. 土地カード報酬時に LAND_CARD_REWARD ログを出力：

土地カード報酬の発生箇所（place_land_card() 呼び出し後）で以下を追加：

```gdscript
# 土地カード配置時（配置成功後）
if _grid.place_land_card(selected_card, target_pos):
	LogManager.log_event({
		"type": "LAND_CARD_REWARD",
		"time": _tick_index * TICK_INTERVAL if has_method("_tick_index") else 0,
		"candidates": candidates,  # 3候補の配列
		"selected_index": selected_index,  # 選択された候補のindex（0-2）
		"placed_pos": [target_pos.x, target_pos.y],
	})
	print("[LandCardReward] 土地カード配置完了: %s" % str(target_pos))
```

---

## 実装検証チェックリスト

実装完了後、以下を確認してください：

**EconUI.gd：**
- [ ] EconUI クラスが新規作成される
- [ ] _ready() で 8つのラベルが動的生成される
- [ ] _process() で 0.5秒ごとに update_status_display() が呼ばれる
- [ ] 8つのステータス値が正しく表示される（人口/食料/満足度等）

**LogManager 拡張：**
- [ ] POP_CHANGE / SAT_SLOPE / POP_LOSS / LAND_PANEL_GEN / LAND_CARD_REWARD が `_should_log()` で許可される（DEBUG以上）
- [ ] ログファイル（user://logs/run_*.jsonl）にこれらのイベントが出力されることを確認（ゲーム実行後）

**EconEconomy 拡張：**
- [ ] update() 5秒tick末尾で POP_CHANGE / SAT_SLOPE が出力される
- [ ] apply_charge_population_loss() で POP_LOSS（cause=charge）が出力される
- [ ] apply_defense_breakthrough_loss() で POP_LOSS（cause=defense_breakthrough）が出力される
- [ ] _calculate_population_growth_rate() / _calculate_population_decline_rate() / _get_satisfaction_slope_breakdown() が実装されている

**EconGrid 拡張：**
- [ ] generate_initial_land_panels() で各パネルが LAND_PANEL_GEN ログを出力する
- [ ] ゲーム起動時にログファイルに約338行の LAND_PANEL_GEN イベントが記録される

**EconMain 拡張：**
- [ ] _setup_econ_ui() で EconUI がシーンに追加される
- [ ] EconUI が画面左上に表示される
- [ ] 土地カード配置時に LAND_CARD_REWARD ログが出力される

**全般：**
- [ ] `bash check_syntax.sh` エラー0件

---

## 実装完了後の作業

1. **構文チェック実行**
   ```bash
   bash check_syntax.sh
   ```
   エラーが0件であることを確認してください。

2. **ゲーム実行・画面確認**
   - EconUI が画面左上に表示されているか
   - ステータス値が0.5秒ごとに更新されるか
   - （ユーザーが最終確認）

3. **ログファイル確認**
   ゲーム実行後、以下を確認：
   ```bash
   tail -100 ~/.local/share/godot/app_userdata/EconMVP/logs/run_*.jsonl | grep "LAND_PANEL_GEN\|POP_CHANGE\|SAT_SLOPE"
   ```
   イベントが記録されていることを確認。

4. **完了報告**
   以下を含めてください：
   - 変更ファイル（EconUI.gd新規 + EconEconomy.gd + EconGrid.gd + EconMain.gd + LogManager.gd）
   - 変更内容（各ファイルの変更行番号）
   - check_syntax.sh 結果：エラー0件
   - その他修正内容
