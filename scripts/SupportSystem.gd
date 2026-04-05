# SupportSystem.gd
# サポート効果再計算・召喚時効果・永久アーティファクト効果
extends RefCounted

var bm: Node = null

func setup(board_manager: Node) -> void:
	bm = board_manager

func apply_support_effects() -> void:
	# ボーナスをリセット
	for s in range(2):
		for r in range(3):
			for c in range(3):
				var u = bm.board[s][r][c]
				if u != null:
					u._atk_bonus = 0
					u._interval_bonus = 0.0
					u._regen = 0.0
					u._can_attack_from_back = false
					u._can_attack_from_mid = false
					u._back_atk_factor = 1.0
					u._back_target_rear = false
					u._back_no_on_hit = false
					u._damage_reduction = 0
					u._has_lifesteal = u.lifesteal_stacks > 0
					u._has_penetrate = false
					u._has_impact = false
					u._has_big_penetrate = false
					u._is_flying = false
					# _regen_stacks はリセットしない（スタック+時間減少方式）
					u._support_revive = false
	# 各ユニットのサポート効果を適用（旧方式：support_effect文字列）
	for s in range(2):
		for r in range(3):
			for c in range(3):
				var u = bm.board[s][r][c]
				if u != null:
					_process_unit_support(s, r, c, u)
	# skills配列のtrigger=="always"を処理（新方式）
	# サポート効果は前列以外でのみ発動（原則）
	if bm.effect_executor != null:
		for s in range(2):
			var front_col: int = 2 if s == 0 else 0
			for r in range(3):
				for c in range(3):
					var u = bm.board[s][r][c]
					if u == null:
						continue
					for skill in u.skills:
						if skill.get("trigger", "") == "always":
							# 前列チェック: skill_flagはスキル（位置無関係）なので除外
							var _eid_check = skill.get("effect_id", "")
							var _EDB_check = load("res://scripts/EffectDB.gd")
							var _is_skill = _EDB_check.EFFECTS.get(_eid_check, {}).get("type", "") == "skill_flag"
							if c == front_col and not _is_skill:
								continue
							# skillsのtop-level targetをparamsにマージ
							var merged_params: Dictionary = skill.get("params", {}).duplicate()
							if skill.has("target"):
								merged_params["target"] = skill["target"]
							bm.effect_executor.execute(skill["effect_id"], merged_params, {
								"trigger": "always", "side": s, "row": r, "col": c,
								"source": u, "target": null, "damage": 0,
								"board_manager": bm, "deck_manager": bm.deck_manager_ref, "enemy_ai": bm.enemy_ai_ref,
								"event_queue": bm.event_queue
							})
	# アーティファクトのalwaysスキル処理（位置無関係）
	if bm.effect_executor != null:
		for s in range(2):
			for r in range(3):
				for c in range(3):
					var art = bm.board_artifacts[s][r][c]
					if art == null:
						continue
					for skill in art.get("skills", []):
						if skill.get("trigger", "") == "always":
							var _merged_art: Dictionary = skill.get("params", {}).duplicate()
							if skill.has("target"):
								_merged_art["target"] = skill["target"]
							bm._execute_artifact_skill(s, r, c, art, skill["effect_id"], _merged_art)
	# 永久効果型アーティファクトのalwaysスキル（front_ally_all ATKバフ）
	_apply_permanent_artifact_effects()
	# 盤面効果 on_stay: 獣の森等のATKボーナス
	var _EDB_stay = load("res://scripts/EffectDB.gd")
	for s in range(2):
		for r in range(3):
			for c in range(3):
				var u = bm.board[s][r][c]
				var te_stay = bm.board_effects[s][r][c]
				if u != null and te_stay != null and not u.get("_is_flying") == true:
					var tile_def_stay = _EDB_stay.EFFECTS.get(te_stay["effect_id"], {})
					if tile_def_stay.has("atk_bonus") and (not tile_def_stay.has("race") or u.race == tile_def_stay["race"]):
						u._atk_bonus += tile_def_stay["atk_bonus"]
	# アクティブスキル由来のバフ + ATKバフ上限適用
	for s in range(2):
		for r in range(3):
			for c in range(3):
				var u = bm.board[s][r][c]
				if u == null:
					continue
				# アクティブスキル文字列に吸血があれば常時スタック維持
				if "吸血" in u.active_skill and u.lifesteal_stacks < 5:
					u.lifesteal_stacks = 5
				u._has_lifesteal = u.lifesteal_stacks > 0
				# 貫通はスキル（ON/OFF）のためスタック処理なし
				# バフ奪取で得た永続ボーナスを加算
				u._atk_bonus += u._stolen_atk
				u._interval_bonus += u._stolen_spd
				if u._stolen_lifesteal: u.lifesteal_stacks = max(u.lifesteal_stacks, 5)
				# _regen_stacksはスタック+時間減少方式のため_stolen_regenは直接加算済み
				u._damage_reduction += u._stolen_armor
				u._atk_bonus = min(u._atk_bonus, 10)  # ATKバフ重複上限+10

