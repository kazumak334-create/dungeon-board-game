# SkillTreeGenerator.gd
# スキルツリー自動生成アルゴリズム
# 6階層ランダム生成、4+6階層はカード報酬
extends RefCounted
class_name SkillTreeGenerator

# スキルプール（ダミーデータ大量生成）
const SKILL_POOLS = {
	1: [
		{"id": "t1_foundation_a", "name": "基礎強化A", "desc": "全ユニットHP+10%"},
		{"id": "t1_foundation_b", "name": "基礎強化B", "desc": "全ユニットATK+10%"},
		{"id": "t1_foundation_c", "name": "基礎強化C", "desc": "マナ回復+0.2/秒"},
	],
	2: [
		{"id": "t2_economy_a", "name": "金貨収集A", "desc": "バトル報酬gold+20%"},
		{"id": "t2_economy_b", "name": "金貨収集B", "desc": "バトル報酬gold+30%"},
		{"id": "t2_economy_e", "name": "SP増加A", "desc": "バトル報酬SP+1"},
		{"id": "t2_economy_f", "name": "SP増加B", "desc": "バトル報酬SP+2"},
		{"id": "t2_combat_a", "name": "戦闘強化A", "desc": "全ユニットHP+15%"},
		{"id": "t2_combat_b", "name": "戦闘強化B", "desc": "全ユニットATK+15%"},
		{"id": "t2_combat_c", "name": "戦闘強化C", "desc": "全ユニットSPD+10%"},
		{"id": "t2_utility_a", "name": "初期マナ増加", "desc": "バトル開始時マナ+1"},
	],
	3: [
		{"id": "t3_synergy_a", "name": "種族シナジーA", "desc": "同種族3体以上でATK+20%"},
		{"id": "t3_synergy_b", "name": "種族シナジーB", "desc": "同種族5体以上でHP+30%"},
		{"id": "t3_tactical_a", "name": "前列強化", "desc": "前列ユニットATK+25%"},
		{"id": "t3_tactical_b", "name": "後列強化", "desc": "後列ユニットATK+30%"},
		{"id": "t3_tactical_c", "name": "中列強化", "desc": "中列ユニットHP+30%"},
		{"id": "t3_spell_a", "name": "呪文強化A", "desc": "呪文効果+20%"},
		{"id": "t3_spell_b", "name": "呪文強化B", "desc": "呪文コスト-1"},
		{"id": "t3_spell_c", "name": "呪文強化C", "desc": "呪文発動速度+30%"},
		{"id": "t3_defense_a", "name": "防御強化A", "desc": "全ユニット被ダメージ-10%"},
		{"id": "t3_defense_b", "name": "防御強化B", "desc": "全ユニット被ダメージ-15%"},
		{"id": "t3_regen_a", "name": "リジェネA", "desc": "全ユニットに微リジェネ付与"},
		{"id": "t3_regen_b", "name": "リジェネB", "desc": "全ユニットに強リジェネ付与"},
	],
	5: [
		{"id": "t5_tactical_a", "name": "戦術拡張A", "desc": "配置時効果2回発動"},
		{"id": "t5_tactical_b", "name": "戦術拡張B", "desc": "撃破時効果2回発動"},
		{"id": "t5_tactical_c", "name": "戦術拡張C", "desc": "HP50%以下で全効果2倍"},
		{"id": "t5_tactical_d", "name": "戦術拡張D", "desc": "前列ユニット死亡時、後列が自動昇格+ATK+50%"},
		{"id": "t5_economy_a", "name": "経済拡張A", "desc": "ショップ価格-20%"},
		{"id": "t5_economy_b", "name": "経済拡張B", "desc": "カード除去コスト-50%"},
		{"id": "t5_economy_c", "name": "経済拡張C", "desc": "イベント報酬2倍"},
		{"id": "t5_buff_a", "name": "バフ延長A", "desc": "全バフ持続+2ターン"},
		{"id": "t5_buff_b", "name": "バフ延長B", "desc": "全バフスタック+1"},
		{"id": "t5_debuff_a", "name": "デバフ強化A", "desc": "敵デバフ持続+2ターン"},
		{"id": "t5_debuff_b", "name": "デバフ強化B", "desc": "敵デバフスタック+1"},
		{"id": "t5_tile_a", "name": "盤面支配", "desc": "開始時、敵陣全マスに棘配置"},
	],
}

