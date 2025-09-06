extends Panel

@onready var texture_rect: TextureRect = $TextureRect

func update_item(item: ItemData):
	if item:
		texture_rect.texture = item.thumbnail
		texture_rect.visible = true
	else:
		texture_rect.texture = null
		texture_rect.visible = false

func set_active(is_active: bool):
	if is_active:
		modulate = Color(1, 1, 1, 1)
	else:
		modulate = Color(0.5, 0.5, 0.5, 1)
