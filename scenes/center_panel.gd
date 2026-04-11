extends Panel

func _ready() -> void:
	var index := 0

	for cell in $GridContainer.get_children():
		cell.row = index / 3
		cell.col = index % 3
		index += 1
