class_name InteractionComponent
extends Node

@export var raycast: RayCast3D
@export var inventory_component: InventoryComponent
@export var equipment_component: EquipmentComponent

var _last_highlighted_item = null

func _physics_process(delta: float) -> void:
	var target = null
	if raycast and raycast.is_colliding():
		var collider = raycast.get_collider()
		if collider and collider.has_method("set_outline"):
			target = collider

	if target != _last_highlighted_item:
		if _last_highlighted_item:
			_last_highlighted_item.set_outline(false)
		if target:
			target.set_outline(true)
		_last_highlighted_item = target

	if Input.is_action_just_pressed("pick_item"):
		if raycast and raycast.is_colliding():
			var collider = raycast.get_collider()
			# Check if the collider is an item that can be picked up
			if collider and collider.has_method("get_item_data"):
				var item_data = collider.get_item_data()
				if inventory_component and inventory_component.add_item(item_data):
					collider.queue_free()
					# If nothing is equipped, equip the new item.
					if equipment_component and not equipment_component.get_equipped_item():
						equipment_component.equip_item(item_data)

	if Input.is_action_just_pressed("drop_item"):
		if equipment_component:
			var equipped_item = equipment_component.get_equipped_item()
			if equipped_item and inventory_component:
				inventory_component.drop_item(equipped_item)
