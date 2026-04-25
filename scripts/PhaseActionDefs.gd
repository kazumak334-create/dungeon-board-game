# PhaseActionDefs.gd
# フェーズ別アクション定義組み立て（純粋データ・副作用なし）
# EnemyPanelManager / SpellSlotSystem を知らない
class_name PhaseActionDefs
extends RefCounted

# 戻り値: Array 3要素
# 各要素: {action_id, action_label, action_desc, action_cost_text, enabled}

static func build_scratch(gold: int, action_used: String) -> Array:
	"""SCRATCHフェーズ: 確定/覗き見/強欲"""
	var can_peek: bool = (gold >= PhaseActionConfig.PEEK_COST) and (action_used == "")
	var can_greed: bool = (action_used == "")

	return [
		{
			"action_id": "scratch_confirm",
			"action_label": "確定",
			"action_desc": "選択中マスを確定して報酬獲得",
			"action_cost_text": "なし",
			"enabled": true
		},
		{
			"action_id": "scratch_peek",
			"action_label": "覗き見",
			"action_desc": "隣接3マスの中身を公開",
			"action_cost_text": "金%dG" % PhaseActionConfig.PEEK_COST,
			"enabled": can_peek
		},
		{
			"action_id": "scratch_greed",
			"action_label": "強欲",
			"action_desc": "1マス犠牲にして2マス獲得",
			"action_cost_text": "1マス無効化",
			"enabled": can_greed
		}
	]

static func build_shop(gold: int, reroll_count: int, negotiated: bool) -> Array:
	"""SHOPフェーズ: 退店/リロール/交渉"""
	var reroll_cost: int = PhaseActionConfig.get_reroll_cost(reroll_count)
	var can_reroll: bool = (gold >= reroll_cost)
	var can_negotiate: bool = not negotiated

	var reroll_cost_text: String = "無料" if reroll_cost == 0 else "金%dG" % reroll_cost

	return [
		{
			"action_id": "shop_leave",
			"action_label": "退店",
			"action_desc": "NEXT_EIフェーズへ遷移",
			"action_cost_text": "なし",
			"enabled": true
		},
		{
			"action_id": "shop_reroll",
			"action_label": "リロール",
			"action_desc": "商品9枠を全て引き直す",
			"action_cost_text": reroll_cost_text,
			"enabled": can_reroll
		},
		{
			"action_id": "shop_negotiate",
			"action_label": "交渉",
			"action_desc": "成功60%:全商品-30% / 失敗:即退店+ペナルティ",
			"action_cost_text": "なし",
			"enabled": can_negotiate
		}
	]

static func build_next_ei(gold: int, act: int, scout_count: int) -> Array:
	"""NEXT_EIフェーズ: 出撃/偵察/暗転"""
	var scout_cost: int = PhaseActionConfig.get_scout_cost(act, scout_count)
	var can_scout: bool = (gold >= scout_cost)

	return [
		{
			"action_id": "next_ei_launch",
			"action_label": "出撃",
			"action_desc": "バトル開始",
			"action_cost_text": "なし",
			"enabled": true
		},
		{
			"action_id": "next_ei_scout",
			"action_label": "偵察",
			"action_desc": "敵1マスのHP/ATKを公開",
			"action_cost_text": "金%dG" % scout_cost,
			"enabled": can_scout
		},
		{
			"action_id": "next_ei_dark",
			"action_label": "未使用",
			"action_desc": "",
			"action_cost_text": "ー",
			"enabled": false
		}
	]
