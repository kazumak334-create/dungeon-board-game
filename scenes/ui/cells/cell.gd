extends Panel

var row: int
var col: int

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		print("クリック:", row, col)
