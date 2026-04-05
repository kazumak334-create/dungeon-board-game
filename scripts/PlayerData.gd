# PlayerData.gd
# プレイヤーデータ（クラス・装備・スキル）
extends RefCounted

var class_id: String = ""         # クラスID
var class_name_jp: String = ""    # クラス表示名
var initial_mana: float = 3.0     # 初期マナ
var mana_max: float = 10.0        # マナ上限
var mana_regen: float = 1.0       # マナ回復速度(/s)
var skills: Array = []            # クラススキル [{trigger, target, effect_id, params}]
var equipment: Array = []         # 装備リスト [{name, display, effect, skills}] CardDB.EQUIPMENTのエントリ
var skill_tree: Array = []        # スキルツリー（将来実装。枠のみ）

# ランタイム（バトル中のみ）
var _death_mana_count: int = 0    # 死霊術師用：味方死亡時マナ+1の累積回数

func reset_runtime() -> void:
	_death_mana_count = 0
