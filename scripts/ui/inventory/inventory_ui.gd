# inventory_ui.gd
class_name InventoryUI
extends Control

signal item_equipped(item_data: ItemData)
signal item_dropped(item_data: ItemData)

@export var inventory_component: NodePath

@onready var item_grid: GridContainer = $Panel/MarginContainer/VBoxContainer/HBoxContainer/ScrollContainer/ItemGrid
@onready var item_details_panel: PanelContainer = $Panel/MarginContainer/VBoxContainer/HBoxContainer/item_details_panel
@onready var item_thumbnail: TextureRect = $Panel/MarginContainer/VBoxContainer/HBoxContainer/item_details_panel/MarginContainer/VBoxContainer/ItemThumbnail
@onready var item_name: Label = $Panel/MarginContainer/VBoxContainer/HBoxContainer/item_details_panel/MarginContainer/VBoxContainer/ItemName
@onready var item_description: Label = $Panel/MarginContainer/VBoxContainer/HBoxContainer/item_details_panel/MarginContainer/VBoxContainer/ItemDescription
@onready var equip_button: Button = $Panel/MarginContainer/VBoxContainer/HBoxContainer/item_details_panel/MarginContainer/VBoxContainer/ActionButtons/UseButton
@onready var drop_button: Button = $Panel/MarginContainer/VBoxContainer/HBoxContainer/item_details_panel/MarginContainer/VBoxContainer/ActionButtons/DropButton

const InventorySlotUI: PackedScene = preload("res://scenes/ui/inventory/inventory_slot.tscn")

var inventory: InventoryComponent
var selected_item: ItemData = null


func _ready() -> void:
	# The inventory should be able to process input even when the game is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if get_node_or_null(inventory_component):
		inventory = get_node(inventory_component)
		inventory.inventory_updated.connect(update_ui)
		update_ui()
	else:
		print_debug("InventoryComponent not assigned to InventoryUI")
	
	equip_button.text = "Equip"
	equip_button.pressed.connect(_on_equip_button_pressed)
	drop_button.pressed.connect(_on_drop_button_pressed)
	
	# Start with the inventory closed.
	close_inventory()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		if visible:
			close_inventory()
		else:
			open_inventory()
	
	if visible and selected_item:
		if event.is_action_pressed("drop_item"):
			_on_drop_button_pressed()
			
		if event.is_action_pressed("equip_item"):
			_on_equip_button_pressed()
			close_inventory()


func open_inventory() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	update_ui()


func close_inventory() -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().paused = false
	_clear_selection()


func update_ui() -> void:
	# Clear existing slots
	for child in item_grid.get_children():
		child.queue_free()

	# Hide details and clear selection when UI is refreshed
	_clear_selection()

	if not inventory:
		return

	# Create a dictionary to count item quantities
	var item_counts: Dictionary = {}
	for item: ItemData in inventory.get_items():
		if item_counts.has(item):
			item_counts[item] += 1
		else:
			item_counts[item] = 1

	# Populate grid with new slots
	for item_data: ItemData in item_counts:
		var quantity: int = item_counts[item_data]
		var slot: Control = InventorySlotUI.instantiate()
		item_grid.add_child(slot)
		slot.display_item(item_data, quantity)
		slot.pressed.connect(_on_slot_pressed.bind(item_data))


func _on_slot_pressed(item_data: ItemData) -> void:
	selected_item = item_data
	item_thumbnail.texture = item_data.thumbnail
	item_name.text = item_data.item_name
	item_description.text = item_data.item_description
	item_details_panel.visible = true


func _clear_selection() -> void:
	selected_item = null
	item_details_panel.visible = false
	item_thumbnail.texture = null
	item_name.text = ""
	item_description.text = ""


func _on_equip_button_pressed() -> void:
	if selected_item and inventory:
		inventory.equip_item(selected_item)
		item_equipped.emit(selected_item)


func _on_drop_button_pressed() -> void:
	if selected_item and inventory:
		inventory.drop_item(selected_item)
		item_dropped.emit(selected_item)
