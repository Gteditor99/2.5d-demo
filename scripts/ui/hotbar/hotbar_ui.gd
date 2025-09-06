extends HBoxContainer

@export var inventory_component: InventoryComponent
@export var hotbar_slot_scene: PackedScene

var hotbar_slots: Array[Control] = []

func _ready():
	if not inventory_component:
		push_error("HotbarUI: inventory_component is not assigned.")
		return

	inventory_component.hotbar_updated.connect(update_hotbar)
	create_hotbar_slots()
	update_hotbar()

func create_hotbar_slots():
	for i in range(inventory_component.inventory.hotbar_size):
		var slot = hotbar_slot_scene.instantiate()
		add_child(slot)
		hotbar_slots.append(slot)

func update_hotbar():
	for i in range(hotbar_slots.size()):
		var item = inventory_component.inventory.hotbar_items[i]
		hotbar_slots[i].update_item(item)

func set_active_slot(slot_index: int):
	for i in range(hotbar_slots.size()):
		hotbar_slots[i].set_active(i == slot_index)
