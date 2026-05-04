class_name DetailPopup
extends PanelContainer

# 建物詳細ポップアップ（要件定義書 REQUIREMENTS_SPRINT_8.md §6.6.3）
# M項目（建物名・分類・タイプ・状態・進捗・発動・効果）を必ず表示
# O項目（停止理由・必要稼働人手・発動間隔・足元土地・特殊タグ）は条件付き

# 建物名（日本語）SSoT（要件定義書 §6.6.3.2）
const BUILDING_NAME_JP: Dictionary = {
	EconBuilding.BuildingType.BARRACKS:  "兵舎",
	EconBuilding.BuildingType.FORTRESS:  "要塞",
	EconBuilding.BuildingType.WORKSHOP:  "工房",
	EconBuilding.BuildingType.VILLAGE:   "農村",
	EconBuilding.BuildingType.BASE:      "拠点",
	EconBuilding.BuildingType.SAWMILL:   "森小屋",
	EconBuilding.BuildingType.MINE:      "採掘所",
	EconBuilding.BuildingType.EQUIPMENT_SHOP: "装備屋",
	EconBuilding.BuildingType.TRADE_POST: "交換所",
	EconBuilding.BuildingType.WALL:      "防壁",
	EconBuilding.BuildingType.PLAZA:     "広場",
	EconBuilding.BuildingType.HOUSE:     "住宅",
	EconBuilding.BuildingType.EXCHANGE:  "交換所",
	EconBuilding.BuildingType.LIBRARY:   "書庫",
	EconBuilding.BuildingType.SMITHY:    "鍛冶屋",
	EconBuilding.BuildingType.WATCHTOWER: "防衛拠点",
	EconBuilding.BuildingType.DINER:     "食堂",
	EconBuilding.BuildingType.MILL:      "製粉所",
}

const POPUP_WIDTH := 240.0
const POPUP_MAX_HEIGHT := 280.0

var _vbox: VBoxContainer = null
var _type: String = ""  # "building" / "satisfaction" / "troop"
var _target = null

func _ready() -> void:
	print("[DetailPopup] _ready()")
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(POPUP_WIDTH, 0.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.075, 0.055, 0.95)
	sb.border_color = Color(0.35, 0.29, 0.20, 0.95)
	sb.set_border_width_all(1)
	sb.content_margin_left = 6.0
	sb.content_margin_right = 6.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	add_theme_stylebox_override("panel", sb)
	_vbox = VBoxContainer.new()
	_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vbox.add_theme_constant_override("separation", 3)
	add_child(_vbox)
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and ke.keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()

func show_building(building: EconBuilding, click_pos: Vector2) -> void:
	_type = "building"
	_target = building
	_rebuild_building_content(building)
	_position_popup(click_pos)
	visible = true
	print("[DetailPopup] show_building type=%s pos=%s" % [str(building.building_type), str(click_pos)])

func close() -> void:
	visible = false
	_type = ""
	_target = null
	print("[DetailPopup] close()")

func _rebuild_building_content(building: EconBuilding) -> void:
	if _vbox == null:
		return
	for child in _vbox.get_children():
		child.queue_free()

	var btype: EconBuilding.BuildingType = building.building_type
	var btype_int: int = int(btype)
	var name_jp: String = BUILDING_NAME_JP.get(btype, "不明")

	# M: ヘッダー（建物名・日本語）
	_add_label(name_jp, 12, Color(0.76, 0.65, 0.40), true)

	# M: 分類
	_add_separator()
	_add_row("分類", _get_category_text(building))

	# M: タイプenum名
	var type_keys: Array = EconBuilding.BuildingType.keys()
	var type_enum_name: String = type_keys[btype_int] if btype_int < type_keys.size() else str(btype_int)
	_add_row("タイプ", type_enum_name)

	# M: 状態
	var state_text: String
	if not building.is_built:
		state_text = "建設中"
	elif building.is_operating:
		state_text = "稼働中"
	else:
		state_text = "停止中"
	_add_row("状態", state_text)

	# M: 進捗
	var progress_pct: int
	if not building.is_built:
		progress_pct = int(building.get_build_progress_ratio() * 100.0)
	else:
		progress_pct = int(building.get_timer_progress() * 100.0)
	_add_row("進捗", "%d%%" % progress_pct)

	# O: 停止理由（停止中のみ）
	if building.is_built and not building.is_operating:
		_add_separator()
		var stop_key := "stop_reason"
		var stop_reason: String = building.get(stop_key) if building.get(stop_key) != null else ""
		if stop_reason != "":
			_add_row("停止理由", stop_reason, Color(0.80, 0.25, 0.20))

	# M: 発動方式
	_add_separator()
	_add_row("発動", _get_trigger_text(btype))

	# M: 効果
	_add_row("効果", _get_effect_text(btype, building.fusion_rank))

	# O: 必要稼働人手（パッシブ以外）
	if building.required_operation_labor > 0:
		_add_separator()
		_add_row("必要稼働人手", str(building.required_operation_labor))

