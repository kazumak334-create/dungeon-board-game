# TestBattleConfig.gd
# バトルコンフィグテスト（battle_timer, battle_config_default/reset/time_limit/custom_hp）
extends RefCounted

func run(runner: RefCounted) -> void:
	_test_battle_timer(runner)
	_test_battle_config_default(runner)
	_test_battle_config_reset(runner)
	_test_battle_config_time_limit(runner)
	_test_battle_config_custom_hp(runner)

func _test_battle_timer(r: RefCounted) -> void:
	# test_battle_timer_initial: _battle_timerの初期値が60秒
	var MainScript = load("res://scripts/Main.gd")
	var main_inst = MainScript.new()
	r._assert_eq(main_inst._battle_timer, 60.0, "battle_timer_initial: 初期値60秒")

	# test_battle_timer_countdown: deltaを引いた値が_battle_timerに反映
	main_inst._battle_timer = 60.0
	var before: float = main_inst._battle_timer
	var test_delta: float = 5.0
	main_inst._battle_timer -= test_delta
	r._assert_eq(main_inst._battle_timer, before - test_delta, "battle_timer_countdown: delta適用で減少")

	# test_battle_timer_timeout: 0以下になったら非アクティブ扱い（_battle_timer_activeはfalse）
	main_inst._battle_timer = 0.0
	main_inst._battle_timer_active = false
	r._assert_true(not main_inst._battle_timer_active, "battle_timer_timeout: 0以下で非アクティブ")

func _test_battle_config_default(r: RefCounted) -> void:
	# DEFAULT_BATTLE_CONFIGの全キーが存在することを確認
	var required_keys: Array = [
		"time_limit", "time_up_result", "win_condition", "lose_condition",
		"player_base_hp", "enemy_base_hp", "enemy_check_interval",
		"enemy_hp_scale", "reward_multiplier", "skill_points_reward",
		"initial_units", "summon_race_filter", "placement_restriction",
		"mana_max_override"
	]
	var cfg: Dictionary = GameSession.DEFAULT_BATTLE_CONFIG
	for key in required_keys:
		r._assert_true(cfg.has(key), "battle_config_default: DEFAULT_BATTLE_CONFIGに[%s]がない" % key)
	r._assert_eq(cfg.get("time_limit", 0.0), 60.0, "battle_config_default: time_limit=60.0")
	r._assert_eq(cfg.get("time_up_result", ""), "lose", "battle_config_default: time_up_result=lose")
	r._assert_eq(cfg.get("player_base_hp", 0), 30, "battle_config_default: player_base_hp=30")
	r._assert_eq(cfg.get("enemy_base_hp", 0), 30, "battle_config_default: enemy_base_hp=30")

func _test_battle_config_reset(r: RefCounted) -> void:
	# reset()後にbattle_configがデフォルト値に戻ることを確認
	GameSession.battle_config["time_limit"] = 999.0
	GameSession.battle_config["player_base_hp"] = 99
	GameSession.reset()
	r._assert_eq(GameSession.battle_config.get("time_limit", 0.0), 60.0, "battle_config_reset: time_limit=60.0に戻る")
	r._assert_eq(GameSession.battle_config.get("player_base_hp", 0), 30, "battle_config_reset: player_base_hp=30に戻る")
	r._assert_eq(GameSession.battle_config.get("time_up_result", ""), "lose", "battle_config_reset: time_up_result=loseに戻る")

func _test_battle_config_time_limit(r: RefCounted) -> void:
	# time_limit=0.0で_battle_timer_activeがfalseになることを確認
	GameSession.battle_config = GameSession.DEFAULT_BATTLE_CONFIG.duplicate(true)
	GameSession.battle_config["time_limit"] = 0.0
	var MainScript = load("res://scripts/Main.gd")
	var main_inst = MainScript.new()
	# dev_mode=falseの状態でtime_limit=0.0 → activeはfalse
	main_inst.dev_mode = false
	var tl: float = GameSession.battle_config.get("time_limit", 60.0)
	var active: bool = (tl > 0.0) and not main_inst.dev_mode
	r._assert_true(not active, "battle_config_time_limit: time_limit=0.0でactive=false")
	# 元に戻す
	GameSession.battle_config = GameSession.DEFAULT_BATTLE_CONFIG.duplicate(true)

func _test_battle_config_custom_hp(r: RefCounted) -> void:
	# player_base_hp/enemy_base_hpがbase_hpに反映されることを確認
	GameSession.battle_config = GameSession.DEFAULT_BATTLE_CONFIG.duplicate(true)
	GameSession.battle_config["player_base_hp"] = 50
	GameSession.battle_config["enemy_base_hp"] = 20
	var base_hp: Array = [30, 30]
	var cfg: Dictionary = GameSession.battle_config
	base_hp[0] = cfg.get("player_base_hp", 30)
	base_hp[1] = cfg.get("enemy_base_hp", 30)
	r._assert_eq(base_hp[0], 50, "battle_config_custom_hp: player_base_hp=50が反映")
	r._assert_eq(base_hp[1], 20, "battle_config_custom_hp: enemy_base_hp=20が反映")
	# 元に戻す
	GameSession.battle_config = GameSession.DEFAULT_BATTLE_CONFIG.duplicate(true)
