extends Control
class_name CardView

enum CardKind { UNIT, SPELL }

@export var card_kind: CardKind = CardKind.UNIT:
	set(value):
		card_kind = value
		_apply_kind()

@export var mana: int = 1:
	set(value):
		mana = value
		_update_text()

@export var card_name: String = "スライム":
	set(value):
		card_name = value
		_update_text()

@export_multiline var effect_text: String = "合成素材になる基本ユニット":
	set(value):
		effect_text = value
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

func _ready() -> void:
	_update_text()
	_apply_kind()
	if frame_texture:
		$FrameTexture.texture = frame_texture
	if top_icon_texture:
		$OverlayRoot/TopIcon.texture = top_icon_texture
	if art_texture:
		$OverlayRoot/ArtTexture.texture = art_texture

func _update_text() -> void:
	if not has_node("OverlayRoot/ManaLabel"):
		return
	$OverlayRoot/ManaLabel.text = str(mana)
	$OverlayRoot/NameLabel.text = card_name
	$OverlayRoot/EffectLabel.text = effect_text
	$OverlayRoot/StatRow/HpLabel.text = str(hp)
	$OverlayRoot/StatRow/AtkLabel.text = str(atk)
	$OverlayRoot/StatRow/SpdLabel.text = str(spd)

func _apply_kind() -> void:
	if not has_node("OverlayRoot/StatRow"):
		return
	$OverlayRoot/StatRow.visible = card_kind == CardKind.UNIT
