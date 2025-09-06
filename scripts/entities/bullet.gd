extends Area3D

#const ProjectileComponent = preload("res://scripts/components/projectile_component.gd")
@onready var projectile_component: ProjectileComponent = $ProjectileComponent

func _ready():
	if not projectile_component:
		push_error("Bullet requires a ProjectileComponent.")
		queue_free()
		return
