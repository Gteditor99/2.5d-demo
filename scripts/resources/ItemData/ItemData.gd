@tool
class_name ItemData
extends Resource

@export var item_name: String = "New Item"
@export_multiline var item_description: String = "Description of the item."
@export var thumbnail: Texture2D

@export var model: PackedScene
@export var components: Array[Resource] = []
