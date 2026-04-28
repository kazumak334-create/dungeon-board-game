class_name RewardGenerator
extends RefCounted

# 3択ユニットを生成（突・守・崩の3種固定、順序ランダム）
# 戻り値: [unit_type: int, unit_type: int, unit_type: int]
static func generate_choices(rng: RandomNumberGenerator) -> Array[int]:
	print("[RewardGenerator] generate_choices called")
	# 0=ATTACKER, 1=TANK, 2=BREAKER の3種をFisher-Yatesシャッフル
	var choices: Array[int] = [0, 1, 2]
	for i in range(choices.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: int = choices[i]
		choices[i] = choices[j]
		choices[j] = tmp
	print("[RewardGenerator] choices=", choices)
	return choices