func _process_unit_support(side: int, row: int, col: int, unit: Object) -> void:
	var front_col: int = 2 if side == 0 else 0
	if col == front_col:
		return
	for entry in unit.support_effect.split(" / "):
		if "常時発動" not in entry:
			continue
		# 狙撃：後列のみ、敵最後列優先、命中時アクティブ発動なし
		if "狙撃" in entry:
			unit._can_attack_from_back = true
			unit._back_atk_factor = 0.3 if "極低ATK" in entry else 1.0
			unit._back_target_rear = true
			unit._back_no_on_hit = true
			continue
		# 支援攻撃：後列+中列から発動
		if "支援攻撃" in entry:
			unit._can_attack_from_back = true
			unit._can_attack_from_mid = true
			unit._back_atk_factor = 0.3 if "極低ATK" in entry else 1.0
			if "命中時アクティブ発動なし" in entry or "命中時アクティブは発動しない" in entry:
				unit._back_no_on_hit = true
			continue
		# 後列攻撃（後方互換）
		if "後列攻撃" in entry:
			unit._can_attack_from_back = true
			unit._back_atk_factor = 0.3 if "極低ATK" in entry else 1.0
			if "最後列優先" in entry:
				unit._back_target_rear = true
			if "命中時アクティブ発動なし" in entry or "命中時アクティブは発動しない" in entry:
				unit._back_no_on_hit = true
			continue
		# 〈〉内のターゲット記述を取得
		var bs: int = entry.find("〈")
		var be: int = entry.find("〉")
		if bs == -1 or be == -1:
			continue
		var parts: Array = entry.substr(bs + 1, be - bs - 1).split("・")
		var target_desc: String = parts[1] if parts.size() > 1 else ""
		var targets: Array = _get_support_targets(side, row, col, target_desc)
		if "ATKバフ" in entry:
			for t in targets:
				t._atk_bonus += 2
		elif "SPDバフ" in entry:
			for t in targets:
				t._interval_bonus += 0.3
		elif "HPバフ" in entry:
			for t in targets:
				t._regen += 1.0
		elif "障壁付与" in entry:
			for t in targets:
				t._damage_reduction += 1
		elif "吸血付与" in entry:
			for t in targets:
				t.lifesteal_stacks = max(t.lifesteal_stacks, 5)
		elif "貫通付与" in entry:
			for t in targets:
				t._has_penetrate = true  # スキル方式（ON/OFF）
		elif "リジェネ付与" in entry:
			for t in targets:
				t._regen += 1.0  # サポート由来は_regen（毎秒HP回復・リセット再計算型）
		elif "スライム全体強化" in entry or ("スライム全体" in entry and "攻撃" in entry):
			# キングスライム：自軍スライム全体のATK+50%, HP+50%
			for r2 in range(3):
				for c2 in range(3):
					var ally = bm.board[side][r2][c2]
					if ally != null and ally.race == "スライム" and ally != unit:
						ally._atk_bonus += max(1, ally.attack / 2)
		elif "再起付与" in entry:
			for t in targets:
				if not t._support_revive_used:
					t._support_revive = true
		elif "デバフ波及" in entry:
			pass  # デバフ波及はフラグ不要：撃破時に_process_debuff_spreadで処理

