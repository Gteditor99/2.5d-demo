# inventory_slot.gd
class_name InventorySlotUI
extends TextureButton

var item_data: ItemData

func display_item(new_item_data: ItemData, quantity: int):
	item_data = new_item_data
	var item_icon = $ItemIcon
	var quantity_label = $QuantityLabel
	
	if item_data:
		item_icon.texture = item_data.thumbnail
		item_icon.visible = true
		
		if quantity > 1:
			quantity_label.text = str(quantity)
			quantity_label.visible = true
		else:
			quantity_label.visible = false
	else:
		item_icon.visible = false
		quantity_label.visible = false