# クラス固有スキルプール（4+6階層）
const CLASS_SKILL_POOLS = {
	"berserker": {
		4: [
			{"id": "bers_t4_a", "name": "獣王の血脈", "desc": "獣系ユニット追加", "card": "ワイルドホーク"},
			{"id": "bers_t4_b", "name": "獣王の咆哮", "desc": "獣系ユニット追加", "card": "ファングタイガー"},
			{"id": "bers_t4_c", "name": "獣王の爪", "desc": "獣系ユニット追加", "card": "シャドウウルフ"},
			{"id": "bers_t4_d", "name": "獣王の牙", "desc": "獣系ユニット追加", "card": "ゴブリン"},
			{"id": "bers_t4_e", "name": "獣王の怒り", "desc": "獣系ユニット追加", "card": "ゴブリンアーチャー"},
			{"id": "bers_t4_f", "name": "獣王の狩猟", "desc": "獣系ユニット追加", "card": "ゴブリンシャーマン"},
			{"id": "bers_t4_g", "name": "獣王の群れ", "desc": "獣系ユニット追加", "card": "ワイルドホーク"},
			{"id": "bers_t4_h", "name": "獣王の野生", "desc": "獣系ユニット追加", "card": "ファングタイガー"},
		],
		6: [
			{"id": "bers_t6_a", "name": "究極：獣王降臨", "desc": "獣王ガルガンタ追加", "card": "ファングタイガー"},
			{"id": "bers_t6_b", "name": "究極：野生の咆哮", "desc": "全獣系強化+特殊カード", "card": "シャドウウルフ"},
			{"id": "bers_t6_c", "name": "究極：血の契約II", "desc": "血の契約上位版", "card": "血の契約"},
			{"id": "bers_t6_d", "name": "究極：狂戦士の魂", "desc": "全ユニットバーサーク", "card": "ゴブリン"},
			{"id": "bers_t6_e", "name": "究極：獣の森", "desc": "自陣全マスに獣の森", "card": "ワイルドホーク"},
			{"id": "bers_t6_f", "name": "究極：牙の嵐", "desc": "全獣系に貫通+吸血", "card": "ファングタイガー"},
		],
	},
	"alchemist": {
		4: [
			{"id": "alch_t4_a", "name": "錬金の秘技A", "desc": "スライム系追加", "card": "アメーバ"},
			{"id": "alch_t4_b", "name": "錬金の秘技B", "desc": "スライム系追加", "card": "ポイズンスライム"},
			{"id": "alch_t4_c", "name": "錬金の秘技C", "desc": "スライム系追加", "card": "アイアンスライム"},
			{"id": "alch_t4_d", "name": "錬金の秘技D", "desc": "スライム系追加", "card": "キングスライム"},
			{"id": "alch_t4_e", "name": "錬金の秘技E", "desc": "呪文追加", "card": "合成促進剤"},
			{"id": "alch_t4_f", "name": "錬金の秘技F", "desc": "呪文追加", "card": "シャッフル"},
			{"id": "alch_t4_g", "name": "錬金の秘技G", "desc": "呪文追加", "card": "アースクエイク"},
			{"id": "alch_t4_h", "name": "錬金の秘技H", "desc": "呪文追加", "card": "フルヒール"},
		],
		6: [
			{"id": "alch_t6_a", "name": "究極：賢者の石", "desc": "スライム神召喚", "card": "キングスライム"},
			{"id": "alch_t6_b", "name": "究極：完全合成", "desc": "合成時両方の効果継承", "card": "合成促進剤"},
			{"id": "alch_t6_c", "name": "究極：錬金陣", "desc": "自陣全マスに錬金床", "card": "アメーバ"},
			{"id": "alch_t6_d", "name": "究極：生命の泉", "desc": "全ユニット死亡時復活1回", "card": "フルヒール"},
			{"id": "alch_t6_e", "name": "究極：毒の帝国", "desc": "全ユニットに毒付与", "card": "ポイズンスライム"},
			{"id": "alch_t6_f", "name": "究極：金属化", "desc": "全ユニットに鎧10", "card": "アイアンスライム"},
		],
	},
	"necromancer": {
		4: [
			{"id": "necro_t4_a", "name": "死霊の軍勢A", "desc": "アンデッド追加", "card": "スケルトン"},
			{"id": "necro_t4_b", "name": "死霊の軍勢B", "desc": "アンデッド追加", "card": "ゾンビ"},
			{"id": "necro_t4_c", "name": "死霊の軍勢C", "desc": "アンデッド追加", "card": "ゴースト"},
			{"id": "necro_t4_d", "name": "死霊の軍勢D", "desc": "アンデッド追加", "card": "リッチ"},
			{"id": "necro_t4_e", "name": "死霊の軍勢E", "desc": "アンデッド追加", "card": "ヴリコラカス"},
			{"id": "necro_t4_f", "name": "死霊の軍勢F", "desc": "アンデッド追加", "card": "ボーンドラゴン"},
			{"id": "necro_t4_g", "name": "死霊の軍勢G", "desc": "呪文追加", "card": "死の波動"},
			{"id": "necro_t4_h", "name": "死霊の軍勢H", "desc": "呪文追加", "card": "血の契約"},
		],
		6: [
			{"id": "necro_t6_a", "name": "究極：死霊王降臨", "desc": "ブラッドキング追加", "card": "リッチ"},
			{"id": "necro_t6_b", "name": "究極：不死の軍団", "desc": "全ユニット再起×2", "card": "スケルトン"},
			{"id": "necro_t6_c", "name": "究極：吸血の宴", "desc": "全ユニット吸血20", "card": "ヴリコラカス"},
			{"id": "necro_t6_d", "name": "究極：呪いの地", "desc": "敵陣全マスに呪い", "card": "ゴースト"},
			{"id": "necro_t6_e", "name": "究極：魂の収穫", "desc": "撃破時SP+1", "card": "リッチ"},
			{"id": "necro_t6_f", "name": "究極：永劫回帰", "desc": "全ユニット死亡時デッキに戻る", "card": "ゾンビ"},
		],
	},
}