func _get_support_targets(side: int, row: int, col: int, target_desc: String) -> Array:
	var positions: Array = []
	if "隣接" in target_desc:
		for d in [[-1, 0], [1, 0], [0, -1], [0, 1]]:
			var r2: int = row + d[0]
			var c2: int = col + d[1]
			if r2 >= 0 and r2 < 3 and c2 >= 0 and c2 < 3:
				positions.append([r2, c2])
	elif "同行前列" in target_desc:
		var front: int = 2 if side == 0 else 0
		positions.append([row, front])
	elif "前列" in target_desc:
		var front: int = 2 if side == 0 else 0
		for r2 in range(3):
			positions.append([r2, front])
	elif "同行" in target_desc:
		for c2 in range(3):
			if c2 != col:
				positions.append([row, c2])
	elif "同列" in target_desc:
		for r2 in range(3):
			if r2 != row:
				positions.append([r2, col])
	elif "全体" in target_desc:
		for r2 in range(3):
			for c2 in range(3):
				if not (r2 == row and c2 == col):
					positions.append([r2, c2])
	# 種族フィルタ
	var race_filter: String = ""
	for race in ["獣", "スライム", "アンデッド"]:
		if race in target_desc:
			race_filter = race
			break
	var result: Array = []
	for pos in positions:
		var u = bm.board[side][pos[0]][pos[1]]
		if u == null:
			continue
		if race_filter != "" and u.race != race_filter:
			continue
		result.append(u)
	return result

func push_summon_effects(side: int, row: int, col: int, unit: Object) -> void:
	if bm.event_queue == null:
		return
	# skills配列のon_summon処理（新方式）
	if bm.effect_executor != null:
		for skill in unit.skills:
			if skill.get("trigger", "") == "on_summon":
				var _mp: Dictionary = skill.get("params", {}).duplicate()
				if skill.has("target"): _mp["target"] = skill["target"]
				bm.effect_executor.execute(skill["effect_id"], _mp, {
					"trigger": "on_summon", "side": side, "row": row, "col": col,
					"source": unit, "target": null, "damage": 0,
					"board_manager": bm, "deck_manager": bm.deck_manager_ref, "enemy_ai": bm.enemy_ai_ref,
					"event_queue": bm.event_queue
				})
	# 旧方式（active_skill文字列パース）は削除済み。全てskills配列で処理。

func _apply_permanent_artifact_effects() -> void:
	# 永久効果型アーティファクト（player_artifacts / enemy_artifacts）のalwaysスキルを適用
	var artifact_lists: Array = [bm.player_artifacts, bm.enemy_artifacts]
	for s in range(2):
		for art_entry in artifact_lists[s]:
			if not (art_entry is Dictionary):
				continue
			for skill in art_entry.get("skills", []):
				if skill.get("trigger", "") != "always":
					continue
				var _mp_perm: Dictionary = skill.get("params", {}).duplicate()
				if skill.has("target"):
					_mp_perm["target"] = skill["target"]
				var eid: String = skill.get("effect_id", "")
				if bm.effect_executor != null:
					bm.effect_executor.execute(eid, _mp_perm, {
						"trigger": "always", "side": s, "row": 0, "col": 0,
						"source": null, "target": null, "damage": 0,
						"board_manager": bm, "deck_manager": bm.deck_manager_ref, "enemy_ai": bm.enemy_ai_ref,
						"event_queue": bm.event_queue
					})