func _get_category_text(building: EconBuilding) -> String:
	# building_type から分類を判定
	match building.building_type:
		EconBuilding.BuildingType.TRADE_POST, EconBuilding.BuildingType.EXCHANGE:
			return "特殊建物"
		_:
			return "通常建物"

func _get_trigger_text(btype: EconBuilding.BuildingType) -> String:
	match btype:
		EconBuilding.BuildingType.HOUSE, EconBuilding.BuildingType.PLAZA:
			return "パッシブ"
		EconBuilding.BuildingType.TRADE_POST, EconBuilding.BuildingType.EXCHANGE:
			return "パッシブ（累計型）"
		_:
			return "周期発動"

func _get_effect_text(btype: EconBuilding.BuildingType, lv: int) -> String:
	var lv_bonus: float = 1.0 + (lv - 1) * 0.25
	match btype:
		EconBuilding.BuildingType.HOUSE:
			return "人口上限+%d" % (10 * lv)
		EconBuilding.BuildingType.VILLAGE:
			return "小麦+2 / 5秒、コットン+1 / 5秒"
		EconBuilding.BuildingType.SAWMILL:
			return "木材+%d / 5秒" % roundi(2.0 * lv_bonus)
		EconBuilding.BuildingType.MINE:
			return "石材+%d / 5秒" % roundi(2.0 * lv_bonus)
		EconBuilding.BuildingType.DINER:
			return "食料値供給+2 / 5秒（小麦-1消費）"
		EconBuilding.BuildingType.BARRACKS:
			return "兵力+%d / 5秒" % (lv + 1)
		EconBuilding.BuildingType.PLAZA:
			return "幸福度供給+%d（隣接住宅+1/件）" % lv
		EconBuilding.BuildingType.TRADE_POST, EconBuilding.BuildingType.EXCHANGE:
			return "足元資源累計10ごとに1ドロー"
		EconBuilding.BuildingType.SMITHY:
			return "隣接兵舎DPS+%d%%" % int((lv_bonus - 1.0) * 10.0 + 10.0)
		EconBuilding.BuildingType.WATCHTOWER:
			return "防衛兵力統括・防壁回復"
		EconBuilding.BuildingType.MILL:
			return "小麦+2 / 5秒（小麦-1消費）"
		_:
			return "効果未定義"

func _add_label(text: String, font_size: int = 10, color: Color = Color(0.70, 0.65, 0.55), bold: bool = false) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_vbox.add_child(lbl)

func _add_row(key: String, value: String, value_color: Color = Color(0.70, 0.65, 0.55)) -> void:
	var hbox := HBoxContainer.new()
	var key_lbl := Label.new()
	key_lbl.text = key
	key_lbl.add_theme_font_size_override("font_size", 10)
	key_lbl.add_theme_color_override("font_color", Color(0.50, 0.47, 0.40))
	key_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(key_lbl)
	var val_lbl := Label.new()
	val_lbl.text = value
	val_lbl.add_theme_font_size_override("font_size", 10)
	val_lbl.add_theme_color_override("font_color", value_color)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(val_lbl)
	_vbox.add_child(hbox)

func _add_separator() -> void:
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.35, 0.29, 0.20, 0.60))
	_vbox.add_child(sep)

func _position_popup(click_pos: Vector2) -> void:
	# クリック位置の右上 +12px（要件定義書 §6.6.3.3）
	var popup_size := Vector2(POPUP_WIDTH, POPUP_MAX_HEIGHT)
	var screen_size := get_viewport_rect().size
	var pos := Vector2(click_pos.x + 12.0, click_pos.y - 12.0 - popup_size.y)
	# 画面外補正（左反転 / 上反転）
	if pos.x + popup_size.x > screen_size.x:
		pos.x = click_pos.x - popup_size.x - 12.0
	if pos.y < 0.0:
		pos.y = click_pos.y + 12.0
	if pos.x < 0.0:
		pos.x = 0.0
	position = pos
