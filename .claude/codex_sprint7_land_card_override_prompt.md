# Codex Sprint 7 実装タスク：土地カード報酬の上書き型改修

## 背景

現在の土地カード配置ロジックが「隣接する空きマスへの新規追加」で実装されていますが、Sprint 1 により全盤面（338マス）が既に land_panels に登録済みのため、空きマスが存在しません。

仕様変更：土地カードは「既存パネルの改造カード」として再定義します。

参照：`docs/requirements/req_econ_initial_deck_sprint7.md` §3（更新済み）

---

## 実装対象

### ファイル：EconGrid.gd

#### 1. 新規追加：上書き可能セル取得API

```gdscript
func get_all_overwritable_cells_for_land() -> Array:
	"""
	既存の land_panels キーから自拠点を除いたすべてのセルを返す。
	土地カード上書き対象の候補リスト。
	"""
	var cells: Array = []
	for pos in land_panels.keys():
		if pos == BASE_INITIAL_POS:
			continue
		cells.append(pos)
	return cells
```

#### 2. 修正：土地カード上書き処理

既存の `place_land_card(card: Dictionary, target_pos: Vector2i) -> bool` を以下に置換：

```gdscript
func place_land_card(card: Dictionary, target_pos: Vector2i) -> bool:
	"""
	既存の土地パネルを上書きする。
	
	Args:
		card: 上書きに使用する土地カード（panel_data フィールド含む）
		target_pos: 対象座標（Vector2i）
	
	Returns:
		成功時 true、失敗時 false
	
	仕様：
	- target_pos が盤面範囲外の場合：false を返す
	- target_pos が自拠点の場合：false を返す
	- target_pos が land_panels に未登録の場合：false を返す
	- 上書き対象フィールド：resources, special_tag, terrain_type, category
	- 保持フィールド：pos, distance_band
	"""
	# 盤面範囲チェック
	if not is_within_bounds(target_pos):
		return false
	
	# 自拠点除外
	if target_pos == BASE_INITIAL_POS:
		return false
	
	# パネル存在チェック
	if not land_panels.has(target_pos):
		return false
	
	# 上書き対象データの取得
	var panel_data: Dictionary = card.get("panel_data", {})
	var existing: Dictionary = land_panels[target_pos]
	
	# 上書き実行：フィールド指定
	land_panels[target_pos] = {
		"pos": target_pos,  # 保持：対象座標
		"resources": panel_data.get("resources", {}).duplicate(true),
		"special_tag": panel_data.get("special_tag", "none"),
		"terrain_type": panel_data.get("terrain_type", existing.get("terrain_type", "grassland")),
		"category": "composite" if panel_data.get("resources", {}).size() > 1 else "single",
		"distance_band": existing.get("distance_band", calculate_distance_band(target_pos)),  # 保持：既存値 or 再計算
	}
	
	print("[EconGrid] 土地カード上書き: %s → resources=%s, special_tag=%s, terrain_type=%s" % [
		str(target_pos),
		str(panel_data.get("resources", {})),
		panel_data.get("special_tag", "none"),
		panel_data.get("terrain_type", "")
	])
	
	queue_redraw()
	return true
```

#### 3. 既存APIの扱い（互換性保持）

以下のAPIは「新規追加前提」のため、使用していないことを確認して、必要に応じてコメント化またはドキュメント上「未使用」と明記：

```gdscript
# 以下は廃止予定（土地カード報酬では使用しない）
# func get_adjacent_empty_cells(pos: Vector2i) -> Array:
# func get_all_placeable_cells_for_land() -> Array:
```

必要に応じて削除または `@deprecated` コメントを追加してください。

---

## 実装検証チェックリスト

実装完了後、以下を確認してください：

- [ ] `get_all_overwritable_cells_for_land()` が land_panels.keys() から自拠点を除いた Array を返す
- [ ] `place_land_card()` が既存パネルを上書きできる（resources/special_tag/terrain_type/category）
- [ ] 上書き後、pos と distance_band は対象座標の既存値を保持
- [ ] 上書き後、[EconGrid] ログが出力される
- [ ] 自拠点パネル上書きが false で拒否される
- [ ] 盤面範囲外座標が false で拒否される
- [ ] 土地カード上書き後、食堂（DINER）の has_spice_tag() や製粉所（MILL）の get_panel_wheat_value() が上書き後の値を正しく参照できる
- [ ] `bash check_syntax.sh` エラー0件

---

## 実装完了後の作業

1. **構文チェック実行**
   ```bash
   bash check_syntax.sh
   ```
   エラーが0件であることを確認してください。

2. **ログ確認**
   ゲーム実行時に以下のログが出力されることを確認：
   ```
   [EconGrid] 土地カード上写き: (3, 5) → resources={...}, special_tag=..., terrain_type=...
   ```

3. **完了報告**
   以下を含めてください：
   - 変更ファイル：EconGrid.gd
   - 変更内容：place_land_card()、get_all_overwritable_cells_for_land() 追加
   - check_syntax.sh 結果：エラー0件
   - その他修正内容（互換APIの扱い等）
