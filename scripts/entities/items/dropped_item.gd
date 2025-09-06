extends RigidBody3D

@export var item_data: ItemData
@export var outline_material: Material

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

func get_item_data() -> ItemData:
	return item_data

func set_outline(enable: bool):
	if mesh_instance:
		mesh_instance.material_overlay = outline_material if enable else null
