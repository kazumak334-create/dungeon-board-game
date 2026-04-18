extends Control
class_name CardView

enum CardKind { UNIT, SPELL }
enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGEND, GOD }

const FRAME_TEXTURES = {
	Rarity.COMMON:   "res://assets/cards/frames/unit_common_320.png",
	Rarity.UNCOMMON: "res://assets/cards/frames/unit_uncommon_320.png",
	Rarity.RARE:     "res://assets/cards/frames/unit_rare_320.png",
	Rarity.EPIC:     "res://assets/cards/frames/unit_epic_320.png",
	Rarity.LEGEND:   "res://assets/cards/frames/unit_legend_320.png",
	Rarity.GOD:      "res://assets/cards/frames/unit_god_320.png",
}

const RARITY_FONTS = {
	Rarity.COMMON:   "res://assets/fonts/bronze_font.fnt",
	Rarity.UNCOMMON: "res://assets/fonts/bronze_font.fnt",
	Rarity.RARE:     "res://assets/fonts/silver_font.fnt",
	Rarity.EPIC:     "res://assets/fonts/silver_font.fnt",
	Rarity.LEGEND:   "res://assets/fonts/gold_font.fnt",
	Rarity.GOD:      "res://assets/fonts/gold_font.fnt",
}

const TRAIT_ICONS = {
	"flying":      "res://assets/cards/traits/flying.png",
	"pierce":      "res://assets/cards/traits/pierce.png",
	"swarm":       "res://assets/cards/traits/swarm.png",
	"regenerate":  "res://assets/cards/traits/regenerate.png",
	"armored":     "res://assets/cards/traits/armored.png",
	"toxic":       "res://assets/cards/traits/toxic.png",
	"ranged":      "res://assets/cards/traits/ranged.png",
	"berserker":   "res://assets/cards/traits/berserker.png",
	"magic":       "res://assets/cards/traits/magic.png",
	"undead":      "res://assets/cards/traits/undead.png",
}

const TRAIT_BADGE_SIZE = 16

@export var card_kind: CardKind = CardKind.UNIT:
	set(value):
		card_kind = value
		_apply_kind()

@export var rarity: Rarity = Rarity.COMMON:
	set(value):
		rarity = value
		if is_node_ready():
			_update_frame()

@export var mana: int = 1:
	set(value):
		mana = value
		_update_text()

@export var card_name: String = "スライム":
	set(value):
		card_name = value
		_update_text()

@export var hp: int = 3:
	set(value):
		hp = value
		_update_text()

@export var atk: int = 2:
	set(value):
		atk = value
		_update_text()

@export var spd: int = 1:
	set(value):
		spd = value
		_update_text()

@export var frame_texture: Texture2D:
	set(value):
		frame_texture = value
		if has_node("FrameTexture"):
			$FrameTexture.texture = frame_texture

@export var top_icon_texture: Texture2D:
	set(value):
		top_icon_texture = value
		if has_node("OverlayRoot/TopIcon"):
			$OverlayRoot/TopIcon.texture = top_icon_texture

@export var art_texture: Texture2D:
	set(value):
		art_texture = value
		if has_node("OverlayRoot/ArtTexture"):
			$OverlayRoot/ArtTexture.texture = art_texture

@export var traits: Array[String] = []:
	set(value):
		traits = value
		_update_trait_badges()

func _ready() -> void:
	# ready時に改めてプロパティを適用（ready前に設定された値を反映）
	_update_frame()  # rarity, frame_textureを反映
	_update_text()
	_apply_kind()
	_update_trait_badges()
	if top_icon_texture:
		$OverlayRoot/TopIcon.texture = top_icon_texture
	if art_texture:
		$OverlayRoot/ArtTexture.texture = art_texture

func _update_text() -> void:
	if not has_node("OverlayRoot/ManaLabel"):
		return
	$OverlayRoot/ManaLabel.text = str(mana)

	# card_nameがユニットIDの場合はen_nameを使用
	var display_name = card_name
	if CardDB.UNITS.has(card_name):
		display_name = CardDB.UNITS[card_name].get("en_name", card_name)

	# ビットマップフォントは大文字のみ対応のため必ずto_upper()を通す
	$OverlayRoot/NameLabel.text = display_name.to_upper()
	$OverlayRoot/StatRow/HpLabel.text = str(hp)
	$OverlayRoot/StatRow/AtkLabel.text = str(atk)
	$OverlayRoot/StatRow/SpdLabel.text = str(spd)

func _apply_kind() -> void:
	if not has_node("OverlayRoot/StatRow"):
		return
	$OverlayRoot/StatRow.visible = card_kind == CardKind.UNIT

func _update_frame() -> void:
	if not has_node("FrameTexture"):
		return
	# frame_textureが明示的に設定されている場合はそちらを優先
	if frame_texture:
		$FrameTexture.texture = frame_texture
	else:
		# レアリティに応じたフレームを自動設定
		$FrameTexture.texture = load(FRAME_TEXTURES[rarity])

	# レアリティに応じたフォントを全ラベルに設定
	var font_path = RARITY_FONTS[rarity]
	print("[CardView] レアリティ %s → フォントパス: %s" % [rarity, font_path])
	if ResourceLoader.exists(font_path):
		var font = load(font_path)
		if font:
			# 全ラベルにレアリティに応じたフォントを適用
			var label_paths = [
				"OverlayRoot/NameLabel",
				"OverlayRoot/ManaLabel",
				"OverlayRoot/StatRow/HpLabel",
				"OverlayRoot/StatRow/AtkLabel",
				"OverlayRoot/StatRow/SpdLabel"
			]
			for label_path in label_paths:
				if has_node(label_path):
					var label = get_node(label_path)
					label.add_theme_font_override("font", font)
					# ビットマップフォントの元の色を表示するため、font_colorオーバーライドを削除
					label.remove_theme_color_override("font_color")
			print("[CardView] フォント適用成功: %s" % font_path)
		else:
			push_warning("[CardView] フォント読み込み失敗: %s" % font_path)
	else:
		push_warning("[CardView] フォントファイルが存在しません: %s" % font_path)

func _update_trait_badges() -> void:
	if not has_node("OverlayRoot/TraitBadges"):
		return

	var container = $OverlayRoot/TraitBadges
	# 既存のバッジをクリア
	for child in container.get_children():
		child.queue_free()

	# 最大10個まで表示
	var display_count = min(traits.size(), 10)
	for i in range(display_count):
		var trait_name = traits[i]
		var badge = TextureRect.new()
		badge.custom_minimum_size = Vector2(TRAIT_BADGE_SIZE, TRAIT_BADGE_SIZE)
		badge.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		badge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

		# アイコンが存在する場合は読み込み、なければプレースホルダ
		if TRAIT_ICONS.has(trait_name) and ResourceLoader.exists(TRAIT_ICONS[trait_name]):
			badge.texture = load(TRAIT_ICONS[trait_name])
		else:
			# プレースホルダ: 小さい色付き四角
			var placeholder = ColorRect.new()
			placeholder.custom_minimum_size = Vector2(TRAIT_BADGE_SIZE, TRAIT_BADGE_SIZE)
			placeholder.color = Color(0.5, 0.5, 0.5, 0.8)
			container.add_child(placeholder)
			continue

		container.add_child(badge)
