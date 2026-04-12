# TileEffectManager.gd
# 警戒レベルに応じた盤面効果付与
class_name TileEffectManager
extends RefCounted

# 警戒レベルLv1+: 敵前列ランダムマスにアーマー付与
# 警戒レベルLv2+: Lv1 + プレイヤー側に棘/呪いマスランダム配置
func apply_alert_tile_effects(alert_level: int, board_manager: Node) -> void:
	if alert_level < 1:
		return

	print("[TileEffectManager] 警戒レベル %d の盤面効果を適用" % alert_level)

	# Lv1+: 敵前列（col=0, side=1）のランダム3マスにアーマー
	if alert_level >= 1:
		_apply_armor_to_enemy_front(board_manager)

	# Lv2+: プレイヤー側にランダム3マス 棘/呪いマス
	if alert_level >= 2:
		_apply_hazard_tiles_to_player(board_manager)

func _apply_armor_to_enemy_front(board_manager: Node) -> void:
	# 敵前列（side=1, col=0）のランダムマスにアーマー付与
	var tile_count: int = ConfigLoader.get_value("alert_system", "tile_effect_count_lv1", 3)
	var candidates: Array = []
	for row in range(3):
		candidates.append({"side": 1, "row": row, "col": 0})

	candidates.shuffle()
	var apply_count = min(tile_count, candidates.size())
	for i in range(apply_count):
		var pos = candidates[i]
		board_manager.set_tile_effect(pos["side"], pos["row"], pos["col"], "armor_tile", -1.0)
		print("[TileEffectManager] アーマーマス配置: side=%d row=%d col=%d" % [pos["side"], pos["row"], pos["col"]])

func _apply_hazard_tiles_to_player(board_manager: Node) -> void:
	# プレイヤー側（side=0）のランダムマスに棘/呪いマス付与
	var tile_count: int = ConfigLoader.get_value("alert_system", "tile_effect_count_lv2", 3)
	var candidates: Array = []
	for row in range(3):
		for col in range(3):
			candidates.append({"row": row, "col": col})

	candidates.shuffle()
	var apply_count = min(tile_count, candidates.size())
	for i in range(apply_count):
		var pos = candidates[i]
		# 棘/呪いをランダム選択
		var effect_id = "thorn_tile" if randf() < 0.5 else "curse_tile"
		board_manager.set_tile_effect(0, pos["row"], pos["col"], effect_id, -1.0)
		print("[TileEffectManager] ハザードマス配置: %s side=0 row=%d col=%d" % [effect_id, pos["row"], pos["col"]])
