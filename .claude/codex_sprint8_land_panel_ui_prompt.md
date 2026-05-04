# Codex Sprint 8 追加実装：土地パネルUI・LAND_CARD_REWARDログ

## 背景

Sprint 8 の要件定義書§4（土地パネルUI・ログ）の以下が未実装です：

1. **盤面上の土地パネル情報表示** - 資源アイコン・値・特殊タグ・地形タイプ
2. **土地パネル詳細UI** - ホバー/クリック時に詳細情報を表示
3. **LAND_CARD_REWARD ログ** - 土地カード報酬発生時にログ出力

参照：`docs/requirements/req_econ_logging_ui_sprint8.md` §4（313-413行）

---

## 実装対象

### 1. 盤面上の土地パネル情報表示（EconGrid._draw() 拡張）

**ファイル：** `scripts/econ_mvp/EconGrid.gd`

#### 実装方針

_draw() メソッド内（各六角形セル描画時）に、以下を追加：

```gdscript
func _draw() -> void:
	for row in range(ROWS):
		var col_count := get_col_count(row)
		for col in range(col_count):
			var pos := Vector2i(col, row)
			var center := hex_to_pixel(col, row)
			var corners := _get_hex_corners(center)
			
			# 既存の resource_cells / tile_cells 描画...（変更なし）
			
			# ← ここから追加：土地パネル情報の描画
			if land_panels.has(pos):
				var panel: Dictionary = land_panels[pos]
				var resources: Dictionary = panel.get("resources", {})
				var special_tag: String = str(panel.get("special_tag", "none"))
				
				# 資源アイコン・値を描画（複合資源対応）
				var resource_list: Array = resources.keys()
				if resource_list.size() > 0:
					_draw_resource_icons(center, resource_list, resources)
				
				# 特殊タグマーク（香辛料：黄色マーク）
				if special_tag == "spice":
					_draw_spice_tag_mark(center)
```

#### ヘルパー関数の追加

```gdscript
func _draw_resource_icons(center: Vector2, resource_types: Array, resource_values: Dictionary) -> void:
	"""
	複合資源に対応した資源アイコン・値の描画。
	- 単一資源：中央に大きく表示
	- 複合資源：左右に並べて表示
	"""
	var icon_size := 12.0
	var font_size := 10
	
	if resource_types.size() == 1:
		# 単一資源：中央に表示
		var res_type: String = str(resource_types[0])
		var res_value: int = int(resource_values.get(res_type, 0))
		var icon_color: Color = _get_resource_color(res_type)
		var icon_pos: Vector2 = center + Vector2(-8, 0)
		
		# アイコン（小さい円）
		draw_circle(icon_pos, icon_size * 0.5, icon_color)
		
		# 値（テキスト）
		var value_pos: Vector2 = center + Vector2(8, 4)
		draw_string(ThemeDB.fallback_font, value_pos, str(res_value), HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)
	else:
		# 複合資源：左右に分割
		for i in range(resource_types.size()):
			var res_type: String = str(resource_types[i])
			var res_value: int = int(resource_values.get(res_type, 0))
			var icon_color: Color = _get_resource_color(res_type)
			var offset_x: float = -6.0 + (i * 12.0)
			var icon_pos: Vector2 = center + Vector2(offset_x, -4)
			var value_pos: Vector2 = center + Vector2(offset_x, 6)
			
			# アイコン
			draw_circle(icon_pos, icon_size * 0.4, icon_color)
			
			# 値
			draw_string(ThemeDB.fallback_font, value_pos, str(res_value), HORIZONTAL_ALIGNMENT_CENTER, -1, 8, Color.WHITE)

func _get_resource_color(resource_type: String) -> Color:
	match str(resource_type):
		"wood":
			return Color8(63, 82, 50)
		"resin":
			return Color8(154, 138, 60)
		"stone":
			return Color8(93, 86, 78)
		"iron":
			return Color8(80, 65, 55)
		"wheat":
			return Color8(169, 146, 80)
		"cotton":
			return Color8(240, 235, 220)
		_:
			return Color.WHITE

func _draw_spice_tag_mark(center: Vector2) -> void:
	"""
	香辛料タグを黄色マークで表示（六角形の上部コーナー）。
	"""
	var mark_pos: Vector2 = center + Vector2(0, -HEX_SIZE * 0.7)
	draw_circle(mark_pos, 4.0, Color("#FFD700"))  # 黄色
	draw_circle(mark_pos, 4.0, Color.WHITE, false, 1.0)  # 白枠
```

---

### 2. 土地パネル詳細UI（新規 or EconGridUI）

**ファイル：** `scripts/econ_mvp/EconLandPanelDetailUI.gd`（新規作成）

#### シンプル実装（MVP方針）

詳細UI表示は「後続Sprint」として一旦スキップし、代わりに以下を実装：

**代替案：デバッグ出力**
クリック時に詳細情報をコンソールに出力（ユーザーが print で確認可能）

