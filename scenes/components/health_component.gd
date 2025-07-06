extends Node

@export var entity: CharacterBody3D
@export var health: int = 100

func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		die()


func die() -> void:
	# signal death or perform cleanup
	entity.queue_free()
