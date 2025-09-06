class_name InventoryComponent
extends Node

@export var inventory: InventoryData
@export var equipment_component: EquipmentComponent
@export var starting_items: Array[ItemData] = []

signal inventory_updated
signal hotbar_updated

const DroppedItemScene = preload("res://scenes/entities/items/dropped_item.tscn")

var selected_hotbar_slot: int = 0

func _ready():
	# Verify that the inventory is configured correctly.
	if not inventory:
		push_error("InventoryComponent is not configured. Assign an InventoryData resource to it in the editor.")
		return

	# Clear the inventory and add starting items.
	inventory.items.clear()
	inventory.hotbar_items.resize(inventory.hotbar_size)
	inventory.hotbar_items.fill(null)

	if not starting_items.is_empty():
		for i in range(starting_items.size()):
			add_item(starting_items[i])
			if i < inventory.hotbar_size:
				set_hotbar_item(i, starting_items[i])

	if equipment_component:
		equip_item(get_selected_hotbar_item())
	else:
		push_error("InventoryComponent: equipment_component is not assigned. Cannot equip starting item.")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("drop_item"):
		if equipment_component:
			var equipped_item = equipment_component.get_equipped_item()
			if equipped_item:
				drop_item(equipped_item)

	if event.is_action_pressed("hotbar_next"):
		set_selected_hotbar_slot((selected_hotbar_slot + 1) % inventory.hotbar_size)

	if event.is_action_pressed("hotbar_prev"):
		set_selected_hotbar_slot((selected_hotbar_slot - 1 + inventory.hotbar_size) % inventory.hotbar_size)

	for i in range(inventory.hotbar_size):
		if event.is_action_pressed("hotbar_" + str(i + 1)):
			set_selected_hotbar_slot(i)

func get_items() -> Array:
	if inventory:
		return inventory.items
	return []

func add_item(item_data: ItemData, quantity: int = 1):
	if inventory:
		for i in range(quantity):
			inventory.items.append(item_data)
		emit_signal("inventory_updated")
		return true
	return false

func remove_item(item_data: ItemData, quantity: int = 1) -> bool:
	if inventory:
		var removed_count = 0
		for i in range(inventory.items.size() - 1, -1, -1):
			if inventory.items[i].resource_path == item_data.resource_path:
				inventory.items.remove_at(i)
				removed_count += 1
				if removed_count == quantity:
					break
		if removed_count > 0:
			emit_signal("inventory_updated")
		return removed_count == quantity
	return false

func get_item_count(item_data: ItemData) -> int:
	if inventory:
		var count = 0
		for item in inventory.items:
			if item.resource_path == item_data.resource_path:
				count += 1
		return count
	return 0

func drop_item(item_data: ItemData) -> void:
	if not equipment_component:
		push_error("InventoryComponent: The 'equipment_component' variable is not assigned.")
		return

	var equipped_item = equipment_component.get_equipped_item()

	if equipped_item and equipped_item.resource_path == item_data.resource_path:
		equipment_component.unequip_item()

	if remove_item(item_data, 1):
		if item_data.model:
			var dropped_item = DroppedItemScene.instantiate()
			dropped_item.item_data = item_data
			dropped_item.mass = 1.0

			var item_instance = item_data.model.instantiate()
			dropped_item.add_child(item_instance)

			get_tree().current_scene.add_child(dropped_item)

			var parent = get_parent()
			if parent and parent is Node3D:
				dropped_item.global_transform = parent.global_transform
				dropped_item.global_transform.origin += parent.transform.basis.z * -2 + Vector3.UP

func equip_item(item_data: ItemData) -> void:
	if equipment_component:
		equipment_component.equip_item(item_data)
		emit_signal("inventory_updated")

func set_hotbar_item(slot_index: int, item: ItemData):
	if inventory and slot_index >= 0 and slot_index < inventory.hotbar_size:
		inventory.hotbar_items[slot_index] = item
		emit_signal("hotbar_updated")

func get_hotbar_item(slot_index: int) -> ItemData:
	if inventory and slot_index >= 0 and slot_index < inventory.hotbar_size:
		return inventory.hotbar_items[slot_index]
	return null

func get_selected_hotbar_item() -> ItemData:
	return get_hotbar_item(selected_hotbar_slot)

func set_selected_hotbar_slot(slot_index: int):
	if slot_index >= 0 and slot_index < inventory.hotbar_size:
		selected_hotbar_slot = slot_index
		equip_item(get_selected_hotbar_item())
		emit_signal("hotbar_updated")
