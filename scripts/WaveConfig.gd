# scripts/WaveConfig.gd
# Wave強化係数定数モジュール（Phase 4 #0a）
extends RefCounted

# Wave強化係数テーブル（pve_wave_pending_issues.md 論点1 確定仕様）
# HP・ATKに乗算（SPDは固定）
const WAVE_SCALE: Array = [
	0.6,  # 小Wave1
	0.8,  # 小Wave2
	1.0,  # 小Wave3
	1.3,  # 小Wave4
	1.6,  # 小Wave5
	2.0,  # 小Wave6
	3.0,  # ボスWave第一形態（Wave7）
	3.5,  # ボスWave第二形態（Wave8）
]

const SMALL_WAVE_COUNT: int = 6          # 小Waveの数
const BOSS_WAVE_PHASE1: int = 7          # ボスWave第一形態（1-indexed）
const BOSS_WAVE_PHASE2: int = 8          # ボスWave第二形態（1-indexed）
const TOTAL_WAVES_PER_BW: int = 8        # 1BWあたりのWave総数（小6 + ボス2）
const BIG_WAVES_PER_ACT: int = 1         # 1Act = 1BW

# デバッグ出力用
static func get_scale(wave_index: int) -> float:
	if wave_index < 1 or wave_index > TOTAL_WAVES_PER_BW:
		push_error("[WaveConfig] 無効なwave_index: %d" % wave_index)
		return 1.0
	return WAVE_SCALE[wave_index - 1]

static func is_boss_wave(wave_index: int) -> bool:
	return wave_index == BOSS_WAVE_PHASE1 or wave_index == BOSS_WAVE_PHASE2

static func is_final_wave(wave_index: int) -> bool:
	return wave_index == BOSS_WAVE_PHASE2
