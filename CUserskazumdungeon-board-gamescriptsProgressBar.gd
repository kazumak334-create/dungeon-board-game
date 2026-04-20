class_name ProgressBar
extends HBoxContainer

const CELL_WIDTH: int = 50
const CELL_HEIGHT: int = 60
const CELL_GAP: int = 8

enum CellType { BATTLE, SHOP, BOSS }

const COLOR_UNREACHED: Color = Color(0.2, 0.2, 0.25)
const COLOR_IN_PROGRESS: Color = Color(0.9, 0.8, 0.1)
const COLOR_SHOP_ACTIVE: Color = Color(0.3, 0.7, 1.0)
const COLOR_CLEARED: Color = Color(0.3, 0.8, 0.3)

const ICONS: Array = ["⚔", "💰", "⚔", "💰", "⚔", "💰", "💀"]

var _panels: Array = []
var _labels: Array = []

func _ready() -> void:
	size = Vector2(7 * (CELL_WIDTH + CELL_GAP) - CELL_GAP, CELL_HEIGHT)
	for i in range(7):
		var panel = ColorRect.new()
		panel.size = Vector2(CELL_WIDTH, CELL_HEIGHT)
		panel.color = COLOR_UNREACHED
		add_child(panel)
		_panels.append(panel)
		
		var label = Label.new()
		label.text = ICONS[i]
		label.position = Vector2(CELL_WIDTH / 2 - 10, CELL_HEIGHT / 2 - 10)
		label.add_theme_font_size_override("font_size", 24)
		panel.add_child(label)
		_labels.append(label)

func update_progress(big_wave: int, small_wave: int) -> void:
	var current_index = get_progress_index(small_wave)
	for i in range(7):
		if i < current_index:
			_panels[i].color = COLOR_CLEARED
		elif i == current_index:
			_panels[i].color = COLOR_IN_PROGRESS
		else:
			_panels[i].color = COLOR_UNREACHED

func get_progress_index(small_wave: int) -> int:
	if small_wave <= 2: return 0
	elif small_wave <= 4: return 2
	elif small_wave <= 6: return 4
	else: return 6

func on_intermission(shop_config: Dictionary) -> void:
	var small_wave = shop_config.get("small_wave", 0)
	var shop_index = -1
	if small_wave == 2: shop_index = 1
	elif small_wave == 4: shop_index = 3
	elif small_wave == 6: shop_index = 5
	
	if shop_index >= 0:
		_panels[shop_index].color = COLOR_SHOP_ACTIVE
