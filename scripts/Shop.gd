# Shop.gd
# ショップ画面（スタブ）: 将来は素材売買・カード購入
extends Control

const UIF = preload("res://scripts/UIFactory.gd")

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	UIF.add_bg(self)
	UIF.add_title(self, "ショップ")
	UIF.add_subtitle(self, "所持金: %dG" % GameSession.gold, 90, UIF.GOLD_COLOR)
	UIF.add_subtitle(self, "準備中...", 320, UIF.DIM_COLOR)
	UIF.add_back_button(self, "← マップへ", func(): SceneManager.go_to(SceneManager.MAP_SELECT))