```gdscript
# EconGrid.gd に _input() メソッド追加
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mouse_pos: Vector2 = get_local_mouse_position()
		var clicked_pos: Vector2i = _pixel_to_grid_pos(mouse_pos)
		if land_panels.has(clicked_pos):
			var panel: Dictionary = land_panels[clicked_pos]
			print("[LandPanelDetail] クリック座標: %s" % str(clicked_pos))
			print("  距離: %d" % _calculate_manhattan_distance(clicked_pos))
			print("  距離帯: %s" % panel.get("distance_band", "unknown"))
			print("  カテゴリ: %s" % panel.get("category", "unknown"))
			print("  資源: %s" % str(panel.get("resources", {})))
			print("  特殊タグ: %s" % panel.get("special_tag", "none"))
			print("  地形: %s" % panel.get("terrain_type", "grassland"))
```

**注：** 本格的なUI詳細表示は Sprint 8.5 以降とする（MVP スコープ外）

---

### 3. LAND_CARD_REWARD ログ出力

**ファイル：** `scripts/econ_mvp/EconMain.gd`

#### 土地カード配置時にログを出力

土地カード報酬が「実際に発生する」箇所で以下を追加：

```gdscript
# 土地カード3択選択 → 配置の流れを実装している箇所で：
# 例：generate_land_card_candidates() を呼んで、ユーザー選択後に place_land_card() を実行する箇所

func _apply_land_card_reward(candidates: Array, selected_index: int, target_pos: Vector2i) -> void:
	"""
	土地カード報酬を適用し、ログを出力する。
	"""
	if selected_index < 0 or selected_index >= candidates.size():
		return
	
	var selected_card: Dictionary = candidates[selected_index]
	
	# 土地カード配置
	if _grid.place_land_card(selected_card, target_pos):
		# LAND_CARD_REWARD ログ出力
		LogManager.log_event({
			"type": "LAND_CARD_REWARD",
			"time": _get_battle_time(),
			"candidates": candidates,
			"selected_index": selected_index,
			"placed_pos": [target_pos.x, target_pos.y],
		})
		print("[LandCardReward] 土地カード配置完了: 座標(%d,%d)" % [target_pos.x, target_pos.y])
	else:
		push_error("[LandCardReward] 土地カード配置失敗: 座標(%d,%d)" % [target_pos.x, target_pos.y])

func _get_battle_time() -> float:
	"""
	戦闘時間を取得（EconEconomyの_tick_indexを利用）。
	"""
	if _economy == null:
		return 0.0
	# _tick_indexが外部からアクセス可能か確認し、不可の場合は別の時間ソースを使用
	return float(_economy._tick_index) * _economy.TICK_INTERVAL if _economy.has_method("_tick_index") else 0.0
```

**注：** 土地カード報酬が「実際に発生する」シーンは実装によって異なります。
- どこで土地カード3択が表示されるのか
- どこでユーザーが選択するのか
- どこで配置が確定するのか

これらが未実装の場合は、以下を実装する必要があります：
- UI フロー：報酬発生 → 3択表示 → ユーザー選択 → 配置
- Codex に別途プロンプトを送信して実装

---

## 実装検証チェックリスト

**盤面表示：**
- [ ] EconGrid._draw() で土地パネルの資源アイコン・値が表示される
- [ ] 単一資源パネルでは大きく表示される
- [ ] 複合資源パネルでは複数アイコンが並べて表示される
- [ ] 香辛料タグが黄色マークで表示される

**詳細情報（デバッグ出力）：**
- [ ] パネルをクリックすると console に詳細情報が出力される
- [ ] 座標・距離・距離帯・カテゴリ・資源値・特殊タグ・地形が含まれる

**LAND_CARD_REWARD ログ：**
- [ ] 土地カード配置時に LAND_CARD_REWARD イベントが出力される
- [ ] candidates・selected_index・placed_pos が含まれる
- [ ] ログファイル（user://logs/run_*.jsonl）に記録される

**全般：**
- [ ] `bash check_syntax.sh` エラー0件

---

## 注意事項

### 土地パネルUI描画の制限

現在の実装では `ThemeDB.fallback_font` を使用しているため、フォント表示にやや制限があります。本格的なテキスト描画は後続Sprintで改善可能。

### 土地カード報酬フロー未実装

LAND_CARD_REWARD ログは「報酬発生時」に出力する必要がありますが、現在のEconMainに「土地カード報酬を発生させるロジック」そのものがない可能性があります。

確認事項：
- [ ] EconMain に「土地カード3択を表示する」UIロジックがあるか
- [ ] 「ユーザーが選択する」流れがあるか
- [ ] 「選択後に place_land_card() を呼ぶ」流れがあるか

これらが未実装の場合は、別途Codexプロンプトが必要です。

---

## 完了報告テンプレート

実装完了時は以下を報告：

```
変更ファイル：
- EconGrid.gd: _draw() 拡張、_draw_resource_icons()、_get_resource_color()、_draw_spice_tag_mark()、_input()、_pixel_to_grid_pos()、_calculate_manhattan_distance()

追加ファイル：
- なし

変更行番号：
- EconGrid.gd: [行番号範囲]
- EconMain.gd: [土地カード配置時のログ出力箇所]

check_syntax.sh 結果：
- ✅ エラー0件

その他：
- [実装時の判断・修正内容がある場合は記述]
```
