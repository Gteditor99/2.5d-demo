extends RigidBody3D

const ProjectileComponent = preload("res://scripts/components/projectile_component.gd")
@onready var projectile_component: ProjectileComponent = $ProjectileComponent

func _ready():
	if not projectile_component:
		push_error("Bullet requires a ProjectileComponent.")
		queue_free()
		return
	
	# The ProjectileComponent now handles all the logic.
	# This script is now just a container for the RigidBody3D and the component.
	# You can add visual effects or other non-core logic here if needed.
