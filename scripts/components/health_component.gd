class_name HealthComponent
extends Node

signal died
signal health_updated(new_health: int)

@export var entity: CharacterBody3D
@export var max_health: int = 100
var current_health: int

func _ready() -> void:
	current_health = max_health

func take_damage(amount: int) -> void:
	current_health -= amount
	emit_signal("health_updated", current_health)
	if current_health <= 0:
		die()

func die() -> void:
	emit_signal("died")
	#entity.queue_free()
