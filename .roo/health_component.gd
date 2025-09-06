class_name HealthComponent
extends Node

signal health_changed(health)
signal died

@export var max_health: int = 100

var health: int

func _ready():
	health = max_health

func take_damage(damage: int):
	health -= damage
	emit_signal("health_changed", health)
	if health <= 0:
		emit_signal("died")