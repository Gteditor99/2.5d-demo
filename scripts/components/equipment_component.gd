class_name EquipmentComponent
extends Node

signal item_equipped
signal item_unequipped

@export var viewmodel_anchor: NodePath
@export var weapon_system_component: WeaponSystemComponent

var equipped_item: ItemData
var equipped_item_instance: Node

func equip_item(item_data: ItemData) -> ItemData:
	# If the same item is already equipped, do nothing.
	if equipped_item and item_data and equipped_item.resource_path == item_data.resource_path:
		return equipped_item

	var previously_equipped = unequip_item()

	if item_data:
		equipped_item = item_data

		# Load the weapon data into the shared weapon system
		if weapon_system_component:
			weapon_system_component.load_weapon_data(item_data)
		else:
			push_error("EquipmentComponent: weapon_system_component is not assigned.")

		# Instantiate the visual model for the weapon
		if item_data.model:
			var anchor = get_node_or_null(viewmodel_anchor)
			if anchor:
				equipped_item_instance = item_data.model.instantiate()
				anchor.add_child(equipped_item_instance)

				if equipped_item_instance is Node3D:
					equipped_item_instance.transform = Transform3D.IDENTITY
				
				if anchor.has_method("set_weapon_node"):
					anchor.set_weapon_node(equipped_item_instance)
				
				# Set the initial state of the viewmodel
				if anchor.has_method("set_state"):
					anchor.set_state(ViewModelComponent.State.IDLE, item_data)
			else:
				push_error("EquipmentComponent: viewmodel_anchor is not assigned.")

		emit_signal("item_equipped", equipped_item)

	return previously_equipped

func unequip_item() -> ItemData:
	if not equipped_item:
		return null

	var unequipped = equipped_item
	
	# Unload the data from the weapon system
	if weapon_system_component:
		weapon_system_component.unload_weapon_data()

	# Destroy the visual model
	if equipped_item_instance:
		var anchor = get_node_or_null(viewmodel_anchor)
		if anchor and anchor.has_method("set_weapon_node"):
			anchor.set_weapon_node(null)
		equipped_item_instance.queue_free()
		equipped_item_instance = null

	equipped_item = null
	emit_signal("item_unequipped", unequipped)
	return unequipped

func get_equipped_item() -> ItemData:
	return equipped_item

func get_current_barrel_node() -> Node3D:
	if equipped_item_instance:
		return equipped_item_instance.find_child("spawnpoint", true, false)
	return null
