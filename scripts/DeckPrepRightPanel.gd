# DeckPrepRightPanel.gd
# DeckPrep右パネル（カード詳細専用）
extends RefCounted

const UIF = preload("res://scripts/UIFactory.gd")
const UIColors = preload("res://scripts/ui/UIColors.gd")

var _main_node: Control = null
var _info_container: Control = null

# レイアウト定数
const INFO_X = 1075
const INFO_Y = 40
const INFO_W = 200
const INFO_H = 675

func setup(main_node: Control) -> void:
	_main_node = main_node

func build_info_lane() -> Control:
	# 右パネル背景
	var info_panel = UIF.create_panel(
		Vector2(INFO_X, INFO_Y),
		Vector2(INFO_W, INFO_H),
		UIColors.COLOR_SIDE_PANEL,
		UIColors.COLOR_BORDER,
		1,
		4
	)
	_main_node.add_child(info_panel)

	_info_container = Control.new()
	_info_container.position = Vector2(INFO_X, INFO_Y)
	_info_container.size = Vector2(INFO_W, INFO_H)
	_main_node.add_child(_info_container)

	return _info_container
