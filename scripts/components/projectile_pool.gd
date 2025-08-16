class_name ProjectilePool
extends Node

var projectile_scene: PackedScene
var pool: Array = []

func _init(scene: PackedScene, initial_size: int = 10):
	self.projectile_scene = scene
	for i in range(initial_size):
		var projectile = projectile_scene.instantiate()
		var projectile_component = projectile.get_node("ProjectileComponent")
		if projectile_component:
			projectile_component.returned_to_pool.connect(return_projectile)
		projectile.visible = false
		add_child(projectile)
		pool.append(projectile)

func get_projectile() -> Node3D:
	for projectile in pool:
		if not projectile.visible:
			projectile.visible = true
			return projectile
	
	# If no projectiles are available, create a new one
	var new_projectile = projectile_scene.instantiate()
	var projectile_component = new_projectile.get_node("ProjectileComponent")
	if projectile_component:
		projectile_component.returned_to_pool.connect(return_projectile)
	add_child(new_projectile)
	pool.append(new_projectile)
	return new_projectile

func return_projectile(projectile: Node3D):
	projectile.visible = false