# 再現性用RNG
var _rng: RandomNumberGenerator = null

func generate(seed_value: int, class_id: String) -> Dictionary:
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed_value

	var nodes: Array = []
	var node_id_counter: int = 0

	# 1階層: 1個固定
	var tier1_pool = SKILL_POOLS[1].duplicate()
	tier1_pool.shuffle()
	var tier1_node = _create_node(tier1_pool[0], 1, 1, [], {"x": 50, "y": 300})
	nodes.append(tier1_node)
	var prev_tier_ids = [tier1_node["id"]]

	# 2階層: 3個固定
	var tier2_pool = SKILL_POOLS[2].duplicate()
	tier2_pool.shuffle()
	var tier2_nodes = []
	for i in range(3):
		var y_pos = 150 + i * 150
		var node = _create_node(tier2_pool[i], 2, 2, [tier1_node["id"]], {"x": 250, "y": y_pos})
		nodes.append(node)
		tier2_nodes.append(node["id"])
	prev_tier_ids = tier2_nodes

	# 3階層: 2-3個ランダム
	var tier3_count = _rng.randi_range(2, 3)
	var tier3_pool = SKILL_POOLS[3].duplicate()
	tier3_pool.shuffle()
	var tier3_nodes = []
	for i in range(tier3_count):
		var prereq_count = _rng.randi_range(1, 2) if prev_tier_ids.size() >= 2 else 1
		var prereqs = []
		var shuffled_prev = prev_tier_ids.duplicate()
		shuffled_prev.shuffle()
		for j in range(prereq_count):
			prereqs.append(shuffled_prev[j])
		var y_pos = 100 + i * 175
		var node = _create_node(tier3_pool[i], 3, 3, prereqs, {"x": 450, "y": y_pos})
		nodes.append(node)
		tier3_nodes.append(node["id"])
	prev_tier_ids = tier3_nodes

	# 4階層: 2個ランダム（カード報酬・クラス固有）
	var tier4_pool = CLASS_SKILL_POOLS.get(class_id, CLASS_SKILL_POOLS["berserker"])[4].duplicate()
	tier4_pool.shuffle()
	var tier4_nodes = []
	for i in range(2):
		var prereq_count = _rng.randi_range(1, 2) if prev_tier_ids.size() >= 2 else 1
		var prereqs = []
		var shuffled_prev = prev_tier_ids.duplicate()
		shuffled_prev.shuffle()
		for j in range(prereq_count):
			prereqs.append(shuffled_prev[j])
		var y_pos = 200 + i * 200
		var node = _create_card_node(tier4_pool[i], 4, 4, prereqs, {"x": 650, "y": y_pos})
		nodes.append(node)
		tier4_nodes.append(node["id"])
	prev_tier_ids = tier4_nodes

	# 5階層: 2-3個ランダム
	var tier5_count = _rng.randi_range(2, 3)
	var tier5_pool = SKILL_POOLS[5].duplicate()
	tier5_pool.shuffle()
	var tier5_nodes = []
	for i in range(tier5_count):
		var prereq_count = _rng.randi_range(1, 2) if prev_tier_ids.size() >= 2 else 1
		var prereqs = []
		var shuffled_prev = prev_tier_ids.duplicate()
		shuffled_prev.shuffle()
		for j in range(prereq_count):
			prereqs.append(shuffled_prev[j])
		var y_pos = 100 + i * 175
		var node = _create_node(tier5_pool[i], 5, 5, prereqs, {"x": 850, "y": y_pos})
		nodes.append(node)
		tier5_nodes.append(node["id"])
	prev_tier_ids = tier5_nodes

	# 6階層: 1個固定（カード報酬・究極・クラス固有）
	var tier6_pool = CLASS_SKILL_POOLS.get(class_id, CLASS_SKILL_POOLS["berserker"])[6].duplicate()
	tier6_pool.shuffle()
	var prereqs = prev_tier_ids.duplicate()
	var tier6_node = _create_card_node(tier6_pool[0], 6, 6, prereqs, {"x": 1050, "y": 300})
	nodes.append(tier6_node)

	return {
		"seed": seed_value,
		"class_id": class_id,
		"nodes": nodes,
	}

func _create_node(skill_def: Dictionary, tier: int, cost: int, prereqs: Array, pos: Dictionary) -> Dictionary:
	return {
		"id": skill_def["id"],
		"tier": tier,
		"cost": cost,
		"name": skill_def["name"],
		"description": skill_def["desc"],
		"reward_type": "stat",
		"reward_card": null,
		"prerequisites": prereqs,
		"unlocked": false,
		"position": pos,
	}

func _create_card_node(skill_def: Dictionary, tier: int, cost: int, prereqs: Array, pos: Dictionary) -> Dictionary:
	return {
		"id": skill_def["id"],
		"tier": tier,
		"cost": cost,
		"name": skill_def["name"],
		"description": skill_def["desc"],
		"reward_type": "card",
		"reward_card": skill_def["card"],
		"prerequisites": prereqs,
		"unlocked": false,
		"position": pos,
	}
